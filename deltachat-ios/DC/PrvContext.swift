import Foundation
import Privitty

public class PrvContext {
    
    // MARK: - Singleton
    public static let shared = PrvContext()
    
    // MARK: - Properties
    private var core: PrivittyCore?
    private let documentsPath: String
    
    // MARK: - Initialization
    private init() {
        documentsPath = FileHelper.applicationSupportPath()
    }
    
    // MARK: - Core Management
    /// Initialize Privitty Core (safe to call multiple times)
    public func initialize() -> Bool {
        // Check if already initialized
        if let existingCore = core {
            logger.debug("Core object exists, checking if initialized...")

            // Safely check initialization
            let isInit = existingCore.isInitialized()
            logger.debug("Core isInitialized: \(isInit)")

            if isInit {
                logger.info("Privitty Core already initialized")
                return true
            }
        }
        
        logger.info("Creating new Privitty Core instance...")
        logger.debug("Base directory: \(documentsPath)")
        
        guard let newCore = PrivittyCore(baseDirectory: documentsPath) else {
            logger.error("Failed to create PrivittyCore object")
            return false
        }

        // Verify it initialized properly
        let isInit = newCore.isInitialized()
        logger.debug("New core isInitialized: \(isInit)")
        
        if isInit {
            // Store the core only if it's initialized
            core = newCore

            // Get and print version information
            if let versionResponse = newCore.getVersion(),
               let success = versionResponse["success"] as? Int, success == 1,
               let data = versionResponse["data"] as? [String: Any] {

                logger.debug("Raw version response: \(versionResponse)")

                if let coreVersion = data["core_version"] as? String {
                    logger.info("Privitty Core Version: \(coreVersion)")
                }

                if let buildDate = data["build_date"] as? String,
                   let buildTime = data["build_time"] as? String {
                    logger.info("Build: \(buildDate) \(buildTime)")
                }
            } else {
                logger.warning("Failed to get or parse version response")
            }

            logger.info("Privitty Core initialized successfully")
            return true
        }

        logger.error("Core object created but not initialized")
        return false
    }

    /// Get core instance (returns nil if not initialized)
    public func getCore() -> PrivittyCore? {
        guard let existingCore = core else {
            logger.error("Core not available - call initialize() first")
            return nil
        }

        // Double-check it's still initialized
        guard existingCore.isInitialized() else {
            logger.error("Core exists but is not initialized")
            return nil
        }

        return existingCore
    }

    /// Check if core is initialized
    public func isInitialized() -> Bool {
        guard let existingCore = core else {
            logger.debug("isInitialized: core is nil")
            return false
        }

        let isInit = existingCore.isInitialized()
        logger.debug("isInitialized: \(isInit)")
        return isInit
    }

    /// Shutdown core
    public func shutdown() {
        logger.info("Shutting down Privitty Core...")
        core = nil
    }

    // MARK: - User Management
    /// Get current selected user
    public func getCurrentUser() -> String? {
        guard let core = getCore() else { return nil }
        guard let user = core.getCurrentUser() else { return nil }
        return user.isEmpty ? nil : user
    }

    /// Get all available users
    public func getAvailableUsers() -> [String] {
        guard let core = getCore() else { return [] }
        guard let users = core.getAvailableUsers() as? [String] else { return [] }
        return users
    }

    /// Create or switch to a user profile using switchProfile
    /// This method will automatically create the user if it doesn't exist
    public func createOrSwitchUser(username: String) -> Bool {
        guard let core = getCore() else {
            logger.error("Cannot create/switch user: Core not initialized")
            return false
        }

        // Check if user is already selected
        if let currentUser = core.getCurrentUser(), currentUser == username {
            logger.debug("User '\(username)' already selected")
            return true
        }

        logger.info("Switching to user profile: \(username)")

        if core.switchProfile(withUsername: username) {
            logger.info("Successfully switched to user: \(username)")
            return true
        }

        logger.error("Failed to switch to user: \(username)")
        return false
    }

    /// Ensure user is set up (create if doesn't exist, select if exists)
    /// Alias for createOrSwitchUser for backward compatibility
    public func ensureUserSetup(username: String) -> Bool {
        return createOrSwitchUser(username: username)
    }

    // MARK: - Chat/Peer Operations
    /// Create a peer add request
    public func createPeerAddRequest(chatId: String,
                                     peerName: String,
                                     peerEmail: String? = nil,
                                     peerId: String? = nil) -> (success: Bool, pdu: String?, error: String?) {

        guard let core = getCore() else {
            logger.error("Cannot create peer add request: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        // Verify user is selected
        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot create peer add request: No user selected")
            return (false, nil, "No user selected. Please create and select a user first.")
        }

        logger.info("Creating peer add request...")
        logger.debug("Current user: \(currentUser)")
        logger.debug("Chat ID: \(chatId)")
        logger.debug("Peer: \(peerName)")

        let result = core.createPeerAddRequest(
            withChatId: chatId,
            peerName: peerName,
            peerEmail: peerEmail,
            peerId: peerId
        )

        // Parse result (NSDictionary format)
        guard let resultDict = result else {
            logger.error("Failed to get peer add request response")
            return (false, nil, "No response returned")
        }

        if let success = resultDict["success"] as? Int, success == 1,
           let data = resultDict["data"] as? [String: Any],
           let pdu = data["pdu"] as? String {
            logger.info("Peer add request created successfully")
            logger.debug("PDU length: \(pdu.count) characters")
            return (true, pdu, nil)
        } else if let error = resultDict["error"] as? String {
            logger.error("Failed to create peer add request: \(error)")
            return (false, nil, error)
        }

        logger.error("Unknown error creating peer add request")
        return (false, nil, "Unknown error")
    }

    /// Process incoming message
    public func processIncomingMessage(pdu: String) -> (success: Bool, data: [String: Any]?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot process message: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot process message: No user selected")
            return (false, nil, "No user selected")
        }

        logger.info("Processing incoming message for user: \(currentUser)")
        logger.debug("PDU length: \(pdu.count) characters")

        let eventDataJson = """
        {
            "pdu": "\(pdu)",
            "context": {
                "platform": "ios",
                "timestamp": "\(Int(Date().timeIntervalSince1970))",
                "source": "network"
            }
        }
        """

        let result = core.processMessage(withData: eventDataJson)

        // Parse result (NSDictionary format)
        guard let resultDict = result else {
            logger.error("Failed to get message processing response")
            return (false, nil, "No response returned")
        }

        if let success = resultDict["success"] as? Int, success == 1 {
            logger.info("Message processed successfully")
            let data = resultDict["data"] as? [String: Any]
            return (true, data, nil)
        } else if let error = resultDict["error"] as? String {
            logger.error("Failed to process message: \(error)")
            return (false, nil, error)
        }

        logger.error("Unknown error processing message")
        return (false, nil, "Unknown error")
    }

    /// Check if chat is protected
    public func isChatProtected(chatId: String) -> Bool {
        guard let core = getCore() else { 
            logger.error("Cannot check chat protection: Core not initialized")
            return false 
        }

        let isProtected = core.isChatProtected(chatId)
        logger.debug("Chat \(chatId) protection status: \(isProtected)")
        return isProtected
    }

    /// Check if a message is a Privitty message
    public func isPrivittyMessage(_ messageText: String?) -> Bool {
        guard let messageText = messageText, !messageText.isEmpty else {
            return false
        }

        guard let core = getCore() else {
            logger.error("Cannot check Privitty message: Core not initialized")
            return false
        }

        return core.isPrivittyMessage(with: messageText)
    }
}
