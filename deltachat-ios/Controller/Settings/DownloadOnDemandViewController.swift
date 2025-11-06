import UIKit
import DcCore
class DownloadOnDemandViewController: UITableViewController {

    private var dcContext: DcContext

    private var options: [Int]

    private lazy var staticCells: [UITableViewCell] = {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = DownloadOnDemandViewController.getValString(val: $0)
            return cell
        })
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.options = [0, 163840, 655360, 5242880, 26214400]
        super.init(style: .insetGrouped)
        self.title = String.localized("auto_download_messages")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func getValString(val: Int) -> String {
        switch val {
        case 0:
            return String.localized("pref_show_emails_all")
        case 40960, 163840:
            return String.localizedStringWithFormat(String.localized("up_to_x_most_worse_quality_images"), "160 KiB")
        case 655360:
            return String.localizedStringWithFormat(String.localized("up_to_x_most_balanced_quality_images"), "640 KiB")
        case 5242880:
            return String.localizedStringWithFormat(String.localized("up_to_x"), "5 MiB")
        case 26214400:
            return String.localizedStringWithFormat(String.localized("up_to_x"), "25 MiB")
        default:
            return "Err"
        }
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let lastSelectedIndex = options.firstIndex(of: dcContext.getConfigInt("download_limit")) {
            let oldIndexPath = IndexPath(row: lastSelectedIndex, section: 0)
            if let oldSelectedCell = tableView.cellForRow(at: oldIndexPath) {
                oldSelectedCell.accessoryType = .none
                oldSelectedCell.tintColor = .secondaryLabel
                oldSelectedCell.backgroundColor = DcColors.settingScreenBackgroundColor
                oldSelectedCell.contentView.backgroundColor = DcColors.settingScreenBackgroundColor
            }
        }

        if let newSelectedCell = tableView.cellForRow(at: indexPath) {
            newSelectedCell.accessoryType = .checkmark
            newSelectedCell.tintColor = DcColors.defaultInverseColor
            newSelectedCell.backgroundColor = DcColors.iconBackgroundColor
            newSelectedCell.contentView.backgroundColor = DcColors.iconBackgroundColor
        }

        dcContext.setConfigInt("download_limit", options[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if options[indexPath.row] == dcContext.getConfigInt("download_limit") {
            cell.accessoryType = .checkmark
            cell.tintColor = DcColors.privittyThemeColor
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let selectedValue = dcContext.getConfigInt("download_limit")
        if options[indexPath.row] != selectedValue {
            let bgColor = DcColors.settingScreenBackgroundColor
            cell.backgroundColor = bgColor
            cell.contentView.backgroundColor = bgColor
        } else {
            cell.backgroundColor = DcColors.iconBackgroundColor
            cell.contentView.backgroundColor = DcColors.iconBackgroundColor
        }
    }
}
