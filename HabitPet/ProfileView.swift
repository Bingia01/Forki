import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: UserDataStore
    @ObservedObject var nutrition: NutritionState
    @ObservedObject private var account = AccountService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirmRestore = false
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("This device") {
                    TextField("Name", text: $store.userData.name)
                    Picker("Pet", selection: $store.userData.selectedCharacter) {
                        ForEach(CharacterType.allCases) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Daily goal: \(nutrition.caloriesGoal) kcal", value: Binding(get: { nutrition.caloriesGoal }, set: { nutrition.setGoal($0) }), in: 1000...4000, step: 50)
                        .accessibilityIdentifier("profile-calorie-goal")
                    Toggle("Meal reminders", isOn: Binding(get: { store.userData.notifications }, set: { enabled in
                        run { store.userData.notifications = try await MealReminders.configure(enabled: enabled) }
                    }))
                    Text("Profile and meals are saved on this device. Cloud backups are optional and run only when you choose Back Up or Restore.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Account and backup") {
                    if let session = account.session {
                        Text(session.user.email ?? "Signed in")
                        Button("Back Up This Device") { run {
                            try await account.backup(profile: store.userData, meals: nutrition.loggedMeals, goal: nutrition.caloriesGoal)
                            message = "Backup saved."
                        } }
                        Button("Restore Account Backup") { confirmRestore = true }
                        Button("Delete Account and Backups", role: .destructive) { confirmDelete = true }
                        Button("Sign Out") { run { await account.signOut() } }
                    } else {
                        TextField("Account email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                        SecureField("Password", text: $password)
                        Button("Sign In") { authenticate(register: false) }
                        Button("Create Account") { authenticate(register: true) }
                        Text("Confirm your email after creating an account, then sign in. Local onboarding alone does not create an account.").font(.caption)
                    }
                }
                if busy { ProgressView() }
                if let message { Text(message).accessibilityIdentifier("profile-message") }
            }
            .disabled(busy)
            .navigationTitle("Profile")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Permanently delete your account, cloud backups, and this device’s data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) { run {
                    try await account.deleteAccount()
                    _ = try await MealReminders.configure(enabled: false)
                    nutrition.reset()
                    store.reset()
                    dismiss()
                } }
            }
            .confirmationDialog("Replace this device’s profile and meals with the account backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Restore Backup", role: .destructive) { run {
                    let backup = try await account.restore()
                    store.userData = backup.profile
                    nutrition.replaceAll(with: backup.meals)
                    nutrition.setGoal(backup.calorie_goal)
                    store.userData.notifications = try await MealReminders.configure(enabled: backup.profile.notifications)
                    message = "Backup restored."
                } }
            }
        }
    }
    private func authenticate(register: Bool) {
        guard email.contains("@"), password.count >= 8 else { message = "Enter a valid email and a password with at least 8 characters."; return }
        run {
            let confirmation = try await account.authenticate(email: email, password: password, register: register, name: store.userData.name)
            password = ""
            message = confirmation ? "Check your inbox to confirm your email, then sign in." : "Signed in."
        }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true; message = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await action() } catch { message = error.localizedDescription }
        }
    }
}
