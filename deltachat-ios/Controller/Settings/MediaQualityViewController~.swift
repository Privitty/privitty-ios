import UIKit
import DcCore
class MediaQualityViewController: UITableViewController {

    private var dcContext: DcContext

    private var options: [Int]

    private lazy var staticCells: [UITableViewCell] = {
        return options.map({
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = MediaQualityViewController.getValString(val: $0)
            return cell
        })
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.options = [Int(DC_MEDIA_QUALITY_BALANCED), Int(DC_MEDIA_QUALITY_WORSE)]
        super.init(style: .insetGrouped)
        self.title = String.localized("pref_outgoing_media_quality")
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func getValString(val: Int) -> String {
        switch Int32(val) {
        case DC_MEDIA_QUALITY_BALANCED:
            return String.localized("pref_outgoing_balanced")
        case DC_MEDIA_QUALITY_WORSE:
            return String.localized("pref_outgoing_worse")
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

        let oldIndexPath = IndexPath(row: dcContext.getConfigInt("media_quality"), section: 0)

        if let oldSelectedCell = tableView.cellForRow(at: oldIndexPath) {
            oldSelectedCell.accessoryType = .none
            oldSelectedCell.tintColor = .secondaryLabel
            oldSelectedCell.backgroundColor = DcColors.settingScreenBackgroundColor
            oldSelectedCell.contentView.backgroundColor = DcColors.settingScreenBackgroundColor
        }

        if let newSelectedCell = tableView.cellForRow(at: indexPath) {
            newSelectedCell.accessoryType = .checkmark
            newSelectedCell.tintColor = DcColors.defaultInverseColor

            newSelectedCell.backgroundColor = DcColors.iconBackgroundColor
            newSelectedCell.contentView.backgroundColor = DcColors.iconBackgroundColor
        }

        dcContext.setConfigInt("media_quality", indexPath.row)
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = staticCells[indexPath.row]
        if options[indexPath.row] == dcContext.getConfigInt("media_quality") {
            cell.accessoryType = .checkmark
            cell.tintColor = DcColors.defaultInverseColor
        }
        return cell
    }
    
//    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//        let bgColor = DcColors.settingScreenBackgroundColor
//        cell.backgroundColor = bgColor
//        cell.contentView.backgroundColor = bgColor
//    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let selectedValue = dcContext.getConfigInt("media_quality")
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
