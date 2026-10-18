import Foundation

struct BackendConfiguration {
    let functionsURL: URL
    let publicKey: String
    init(functionsURL: URL, publicKey: String) {
        self.functionsURL = functionsURL
        self.publicKey = publicKey
    }
    func accountURL(path: String) throws -> URL {
        guard var origin = URLComponents(url: functionsURL, resolvingAgainstBaseURL: true) else {
            throw BackendConfigurationError.missingConfiguration
        }
        origin.path = "/"; origin.query = nil; origin.fragment = nil
        guard let base = origin.url, let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw BackendConfigurationError.missingConfiguration
        }
        return url
    }
    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "CalorieCameraConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListDecoder().decode([String: String].self, from: data),
              let base = values["SUPABASE_FUNCTIONS_URL"], let endpoint = URL(string: base),
              endpoint.scheme == "https", let key = values["SUPABASE_ANON_KEY"], !key.isEmpty else {
            throw BackendConfigurationError.missingConfiguration
        }
        functionsURL = endpoint
        publicKey = key
    }
}

enum BackendConfigurationError: LocalizedError {
    case missingConfiguration
    var errorDescription: String? { "Food services are not configured. Please use the built-in food list." }
}
