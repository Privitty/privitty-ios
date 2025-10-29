import UIKit
import DcCore

class AvatarSelectionCell: UITableViewCell {
    let badgeSize: CGFloat = 72
    private var avatarSet = false

    var onAvatarTapped: (() -> Void)?

    lazy var defaultImage: UIImage = {
        return UIImage(named: "privitty_camera_icon") ?? UIImage()
    }()

    private lazy var imageButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = DcColors.privittyCameraBackgroundColor
        button.layer.masksToBounds = true
        button.layer.cornerRadius = badgeSize / 2
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.layer.borderWidth = 2
        button.layer.borderColor = DcColors.privittyThemeColor.cgColor
        button.addTarget(self, action: #selector(onAvatarButtonTapped), for: .touchUpInside)
        return button
    }()

    lazy var hintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DcColors.defaultTextColor
        label.text = String.localized("pref_profile_photo")
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var container: UIStackView = {
        let container = UIStackView(arrangedSubviews: [hintLabel, imageButton])
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    init(image: UIImage?) {
        super.init(style: .default, reuseIdentifier: nil)
        setupSubviews()
        setAvatar(image: image)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(container)
        container.alignTopToAnchor(contentView.layoutMarginsGuide.topAnchor)
        container.alignBottomToAnchor(contentView.layoutMarginsGuide.bottomAnchor)
        container.alignLeadingToAnchor(contentView.layoutMarginsGuide.leadingAnchor)
        container.alignTrailingToAnchor(contentView.layoutMarginsGuide.trailingAnchor)

        NSLayoutConstraint.activate([
            imageButton.widthAnchor.constraint(equalToConstant: badgeSize),
            imageButton.heightAnchor.constraint(equalToConstant: badgeSize)
        ])

        selectionStyle = .none
    }

    @objc func onAvatarButtonTapped() {
        onAvatarTapped?()
    }
    
    func getAvatarImage() -> UIImage? {
        return imageButton.image(for: .normal)
    }

    func setAvatar(image: UIImage?) {
        if let avatarImage = image {
            imageButton.setImage(avatarImage, for: .normal)
            imageButton.imageView?.contentMode = .scaleAspectFill
            imageButton.tintColor = nil
            avatarSet = true
        } else {
            if let image = UIImage(named: "privitty_camera_icon")?.withRenderingMode(.alwaysTemplate) {
                imageButton.setImage(image, for: .normal)
                imageButton.tintColor = DcColors.privittyThemeColor
                imageButton.imageView?.contentMode = .scaleAspectFit
                imageButton.imageEdgeInsets = UIEdgeInsets(top: 25, left: 25, bottom: 25, right: 25)
            }
            avatarSet = false
        }
    }

    func isAvatarSet() -> Bool {
        return avatarSet
    }
}
