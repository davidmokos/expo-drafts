import UIKit

final class DraftsViewController: UITableViewController, UISearchResultsUpdating {
  private let manager: ExpoDraftsManager
  private let search = UISearchController(searchResultsController: nil)
  private var drafts: [DraftEntry] = []
  private var loading = true
  private var errorMessage: String?
  private var loadingDraftID: String?
  private var preparingBuildID: String?
  private var buildRefreshTimer: Timer?
  private var foregroundObserver: NSObjectProtocol?
  private var pickerVisible = false
  private var busy: Bool { loadingDraftID != nil || preparingBuildID != nil }

  private var filteredDrafts: [DraftEntry] {
    guard let query = search.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return drafts }
    return drafts.filter { "\($0.name) \($0.channel) \($0.branch ?? "") \($0.message ?? "")".localizedCaseInsensitiveContains(query) }
  }

  private var showsBuildLink: Bool {
    manager.buildURL != nil && filteredDrafts.contains { manager.compatibility($0) != nil }
  }

  init(manager: ExpoDraftsManager) {
    self.manager = manager
    super.init(style: .insetGrouped)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  deinit {
    buildRefreshTimer?.invalidate()
    if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Drafts"
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
      self?.dismiss(animated: true)
    })

    search.searchResultsUpdater = self
    search.obscuresBackgroundDuringPresentation = false
    search.searchBar.placeholder = "Search"
    navigationItem.searchController = search
    navigationItem.hidesSearchBarWhenScrolling = false
    definesPresentationContext = true

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "draft")
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "build")
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 64
    tableView.alwaysBounceVertical = true
    refreshControl = UIRefreshControl()
    refreshControl?.addTarget(self, action: #selector(refreshCatalog), for: .valueChanged)
    foregroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self, self.pickerVisible else { return }
      self.refreshBuildMetadata()
    }
    refreshCatalog()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    pickerVisible = true
    updateBuildPolling()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    pickerVisible = false
    buildRefreshTimer?.invalidate()
    buildRefreshTimer = nil
  }

  @objc private func refreshCatalog() {
    guard !busy else { return }
    loading = true
    errorMessage = nil
    updateBackground()
    refreshBuildMetadata()
    manager.fetchCatalog { [weak self] result in
      guard let self else { return }
      self.loading = false
      self.refreshControl?.endRefreshing()
      switch result {
      case .success(let catalog):
        self.drafts = catalog.drafts.sorted { $0.createdAt > $1.createdAt }
      case .failure(let error):
        self.errorMessage = error.localizedDescription
        if !self.drafts.isEmpty {
          let alert = UIAlertController(title: "Couldn't Refresh Drafts", message: error.localizedDescription, preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in self?.refreshCatalog() })
          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          self.present(alert, animated: true)
        }
      }
      self.tableView.reloadData()
      self.updateBackground()
      self.updateBuildPolling()
    }
  }

  private func refreshBuildMetadata() {
    guard !busy else { return }
    manager.fetchBuildCatalog { [weak self] in
      guard let self else { return }
      self.tableView.reloadData()
      self.updateBuildPolling()
    }
    tableView.reloadData()
  }

  private func updateBuildPolling() {
    buildRefreshTimer?.invalidate()
    buildRefreshTimer = nil
    guard pickerVisible, !busy, UIApplication.shared.applicationState == .active,
      drafts.contains(where: { manager.compatibility($0) != nil && manager.build(for: $0)?.isInProgress == true }) else { return }
    buildRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      guard let self, self.pickerVisible, UIApplication.shared.applicationState == .active else { return }
      self.refreshBuildMetadata()
    }
  }

  private func buildSubtitle(for draft: DraftEntry) -> String {
    guard draft.iosUpdate != nil else { return "No iOS update" }
    if let build = manager.build(for: draft) {
      if build.verifiedInstallURL != nil { return "Install compatible build" }
      switch build.state {
      case "queued": return "Build queued"
      case "building": return "Build in progress"
      case "failed": return manager.buildRequestsConfigured ? "Build failed · Request build" : "Build failed"
      default: return manager.buildRequestsConfigured ? "Build unavailable · Request build" : "Build unavailable"
      }
    }
    if manager.buildsCatalogLoading { return "Checking compatible builds…" }
    if manager.buildsCatalogError != nil { return "Build status unavailable" }
    return manager.buildRequestsConfigured ? "Requires a new build · Request build" : "Requires a new build"
  }

  private func updateBackground() {
    guard filteredDrafts.isEmpty else {
      if #available(iOS 17.0, *) { contentUnavailableConfiguration = nil }
      tableView.backgroundView = nil
      return
    }

    if #available(iOS 17.0, *) {
      var configuration: UIContentUnavailableConfiguration
      if loading && drafts.isEmpty {
        configuration = .loading()
      } else if let errorMessage, drafts.isEmpty {
        configuration = .empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "Couldn't Load Drafts"
        configuration.secondaryText = errorMessage
        configuration.button.title = "Try Again"
        configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.refreshCatalog() }
      } else if drafts.isEmpty {
        configuration = .empty()
        configuration.image = UIImage(systemName: "square.stack")
        configuration.text = "No Drafts"
        configuration.secondaryText = "Published previews will appear here."
      } else {
        configuration = .search()
      }
      contentUnavailableConfiguration = configuration
    } else {
      let label = UILabel()
      label.numberOfLines = 0
      label.textAlignment = .center
      label.font = .preferredFont(forTextStyle: .body)
      label.adjustsFontForContentSizeCategory = true
      label.textColor = .secondaryLabel
      label.text = loading && drafts.isEmpty ? "Loading…" :
        (errorMessage ?? (drafts.isEmpty ? "No drafts yet." : "No results."))
      tableView.backgroundView = label
    }
  }

  func updateSearchResults(for searchController: UISearchController) {
    tableView.reloadData()
    updateBackground()
  }

  override func numberOfSections(in tableView: UITableView) -> Int { showsBuildLink ? 2 : 1 }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    section == 0 ? filteredDrafts.count : 1
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    guard section == 0, manager.buildsCatalogError != nil,
      filteredDrafts.contains(where: { manager.compatibility($0) != nil }) else { return nil }
    return "Build status could not be refreshed. Compatible drafts can still be opened."
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 1 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "build", for: indexPath)
      var content = cell.defaultContentConfiguration()
      content.text = "All EAS Builds"
      content.textProperties.color = !busy ? .tintColor : .secondaryLabel
      content.image = UIImage(systemName: "arrow.up.right")
      cell.contentConfiguration = content
      cell.selectionStyle = !busy ? .default : .none
      cell.accessibilityIdentifier = "expo-drafts-builds"
      cell.accessibilityTraits = !busy ? [.button] : [.button, .notEnabled]
      return cell
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "draft", for: indexPath)
    let draft = filteredDrafts[indexPath.row]
    let reason = manager.compatibility(draft)
    let current = manager.isCurrent(draft)
    let downloading = loadingDraftID == draft.id
    let preparingBuild = preparingBuildID == draft.id
    let subtitle: String
    if preparingBuild { subtitle = "Preparing installation…" }
    else if downloading { subtitle = "Downloading…" }
    else if reason != nil {
      subtitle = buildSubtitle(for: draft)
    } else {
      subtitle = draft.pullRequest.map { "PR #\($0.number)" } ?? draft.channel
    }

    var content = cell.defaultContentConfiguration()
    content.text = draft.name
    content.textProperties.numberOfLines = 2
    content.textProperties.color = reason == nil ? .label : .secondaryLabel
    content.secondaryText = subtitle
    content.secondaryTextProperties.numberOfLines = 0
    cell.contentConfiguration = content
    cell.accessoryType = current ? .checkmark : (reason != nil && draft.iosUpdate != nil ? .disclosureIndicator : .none)
    if preparingBuild || downloading || (reason != nil && manager.build(for: draft)?.isInProgress == true) {
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      cell.accessoryView = spinner
    } else {
      cell.accessoryView = nil
    }
    let selectable = !busy && (reason == nil || draft.iosUpdate != nil)
    cell.selectionStyle = selectable ? .default : .none
    cell.accessibilityLabel = "\(draft.name), \(subtitle)"
    cell.accessibilityValue = current ? "Current update" : nil
    cell.accessibilityHint = reason != nil && draft.iosUpdate != nil ? "Shows build options. This update cannot run in the installed native build." : nil
    cell.accessibilityTraits = selectable ? [.button] : [.button, .notEnabled]
    if current { cell.accessibilityTraits.insert(.selected) }
    cell.accessibilityIdentifier = "expo-drafts-row-\(draft.channel)"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard !busy else { return }
    if indexPath.section == 1 {
      manager.openBuild()
      return
    }
    let draft = filteredDrafts[indexPath.row]
    guard manager.compatibility(draft) == nil else {
      if draft.iosUpdate != nil { presentBuildActions(for: draft, at: indexPath) }
      return
    }
    if manager.isCurrent(draft) { dismiss(animated: true); return }
    search.isActive = false
    loadingDraftID = draft.id
    updateBuildPolling()
    isModalInPresentation = true
    navigationItem.rightBarButtonItem?.isEnabled = false
    search.searchBar.isUserInteractionEnabled = false
    refreshControl?.isEnabled = false
    tableView.reloadData()
    manager.launch(draft) { [weak self] result in
      guard let self else { return }
      self.loadingDraftID = nil
      self.isModalInPresentation = false
      self.navigationItem.rightBarButtonItem?.isEnabled = true
      self.search.searchBar.isUserInteractionEnabled = true
      self.refreshControl?.isEnabled = true
      self.tableView.reloadData()
      self.updateBuildPolling()
      switch result {
      case .success: self.dismiss(animated: true)
      case .failure(let error):
        let alert = UIAlertController(title: "Couldn't Open Draft", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Refresh Drafts", style: .default) { [weak self] _ in self?.refreshCatalog() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
      }
    }
  }

  private func presentBuildActions(for draft: DraftEntry, at indexPath: IndexPath) {
    let build = manager.build(for: draft)
    let installURL = build?.verifiedInstallURL
    let statusURL = build?.verifiedStatusURL
    let message: String
    if installURL != nil {
      #if targetEnvironment(simulator)
      message = "A compatible device build is ready. Install it from Drafts on a registered iPhone or iPad. Device builds cannot be installed in the simulator."
      #else
      message = "Confirm installation when iOS asks. This replaces the installed app. Reopen the app when installation finishes, then select this update."
      #endif
    } else if build?.isInProgress == true {
      let progress = build?.state == "queued" ? "A compatible iOS device build is queued." : "A compatible iOS device build is in progress."
      message = progress + (statusURL == nil ? " Refresh the build status to check for completion." : " Open its status page for progress.")
    } else if manager.buildsCatalogLoading {
      message = "Build status is still loading. Refresh the status before requesting a new build."
    } else if !manager.buildRequestsConfigured {
      message = "This draft needs a compatible iOS device build. Build requests are not configured in this app."
    } else if manager.buildsCatalogError != nil {
      message = "Build status could not be refreshed. You can check existing requests or open a new request on GitHub. Sign in and submit the issue to request a build; opening the form does not start one."
    } else {
      message = (build?.state == "failed" ? "The compatible build failed. " : "This draft needs a compatible iOS device build. ") +
        "Request one on GitHub. Sign in and submit the issue to request a build; opening the form does not start one. Repository write access is required."
    }
    let sheet = UIAlertController(title: draft.name, message: message, preferredStyle: .actionSheet)
    if let installURL {
      sheet.addAction(UIAlertAction(title: "Install compatible build", style: .default) { [weak self, weak sheet] _ in
        sheet?.dismiss(animated: true) { self?.installBuild(for: draft) }
      })
      sheet.addAction(UIAlertAction(title: "View EAS Build Page", style: .default) { [weak self] _ in self?.openBuildURL(installURL) })
    }
    if let statusURL, statusURL != installURL {
      sheet.addAction(UIAlertAction(title: "View Build Status", style: .default) { [weak self] _ in self?.openBuildURL(statusURL) })
    }
    if installURL == nil && build?.isInProgress != true && !manager.buildsCatalogLoading && manager.buildRequestsConfigured {
      sheet.addAction(UIAlertAction(title: "Request Build", style: .default) { [weak self] _ in
        guard let self else { return }
        do { self.openBuildURL(try self.manager.buildRequestURL(for: draft)) }
        catch { self.presentBuildError(error) }
      })
    }
    if installURL == nil && !manager.buildRequestsConfigured && manager.buildURL != nil {
      sheet.addAction(UIAlertAction(title: "All EAS Builds", style: .default) { [weak self] _ in self?.manager.openBuild() })
    }
    sheet.addAction(UIAlertAction(title: "Refresh Build Status", style: .default) { [weak self] _ in self?.refreshBuildMetadata() })
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = tableView
      popover.sourceRect = tableView.rectForRow(at: indexPath)
    }
    present(sheet, animated: true)
  }

  private func installBuild(for draft: DraftEntry) {
    guard !busy else { return }
    preparingBuildID = draft.id
    isModalInPresentation = true
    navigationItem.rightBarButtonItem?.isEnabled = false
    search.searchBar.isUserInteractionEnabled = false
    refreshControl?.isEnabled = false
    tableView.reloadData()
    updateBuildPolling()
    manager.installBuild(for: draft) { [weak self] error in
      guard let self else { return }
      self.preparingBuildID = nil
      self.isModalInPresentation = false
      self.navigationItem.rightBarButtonItem?.isEnabled = true
      self.search.searchBar.isUserInteractionEnabled = true
      self.refreshControl?.isEnabled = true
      self.tableView.reloadData()
      self.updateBuildPolling()
      if let error { self.presentBuildError(error) }
    }
  }

  private func openBuildURL(_ url: URL) {
    manager.openBuildActionURL(url) { [weak self] error in
      if let error { self?.presentBuildError(error) }
    }
  }

  private func presentBuildError(_ error: Error) {
    let alert = UIAlertController(title: "Couldn't Open Build Action", message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }
}
