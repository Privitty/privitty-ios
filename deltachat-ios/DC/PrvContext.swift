import Foundation
import Privitty
import DcCore

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
    public func createOrSwitchUser(username: String, useremail: String = "", userid: String = "") -> Bool {
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
        logger.debug("User email: \(useremail.isEmpty ? "(none)" : useremail)")
        logger.debug("User ID: \(userid.isEmpty ? "(none)" : userid)")

        if core.switchProfile(withUsername: username, useremail: useremail, userid: userid) {
            logger.info("Successfully switched to user: \(username)")
            return true
        }

        logger.error("Failed to switch to user: \(username)")
        return false
    }

    /// Ensure user is set up (create if doesn't exist, select if exists)
    /// Alias for createOrSwitchUser for backward compatibility
    public func ensureUserSetup(username: String, useremail: String = "", userid: String = "") -> Bool {
        return createOrSwitchUser(username: username, useremail: useremail, userid: userid)
    }

    // MARK: - File access status models

    public enum FileAccessStatus: String {
        case active = "active"
        case requested = "requested"
        case expired = "expired"
        case revoked = "revoked"
        case deleted = "deleted"
        case waitingOwnerAction = "waiting_owner_action"
        case denied = "denied"
        case notFound = "not_found"

        public var isAccessible: Bool {
            self == .active
        }

        public var isPending: Bool {
            switch self {
            case .requested, .waitingOwnerAction:
                return true
            default:
                return false
            }
        }

        public var userFacingDescription: String {
            switch self {
            case .active:
                return fallbackLocalized("privitty_file_access_active", default: "Access active")
            case .requested:
                return fallbackLocalized("privitty_file_access_requested", default: "Access requested")
            case .expired:
                return fallbackLocalized("privitty_file_access_expired", default: "Access expired")
            case .revoked:
                return fallbackLocalized("privitty_file_access_revoked", default: "Access revoked")
            case .deleted:
                return fallbackLocalized("privitty_file_access_deleted", default: "File deleted")
            case .waitingOwnerAction:
                return fallbackLocalized("privitty_file_access_waiting_owner", default: "Waiting for owner")
            case .denied:
                return fallbackLocalized("privitty_file_access_denied", default: "Access denied")
            case .notFound:
                return fallbackLocalized("privitty_file_access_not_found", default: "File not found")
            }
        }

        private func fallbackLocalized(_ key: String, default defaultValue: String) -> String {
            let localized = String.localized(key)
            return localized == key ? defaultValue : localized
        }
    }

    public struct FileAccessStatusData {
        public let status: FileAccessStatus
        public let statusCode: Int?
        public let chatId: String?
        public let fileName: String?
        public let expiryTime: TimeInterval?
        public let isDownloadAllowed: Bool?
        public let isForwardAllowed: Bool?
        public let accessDuration: TimeInterval?

        init(dictionary: [String: Any]) {
            let statusString = (dictionary["status"] as? String ?? "").lowercased()
            self.status = FileAccessStatus(rawValue: statusString) ?? .notFound

            if let code = dictionary["status_code"] as? Int {
                statusCode = code
            } else if let codeNumber = dictionary["status_code"] as? NSNumber {
                statusCode = codeNumber.intValue
            } else {
                statusCode = nil
            }

            chatId = dictionary["chat_id"] as? String
            fileName = dictionary["file_name"] as? String

            if let expiry = dictionary["expiry_time"] as? NSNumber {
                expiryTime = expiry.doubleValue / 1000.0
            } else if let expiry = dictionary["expiry_time"] as? Double {
                expiryTime = expiry / 1000.0
            } else if let expiry = dictionary["expiry_time"] as? Int {
                expiryTime = Double(expiry) / 1000.0
            } else {
                expiryTime = nil
            }

            if let download = dictionary["is_download"] as? Bool {
                isDownloadAllowed = download
            } else if let download = dictionary["is_download"] as? NSNumber {
                isDownloadAllowed = download.boolValue
            } else {
                isDownloadAllowed = nil
            }

            if let forward = dictionary["is_forward"] as? Bool {
                isForwardAllowed = forward
            } else if let forward = dictionary["is_forward"] as? NSNumber {
                isForwardAllowed = forward.boolValue
            } else {
                isForwardAllowed = nil
            }

            if let duration = dictionary["access_duration"] as? NSNumber {
                accessDuration = duration.doubleValue
            } else if let duration = dictionary["access_duration"] as? Double {
                accessDuration = duration
            } else if let duration = dictionary["access_duration"] as? Int {
                accessDuration = Double(duration)
            } else {
                accessDuration = nil
            }
        }

        public var hasExpiry: Bool {
            if let expiryTime {
                return expiryTime > 0
            }
            return false
        }

        public var expiryDate: Date? {
            guard hasExpiry, let expiryTime else { return nil }
            return Date(timeIntervalSince1970: expiryTime)
        }
    }

    /// Switch Privitty profile to match the given Delta Chat context
    /// Extracts display name and email from DcContext and passes them to switchProfile
    /// Returns true if a profile was selected (or created) successfully.
    public func switchProfile(for dcContext: DcContext) -> Bool {
        // Get display name (username)
        let userName = dcContext.displayname ?? dcContext.getConfig("configured_addr") ?? "user-\(dcContext.id)"
        
        // Get configured email address
        let selfEmail = dcContext.getConfig("configured_addr") ?? ""
        
        logger.info("Creating/switching Privitty user: \(userName)")
        logger.debug("Email: \(selfEmail)")
        
        // Call switchProfile with all three parameters (userid is empty string)
        if ensureUserSetup(username: userName, useremail: selfEmail, userid: "") {
            logger.info("Privitty profile selected: \(userName)")
            return true
        } else {
            logger.error("Failed to select Privitty profile for: \(userName)")
            return false
        }
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
    public func processIncomingMessage(chatId: Int, pdu: String, direction: String = "incoming") -> (success: Bool, data: [String: Any]?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot process message: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot process message: No user selected")
            return (false, nil, "No user selected")
        }

        logger.info("Processing incoming message for user: \(currentUser)")
        logger.debug("Chat ID: \(chatId), Direction: \(direction), PDU length: \(pdu.count) characters")

        let eventDataJson = """
        {
            "chat_id": "\(chatId)",
            "direction": "\(direction)",
            "pdu": "\(pdu)"
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

    // MARK: - File Operations
    /// Request file encryption
    public func requestFileEncryption(filePath: String, 
                                     chatId: String, 
                                     allowDownload: Bool, 
                                     allowForward: Bool, 
                                     accessTime: Int) -> (success: Bool, data: [String: Any]?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot encrypt file: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot encrypt file: No user selected")
            return (false, nil, "No user selected")
        }

        logger.info("Requesting file encryption for user: \(currentUser)")
        logger.debug("File: \(filePath)")
        logger.debug("Chat ID: \(chatId)")
        logger.debug("Access Time: \(accessTime) seconds")
        logger.debug("Allow Download: \(allowDownload)")
        logger.debug("Allow Forward: \(allowForward)")

        let result = core.processFileEncryptRequest(
            withFilePath: filePath,
            chatId: chatId,
            allowDownload: allowDownload,
            allowForward: allowForward,
            accessTime: accessTime
        )

        // Parse result (NSDictionary format)
        guard let resultDict = result else {
            logger.error("Failed to get file encryption response")
            return (false, nil, "No response returned")
        }

        if let success = resultDict["success"] as? Int, success == 1 {
            logger.info("File encrypted successfully")
            let data = resultDict["data"] as? [String: Any]
            return (true, data, nil)
        } else if let error = resultDict["error"] as? String {
            logger.error("Failed to encrypt file: \(error)")
            return (false, nil, error)
        }

        logger.error("Unknown error encrypting file")
        return (false, nil, "Unknown error")
    }

    /// Request file decryption
    public func requestFileDecryption(prvFile: String,
                                      chatId: String) -> (success: Bool, data: [String: Any]?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot decrypt file: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot decrypt file: No user selected")
            return (false, nil, "No user selected")
        }

        logger.info("Requesting file decryption for user: \(currentUser)")
        logger.debug("PRV file: \(prvFile)")
        logger.debug("Chat ID: \(chatId)")

        let result = core.processFileDecryptRequest(withPrvFile: prvFile, chatId: chatId)

        guard let resultDict = result else {
            logger.error("Failed to get file decryption response")
            return (false, nil, "No response returned")
        }

        if let success = resultDict["success"] as? Int, success == 1 {
            logger.info("File decrypted successfully")
            let data = resultDict["data"] as? [String: Any]
            return (true, data, nil)
        } else if let successBool = resultDict["success"] as? Bool, successBool == true {
            logger.info("File decrypted successfully")
            let data = resultDict["data"] as? [String: Any]
            return (true, data, nil)
        } else if let error = resultDict["error"] as? String {
            logger.error("Failed to decrypt file: \(error)")
            return (false, nil, error)
        }

        logger.error("Unknown error decrypting file")
        return (false, nil, "Unknown error")
    }

    /// Retrieve file access status for a Privitty encrypted file
    public func getFileAccessStatus(chatId: String,
                                    filePath: String) -> (success: Bool, data: FileAccessStatusData?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot check file access status: Core not initialized")
            return (false, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot check file access status: No user selected")
            return (false, nil, "No user selected")
        }

        logger.debug("Requesting file access status for user: \(currentUser)")
        logger.debug("File path: \(filePath)")
        logger.debug("Chat ID: \(chatId)")

        guard let result = core.getFileAccessStatus(withChatId: chatId, filePath: filePath) else {
            logger.error("Failed to get file access status response")
            return (false, nil, "No response returned")
        }

        let successValue: Bool
        if let value = result["success"] as? Bool {
            successValue = value
        } else if let value = result["success"] as? NSNumber {
            successValue = value.boolValue
        } else if let value = result["success"] as? Int {
            successValue = value != 0
        } else {
            successValue = false
        }

        if successValue {
            if let dataDict = result["data"] as? [String: Any] {
                let data = FileAccessStatusData(dictionary: dataDict)
                return (true, data, nil)
            }
            return (true, nil, nil)
        }

        let errorMessage = (result["error"] as? String) ?? (result["message"] as? String) ?? "Unknown error"
        logger.error("File access status check failed: \(errorMessage)")
        return (false, nil, errorMessage)
    }

    /// Request access to a Privitty encrypted file (sends request to owner)
    public func processInitAccessGrantRequest(chatId: String,
                                              filePath: String) -> (success: Bool, data: [String: Any]?, message: String?, error: String?) {
        guard let core = getCore() else {
            logger.error("Cannot request file access: Core not initialized")
            return (false, nil, nil, "Core not initialized")
        }

        guard let currentUser = getCurrentUser() else {
            logger.error("Cannot request file access: No user selected")
            return (false, nil, nil, "No user selected")
        }

        logger.info("Requesting file access grant for user: \(currentUser)")
        logger.debug("File path: \(filePath)")
        logger.debug("Chat ID: \(chatId)")

        guard let result = core.processInitAccessGrantRequest(withChatId: chatId, filePath: filePath) else {
            logger.error("Failed to get access grant request response")
            return (false, nil, nil, "No response returned")
        }

        let message = result["message"] as? String

        let successValue: Bool
        if let value = result["success"] as? Bool {
            successValue = value
        } else if let value = result["success"] as? NSNumber {
            successValue = value.boolValue
        } else if let value = result["success"] as? Int {
            successValue = value != 0
        } else {
            successValue = false
        }

        if successValue {
            let data = result["data"] as? [String: Any]
            return (true, data, message, nil)
        }

        let errorMessage = (result["error"] as? String) ?? message ?? "Unknown error"
        logger.error("File access request failed: \(errorMessage)")
        return (false, nil, message, errorMessage)
    }
}
