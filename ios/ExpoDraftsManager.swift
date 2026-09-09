import Foundation
import UIKit
import EXUpdates

/// This object and its window belong to the application, outside the React lifecycle.
final class ExpoDraftsManager {
  static let shared = ExpoDraftsManager()
  private var window: DraftsWindow?
  private var visible = true
  private weak var picker: DraftsViewController?
  private(set) var switching = false
  private var catalogTask: URLSessionDataTask?
  private var buildsCatalogTask: URLSessionDataTask?
  private let expoSession = DraftsExpoSession()
  private let easClient = DraftsEASClient()
  private var catalogGeneration = UUID()
  private(set) var cachedCatalog: DraftCatalog?
  private(set) var discoveryAccessError: String?
  private var installationRequest: DraftBuildManifestRequest?
  private var preparingInstallation = false
  private let installationState = DraftInstallationStateStore()
  private var buildsCatalogGeneration = UUID()
  private(set) var buildsCatalog: DraftBuildCatalog?
  private(set) var buildsCatalogLoading = false
  private(set) var buildsCatalogError: String?

  var enabled: Bool { Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsEnabled") as? Bool ?? false }
  var projectID: String { Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsProjectID") as? String ?? "" }
  var buildURL: String? { Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsBuildURL") as? String }
  var buildProfile: String { Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsBuildProfile") as? String ?? "drafts-device" }
  var usesEASDiscovery: Bool {
    (Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsCatalogURL") as? String)?.isEmpty != false
  }
  var isSignedIn: Bool { expoSession.isSignedIn }
  var isAuthenticating: Bool { expoSession.isAuthenticating }

  func signIn(presenting controller: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
    expoSession.signIn(presenting: controller, completion: completion)
  }

  func signOut() {
    catalogGeneration = UUID()
    buildsCatalogGeneration = UUID()
    easClient.cancel()
    expoSession.signOut()
    cachedCatalog = nil
    buildsCatalog = nil
    buildsCatalogLoading = false
    buildsCatalogError = nil
    discoveryAccessError = nil
  }

  private func handleDiscoveryError(_ error: Error) {
    guard let error = error as? DraftEASError else { return }
    if error.requiresSignIn {
      signOut()
    } else if error.invalidatesCachedData {
      catalogGeneration = UUID()
      buildsCatalogGeneration = UUID()
      easClient.cancel()
      cachedCatalog = nil
      buildsCatalog = nil
      buildsCatalogLoading = false
      discoveryAccessError = error.localizedDescription
    }
  }
  var buildRequestsConfigured: Bool {
    let url = Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsBuildRequestURL") as? String
    return url?.isEmpty == false
  }

  private var constants: [String: Any?] {
    guard AppController.isInitialized() else { return [:] }
    return AppController.sharedInstance.getConstantsForModule().toModuleConstantsMap()
  }

  var runtimeVersion: String { constants["runtimeVersion"] as? String ?? "" }
  var currentChannel: String { constants["channel"] as? String ?? "" }
  var currentUpdateID: String { (constants["updateId"] as? String ?? "").lowercased() }
  var updatesEnabled: Bool { constants["isEnabled"] as? Bool ?? false }
  var isEmbeddedLaunch: Bool { constants["isEmbeddedLaunch"] as? Bool ?? false }
  var canRunBundledVersion: Bool {
    guard updatesEnabled,
      let controller = AppController.sharedInstance as? EnabledAppController else { return false }
    return controller.getEmbeddedUpdate() != nil
  }

  var pendingInstallation: DraftInstallationRequest? {
    installationState.active(projectID: projectID, currentRuntime: runtimeVersion)
  }

  func dismissInstallationStatus() {
    installationState.clear()
  }

  func bundleIdentity(drafts: [DraftEntry]) -> DraftBundleIdentity {
    DraftBundleIdentity(
      constants: constants, drafts: drafts,
      nativeVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
      nativeBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    )
  }

  func state() -> [String: Any] {
    [
      "enabled": enabled,
      "runtimeVersion": runtimeVersion,
      "channel": currentChannel,
      "updateId": currentUpdateID,
      "isSwitching": switching,
      "isUpdatesEnabled": updatesEnabled
    ]
  }

  func install() {
    guard enabled else { return }
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }) else { return }
    if window?.windowScene !== scene {
      window?.isHidden = true
      window = DraftsWindow(windowScene: scene, onOpen: { [weak self] in self?.open() })
    }
    window?.isHidden = !visible
  }

  func setVisible(_ value: Bool) {
    visible = value
    install()
  }

  func open() {
    guard enabled else { return }
    visible = true
    install()
    guard picker == nil, let root = window?.rootViewController else { return }
    let viewController = DraftsViewController(manager: self)
    picker = viewController
    let navigation = UINavigationController(rootViewController: viewController)
    navigation.view.accessibilityViewIsModal = true
    navigation.modalPresentationStyle = .pageSheet
    if let sheet = navigation.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
    }
    root.present(navigation, animated: true)
  }

  func fetchCatalog(completion: @escaping (Result<DraftCatalog, Error>) -> Void) {
    catalogTask?.cancel()
    let generation = UUID()
    catalogGeneration = generation
    if usesEASDiscovery {
      discoveryAccessError = nil
      guard let secret = expoSession.sessionSecret else {
        completion(.failure(DraftsError.message("Sign in to Expo to browse this project's EAS Updates.")))
        return
      }
      easClient.fetchCatalog(projectID: projectID, sessionSecret: secret) { [weak self] result in
        guard let self, self.catalogGeneration == generation else { return }
        switch result {
        case .success(let catalog): self.cachedCatalog = catalog
        case .failure(let error): self.handleDiscoveryError(error)
        }
        completion(result)
      }
      return
    }
    guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsCatalogURL") as? String,
      let url = URL(string: rawURL), url.isDraftsTrustedURL else {
      completion(.failure(DraftsError.message("Add a secure catalogUrl to the expo-drafts config plugin, then create a new native build.")))
      return
    }
    guard !projectID.isEmpty else {
      completion(.failure(DraftsError.message("The build is missing its EAS project ID. Configure expo-drafts and create a new build.")))
      return
    }
    // GitHub caches anonymous Contents API responses. Explicit refreshes need a
    // unique cache key; arbitrary catalog endpoints retain their original URLs.
    var requestURL = url
    if url.host == "api.github.com", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "expo-drafts-refresh", value: UUID().uuidString)]
      requestURL = components.url ?? url
    }
    var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25)
    request.setValue(url.host == "api.github.com" ? "application/vnd.github.raw+json" : "application/json", forHTTPHeaderField: "Accept")
    let expectedProjectID = projectID
    catalogTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      if (error as NSError?)?.code == NSURLErrorCancelled { return }
      let result: Result<DraftCatalog, Error> = Result {
        if let error { throw error }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
          throw DraftsError.message("The draft catalog could not be loaded. Check its URL and try again.")
        }
        guard http.url?.isDraftsTrustedURL == true else {
          throw DraftsError.message("The catalog redirected to an insecure URL. Use an HTTPS catalog URL.")
        }
        guard data.count <= 5_000_000 else { throw DraftsError.message("The draft catalog is too large.") }
        let catalog = try JSONDecoder().decode(DraftCatalog.self, from: data)
        guard catalog.schemaVersion == 1 else { throw DraftsError.message("This catalog requires a newer version of expo-drafts. Create a new EAS build.") }
        guard catalog.projectId.lowercased() == expectedProjectID.lowercased() else {
          throw DraftsError.message("This catalog belongs to another EAS project. Check the catalog URL in your build configuration.")
        }
        guard catalog.drafts.allSatisfy({
          UUID(uuidString: $0.id) != nil && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          !$0.channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          $0.updates.allSatisfy { UUID(uuidString: $0.id) != nil && !$0.runtimeVersion.isEmpty && ["ios", "android"].contains($0.platform) } &&
          Set($0.updates.map(\.platform)).count == $0.updates.count
        }), Set(catalog.drafts.map(\.channel)).count == catalog.drafts.count,
          Set(catalog.drafts.map(\.id)).count == catalog.drafts.count else {
          throw DraftsError.message("The catalog contains invalid or duplicate draft, channel, or platform update information. Publish a fresh catalog.")
        }
        return catalog
      }
      DispatchQueue.main.async {
        guard let self, self.catalogGeneration == generation else { return }
        if case .success(let catalog) = result { self.cachedCatalog = catalog }
        completion(result)
      }
    }
    catalogTask?.resume()
  }

  func build(for draft: DraftEntry) -> DraftBuildEntry? {
    guard let update = draft.iosUpdate else { return nil }
    return buildsCatalog?.build(runtimeVersion: update.runtimeVersion, platform: "ios", profile: buildProfile)
  }

  /// Build metadata is optional. A missing or unavailable catalog never changes whether
  /// an EAS Update can run in the installed native build.
  func fetchBuildCatalog(completion: @escaping () -> Void) {
    buildsCatalogTask?.cancel()
    buildsCatalogTask = nil
    let generation = UUID()
    buildsCatalogGeneration = generation
    if usesEASDiscovery {
      guard let secret = expoSession.sessionSecret else {
        buildsCatalogLoading = false
        buildsCatalogError = nil
        buildsCatalog = nil
        completion()
        return
      }
      buildsCatalogLoading = true
      buildsCatalogError = nil
      easClient.fetchBuildCatalog(projectID: projectID, profile: buildProfile, sessionSecret: secret) { [weak self] result in
        guard let self, self.buildsCatalogGeneration == generation else { return }
        self.buildsCatalogLoading = false
        switch result {
        case .success(let catalog): self.buildsCatalog = catalog
        case .failure(let error):
          self.handleDiscoveryError(error)
          self.buildsCatalogError = error.localizedDescription
        }
        completion()
      }
      return
    }
    guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsBuildsCatalogURL") as? String, !rawURL.isEmpty else {
      buildsCatalogLoading = false
      buildsCatalogError = nil
      buildsCatalog = nil
      completion()
      return
    }
    guard let url = URL(string: rawURL), url.isDraftsSecureWebURL else {
      buildsCatalogLoading = false
      buildsCatalogError = "The build catalog URL must use HTTPS."
      completion()
      return
    }
    var requestURL = url
    if ["api.github.com", "raw.githubusercontent.com"].contains(url.host?.lowercased() ?? ""),
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "expo-drafts-refresh", value: UUID().uuidString)]
      requestURL = components.url ?? url
    }
    var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25)
    request.setValue(url.host == "api.github.com" ? "application/vnd.github.raw+json" : "application/json", forHTTPHeaderField: "Accept")
    let expectedProjectID = projectID
    buildsCatalogLoading = true
    buildsCatalogError = nil
    buildsCatalogTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      if (error as NSError?)?.code == NSURLErrorCancelled { return }
      let result: Result<DraftBuildCatalog, Error> = Result {
        if let error { throw error }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
          throw DraftsError.message("Build status could not be loaded. Refresh to try again.")
        }
        guard http.url?.isDraftsSecureWebURL == true else {
          throw DraftsError.message("The build catalog redirected to an insecure URL.")
        }
        return try DraftBuildCatalog.decode(data, projectID: expectedProjectID)
      }
      DispatchQueue.main.async {
        guard let self, self.buildsCatalogGeneration == generation else { return }
        self.buildsCatalogLoading = false
        self.buildsCatalogTask = nil
        switch result {
        case .success(let catalog): self.buildsCatalog = catalog
        case .failure(let error): self.buildsCatalogError = error.localizedDescription
        }
        completion()
      }
    }
    buildsCatalogTask?.resume()
  }

  func buildRequestURL(for draft: DraftEntry) throws -> URL {
    try DraftBuildRequest.url(
      for: draft, projectID: projectID,
      baseURL: Bundle.main.object(forInfoDictionaryKey: "ExpoDraftsBuildRequestURL") as? String
    )
  }

  func openBuildActionURL(_ url: URL, completion: @escaping (Error?) -> Void) {
    guard url.isDraftsSecureWebURL else {
      completion(DraftsError.message("Build links must use HTTPS."))
      return
    }
    UIApplication.shared.open(url, options: [:]) { success in
      DispatchQueue.main.async {
        completion(success ? nil : DraftsError.message("The browser could not open this build link."))
      }
    }
  }

  func installBuild(for draft: DraftEntry, completion: @escaping (Error?) -> Void) {
    precondition(Thread.isMainThread)
    guard !switching, !preparingInstallation else {
      completion(DraftsError.message("Wait for the current draft action to finish."))
      return
    }
    guard let update = draft.iosUpdate, let build = build(for: draft),
      build.state == "ready", build.platform == "ios", build.profile == buildProfile,
      build.runtimeVersion == update.runtimeVersion, build.verifiedInstallURL != nil,
      let buildID = build.buildId, let bundleIdentifier = Bundle.main.bundleIdentifier else {
      completion(DraftsError.message("This draft has no verified compatible device build. Refresh its build status and try again."))
      return
    }
    #if targetEnvironment(simulator)
    completion(DraftsError.message("Device builds cannot be installed in the simulator. Open this draft on a registered iPhone or iPad to install it."))
    #else
    preparingInstallation = true
    let sourceRuntime = runtimeVersion
    do {
      let request = try DraftBuildManifestRequest(projectID: projectID, buildID: buildID, bundleIdentifier: bundleIdentifier) { [weak self] result in
        guard let self else { return }
        self.installationRequest = nil
        guard !self.switching, let currentBuild = self.build(for: draft),
          currentBuild.buildId == buildID, currentBuild.verifiedInstallURL != nil else {
          self.preparingInstallation = false
          completion(DraftsError.message("The selected build changed. Refresh its status and try again."))
          return
        }
        switch result {
        case .failure(let error):
          self.preparingInstallation = false
          completion(error)
        case .success(let installerURL):
          // A successful open only hands the manifest to iOS. Installation may be
          // cancelled or fail later; the app must not record it as completed.
          UIApplication.shared.open(installerURL, options: [:]) { success in
            DispatchQueue.main.async {
              self.preparingInstallation = false
              guard success else {
                completion(DraftsError.message("iOS could not open the installer. Try again on a registered physical device."))
                return
              }
              do {
                try self.installationState.save(DraftInstallationRequest(
                  projectID: self.projectID, sourceRuntime: sourceRuntime,
                  targetRuntime: update.runtimeVersion, buildID: buildID,
                  draftID: draft.id, name: draft.name, requestedAt: Date()
                ))
                completion(nil)
              } catch {
                completion(DraftsError.message("iOS opened the installer, but the request status could not be saved. After confirming Install, go to the Home Screen and reopen the app when installation finishes."))
              }
            }
          }
        }
      }
      installationRequest = request
      request.start()
    } catch {
      preparingInstallation = false
      completion(error)
    }
    #endif
  }

  func compatibility(_ draft: DraftEntry) -> String? {
    guard updatesEnabled, !runtimeVersion.isEmpty else { return "Install a release build with EAS Update enabled" }
    guard let update = draft.iosUpdate else { return "No iOS update · Needs new EAS build" }
    guard update.runtimeVersion == runtimeVersion else { return "Native changes · Needs new EAS build" }
    return nil
  }

  func isCurrent(_ draft: DraftEntry) -> Bool {
    draft.iosUpdate?.id.lowercased() == currentUpdateID
  }

  func launch(_ draft: DraftEntry, completion: @escaping (Result<Void, Error>) -> Void) {
    guard !switching else {
      completion(.failure(DraftsError.message("Another bundle is already opening.")))
      return
    }
    guard !preparingInstallation else {
      completion(.failure(DraftsError.message("Wait for the installation handoff to finish before opening a draft.")))
      return
    }
    if let reason = compatibility(draft) {
      completion(.failure(DraftsError.message(reason)))
      return
    }
    guard let expected = draft.iosUpdate,
      let controller = AppController.sharedInstance as? EnabledAppController else {
      completion(.failure(DraftsError.message("Draft switching requires a release build with expo-updates enabled.")))
      return
    }
    guard let endpoint = controller.updateURL,
      endpoint.scheme == "https", endpoint.host == "u.expo.dev",
      endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() == projectID.lowercased() else {
      completion(.failure(DraftsError.message("The native update endpoint belongs to a different EAS project. Check the build configuration.")))
      return
    }
    if isCurrent(draft) { completion(.success(())); return }
    var nextHeaders = controller.requestHeaders ?? [:]
    nextHeaders["expo-channel-name"] = draft.channel
    // Expo persists fetched updates before returning their manifests. Isolate each selection
    // so rejecting a moved channel head cannot activate that cached update on next launch.
    nextHeaders["expo-drafts-selection"] = expected.id.lowercased()

    selectUpdate(controller: controller, expectedID: expected.id, nextHeaders: nextHeaders, bundled: false, completion: completion)
  }

  func launchEmbedded(completion: @escaping (Result<Void, Error>) -> Void) {
    guard !switching, !preparingInstallation else {
      completion(.failure(DraftsError.message("Wait for the current operation to finish before opening the bundled version.")))
      return
    }
    guard canRunBundledVersion,
      let controller = AppController.sharedInstance as? EnabledAppController,
      let embedded = controller.getEmbeddedUpdate() else {
      completion(.failure(DraftsError.message("This native build has no bundled version available.")))
      return
    }
    if isEmbeddedLaunch { completion(.success(())); return }
    do {
      let config = try UpdatesConfig.configWithExpoPlist(mergingOtherDictionary: nil)
      selectUpdate(
        controller: controller, expectedID: embedded.updateId.uuidString,
        nextHeaders: config.originalEmbeddedRequestHeaders, bundled: true, completion: completion
      )
    } catch { completion(.failure(error)) }
  }

  private func selectUpdate(
    controller: EnabledAppController, expectedID: String, nextHeaders: [String: String],
    bundled: Bool, completion: @escaping (Result<Void, Error>) -> Void
  ) {
    switching = true
    let previousHeaders = controller.requestHeaders ?? [:]

    DraftsUpdateTransaction.begin(controller: controller, expectedID: expectedID, nextHeaders: nextHeaders) { result in
      switch result {
      case .failure(let error):
        self.switching = false
        completion(.failure(error))
      case .success(let transaction):
        var finished = false
        let fail: (Error, Bool) -> Void = { error, restoreRunningBundle in
          DispatchQueue.main.async {
            guard !finished else { return }
            finished = true
            var reportedError = error
            var headersRestored = true
            do { try controller.setUpdateRequestHeadersOverride(previousHeaders) }
            catch {
              headersRestored = false
              reportedError = DraftsError.message("\(reportedError.localizedDescription) Could not restore the previous channel: \(error.localizedDescription)")
            }
            transaction.rollback { rollbackError in
              if let rollbackError {
                reportedError = DraftsError.message("\(reportedError.localizedDescription) Cache recovery will retry when the app restarts: \(rollbackError.localizedDescription)")
              } else if headersRestored {
                transaction.commit()
              }
              if restoreRunningBundle && headersRestored && rollbackError == nil {
                controller.requestRelaunch {
                  DispatchQueue.main.async {
                    self.switching = false
                    completion(.failure(reportedError))
                  }
                } error: { restoreError in
                  DispatchQueue.main.async {
                    self.switching = false
                    completion(.failure(DraftsError.message("\(reportedError.localizedDescription) Reopen the app to return to the previous draft: \(restoreError.localizedDescription)")))
                  }
                }
              } else {
                self.switching = false
                completion(.failure(reportedError))
              }
            }
          }
        }
        let prepared: (Result<Void, Error>) -> Void = { preparation in
          switch preparation {
          case .failure(let error): fail(error, false)
          case .success:
            controller.requestRelaunch {
              DispatchQueue.main.async {
                guard self.currentUpdateID == expectedID.lowercased(), !bundled || self.isEmbeddedLaunch else {
                  fail(DraftsError.message("Expo launched a different bundle. Restoring the previous version."), true)
                  return
                }
                guard !finished else { return }
                finished = true
                transaction.commit()
                self.switching = false
                completion(.success(()))
              }
            } error: { fail($0, false) }
          }
        }
        let download: () -> Void = {
          controller.fetchUpdate { fetchResult in
            switch fetchResult {
            case .success(let manifest):
              guard let actual = manifest["id"] as? String, actual.lowercased() == expectedID.lowercased() else {
                fail(DraftsError.message("This channel changed since the catalog was loaded. Refresh the draft list and choose the latest version."), false)
                return
              }
              transaction.prepareLaunch(expectedID: expectedID, completion: prepared)
            case .failure:
              fail(DraftsError.message("No matching update was downloaded. The draft may have changed or been removed. Refresh and try again."), false)
            case .rollBackToEmbedded:
              fail(DraftsError.message("This channel was rolled back. Refresh the catalog and choose another draft."), false)
            case .error(let error): fail(error, false)
            }
          } error: { fail($0, false) }
        }
        do { try controller.setUpdateRequestHeadersOverride(nextHeaders) }
        catch { fail(error, false); return }
        if bundled {
          transaction.prepareEmbeddedLaunch(expectedID: expectedID, completion: prepared)
          return
        }
        // Check the ID before the downloader can alter the cache. The transaction
        // also covers a channel moving between this check and the actual fetch.
        controller.checkForUpdate { check in
          switch check {
          case .updateAvailable(let manifest):
            guard let actual = manifest["id"] as? String, actual.lowercased() == expectedID.lowercased() else {
              fail(DraftsError.message("This channel has a newer update than the catalog. Refresh drafts and choose its latest version."), false)
              return
            }
            download()
          case .noUpdateAvailable:
            fail(DraftsError.message("This draft is no longer available for the installed runtime. Refresh the draft list."), false)
          case .rollBackToEmbedded:
            fail(DraftsError.message("This channel was rolled back. Refresh the catalog and choose another draft."), false)
          case .error(let error): fail(error, false)
          }
        } error: { fail($0, false) }
      }
    }
  }

  func openBuild(for draft: DraftEntry? = nil) {
    guard let rawURL = draft?.buildUrl ?? buildURL, let url = URL(string: rawURL), url.isDraftsTrustedURL else { return }
    UIApplication.shared.open(url)
  }
}

private final class DraftsWindow: UIWindow {
  init(windowScene: UIWindowScene, onOpen: @escaping () -> Void) {
    super.init(windowScene: windowScene)
    windowLevel = .statusBar - 1
    backgroundColor = .clear
    rootViewController = DraftsFloatingController(onOpen: onOpen)
    isHidden = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if rootViewController?.presentedViewController != nil { return super.hitTest(point, with: event) }
    guard let root = rootViewController as? DraftsFloatingController,
      root.button.frame.insetBy(dx: -8, dy: -8).contains(point) else { return nil }
    return super.hitTest(point, with: event)
  }
}

private final class DraftsFloatingController: UIViewController {
  let button = UIButton(type: .system)
  private let onOpen: () -> Void
  private var positioned = false

  init(onOpen: @escaping () -> Void) { self.onOpen = onOpen; super.init(nibName: nil, bundle: nil) }
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    button.frame = CGRect(x: 0, y: 0, width: 54, height: 54)
    var configuration: UIButton.Configuration
    if #available(iOS 26.0, *) {
      configuration = .glass()
    } else {
      configuration = .tinted()
    }
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "square.stack.3d.up.fill")
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    button.configuration = configuration
    button.accessibilityLabel = "Open Expo Drafts"
    button.accessibilityIdentifier = "expo-drafts-launcher"
    button.addAction(UIAction { [weak self] _ in self?.onOpen() }, for: .touchUpInside)
    button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
    view.addSubview(button)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if !positioned {
      button.frame.origin = CGPoint(x: view.bounds.width - 70, y: view.bounds.height - view.safeAreaInsets.bottom - 92)
      positioned = view.bounds.width > 0
    }
    keepButtonInBounds()
  }

  private func keepButtonInBounds() {
    button.center.x = min(max(button.center.x, 43), max(43, view.bounds.width - 43))
    button.center.y = min(max(button.center.y, view.safeAreaInsets.top + 43), max(43, view.bounds.height - view.safeAreaInsets.bottom - 43))
  }

  @objc private func drag(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    button.center = CGPoint(x: button.center.x + translation.x, y: button.center.y + translation.y)
    gesture.setTranslation(.zero, in: view)
    keepButtonInBounds()
    if gesture.state == .ended || gesture.state == .cancelled {
      let x: CGFloat = button.center.x < view.bounds.midX ? 43 : view.bounds.width - 43
      UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.24) { self.button.center.x = x }
    }
  }
}
