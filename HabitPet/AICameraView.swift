import SwiftUI
import UIKit
import AVFoundation

struct AICameraNutritionResult {
    var label: String
    var confidence: Double
    var volumeML: Double
    var sigmaV: Double
    var rho: Double
    var sigmaRho: Double
    var e: Double
    var sigmaE: Double
    var cFused: Double
    var sigmaCFused: Double
    let protein: Double?         // OPTIONAL grams (nil if unknown)
    let carbs: Double?           // OPTIONAL grams (nil if unknown)
    let fats: Double?            // OPTIONAL grams (nil if unknown)
}

enum AICameraCompletion {
    case success(AICameraNutritionResult, sourceType: UIImagePickerController.SourceType)
    case cancelled
    case failed(Error)
}


struct AICameraView: View {
    var onComplete: (AICameraCompletion) -> Void
    @State private var source: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingPicker = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var analysisTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "camera.viewfinder").font(.system(size: 64))
                Text("Photograph your meal or its nutrition label.")
                Text("Estimates may be inaccurate. Review the food and portion before logging.")
                    .font(.caption).foregroundStyle(.secondary)
                if isAnalyzing { ProgressView("Analyzing photo…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("camera-error") }
                Button("Take Photo") { openCamera() }
                    .disabled(isAnalyzing || !UIImagePickerController.isSourceTypeAvailable(.camera))
                Button("Choose Photo") { source = .photoLibrary; showingPicker = true }
                    .disabled(isAnalyzing)
            }
            .padding().multilineTextAlignment(.center)
            .navigationTitle("Food Camera")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { analysisTask?.cancel(); onComplete(.cancelled) }
            } }
            .sheet(isPresented: $showingPicker) {
                FoodPhotoPicker(source: source) { image in
                    showingPicker = false
                    if let image { analyze(image) }
                }
            }
        }
        .onDisappear { analysisTask?.cancel() }
    }

    private func openCamera() {
        Task { @MainActor in
            let permitted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: permitted = true
            case .notDetermined: permitted = await AVCaptureDevice.requestAccess(for: .video)
            default: permitted = false
            }
            if permitted { source = .camera; showingPicker = true }
            else { errorMessage = "Allow camera access in Settings, or choose a photo." }
        }
    }
    private func analyze(_ image: UIImage) {
        errorMessage = nil
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.75) else {
            errorMessage = "This photo could not be read."; return
        }
        isAnalyzing = true
        let capturedSource = source
        analysisTask = Task { @MainActor in
            defer { isAnalyzing = false }
            do {
                let result = try await FoodAnalysisService().analyze(data)
                try Task.checkCancellation()
                onComplete(.success(result, sourceType: capturedSource))
            } catch is CancellationError { }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }
}

private struct FoodPhotoPicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onSelect: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSelect: (UIImage?) -> Void
        init(onSelect: @escaping (UIImage?) -> Void) { self.onSelect = onSelect }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onSelect(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onSelect(nil) }
    }
}
