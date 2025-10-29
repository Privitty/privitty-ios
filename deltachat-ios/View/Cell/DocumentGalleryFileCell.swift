import UIKit
import DcCore

class DocumentGalleryFileCell: UITableViewCell {

    static let reuseIdentifier = "document_gallery_file_cell"

    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize + UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 24
        if textHeight > 60 {
            return textHeight
        }
        return 60
    }

    private let fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [title, subtitle])
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fillProportionally
        stackView.contentMode = .center
        return stackView
    }()

    private lazy var title: UILabel = {
        let title = UILabel()
        title.font = UIFont.preferredFont(forTextStyle: .headline)
        title.translatesAutoresizingMaskIntoConstraints = false
        return title
    }()

    private lazy var subtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        return subtitle
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        fileImageView.image = nil
        title.text = nil
        subtitle.text = nil
    }

    // MARK: - layout
    private func setupSubviews() {
        contentView.addSubview(fileImageView)
        contentView.addSubview(stackView)
        fileImageView.translatesAutoresizingMaskIntoConstraints = false
        fileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        fileImageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, multiplier: 0.9).isActive = true
        fileImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        fileImageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.constraintToTrailingOf(fileImageView, paddingLeading: 12).isActive = true
        stackView.constraintAlignTrailingTo(contentView, paddingTrailing: 12).isActive = true
        stackView.constraintAlignTopTo(contentView, paddingTop: 6).isActive = true
        stackView.constraintAlignBottomTo(contentView, paddingBottom: 6).isActive = true

    }

    // MARK: - update
    func update(msg: DcMsg, dcContext: DcContext) {
        if msg.type == DC_MSG_VOICE {
            updateVoiceMsg(msg: msg, dcContext: dcContext)
        } else if msg.type == DC_MSG_WEBXDC {
            updateWebxdcMsg(msg: msg)
        } else {
            updateFileMsg(msg: msg)
        }
    }
    
    private func configureMessageIcon(imageName: String, titleText: String, subtitleText: String) {
        contentView.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }

        let iconBackgroundView = UIView()
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        iconBackgroundView.backgroundColor = DcColors.privittyButtonsBackgroundColor
        iconBackgroundView.layer.cornerRadius = 22.5
        iconBackgroundView.layer.masksToBounds = true
        iconBackgroundView.tag = 999
        contentView.addSubview(iconBackgroundView)

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = DcColors.whiteBackground
        iconImageView.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        iconBackgroundView.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconBackgroundView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 45),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 45),

            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        title.text = titleText
        subtitle.text = subtitleText

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
    }

    private func updateFileMsg(msg: DcMsg) {
        configureMessageIcon(
            imageName: "files_icon",
            titleText: msg.filename ?? "",
            subtitleText: msg.getPrettyFileSize()
        )
    }

    private func updateVoiceMsg(msg: DcMsg, dcContext: DcContext) {
        configureMessageIcon(
            imageName: "play_voice_icon",
            titleText: msg.getSenderName(dcContext.getContact(id: msg.fromContactId)),
            subtitleText: msg.formattedSentDate()
        )
    }

    private func updateWebxdcMsg(msg: DcMsg) {
        let dict = msg.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = msg.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                fileImageView.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            }
        }

        let document = dict["document"] as? String ?? ""
        let summary = dict["summary"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName" // name should not be empty

        title.text = document.isEmpty ? name : "\(document) – \(name)"
        subtitle.text = summary.isEmpty ? nil : summary
    }

    private func generateThumbnailFor(url: URL, placeholder: UIImage?) {
        if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
        } else {
            let controller = UIDocumentInteractionController(url: url)
            fileImageView.image = controller.icons.first ?? placeholder
        }
    }
}
