import UIKit

final class DraftsViewController: UITableViewController, UISearchResultsUpdating {
  private let manager: ExpoDraftsManager
  private let search = UISearchController(searchResultsController: nil)
  private var drafts: [DraftEntry] = []
  private var loading = true
  private var errorMessage: String?
  private var loadingDraftID: String?

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
    refreshCatalog()
  }

  @objc private func refreshCatalog() {
    guard loadingDraftID == nil else { return }
    loading = true
    errorMessage = nil
    updateBackground()
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
    }
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

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 1 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "build", for: indexPath)
      var content = cell.defaultContentConfiguration()
      content.text = "Find a Compatible Build"
      content.textProperties.color = loadingDraftID == nil ? .tintColor : .secondaryLabel
      content.image = UIImage(systemName: "arrow.up.right")
      cell.contentConfiguration = content
      cell.selectionStyle = loadingDraftID == nil ? .default : .none
      cell.accessibilityIdentifier = "expo-drafts-builds"
      cell.accessibilityTraits = loadingDraftID == nil ? [.button] : [.button, .notEnabled]
      return cell
    }

    let cell = tableView.dequeueReusableCell(withIdentifier: "draft", for: indexPath)
    let draft = filteredDrafts[indexPath.row]
    let reason = manager.compatibility(draft)
    let current = manager.isCurrent(draft)
    let downloading = loadingDraftID == draft.id
    let subtitle: String
    if downloading { subtitle = "Downloading…" }
    else if reason != nil {
      subtitle = draft.iosUpdate == nil ? "No iOS update" : "Requires a different build"
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
    cell.accessoryType = current ? .checkmark : .none
    if downloading {
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      cell.accessoryView = spinner
    } else {
      cell.accessoryView = nil
    }
    let selectable = reason == nil && loadingDraftID == nil
    cell.selectionStyle = selectable ? .default : .none
    cell.accessibilityLabel = "\(draft.name), \(subtitle)"
    cell.accessibilityValue = current ? "Current update" : nil
    cell.accessibilityTraits = selectable ? [.button] : [.button, .notEnabled]
    if current { cell.accessibilityTraits.insert(.selected) }
    cell.accessibilityIdentifier = "expo-drafts-row-\(draft.channel)"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard loadingDraftID == nil else { return }
    if indexPath.section == 1 {
      manager.openBuild()
      return
    }
    let draft = filteredDrafts[indexPath.row]
    guard manager.compatibility(draft) == nil else { return }
    if manager.isCurrent(draft) { dismiss(animated: true); return }
    search.isActive = false
    loadingDraftID = draft.id
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
}
