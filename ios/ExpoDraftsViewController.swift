import UIKit

enum DraftsStyle {
  static let background = UIColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1)
  static let card = UIColor(red: 0.105, green: 0.12, blue: 0.13, alpha: 1)
  static let accent = UIColor(red: 0.68, green: 0.94, blue: 0.77, alpha: 1)
}

final class DraftsViewController: UITableViewController, UISearchResultsUpdating {
  private let manager: ExpoDraftsManager
  private let search = UISearchController(searchResultsController: nil)
  private var drafts: [DraftEntry] = []
  private var loading = true
  private var errorMessage: String?
  private var loadingDraftID: String?
  private let statusLabel = UILabel()
  private let subtitleLabel = UILabel()

  private var filteredDrafts: [DraftEntry] {
    guard let query = search.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return drafts }
    return drafts.filter { "\($0.name) \($0.channel) \($0.branch ?? "") \($0.message ?? "")".localizedCaseInsensitiveContains(query) }
  }

  init(manager: ExpoDraftsManager) {
    self.manager = manager
    super.init(style: .insetGrouped)
  }
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "expo-drafts"
    overrideUserInterfaceStyle = .dark
    view.backgroundColor = DraftsStyle.background
    navigationController?.view.tintColor = DraftsStyle.accent
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = DraftsStyle.background
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold)]
    navigationItem.standardAppearance = appearance
    navigationItem.scrollEdgeAppearance = appearance
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in self?.refreshCatalog() })
    navigationItem.leftBarButtonItem?.accessibilityLabel = "Refresh drafts"

    search.searchResultsUpdater = self
    search.obscuresBackgroundDuringPresentation = false
    search.searchBar.placeholder = "Search drafts or channels"
    navigationItem.searchController = search
    navigationItem.hidesSearchBarWhenScrolling = false
    definesPresentationContext = true

    tableView.register(DraftCell.self, forCellReuseIdentifier: "draft")
    tableView.separatorStyle = .none
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 118
    tableView.sectionHeaderHeight = 34
    tableView.contentInset.bottom = 20
    refreshControl = UIRefreshControl()
    refreshControl?.tintColor = DraftsStyle.accent
    refreshControl?.addTarget(self, action: #selector(refreshCatalog), for: .valueChanged)
    configureHeader()
    refreshCatalog()
  }

  private func configureHeader() {
    let header = UIView()
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -20)
    ])
    let eyebrow = UILabel()
    eyebrow.text = "YOUR APP, IN PROGRESS"
    eyebrow.textColor = DraftsStyle.accent
    eyebrow.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
    stack.addArrangedSubview(eyebrow)
    let heading = UILabel()
    heading.text = "Choose a draft."
    heading.font = .preferredFont(forTextStyle: .largeTitle).withWeight(.bold)
    heading.adjustsFontForContentSizeCategory = true
    stack.addArrangedSubview(heading)
    subtitleLabel.numberOfLines = 0
    subtitleLabel.text = "Pull request previews. One native build.\nSwitch versions without a development server."
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.adjustsFontForContentSizeCategory = true
    stack.addArrangedSubview(subtitleLabel)
    let runtime = UILabel()
    runtime.text = manager.runtimeVersion.isEmpty ? "EAS UPDATE NOT ENABLED" : "iOS runtime  \(manager.runtimeVersion.prefix(18))\(manager.runtimeVersion.count > 18 ? "…" : "")"
    runtime.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
    runtime.textColor = .tertiaryLabel
    runtime.accessibilityLabel = "iOS runtime \(manager.runtimeVersion)"
    stack.addArrangedSubview(runtime)
    if manager.buildURL != nil {
      let buildButton = UIButton(type: .system)
      buildButton.setTitle("Get a new EAS build  ↗", for: .normal)
      buildButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
      buildButton.contentHorizontalAlignment = .leading
      buildButton.tintColor = DraftsStyle.accent
      buildButton.addAction(UIAction { [weak self] _ in self?.manager.openBuild() }, for: .touchUpInside)
      stack.addArrangedSubview(buildButton)
    }
    let width = view.bounds.width
    header.frame = CGRect(x: 0, y: 0, width: width, height: 1)
    let height = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
    header.frame.size.height = height
    tableView.tableHeaderView = header
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
        self.errorMessage = nil
      case .failure(let error): self.errorMessage = error.localizedDescription
      }
      self.updateBackground()
      self.tableView.reloadData()
    }
  }

  private func updateBackground() {
    let text: String?
    if loading && drafts.isEmpty { text = "Loading your drafts…" }
    else if let errorMessage { text = errorMessage }
    else if drafts.isEmpty { text = "No drafts yet.\nPublish a pull request preview to get started." }
    else if filteredDrafts.isEmpty { text = "No drafts match your search." }
    else { text = nil }

    guard let text else { tableView.tableFooterView = nil; return }
    let footer = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 160))
    statusLabel.text = text
    statusLabel.textAlignment = .center
    statusLabel.textColor = .secondaryLabel
    statusLabel.font = .preferredFont(forTextStyle: .subheadline)
    statusLabel.numberOfLines = 0
    statusLabel.frame = CGRect(x: 30, y: 12, width: footer.bounds.width - 60, height: 100)
    footer.addSubview(statusLabel)
    if errorMessage != nil {
      let retry = UIButton(type: .system)
      retry.setTitle("Try again", for: .normal)
      retry.tintColor = DraftsStyle.accent
      retry.frame = CGRect(x: 30, y: 114, width: footer.bounds.width - 60, height: 44)
      retry.addAction(UIAction { [weak self] _ in self?.refreshCatalog() }, for: .touchUpInside)
      footer.addSubview(retry)
    }
    tableView.tableFooterView = footer
  }

  func updateSearchResults(for searchController: UISearchController) {
    updateBackground()
    tableView.reloadData()
  }

  override func numberOfSections(in tableView: UITableView) -> Int { 1 }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredDrafts.count }
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    drafts.isEmpty ? nil : "\(filteredDrafts.count) DRAFT\(filteredDrafts.count == 1 ? "" : "S")"
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "draft", for: indexPath) as! DraftCell
    let draft = filteredDrafts[indexPath.row]
    cell.configure(draft, reason: manager.compatibility(draft), current: manager.isCurrent(draft), downloading: loadingDraftID == draft.id)
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard loadingDraftID == nil else { return }
    let draft = filteredDrafts[indexPath.row]
    guard manager.compatibility(draft) == nil else { return }
    if manager.isCurrent(draft) { dismiss(animated: true); return }
    search.isActive = false
    loadingDraftID = draft.id
    isModalInPresentation = true
    navigationItem.rightBarButtonItem?.isEnabled = false
    navigationItem.leftBarButtonItem?.isEnabled = false
    tableView.reloadData()
    manager.launch(draft) { [weak self] result in
      guard let self else { return }
      self.loadingDraftID = nil
      self.isModalInPresentation = false
      self.navigationItem.rightBarButtonItem?.isEnabled = true
      self.navigationItem.leftBarButtonItem?.isEnabled = true
      self.tableView.reloadData()
      switch result {
      case .success: self.dismiss(animated: true)
      case .failure(let error):
        let alert = UIAlertController(title: "Couldn't open draft", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Refresh drafts", style: .default) { [weak self] _ in self?.refreshCatalog() })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        self.present(alert, animated: true)
      }
    }
  }
}

private final class DraftCell: UITableViewCell {
  private let nameLabel = UILabel()
  private let metaLabel = UILabel()
  private let detailLabel = UILabel()
  private let stateLabel = UILabel()
  private let spinner = UIActivityIndicatorView(style: .medium)

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = DraftsStyle.card
    let stack = UIStackView(arrangedSubviews: [nameLabel, metaLabel, detailLabel, stateLabel])
    stack.axis = .vertical
    stack.spacing = 7
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 17),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -17)
    ])
    nameLabel.font = .preferredFont(forTextStyle: .headline)
    nameLabel.numberOfLines = 2
    metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    metaLabel.textColor = .secondaryLabel
    metaLabel.numberOfLines = 2
    detailLabel.font = .preferredFont(forTextStyle: .subheadline)
    detailLabel.textColor = .secondaryLabel
    detailLabel.numberOfLines = 2
    stateLabel.font = .preferredFont(forTextStyle: .caption1).withWeight(.semibold)
    stateLabel.numberOfLines = 2
    [nameLabel, detailLabel, stateLabel].forEach { $0.adjustsFontForContentSizeCategory = true }
    isAccessibilityElement = true
  }
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func configure(_ draft: DraftEntry, reason: String?, current: Bool, downloading: Bool) {
    nameLabel.text = draft.name
    nameLabel.textColor = reason == nil ? .label : .secondaryLabel
    var metadata = [draft.channel]
    if let pullRequest = draft.pullRequest { metadata.append("PR #\(pullRequest.number)") }
    if let hash = draft.gitCommitHash { metadata.append(String(hash.prefix(7))) }
    metaLabel.text = metadata.joined(separator: "  ·  ")
    detailLabel.text = draft.message
    detailLabel.isHidden = draft.message?.isEmpty ?? true
    if downloading {
      stateLabel.text = "Downloading update…"
      stateLabel.textColor = DraftsStyle.accent
      spinner.startAnimating()
      accessoryView = spinner
    } else {
      spinner.stopAnimating()
      accessoryView = nil
      stateLabel.text = reason ?? (current ? "●  Running on this device" : "Compatible  ·  Tap to open")
      stateLabel.textColor = reason == nil ? DraftsStyle.accent : UIColor(red: 0.90, green: 0.71, blue: 0.45, alpha: 1)
    }
    selectionStyle = reason == nil ? .default : .none
    accessibilityLabel = "\(draft.name), \(metadata.joined(separator: ", ")), \(stateLabel.text ?? "")"
    accessibilityTraits = reason == nil ? [.button] : [.notEnabled]
    accessibilityIdentifier = "expo-drafts-row-\(draft.channel)"
  }
}

private extension UIFont {
  func withWeight(_ weight: UIFont.Weight) -> UIFont {
    UIFont.systemFont(ofSize: pointSize, weight: weight)
  }
}
