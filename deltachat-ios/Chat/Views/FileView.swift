import UIKit
import DcCore

public class FileView: UIView {

    // MARK: - Properties
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var currentStatus: PrvContext.FileAccessStatus?

    public var horizontalLayout: Bool {
        get {
            return true // Always horizontal for new design
        }
        set {
            // Kept for compatibility, but ignored
        }
    }

    public var allowLayoutChange: Bool = false // Disabled for new design

    // MARK: - Two-Box Layout Views
    
    // Outer Box (colored background based on status)
    private lazy var outerBoxView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    // Header Label ("Document File", "Image File", etc.)
    private lazy var fileTypeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .label // Use .label for proper dark mode support
        label.text = "Document File"
        return label
    }()
    
    // Inner Box (colored background based on status)
    private lazy var innerBoxView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    // Inner Box Stack View (icon + text)
    private lazy var innerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileImageView, fileMetadataStackView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()
    
    // File Icon
    lazy var fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // File metadata (name + size)
    private lazy var fileMetadataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileTitle, fileSubtitle])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        stackView.spacing = 2
        return stackView
    }()
    
    // File name
    lazy var fileTitle: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = .label
        return label
    }()
    
    // File size + PRV
    private lazy var fileSubtitle: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.numberOfLines = 1
        label.textColor = .secondaryLabel
        return label
    }()
    
    // Access Until label (below inner box)
    private lazy var accessUntilLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .label // Use .label for proper dark mode support
        label.numberOfLines = 1
        return label
    }()

    // MARK: - Initialization

    convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    func setupSubviews() {
        // Add outer box
        addSubview(outerBoxView)
        
        // Add file type label to outer box
        outerBoxView.addSubview(fileTypeLabel)
        
        // Add inner box to outer box
        outerBoxView.addSubview(innerBoxView)
        
        // Add inner stack to inner box
        innerBoxView.addSubview(innerStackView)
        
        // Add access until label to outer box
        outerBoxView.addSubview(accessUntilLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Outer box fills the view
            outerBoxView.topAnchor.constraint(equalTo: topAnchor),
            outerBoxView.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerBoxView.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerBoxView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // File type label at top of outer box
            fileTypeLabel.topAnchor.constraint(equalTo: outerBoxView.topAnchor, constant: 8),
            fileTypeLabel.leadingAnchor.constraint(equalTo: outerBoxView.leadingAnchor, constant: 12),
            fileTypeLabel.trailingAnchor.constraint(equalTo: outerBoxView.trailingAnchor, constant: -12),
            
            // Inner box below file type label
            innerBoxView.topAnchor.constraint(equalTo: fileTypeLabel.bottomAnchor, constant: 6),
            innerBoxView.leadingAnchor.constraint(equalTo: outerBoxView.leadingAnchor, constant: 8),
            innerBoxView.trailingAnchor.constraint(equalTo: outerBoxView.trailingAnchor, constant: -8),
            
            // Inner stack fills inner box with padding
            innerStackView.topAnchor.constraint(equalTo: innerBoxView.topAnchor, constant: 8),
            innerStackView.leadingAnchor.constraint(equalTo: innerBoxView.leadingAnchor, constant: 8),
            innerStackView.trailingAnchor.constraint(equalTo: innerBoxView.trailingAnchor, constant: -8),
            innerStackView.bottomAnchor.constraint(equalTo: innerBoxView.bottomAnchor, constant: -8),
            
            // File icon size
            fileImageView.widthAnchor.constraint(equalToConstant: 32),
            fileImageView.heightAnchor.constraint(equalToConstant: 32),
            
            // Access until label below inner box
            accessUntilLabel.topAnchor.constraint(equalTo: innerBoxView.bottomAnchor, constant: 6),
            accessUntilLabel.leadingAnchor.constraint(equalTo: outerBoxView.leadingAnchor, constant: 12),
            accessUntilLabel.trailingAnchor.constraint(equalTo: outerBoxView.trailingAnchor, constant: -12),
            accessUntilLabel.bottomAnchor.constraint(equalTo: outerBoxView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Configuration

    public func configure(message: DcMsg,
                          status: PrvContext.FileAccessStatusData? = nil,
                          forceWebxdcSummary: String? = nil) {
        if message.type == DC_MSG_WEBXDC {
            configureWebxdc(message: message, forceWebxdcSummary: forceWebxdcSummary)
        } else if message.type == DC_MSG_FILE || message.isUnsupportedMediaFile {
            configureFile(message: message, status: status)
        } else {
            logger.error("Configuring message failed")
        }
    }

    private func configureWebxdc(message: DcMsg, forceWebxdcSummary: String?) {
        // Keep webxdc simple - use inner box for now
        fileTypeLabel.text = "Webxdc App"
        
        let dict = message.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = message.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                fileImageView.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 64, height: 64), scaleMode: .aspectFill)
            }
        }

        let document = dict["document"] as? String ?? ""
        let summary = dict["summary"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName"

        fileTitle.text = document.isEmpty ? name : "\(document) – \(name)"
        fileSubtitle.text = forceWebxdcSummary ?? (summary.isEmpty ? String.localized("webxdc_app") : summary)
        
        // Default colors for webxdc (not using access status)
        applyDefaultColors()
        accessUntilLabel.isHidden = true
    }

    private func configureFile(message: DcMsg, status: PrvContext.FileAccessStatusData?) {
        // Extract file type from filename
        let filename = message.filename ?? "Unknown"
        let fileType = extractFileType(from: filename)
        fileTypeLabel.text = fileType.displayName
        
        // Set appropriate icon
        fileImageView.image = fileType.icon
        
        // Set filename (truncate middle)
        fileTitle.text = filename
        
        // Set file size + PRV indicator
        let sizeText = message.getPrettyFileSize()
        let isPrvFile = filename.hasSuffix(".prv")
        fileSubtitle.text = isPrvFile ? "\(sizeText) PRV" : sizeText
        
        // Apply colors based on access status
        if let status = status {
            currentStatus = status.status
            applyColors(for: status.status)
            
            // Show "Access Until" label with expiry date
            if let expiryTime = status.expiryTime, status.status == .active {
                accessUntilLabel.text = "Access Until: \(formatExpiryDate(expiryTime))"
                accessUntilLabel.isHidden = false
            } else if status.status == .expired, let expiryTime = status.expiryTime {
                accessUntilLabel.text = "Expired: \(formatExpiryDate(expiryTime))"
                accessUntilLabel.isHidden = false
            } else if status.status == .requested || status.status == .waitingOwnerAction {
                accessUntilLabel.text = "Requesting access..."
                accessUntilLabel.isHidden = false
            } else if status.status == .denied {
                accessUntilLabel.text = "Access denied"
                accessUntilLabel.isHidden = false
            } else if status.status == .revoked {
                accessUntilLabel.text = "Access revoked"
                accessUntilLabel.isHidden = false
            } else {
                accessUntilLabel.isHidden = true
            }
        } else {
            // No status - use default colors (active state)
            currentStatus = .active
            applyColors(for: .active)
            accessUntilLabel.isHidden = true
        }
    }

    // MARK: - File Type Detection

    private enum FileType {
        case pdf
        case image
        case video
        case generic
        
        var displayName: String {
            switch self {
            case .pdf: return "PDF Document"
            case .image: return "Image File"
            case .video: return "Video File"
            case .generic: return "Document File"
            }
        }
        
        var icon: UIImage {
            switch self {
            case .pdf:
                return UIImage(systemName: "doc.fill") ?? UIImage(systemName: "document")!
            case .image:
                return UIImage(systemName: "photo.fill") ?? UIImage(systemName: "photo")!
            case .video:
                return UIImage(systemName: "play.rectangle.fill") ?? UIImage(systemName: "play.rectangle")!
            case .generic:
                return UIImage(systemName: "doc.fill") ?? UIImage(systemName: "document")!
            }
        }
    }
    
    private func extractFileType(from filename: String) -> FileType {
        // Check for double extension (e.g., "file.pdf.prv")
        let lowercased = filename.lowercased()
        
        if lowercased.hasSuffix(".prv") {
            // Remove .prv and check the real extension
            let withoutPrv = String(lowercased.dropLast(4)) // Remove ".prv"
            
            if withoutPrv.hasSuffix(".pdf") {
                return .pdf
            } else if withoutPrv.hasSuffix(".png") || withoutPrv.hasSuffix(".jpg") || 
                      withoutPrv.hasSuffix(".jpeg") || withoutPrv.hasSuffix(".gif") || 
                      withoutPrv.hasSuffix(".heic") || withoutPrv.hasSuffix(".bmp") {
                return .image
            } else if withoutPrv.hasSuffix(".mov") || withoutPrv.hasSuffix(".mp4") || 
                      withoutPrv.hasSuffix(".avi") || withoutPrv.hasSuffix(".mkv") || 
                      withoutPrv.hasSuffix(".m4v") {
                return .video
            }
        } else {
            // Non-encrypted file - check extension directly
            if lowercased.hasSuffix(".pdf") {
                return .pdf
            } else if lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpg") || 
                      lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".gif") || 
                      lowercased.hasSuffix(".heic") || lowercased.hasSuffix(".bmp") {
                return .image
            } else if lowercased.hasSuffix(".mov") || lowercased.hasSuffix(".mp4") || 
                      lowercased.hasSuffix(".avi") || lowercased.hasSuffix(".mkv") || 
                      lowercased.hasSuffix(".m4v") {
                return .video
            }
        }
        
        return .generic
    }

    // MARK: - Color Application

    private func applyColors(for status: PrvContext.FileAccessStatus) {
        switch status {
        case .requested, .waitingOwnerAction:
            // Requesting Access: Inner #7F66C5, Outer #E7E7E7
            innerBoxView.backgroundColor = DcColors.fileAccessInnerPurple
            outerBoxView.backgroundColor = DcColors.fileAccessOuterGray
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label // Adapts to theme
            accessUntilLabel.textColor = .label // Adapts to theme
            
        case .denied:
            // Request Denied: Inner #D93229, Outer #FEE4E2
            innerBoxView.backgroundColor = DcColors.fileAccessInnerRed
            outerBoxView.backgroundColor = DcColors.fileAccessOuterLightRed
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label
            accessUntilLabel.textColor = .label
            
        case .revoked:
            // Access Revoked: Inner #C4891B, Outer #FDFCED
            innerBoxView.backgroundColor = DcColors.fileAccessInnerOrange
            outerBoxView.backgroundColor = DcColors.fileAccessOuterYellow
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label
            accessUntilLabel.textColor = .label
            
        case .expired:
            // Access Expired: Inner #B0B0B0, Outer #D1D1D1
            innerBoxView.backgroundColor = DcColors.fileAccessInnerDarkGray
            outerBoxView.backgroundColor = DcColors.fileAccessOuterLightGray
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label
            accessUntilLabel.textColor = .label
            
        case .active:
            // Access Granted: Inner #7F66C5, Outer #E7E7E7
            innerBoxView.backgroundColor = DcColors.fileAccessInnerPurple
            outerBoxView.backgroundColor = DcColors.fileAccessOuterGray
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label
            accessUntilLabel.textColor = .label
            
        case .deleted, .notFound:
            // Treat like expired
            innerBoxView.backgroundColor = DcColors.fileAccessInnerDarkGray
            outerBoxView.backgroundColor = DcColors.fileAccessOuterLightGray
            fileTitle.textColor = .white
            fileSubtitle.textColor = .white.withAlphaComponent(0.9)
            fileImageView.tintColor = .white
            fileTypeLabel.textColor = .label
            accessUntilLabel.textColor = .label
        }
    }
    
    private func applyDefaultColors() {
        // Default colors for non-Privitty files
        innerBoxView.backgroundColor = DcColors.fileAccessOuterGray
        outerBoxView.backgroundColor = .systemBackground
        fileTitle.textColor = .label
        fileSubtitle.textColor = .secondaryLabel
        fileImageView.tintColor = .label
        fileTypeLabel.textColor = .label
        accessUntilLabel.textColor = .label
    }

    // MARK: - Date Formatting

    private func formatExpiryDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Accessibility

    public func configureAccessibilityLabel() -> String {
        var accessibilityFileTitle = ""
        var accessiblityFileSubtitle = ""
        var accessibilityStatus = ""
        
        if let fileTitleText = fileTitle.text {
            accessibilityFileTitle = fileTitleText
        }
        if let subtitleText = fileSubtitle.text {
            accessiblityFileSubtitle = subtitleText
        }
        if let accessUntilText = accessUntilLabel.text, !accessUntilLabel.isHidden {
            accessibilityStatus = accessUntilText
        }
        
        return "\(accessibilityFileTitle), \(accessiblityFileSubtitle), \(accessibilityStatus)"
    }

    public func prepareForReuse() {
        fileImageView.image = nil
        fileTitle.text = nil
        fileSubtitle.text = nil
        accessUntilLabel.text = nil
        currentStatus = nil
    }
}
