import AuthenticationServices
import Foundation
import LocalAuthentication
import Security
import UIKit

enum DraftsExpoSessionError: LocalizedError {
  case cancelled
  case alreadyAuthenticating
  case invalidConfiguration
  case presentationUnavailable
  case authenticationFailed
  case invalidCallback
  case invalidSession
  case validationUnavailable
  case storageUnavailable

  var errorDescription: String? {
    switch self {
    case .cancelled: return "Expo sign-in was canceled."
    case .alreadyAuthenticating: return "Expo sign-in is already in progress."
    case .invalidConfiguration: return "Expo sign-in is not configured for this build."
    case .presentationUnavailable: return "Open the app to sign in to Expo."
    case .authenticationFailed: return "Expo sign-in could not start. Please try again."
    case .invalidCallback: return "Expo sign-in returned an invalid response. Please try again."
    case .invalidSession: return "Expo did not accept this session. Please sign in again."
    case .validationUnavailable: return "Could not verify Expo sign-in. Check your connection and try again."
    case .storageUnavailable: return "Could not securely save your Expo session. Please try again."
    }
  }
}

/// Call this helper on the main thread. Credentials stay in memory and in this
/// app/project's device-only Keychain entry, never in preferences or diagnostics.
final class DraftsExpoSession: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var cachedSecret: String?
  private var loadedKeychain = false
  private var attempt: UUID?
  private var authenticationSession: ASWebAuthenticationSession?
  private var validation: DraftsExpoSessionValidation?
  private var presentationWindow: UIWindow?
  private var completion: ((Result<Void, Error>) -> Void)?

  override init() {
    super.init()
  }

  var sessionSecret: String? {
    assertMainThread()
    if !loadedKeychain { loadKeychain() }
    return cachedSecret
  }

  var isSignedIn: Bool { sessionSecret != nil }

  var isAuthenticating: Bool {
    assertMainThread()
    return attempt != nil
  }

  func signIn(presenting controller: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
    assertMainThread()
    guard attempt == nil else { return completion(.failure(DraftsExpoSessionError.alreadyAuthenticating)) }
    guard let scheme = callbackScheme else { return completion(.failure(DraftsExpoSessionError.invalidConfiguration)) }
    guard let window = controller.viewIfLoaded?.window else {
      return completion(.failure(DraftsExpoSessionError.presentationUnavailable))
    }
    var random = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else {
      return completion(.failure(DraftsExpoSessionError.authenticationFailed))
    }
    let nonce = random.map { String(format: "%02x", $0) }.joined()
    let redirect = "\(scheme)://auth/\(nonce)"
    var login = URLComponents(string: "https://expo.dev/login")!
    login.queryItems = [
      URLQueryItem(name: "confirm_account", value: "1"),
      URLQueryItem(name: "app_redirect_uri", value: redirect)
    ]
    guard let loginURL = login.url else { return completion(.failure(DraftsExpoSessionError.invalidConfiguration)) }
    let identifier = UUID()
    attempt = identifier
    self.completion = completion
    presentationWindow = window
    let authentication = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: scheme) { [weak self] callback, error in
      DispatchQueue.main.async {
        guard let self, self.attempt == identifier else { return }
        if let error {
          let native = error as NSError
          let cancelled = native.domain == ASWebAuthenticationSessionError.errorDomain &&
            native.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
          self.finish(identifier, .failure(cancelled ? DraftsExpoSessionError.cancelled : .authenticationFailed))
          return
        }
        guard let secret = Self.secret(from: callback, scheme: scheme, nonce: nonce) else {
          self.finish(identifier, .failure(DraftsExpoSessionError.invalidCallback))
          return
        }
        let validation = DraftsExpoSessionValidation(secret: secret) { [weak self] result in
          guard let self, self.attempt == identifier else { return }
          switch result {
          case .success:
            do {
              try self.saveKeychain(secret)
              self.cachedSecret = secret
              self.loadedKeychain = true
              self.finish(identifier, .success(()))
            } catch {
              self.finish(identifier, .failure(DraftsExpoSessionError.storageUnavailable))
            }
          case .failure(let error): self.finish(identifier, .failure(error))
          }
        }
        self.validation = validation
        validation.start()
      }
    }
    authenticationSession = authentication
    authentication.presentationContextProvider = self
    authentication.prefersEphemeralWebBrowserSession = true
    if !authentication.start() {
      finish(identifier, .failure(DraftsExpoSessionError.authenticationFailed))
    }
  }

  func signOut() {
    assertMainThread()
    cachedSecret = nil
    loadedKeychain = true
    if let query = keychainQuery { SecItemDelete(query as CFDictionary) }
    if let identifier = attempt { finish(identifier, .failure(DraftsExpoSessionError.cancelled)) }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    assertMainThread()
    return presentationWindow ?? ASPresentationAnchor()
  }

  private func finish(_ identifier: UUID, _ result: Result<Void, Error>) {
    assertMainThread()
    guard attempt == identifier else { return }
    // Invalidate the attempt before canceling either operation: late callbacks
    // must not save a session after sign-out or complete a later sign-in.
    attempt = nil
    let callback = completion
    completion = nil
    let authentication = authenticationSession
    authenticationSession = nil
    let pendingValidation = validation
    validation = nil
    presentationWindow = nil
    authentication?.cancel()
    pendingValidation?.cancel()
    callback?(result)
  }

  private var callbackScheme: String? {
    guard let project = Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsProjectID") as? String,
      let projectID = UUID(uuidString: project),
      let scheme = Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsAuthScheme") as? String,
      scheme == "expo-drafts.\(projectID.uuidString.lowercased())",
      let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
      urlTypes.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(scheme) == true }) else { return nil }
    return scheme
  }

  private static func secret(from callback: URL?, scheme: String, nonce: String) -> String? {
    guard let callback, callback.absoluteString.utf8.count <= 32_768,
      let url = URLComponents(url: callback, resolvingAgainstBaseURL: false),
      url.scheme == scheme, url.host == "auth", url.user == nil, url.password == nil,
      url.port == nil, url.fragment == nil, url.percentEncodedPath == "/\(nonce)" else { return nil }
    let secrets = (url.queryItems ?? []).filter { $0.name == "session_secret" }
    guard secrets.count == 1, let secret = secrets[0].value, validSecret(secret) else { return nil }
    return secret
  }

  private static func validSecret(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 16_384 && value.utf8.allSatisfy { (0x21...0x7e).contains($0) }
  }

  private var keychainQuery: [String: Any]? {
    guard let scheme = callbackScheme, let bundleID = Bundle.main.bundleIdentifier else { return nil }
    let context = LAContext()
    context.interactionNotAllowed = true
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "\(bundleID).expo-drafts.expo-session.v1",
      kSecAttrAccount as String: scheme,
      kSecAttrSynchronizable as String: false,
      kSecUseAuthenticationContext as String: context
    ]
  }

  private func loadKeychain() {
    guard var query = keychainQuery else { return }
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { loadedKeychain = true; return }
    // An unavailable Keychain can be tried again after the device is unlocked.
    guard status == errSecSuccess else { return }
    loadedKeychain = true
    guard let data = result as? Data, data.count <= 16_384,
      let value = String(data: data, encoding: .utf8), Self.validSecret(value) else { return }
    cachedSecret = value
  }

  private func saveKeychain(_ secret: String) throws {
    guard let query = keychainQuery else { throw DraftsExpoSessionError.invalidConfiguration }
    let attributes: [String: Any] = [
      kSecValueData as String: Data(secret.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]
    let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updated == errSecSuccess { return }
    guard updated == errSecItemNotFound else { throw DraftsExpoSessionError.storageUnavailable }
    var item = query
    attributes.forEach { item[$0.key] = $0.value }
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
      throw DraftsExpoSessionError.storageUnavailable
    }
  }

  private func assertMainThread() {
    precondition(Thread.isMainThread, "Expo sign-in must be used on the main thread.")
  }
}

/// URLSession delivers every delegate callback on the main queue. The request
/// has no cookie store, credential store, cache, or permitted redirect target.
private final class DraftsExpoSessionValidation: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private static let endpoint = URL(string: "https://api.expo.dev/graphql")!
  private static let maximumBytes = 65_536
  private var session: URLSession?
  private var task: URLSessionDataTask?
  private var data = Data()
  private var completion: ((Result<Void, Error>) -> Void)?
  private var finished = false

  init(secret: String, completion: @escaping (Result<Void, Error>) -> Void) {
    self.completion = completion
    super.init()
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    config.urlCredentialStorage = nil
    config.urlCache = nil
    config.timeoutIntervalForRequest = 20
    config.timeoutIntervalForResource = 25
    config.waitsForConnectivity = false
    let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    self.session = session
    var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.httpShouldHandleCookies = false
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(secret, forHTTPHeaderField: "expo-session")
    request.httpBody = Data(#"{"query":"query ExpoDraftsCurrentActor { meActor { __typename id } }"}"#.utf8)
    task = session.dataTask(with: request)
  }

  func start() { task?.resume() }

  func cancel() { finish(.failure(DraftsExpoSessionError.cancelled)) }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
    finish(.failure(DraftsExpoSessionError.validationUnavailable))
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard !finished, let http = response as? HTTPURLResponse,
      http.url == Self.endpoint, http.statusCode == 200,
      response.expectedContentLength <= Self.maximumBytes else {
      completionHandler(.cancel)
      let status = (response as? HTTPURLResponse)?.statusCode
      finish(.failure([401, 403].contains(status ?? 0) ? DraftsExpoSessionError.invalidSession : .validationUnavailable))
      return
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive received: Data) {
    guard !finished else { return }
    guard received.count <= Self.maximumBytes - data.count else {
      finish(.failure(DraftsExpoSessionError.validationUnavailable))
      return
    }
    data.append(received)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard !finished else { return }
    guard error == nil else { return finish(.failure(DraftsExpoSessionError.validationUnavailable)) }
    guard let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      (response["errors"] == nil || response["errors"] is NSNull || (response["errors"] as? [Any])?.isEmpty == true),
      let payload = response["data"] as? [String: Any], let actor = payload["meActor"] as? [String: Any],
      let id = actor["id"] as? String, !id.isEmpty, id.utf8.count <= 512,
      let type = actor["__typename"] as? String, !type.isEmpty, type.utf8.count <= 128 else {
      return finish(.failure(DraftsExpoSessionError.invalidSession))
    }
    finish(.success(()))
  }

  private func finish(_ result: Result<Void, Error>) {
    guard !finished else { return }
    finished = true
    let callback = completion
    completion = nil
    task?.cancel()
    task = nil
    session?.invalidateAndCancel()
    session = nil
    data.removeAll()
    callback?(result)
  }
}
