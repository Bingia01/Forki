import SwiftUI

// Native camera/photo-library capture keeps clean checkouts independent of a
// developer's Downloads directory. Analysis always uses the configured backend.
struct CalorieCameraBridge: View {
    let onComplete: (AICameraCompletion) -> Void
    var body: some View { AICameraView(onComplete: onComplete) }
}
