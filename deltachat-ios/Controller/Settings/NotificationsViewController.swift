import UIKit
import DcCore
import Intents
import Network

internal final class NotificationsViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        var footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case defaultTagValue = 0
        case systemSettings
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    // MARK: - cells
    private lazy var notificationsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_notifications"),
            on: !dcContext.isMuted(),
            action: { [weak self] cell in
                guard let self else { return }

                dcContext.setMuted(!cell.isOn)
                if cell.isOn {
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.registerForNotifications()
                    }
                } else {
                    NotificationManager.removeAllNotifications()
                }

                UIView.animate(withDuration: 0.25) {
                    if cell.uiSwitch.isOn {
                        cell.uiSwitch.onTintColor = DcColors.iconBackgroundColor
                        cell.uiSwitch.thumbTintColor = DcColors.privittyThemeColor
                    } else {
                        cell.uiSwitch.onTintColor = DcColors.settingScreenBackgroundColor
                        cell.uiSwitch.thumbTintColor = DcColors.switchOnOffStateColor
                    }
                }

                // Update dependent UI and notifications
                self.updateCells()
                self.updateNotificationWarning()
                NotificationManager.updateBadgeCounters()

                NotificationCenter.default.post(
                    name: Event.messagesChanged,
                    object: nil,
                    userInfo: ["message_id": Int(0), "chat_id": Int(0)]
                )
            }
        )
    }()
    
    private lazy var mentionsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_mention_notifications"),
            on: false,
            action: { [weak self] cell in
                guard let self else { return }
                self.dcContext.setMentionsEnabled(cell.isOn)

                UIView.animate(withDuration: 0.25) {
                    if cell.uiSwitch.isOn {
                        cell.uiSwitch.onTintColor = DcColors.iconBackgroundColor
                        cell.uiSwitch.thumbTintColor = DcColors.privittyThemeColor
                    } else {
                        cell.uiSwitch.onTintColor = DcColors.settingScreenBackgroundColor
                        cell.uiSwitch.thumbTintColor = DcColors.switchOnOffStateColor
                    }
                }
            }
        )
    }()

    private lazy var systemSettingsCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.systemSettings.rawValue
        cell.textLabel?.text = String.localized("system_settings")
        cell.textLabel?.textColor =  DcColors.privittyThemeColor
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let notificationsSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [notificationsCell]
        )
        let mentionsSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("pref_mention_notifications_explain"),
            cells: [mentionsCell]
        )
        let systemSettingsSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: String.localized("system_settings_notify_explain_ios"),
            cells: [systemSettingsCell]
        )
        return [notificationsSection, mentionsSection, systemSettingsSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationsViewController.handleConnectivityChanged(_:)), name: Event.connectivityChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NotificationsViewController.applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_notifications")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCells()
        updateNotificationWarning()
    }

    @objc private func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            updateNotificationWarning()
        }
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        updateNotificationWarning()
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else { safe_fatalError(); return }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .systemSettings:
            let urlString = if #available(iOS 16, *) {
                UIApplication.openNotificationSettingsURLString
            } else if #available(iOS 15.4, *) {
                UIApplicationOpenNotificationSettingsURLString
            } else {
                UIApplication.openSettingsURLString
            }

            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        case .defaultTagValue:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let bgColor = DcColors.settingScreenBackgroundColor
        cell.backgroundColor = bgColor
        cell.contentView.backgroundColor = bgColor
    }
 
    private func updateSwitchColors(_ uiSwitch: UISwitch, isOn: Bool) {
        UIView.animate(withDuration: 0.25) {
            if isOn {
                uiSwitch.onTintColor = DcColors.iconBackgroundColor       // Track when ON
                uiSwitch.thumbTintColor = DcColors.privittyThemeColor     // Circle when ON
            } else {
                uiSwitch.onTintColor = DcColors.settingScreenBackgroundColor // Track when OFF
                uiSwitch.thumbTintColor = DcColors.switchOnOffStateColor     // Circle when OFF
            }
        }
    }

    
    private func updateCells() {
        let isMuted = dcContext.isMuted()
        let isMentionsEnabled = dcContext.isMentionsEnabled
        let mentionSwitch = mentionsCell.uiSwitch
        mentionSwitch.isEnabled = !isMuted
        mentionSwitch.setOn(!isMuted && isMentionsEnabled, animated: false)
        updateSwitchColors(mentionSwitch, isOn: mentionSwitch.isOn)
        let notifSwitch = notificationsCell.uiSwitch
        notifSwitch.setOn(!isMuted, animated: false)
        updateSwitchColors(notifSwitch, isOn: notifSwitch.isOn)
    }

    private func updateNotificationWarning() {
        NotificationsViewController.getNotificationStatus(dcContext: dcContext) { warning in
            DispatchQueue.runOnMain { [weak self] in
                self?.sections[0].footerTitle = if let warning {
                    "⚠️ " + warning
                } else {
                    nil
                }
                self?.tableView.reloadData()
            }
        }
    }

    static func isLowDataMode() -> Bool {
        assert(!Thread.isMainThread)
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            result = path.isConstrained
            semaphore.signal()
        }
        monitor.start(queue: DispatchQueue.global())
        _ = semaphore.wait(timeout: .now() + 1)
        monitor.cancel()
        return result
    }

    static func getNotificationStatus(dcContext: DcContext, completionHandler: @escaping (String?) -> Void) {
        DispatchQueue.runOnMain {
            // `UIApplication.shared` needs to be called from main thread
            let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

            // do the remaining things in background thread
            DispatchQueue.global(qos: .userInitiated).async {
                if dcContext.isAnyDatabaseEncrypted() {
                    completionHandler("Unreliable due to \"Encrypted Accounts\" experiment, see \"Device Messages\" for fixing")
                    return
                }

                if dcContext.isMuted() {
                    completionHandler(nil)
                    return
                }

                let connectiviy = dcContext.getConnectivity()
                let pushState = dcContext.getPushState()
                var notificationsEnabledInSystem = false
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .userInitiated).async {
                    NotificationManager.notificationEnabledInSystem { enabled in
                        notificationsEnabledInSystem = enabled
                        semaphore.signal()
                    }
                }
                if semaphore.wait(timeout: .now() + 1) == .timedOut {
                    completionHandler(nil)
                    return
                }

                if !notificationsEnabledInSystem {
                    completionHandler(String.localized("disabled_in_system_settings"))
                    return
                }

                if backgroundRefreshStatus != .available {
                    completionHandler(String.localized("bg_app_refresh_disabled"))
                    return
                }

                if pushState == DC_PUSH_NOT_CONNECTED || connectiviy == DC_CONNECTIVITY_NOT_CONNECTED {
                    completionHandler(String.localized("connectivity_not_connected"))
                    return
                }

                if pushState == DC_PUSH_CONNECTED {
                    // "low data" and "low power" modes do not affect push
                    completionHandler(nil)
                    return
                }

                if isLowDataMode() {
                    completionHandler(String.localized("connectivity_low_data_mode"))
                    return
                }

                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    completionHandler(String.localized("connectivity_low_power_mode"))
                    return
                }

                let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double]
                guard let timestamps = timestamps, !timestamps.isEmpty else {
                    // in most cases, here the app was just installed and we do not have any data.
                    // so, do not show something error-like here.
                    // (in case of errors, it usually converts to an error sooner or later)
                    completionHandler(nil)
                    return
                }

                let averageDelta = (Double(Date().timeIntervalSince1970) - timestamps.first!) / Double(timestamps.count)

                var lastWakeups = ""
                var lastWakeupsCnt = 0
                for timestamp in timestamps.reversed() {
                    lastWakeups += (lastWakeupsCnt > 0 ? ", " : "") + DateUtils.getExtendedAbsTimeSpanString(timeStamp: timestamp)
                    lastWakeupsCnt += 1
                    if lastWakeupsCnt >= 3 {
                        break
                    }
                }

                let avg = "Server does not support instant delivery. "
                    .appending(" ")
                    .appending(String.localizedStringWithFormat(String.localized("last_check_at"), lastWakeups))
                    .appending(", ")
                    .appending(averageDelta / 3600 > 2 ?
                               String.localized(stringID: "notifications_avg_hours", parameter: Int(averageDelta / 3600)) :
                                String.localized(stringID: "notifications_avg_minutes", parameter: Int(averageDelta / 60)))
                completionHandler(avg)
            }
        }
    }
}
