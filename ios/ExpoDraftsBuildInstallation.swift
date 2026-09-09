import Foundation

enum DraftBuildInstallation {
  static let maximumManifestBytes = 1_000_000

  static func manifestURL(projectID: String, buildID: String) throws -> URL {
    guard let project = UUID(uuidString: projectID), let build = UUID(uuidString: buildID) else {
      throw DraftsError.message("The compatible build has invalid EAS identifiers. Refresh its status and try again.")
    }
    return URL(string: "https://api.expo.dev/v2/projects/\(project.uuidString.lowercased())/builds/\(build.uuidString.lowercased())/manifest.plist")!
  }

  static func installerURL(manifestURL: URL, projectID: String, buildID: String) throws -> URL {
    let expected = try self.manifestURL(projectID: projectID, buildID: buildID)
    guard manifestURL.absoluteString == expected.absoluteString else {
      throw DraftsError.message("The installation manifest does not belong to the selected EAS project and build.")
    }
    var components = URLComponents()
    components.scheme = "itms-services"
    components.host = ""
    components.queryItems = [
      URLQueryItem(name: "action", value: "download-manifest"),
      URLQueryItem(name: "url", value: expected.absoluteString)
    ]
    guard let url = components.url else { throw DraftsError.message("Could not prepare the iOS installer.") }
    return url
  }

  static func validateManifest(_ data: Data, responseURL: URL, projectID: String, buildID: String, bundleIdentifier: String) throws -> URL {
    let installer = try installerURL(manifestURL: responseURL, projectID: projectID, buildID: buildID)
    guard data.count <= maximumManifestBytes, !bundleIdentifier.isEmpty,
      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
      let items = plist["items"] as? [[String: Any]], items.count == 1,
      let metadata = items[0]["metadata"] as? [String: Any], metadata["kind"] as? String == "software",
      metadata["bundle-identifier"] as? String == bundleIdentifier,
      let version = metadata["bundle-version"] as? String, !version.isEmpty,
      let assets = items[0]["assets"] as? [[String: Any]],
      assets.filter({ $0["kind"] as? String == "software-package" }).count == 1,
      assets.allSatisfy({ asset in
        guard let rawURL = asset["url"] as? String, let url = URL(string: rawURL) else { return false }
        return url.isDraftsSecureWebURL
      }) else {
      throw DraftsError.message("EAS did not return a valid installation manifest for this app. Refresh the build status and try again.")
    }
    // The system fetches a fresh manifest. Never keep or open its temporary IPA URL.
    return installer
  }
}

/// All mutable state and URLSession delegate callbacks are confined to the main queue.
final class DraftBuildManifestRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let manifestURL: URL
  private let projectID: String
  private let buildID: String
  private let bundleIdentifier: String
  private var completion: ((Result<URL, Error>) -> Void)?
  private var session: URLSession?
  private var data = Data()

  init(projectID: String, buildID: String, bundleIdentifier: String, completion: @escaping (Result<URL, Error>) -> Void) throws {
    self.manifestURL = try DraftBuildInstallation.manifestURL(projectID: projectID, buildID: buildID)
    self.projectID = projectID
    self.buildID = buildID
    self.bundleIdentifier = bundleIdentifier
    self.completion = completion
  }

  func start() {
    precondition(Thread.isMainThread)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 25
    configuration.timeoutIntervalForResource = 25
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    self.session = session
    var request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25)
    request.setValue("application/xml, text/xml, application/x-plist", forHTTPHeaderField: "Accept")
    session.dataTask(with: request).resume()
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    // The EAS endpoint returns the manifest directly. Never follow a login page or artifact redirect.
    completionHandler(nil)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      response.url?.absoluteString == manifestURL.absoluteString else {
      completionHandler(.cancel)
      let status = (response as? HTTPURLResponse)?.statusCode
      let message = status == 401 || status == 403 ?
        "This build's installation manifest requires authentication. iOS needs an accessible manifest to install it." :
        "The installation manifest is unavailable. Refresh the build status and try again."
      finish(.failure(DraftsError.message(message)))
      return
    }
    guard response.expectedContentLength <= Int64(DraftBuildInstallation.maximumManifestBytes) else {
      completionHandler(.cancel)
      finish(.failure(DraftsError.message("The installation manifest is too large.")))
      return
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard completion != nil else { return }
    guard self.data.count + data.count <= DraftBuildInstallation.maximumManifestBytes else {
      finish(.failure(DraftsError.message("The installation manifest is too large.")))
      return
    }
    self.data.append(data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard completion != nil else { return }
    if error != nil {
      finish(.failure(DraftsError.message("The installation manifest could not be loaded. Check your connection and try again.")))
      return
    }
    finish(Result {
      try DraftBuildInstallation.validateManifest(data, responseURL: manifestURL, projectID: projectID, buildID: buildID, bundleIdentifier: bundleIdentifier)
    })
  }

  private func finish(_ result: Result<URL, Error>) {
    guard let completion else { return }
    self.completion = nil
    session?.invalidateAndCancel()
    session = nil
    data.removeAll()
    completion(result)
  }
}
