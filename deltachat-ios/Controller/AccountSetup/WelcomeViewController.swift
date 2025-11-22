import UIKit
import DcCore

class WelcomeViewController: UIViewController {
    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    private let accountCode: String?
    private var backupProgressObserver: NSObjectProtocol?
    private var securityScopedResource: NSURL?

    var progressAlertHandler: ProgressAlertHandler

    private lazy var welcomeView: WelcomeContentView = {
        let view = WelcomeContentView()
        view.onSignUp = { [weak self] in
            guard let self else { return }
            let controller = InstantOnboardingViewController(dcAccounts: dcAccounts)
            navigationController?.pushViewController(controller, animated: true)
        }
        view.onLogIn = { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(title: String.localized("onboarding_alternative_logins"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("multidevice_receiver_title"), style: .default, handler: addAsSecondDevice(_:)))
            alert.addAction(UIAlertAction(title: String.localized("import_backup_title"), style: .default, handler: restoreBackup(_:)))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DcColors.privittyThemeColor
        return view
    }()

    private lazy var canCancel: Bool = {
        // "cancel" removes selected unconfigured account, so there needs to be at least one other account
        return dcAccounts.getAll().count >= 2
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelAccountCreation))
    }()

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private var qrCodeReader: QrCodeReaderController?

    init(dcAccounts: DcAccounts, accountCode: String? = nil) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        self.accountCode = accountCode

        progressAlertHandler = ProgressAlertHandler()

        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized(canCancel ? "add_account" : "welcome_desktop")

        progressAlertHandler.dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DcColors.privittyThemeColor
        
        // Hide navigation bar for full-screen design
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupSubviews()
        if let accountCode {
            handleQrCode(accountCode)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        welcomeView.minContainerHeight = view.frame.height
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        welcomeView.minContainerHeight = size.height
     }

    private func removeBackupProgressObserver() {
        if let backupProgressObserver {
            NotificationCenter.default.removeObserver(backupProgressObserver)
        }
    }

    // MARK: - setup
    private func setupSubviews() {
        // Add welcome view directly to fill entire screen
        view.addSubview(welcomeView)
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            welcomeView.topAnchor.constraint(equalTo: view.topAnchor),
            welcomeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            welcomeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            welcomeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - actions

    private func addAsSecondDevice(_ action: UIAlertAction) {
        let qrReader = QrCodeReaderController(title: String.localized("multidevice_receiver_title"),
                    addHints: "➊ " + String.localized("multidevice_same_network_hint") + "\n\n"
                        +     "➋ " + String.localized("multidevice_open_settings_on_other_device"),
                    showTroubleshooting: true)
        qrReader.delegate = self
        qrCodeReader = qrReader
        navigationController?.pushViewController(qrReader, animated: true)
    }

    private func handleBackupRestoreSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.registerForNotifications()
        appDelegate.reloadDcContext()
        appDelegate.prepopulateWidget()
    }

    @objc private func cancelAccountCreation() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        // take a bit care on account removal:
        // remove only openend and unconfigured and make sure, there is another account
        // (normally, both checks are not needed, however, some resilience wrt future program-flow-changes seems to be reasonable here)
        let selectedAccount = dcAccounts.getSelected()
        if selectedAccount.isOpen() && !selectedAccount.isConfigured() {
            _ = dcAccounts.remove(id: selectedAccount.id)
            KeychainManager.deleteAccountSecret(id: selectedAccount.id)
            if self.dcAccounts.getAll().isEmpty {
                _ = self.dcAccounts.add()
            }
        }

        let lastSelectedAccountId = UserDefaults.standard.integer(forKey: Constants.Keys.lastSelectedAccountKey)
        if lastSelectedAccountId != 0 {
            _ = dcAccounts.select(id: lastSelectedAccountId)
            dcAccounts.startIo()
        }

        appDelegate.reloadDcContext()
    }

    private func restoreBackup(_ action: UIAlertAction) {
        if dcContext.isConfigured() {
            return
        }
        mediaPicker?.showDocumentLibrary(selectBackupArchives: true)
    }

    private func importBackup(at filepath: String) {
        logger.info("restoring backup: \(filepath)")
        progressAlertHandler.showProgressAlert(title: String.localized("import_backup_title"), dcContext: dcContext)
        dcAccounts.stopIo()
        dcContext.imex(what: DC_IMEX_IMPORT_BACKUP, directory: filepath)
    }

    private func addProgressHudBackupListener(importByFile: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
        backupProgressObserver = NotificationCenter.default.addObserver(
            forName: Event.importExportProgress,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            self?.handleImportExportProgress(notification, importByFile: importByFile)
        }
    }

    // MARK: - Notifications
    @objc private func handleImportExportProgress(_ notification: Notification, importByFile: Bool) {
        guard let ui = notification.userInfo else { return }

        if let error = ui["error"] as? Bool, error {
            UIApplication.shared.isIdleTimerDisabled = false
            if dcContext.isConfigured() {
                let accountId = dcContext.id
                _ = dcAccounts.remove(id: accountId)
                KeychainManager.deleteAccountSecret(id: accountId)
                _ = dcAccounts.add()
                dcContext = dcAccounts.getSelected()
                navigationItem.title = String.localized(canCancel ? "add_account" : "welcome_desktop")
            }
            progressAlertHandler.updateProgressAlert(error: ui["errorMessage"] as? String ?? "ErrString")
            stopAccessingSecurityScopedResource()
            removeBackupProgressObserver()
        } else if let done = ui["done"] as? Bool, done {
            UIApplication.shared.isIdleTimerDisabled = false
            dcAccounts.startIo()
            progressAlertHandler.updateProgressAlertSuccess(completion: handleBackupRestoreSuccess)
            removeBackupProgressObserver()
            stopAccessingSecurityScopedResource()
        } else if importByFile {
            progressAlertHandler.updateProgressAlertValue(value: ui["progress"] as? Int)
        } else {
            guard let permille = ui["progress"] as? Int else { return }
            var statusLineText = ""
            if permille < 1000 {
                let percent: Int = permille/10
                statusLineText = String.localized("transferring") + " \(percent)%"
            }
            progressAlertHandler.updateProgressAlert(message: statusLineText)
        }
    }
}

// MARK: - QrCodeReaderDelegate
extension WelcomeViewController: QrCodeReaderDelegate {
    func handleQrCode(_ qrCode: String) {
        let lot = dcContext.checkQR(qrCode: qrCode)
        if lot.state == DC_QR_BACKUP2 {
            confirmSetupNewDevice(qrCode: qrCode)
        } else if lot.state == DC_QR_BACKUP_TOO_NEW {
            qrErrorAlert(title: String.localized("multidevice_receiver_needs_update"))
        } else {
            qrErrorAlert(title: String.localized("qraccount_qr_code_cannot_be_used"), message: dcContext.lastErrorString)
        }
    }

    private func confirmSetupNewDevice(qrCode: String) {
        triggerLocalNetworkPrivacyAlert()
        let alert = UIAlertController(title: String.localized("multidevice_receiver_title"),
                                      message: String.localized("multidevice_receiver_scanning_ask"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(
             title: String.localized("ok"),
             style: .default,
             handler: { [weak self] _ in
                 guard let self else { return }
                 if self.dcAccounts.getSelected().isConfigured() {
                     UserDefaults.standard.setValue(self.dcAccounts.getSelected().id, forKey: Constants.Keys.lastSelectedAccountKey)
                     _ = self.dcAccounts.add()
                 }
                 let accountId = self.dcAccounts.getSelected().id
                 if accountId != 0 {
                     self.dcContext = self.dcAccounts.get(id: accountId)
                     self.dismissQRReader()
                     self.addProgressHudBackupListener(importByFile: false)
                     self.progressAlertHandler.showProgressAlert(title: String.localized("multidevice_receiver_title"), dcContext: self.dcContext)
                     self.dcAccounts.stopIo()
                     DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                         guard let self else { return }
                         logger.info("##### receiveBackup() with qr: \(qrCode)")
                         let res = self.dcContext.receiveBackup(qrCode: qrCode)
                         logger.info("##### receiveBackup() done with result: \(res)")
                     }
                 }
             }
        ))
        alert.addAction(UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { [weak self] _ in
                self?.dcContext.stopOngoingProcess()
                self?.dismissQRReader()
            }
        ))
        if let qrCodeReader {
            qrCodeReader.present(alert, animated: true)
        } else {
            self.present(alert, animated: true)
        }
    }

    private func qrErrorAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                guard let self else { return }
                if self.accountCode != nil {
                    // if an injected accountCode exists, the WelcomeViewController was only opened to handle that
                    // if the action failed the whole controller should be dismissed
                    self.cancelAccountCreation()
                } else {
                    self.qrCodeReader?.startSession()
                }
            }
        )
        alert.addAction(okAction)
        qrCodeReader?.present(alert, animated: true, completion: nil)
    }

    private func dismissQRReader() {
        self.navigationController?.popViewController(animated: true)
        self.qrCodeReader = nil
    }

    private func stopAccessingSecurityScopedResource() {
        self.securityScopedResource?.stopAccessingSecurityScopedResource()
        self.securityScopedResource = nil
    }
}

// MARK: - WelcomeContentView
class WelcomeContentView: UIView {

    var onSignUp: VoidFunction?
    var onLogIn: VoidFunction?

    var minContainerHeight: CGFloat = 0 {
        didSet {
            bottomSheetHeightConstraint?.constant = max(minContainerHeight * 0.59, 539) // Figma: 539px height
        }
    }

    private var bottomSheetHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Top Section (Purple Background with Logo)
    private lazy var topSection: UIView = {
        let view = UIView()
        view.backgroundColor = DcColors.privittyThemeColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var logoView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "privitty_logo_without_title"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Bottom Sheet (Light Violet with Rounded Top Corners)
    private lazy var bottomSheet: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "F8F5FF") // Figma: #F8F5FF
        view.layer.cornerRadius = 32 // Figma: 32px
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 10
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Ellipse Ring (Behind headline)
    private lazy var ellipseRingView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(hexString: "D2D2F3").cgColor // Figma: #D2D2F3
        view.layer.borderWidth = 2.0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Welcome Headline (ONE line with two colors)
    private lazy var welcomeHeadlineLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Create attributed string: "Welcome to Privitty"
        let fullText = "Welcome to Privitty"
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // Paragraph style with line height 52pt
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 52
        paragraphStyle.maximumLineHeight = 52
        
        // "Welcome to " in #020202
        let welcomeRange = (fullText as NSString).range(of: "Welcome to ")
        attributedString.addAttributes([
            .font: UIFont.systemFont(ofSize: 45, weight: .medium),
            .foregroundColor: UIColor(hexString: "020202"),
            .paragraphStyle: paragraphStyle
        ], range: welcomeRange)
        
        // "Privitty" in #6750A4
        let privittyRange = (fullText as NSString).range(of: "Privitty")
        attributedString.addAttributes([
            .font: UIFont.systemFont(ofSize: 45, weight: .medium),
            .foregroundColor: UIColor(hexString: "6750A4"),
            .paragraphStyle: paragraphStyle
        ], range: privittyRange)
        
        label.attributedText = attributedString
        return label
    }()
    
    // MARK: - Description Text
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let text = "Privitty is a secure, decentralized messaging app with advanced privacy features like message revocation and time-limited access."
        
        // Paragraph style with line height 24pt
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 0
        paragraphStyle.minimumLineHeight = 24
        paragraphStyle.maximumLineHeight = 24
        
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(hexString: "4F4F4F"), // Figma: #4F4F4F
                .paragraphStyle: paragraphStyle
            ]
        )
        return label
    }()
    
    // MARK: - Buttons
    private lazy var signUpButton: UIButton = {
        let button = UIButton(type: .system)
        let title = String.localized("onboarding_create_instant_account")
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor(hexString: "F6F6F6"), for: .normal) // White
        button.backgroundColor = UIColor(hexString: "6750A4") // Figma: #6750A4
        button.layer.cornerRadius = 30 // Height 60 / 2 = fully rounded
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(signUpButtonPressed(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var logInButton: UIButton = {
        let button = UIButton(type: .system)
        let title = String.localized("onboarding_alternative_logins")
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor(hexString: "020202"), for: .normal) // Black
        button.backgroundColor = UIColor(hexString: "F8F5FF") // Match bottom sheet
        button.layer.cornerRadius = 30
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor(hexString: "6750A4").cgColor // Purple border
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(logInButtonPressed(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init() {
        super.init(frame: .zero)
        setupSubviews()
        backgroundColor = DcColors.privittyThemeColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - setup
    private func setupSubviews() {
        // Add top section with logo
        addSubview(topSection)
        topSection.addSubview(logoView)
        
        // Add bottom sheet
        addSubview(bottomSheet)
        
        // Add ellipse ring (will be positioned behind headline)
        bottomSheet.addSubview(ellipseRingView)
        
        // Add content to bottom sheet
        bottomSheet.addSubview(welcomeHeadlineLabel)
        bottomSheet.addSubview(descriptionLabel)
        bottomSheet.addSubview(signUpButton)
        bottomSheet.addSubview(logInButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        // Top Section
        NSLayoutConstraint.activate([
            topSection.topAnchor.constraint(equalTo: topAnchor),
            topSection.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSection.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSection.bottomAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 20),
            
            // Logo centered in top section
            logoView.centerXAnchor.constraint(equalTo: topSection.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: topSection.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 170),
            logoView.heightAnchor.constraint(equalToConstant: 170)
        ])
        
        // Bottom Sheet
        bottomSheetHeightConstraint = bottomSheet.heightAnchor.constraint(equalToConstant: 539)
        NSLayoutConstraint.activate([
            bottomSheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor),
            bottomSheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomSheetHeightConstraint!
        ])
        
        // Ellipse Ring (behind headline, positioned absolutely)
        NSLayoutConstraint.activate([
            ellipseRingView.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            ellipseRingView.topAnchor.constraint(equalTo: welcomeHeadlineLabel.topAnchor, constant: -8),
            ellipseRingView.widthAnchor.constraint(equalToConstant: 274),
            ellipseRingView.heightAnchor.constraint(equalToConstant: 67)
        ])
        
        // Welcome Headline
        NSLayoutConstraint.activate([
            welcomeHeadlineLabel.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 42),
            welcomeHeadlineLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            bottomSheet.trailingAnchor.constraint(equalTo: welcomeHeadlineLabel.trailingAnchor, constant: 16)
        ])
        
        // Description
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: welcomeHeadlineLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 23),
            bottomSheet.trailingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor, constant: 23)
        ])
        
        // Buttons
        NSLayoutConstraint.activate([
            signUpButton.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            bottomSheet.trailingAnchor.constraint(equalTo: signUpButton.trailingAnchor, constant: 16),
            bottomSheet.bottomAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 76),
            signUpButton.heightAnchor.constraint(equalToConstant: 60),
            
            logInButton.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 12),
            logInButton.leadingAnchor.constraint(equalTo: signUpButton.leadingAnchor),
            logInButton.trailingAnchor.constraint(equalTo: signUpButton.trailingAnchor),
            logInButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Make ellipse ring rounded with rotation (Figma: 355.5° = -4.5°)
        ellipseRingView.layer.cornerRadius = ellipseRingView.bounds.height / 2
        ellipseRingView.transform = CGAffineTransform(rotationAngle: -4.5 * .pi / 180.0)
    }

    // MARK: - actions
    @objc private func signUpButtonPressed(_ sender: UIButton) {
        onSignUp?()
    }

    @objc private func logInButtonPressed(_ sender: UIButton) {
        onLogIn?()
    }
}

extension WelcomeViewController: MediaPickerDelegate {
    func onDocumentSelected(url: NSURL) {
        // ensure we can access folders outside of the app's sandbox
        let isSecurityScopedResource = url.startAccessingSecurityScopedResource()
        if isSecurityScopedResource {
            securityScopedResource = url
        }

        if let selectedBackupFilePath = url.relativePath {
            addProgressHudBackupListener(importByFile: true)
            importBackup(at: selectedBackupFilePath)
        } else {
            stopAccessingSecurityScopedResource()
        }
    }
}
