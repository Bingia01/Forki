import Foundation
import Combine
import Security

@MainActor final class AccountService: ObservableObject {
    static let shared = AccountService()
    struct User: Codable { let id: UUID; let email: String? }
    struct Session: Codable {
        let access_token: String
        let refresh_token: String
        let expires_at: Double?
        let expires_in: Double?
        let user: User
    }
    struct Backup: Codable {
        let user_id: UUID
        let profile: UserData
        let meals: [LoggedFood]
        let calorie_goal: Int
    }
    @Published private(set) var session: Session?
    private let keychainService = "com.forki.auth.session"
    private let network: URLSession
    init(network: URLSession = .shared) {
        self.network = network
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            session = try? JSONDecoder().decode(Session.self, from: data)
        }
    }
    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: "session"]
    }
    private func save(_ value: Session?) throws {
        let query = keychainQuery
        if let value {
            let data = try JSONEncoder().encode(value)
            let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw AccountError.storage }
            } else if status != errSecSuccess { throw AccountError.storage }
        } else { SecItemDelete(query as CFDictionary) }
        session = value
    }
    enum AccountError: LocalizedError {
        case signIn, unavailable, storage, noBackup
        var errorDescription: String? {
            switch self {
            case .signIn: return "Sign in in Profile to use cloud services. Check your email and password, and confirm your email if you just registered."
            case .unavailable: return "The account service is unavailable. Your data is still saved on this device."
            case .storage: return "Your session could not be saved securely. Please try signing in again."
            case .noBackup: return "There is no backup for this account yet."
            }
        }
    }
    private func request(_ path: String, method: String = "POST", body: Data? = nil, token: String? = nil) throws -> URLRequest {
        let config = try BackendConfiguration()
        let url = try config.accountURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 20
        request.setValue(config.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token ?? config.publicKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await network.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AccountError.unavailable }
        guard (200..<300).contains(http.statusCode) else { throw http.statusCode == 400 || http.statusCode == 401 ? AccountError.signIn : AccountError.unavailable }
        return data
    }
    // Returns true when registration is awaiting email confirmation.
    func authenticate(email: String, password: String, register: Bool, name: String = "") async throws -> Bool {
        var fields: [String: Any] = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        if register { fields["data"] = ["name": name] }
        let body = try JSONSerialization.data(withJSONObject: fields)
        let path = register ? "auth/v1/signup" : "auth/v1/token?grant_type=password"
        let data = try await send(request(path, body: body))
        if let value = try? JSONDecoder().decode(Session.self, from: data) { try save(value); return false }
        if register { return true }
        throw AccountError.signIn
    }
    func accessToken() async throws -> String {
        guard let session else { throw AccountError.signIn }
        if let expiry = session.expires_at, expiry > Date().timeIntervalSince1970 + 60 { return session.access_token }
        let data = try await send(request("auth/v1/token?grant_type=refresh_token", body: JSONEncoder().encode(["refresh_token": session.refresh_token])))
        let fresh = try JSONDecoder().decode(Session.self, from: data)
        try save(fresh)
        return fresh.access_token
    }
    func deleteAccount() async throws {
        let token = try await accessToken()
        let config = try BackendConfiguration()
        var req = URLRequest(url: config.functionsURL.appendingPathComponent("delete_account"))
        req.httpMethod = "DELETE"; req.timeoutInterval = 30
        req.setValue(config.publicKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await send(req)
        try save(nil)
    }
    func signOut() async {
        if let token = try? await accessToken() { _ = try? await send(request("auth/v1/logout", token: token)) }
        try? save(nil)
    }
    func backup(profile: UserData, meals: [LoggedFood], goal: Int) async throws {
        let token = try await accessToken()
        guard let session else { throw AccountError.signIn }
        let value = Backup(user_id: session.user.id, profile: profile, meals: meals, calorie_goal: goal)
        var req = try request("rest/v1/forki_backups?on_conflict=user_id", body: JSONEncoder().encode(value), token: token)
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        _ = try await send(req)
    }
    func restore() async throws -> Backup {
        let token = try await accessToken()
        guard let session else { throw AccountError.signIn }
        let data = try await send(request("rest/v1/forki_backups?user_id=eq.\(session.user.id.uuidString)&select=*", method: "GET", token: token))
        guard let value = try JSONDecoder().decode([Backup].self, from: data).first else { throw AccountError.noBackup }
        return value
    }
}
