import QuickLook
import UIKit
import DcCore

class PreviewController: QLPreviewController {
    enum PreviewType {
        case single(URL)
        case multi([Int], Int) // msgIds, index
    }

    let previewType: PreviewType

    var customTitle: String?
    var dcContext: DcContext
    private var buttonRemovalTimer: Timer?

    init(dcContext: DcContext, type: PreviewType) {
        self.previewType = type
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        dataSource = self
        delegate = self
        switch type {
        case .multi(_, let currentIndex):
            currentPreviewItemIndex = currentIndex
        case .single:
            currentPreviewItemIndex = 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // iOS automatically shows back button - we don't need to add one
        // Just remove the share button
        navigationItem.rightBarButtonItem = nil
        
        // Hide the toolbar to prevent "Save to Files" and other actions
        navigationController?.setToolbarHidden(true, animated: false)
        navigationController?.toolbar.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Remove share button (iOS default back button will remain)
        navigationItem.rightBarButtonItem = nil
        
        // Hide toolbar again
        navigationController?.setToolbarHidden(true, animated: false)
        setToolbarItems(nil, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Also remove after appearing (QLPreviewController might set it late)
        navigationItem.rightBarButtonItem = nil
        
        // Force remove share button by iterating through toolbar items
        hideShareButton()
        
        // Start a timer to continuously remove the share button
        // QLPreviewController keeps trying to add it back
        buttonRemovalTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.hideShareButton()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the timer when view disappears
        buttonRemovalTimer?.invalidate()
        buttonRemovalTimer = nil
        
        // Remove the blocking overlay
        let overlayTag = 99999
        navigationController?.navigationBar.viewWithTag(overlayTag)?.removeFromSuperview()
        
        // Restore toolbar for other views (don't affect other screens)
        navigationController?.setToolbarHidden(false, animated: false)
    }
    
    deinit {
        buttonRemovalTimer?.invalidate()
    }
    
    /// Override to prevent toolbar from ever being shown
    override var hidesBottomBarWhenPushed: Bool {
        get { return true }
        set { super.hidesBottomBarWhenPushed = true }
    }
    
    /// Intercept any attempt to present UIActivityViewController (Share/Print/Save dialogs)
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        // Block UIActivityViewController which shows "Save to Files", "Print", etc.
        if viewControllerToPresent is UIActivityViewController {
            // Silently block the presentation
            completion?()
            return
        }
        
        // Block any alert controller that might be related to sharing/saving
        if let alertController = viewControllerToPresent as? UIAlertController {
            let title = alertController.title ?? ""
            let message = alertController.message ?? ""
            
            // Check if it's related to sharing/saving/printing
            if title.contains("Share") || title.contains("Save") || title.contains("Print") ||
               message.contains("Share") || message.contains("Save") || message.contains("Print") {
                // Block it
                completion?()
                return
            }
        }
        
        // Allow other presentations (if any)
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    /// Aggressively hide all sharing and action buttons
    /// QLPreviewController keeps trying to add them back, so we continuously remove them
    private func hideShareButton() {
        // Remove right navigation bar buttons (share/action buttons)
        navigationItem.rightBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        
        // Remove from navigation controller's top item
        if let topItem = navigationController?.navigationBar.topItem {
            topItem.rightBarButtonItem = nil
            topItem.rightBarButtonItems = nil
        }
        
        // Remove from all navigation items
        navigationController?.navigationBar.items?.forEach { item in
            item.rightBarButtonItem = nil
            item.rightBarButtonItems = nil
        }
        
        // Remove ALL toolbar items (including "Save to Files", share, etc.)
        setToolbarItems(nil, animated: false)
        setToolbarItems([], animated: false)
        toolbarItems = nil
        
        // Hide the entire toolbar
        navigationController?.setToolbarHidden(true, animated: false)
        navigationController?.toolbar.isHidden = true
        
        // Also remove toolbar items from navigation controller
        navigationController?.viewControllers.forEach { vc in
            vc.toolbarItems = nil
            vc.setToolbarItems(nil, animated: false)
        }
        
        // AGGRESSIVE: Search through entire view hierarchy to hide share/action buttons
        // QLPreviewController has internal views that aren't accessible via standard APIs
        hideShareButtonsInViewHierarchy(view: self.view)
        hideShareButtonsInViewHierarchy(view: navigationController?.navigationBar)
        
        // Disable interaction on navigation bar's right side (where share button usually is)
        disableNavigationBarRightSide()
    }
    
    /// Disable user interaction on the right portion of navigation bar to block share button taps
    private func disableNavigationBarRightSide() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        
        // Create an invisible overlay view on the RIGHT side of navigation bar
        // This blocks taps on share/export buttons
        let overlayTag = 99999
        
        // Check if overlay already exists and update its frame
        if let existingOverlay = navigationBar.viewWithTag(overlayTag) {
            let overlayWidth: CGFloat = 120
            let overlayHeight = navigationBar.bounds.height
            let overlayX = navigationBar.bounds.width - overlayWidth
            existingOverlay.frame = CGRect(x: overlayX, y: 0, width: overlayWidth, height: overlayHeight)
            return
        }
        
        // Calculate RIGHT side area (120 points from the right edge)
        let overlayWidth: CGFloat = 120
        let overlayHeight = navigationBar.bounds.height
        let overlayX = navigationBar.bounds.width - overlayWidth
        
        let blockingView = UIView(frame: CGRect(x: overlayX, y: 0, width: overlayWidth, height: overlayHeight))
        blockingView.tag = overlayTag
        blockingView.backgroundColor = .clear // Invisible but blocks taps
        blockingView.isUserInteractionEnabled = true // Intercept taps
        blockingView.autoresizingMask = [.flexibleLeftMargin, .flexibleHeight] // Auto-resize with navigation bar
        
        // Add tap gesture that does nothing (blocks underlying share buttons)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(blockTap))
        blockingView.addGestureRecognizer(tapGesture)
        
        // Bring to front to ensure it's above all buttons
        navigationBar.addSubview(blockingView)
        navigationBar.bringSubviewToFront(blockingView)
    }
    
    @objc private func blockTap() {
        // Do nothing - this intentionally blocks taps on share/export buttons
    }
    
    /// Recursively search and hide all share/action buttons in view hierarchy
    private func hideShareButtonsInViewHierarchy(view: UIView?) {
        guard let view = view else { return }
        
        // Hide share/action buttons
        if let button = view as? UIButton {
            // Check if button is in navigation bar hierarchy
            var parentView = button.superview
            var isInNavigationBar = false
            
            while parentView != nil {
                if parentView is UINavigationBar {
                    isInNavigationBar = true
                    break
                }
                parentView = parentView?.superview
            }
            
            // Check if this is on the RIGHT side (where share button is)
            // Right side buttons are typically at x > screen width - 150
            let screenWidth = UIScreen.main.bounds.width
            let isOnRightSide = button.frame.origin.x > (screenWidth - 150)
            
            // Also check for specific share/action indicators
            let isShareButton = button.accessibilityIdentifier?.contains("share") ?? false ||
                               button.accessibilityIdentifier?.contains("action") ?? false ||
                               button.accessibilityLabel?.contains("Share") ?? false ||
                               button.accessibilityLabel?.contains("Export") ?? false ||
                               button.accessibilityLabel?.contains("Action") ?? false ||
                               button.accessibilityLabel?.contains("More") ?? false
            
            // Don't hide if it's the back button or done button
            let isBackOrDone = button.accessibilityLabel?.contains("Back") ?? false ||
                              button.accessibilityLabel?.contains("Done") ?? false
            
            // Hide if (in navigation bar AND on right side) OR if explicitly identified as share button
            // BUT don't hide back/done buttons
            if ((isInNavigationBar && isOnRightSide) || isShareButton) && !isBackOrDone {
                button.isHidden = true
                button.isEnabled = false
                button.isUserInteractionEnabled = false
                button.alpha = 0
                button.removeFromSuperview()
            }
        }
        
        // Also check for UIBarButtonItem's custom views on RIGHT side
        if view.superview is UINavigationBar {
            let screenWidth = UIScreen.main.bounds.width
            let isOnRightSide = view.frame.origin.x > (screenWidth - 150)
            if isOnRightSide {
                view.isHidden = true
                view.alpha = 0
                view.isUserInteractionEnabled = false
            }
        }
        
        // Recursively check all subviews
        for subview in view.subviews {
            hideShareButtonsInViewHierarchy(view: subview)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PreviewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        switch previewType {
        case .single:
            return 1
        case .multi(let msgIds, _):
            return msgIds.count
        }
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        switch previewType {
        case .single(let url):
            return PreviewItem(url: url, title: self.customTitle)
        case .multi(let msgIds, _):
            let msg = dcContext.getMessage(id: msgIds[index])
            return PreviewItem(url: msg.fileURL, title: self.customTitle)
        }
    }
}

// MARK: - QLPreviewControllerDelegate
extension PreviewController: QLPreviewControllerDelegate {
    
    /// Disable editing mode (annotations, adding pages, etc.) for all file types
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        // Disabled: No annotations, no adding pages to PDFs, no image markup
        return .disabled
    }
    
    /// Prevent sharing by intercepting the share/action button
    func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
        return nil
    }
    
    /// Disable all sharing capabilities by returning false
    func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: QLPreviewItem) -> Bool {
        // Prevent opening URLs or sharing
        return false
    }
}

// needed to prevent showing url-path in PreviewController's title (only relevant if url.count == 1)
class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?

    init(url: URL?, title: String?) {
        self.previewItemURL = url
        self.previewItemTitle = title ?? ""
    }
}
