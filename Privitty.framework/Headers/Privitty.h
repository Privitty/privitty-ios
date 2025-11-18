//
//  Privitty.h
//  Privitty Framework
//
//  Copyright (c) 2024 Alanring Technologies Pvt. Ltd.
//

#import <Foundation/Foundation.h>

//! Project version number for Privitty.
FOUNDATION_EXPORT double PrivittyVersionNumber;

//! Project version string for Privitty.
FOUNDATION_EXPORT const unsigned char PrivittyVersionString[];

/**
 * Complete Objective-C API for Privitty Core
 * All methods match the JNI interface for Android
 * 
 * NULLABILITY NOTES:
 * - Initializers can return nil on failure
 * - Methods returning NSDictionary/NSString can return nil on error
 * - This matches Android JNI behavior where jstring can be NULL
 */
@interface PrivittyCore : NSObject

// =============================================================================
// INITIALIZATION & LIFECYCLE
// =============================================================================

- (nullable instancetype)initWithBaseDirectory:(NSString*)baseDirectory;
- (nullable instancetype)init;
- (BOOL)initialize;
- (BOOL)isInitialized;
- (void)shutdown;

// =============================================================================
// SYSTEM STATUS
// =============================================================================

- (nullable NSDictionary*)getSystemStatus;
- (nullable NSDictionary*)getHealthStatus;
- (nullable NSDictionary*)getVersion;

// =============================================================================
// PEER MANAGEMENT
// =============================================================================

- (nullable NSDictionary*)createPeerAddRequestWithChatId:(NSString*)chatId
                                                 peerName:(NSString*)peerName
                                                peerEmail:(nullable NSString*)peerEmail
                                                   peerId:(nullable NSString*)peerId;

- (nullable NSDictionary*)processPeerAddResponseWithChatId:(NSString*)chatId
                                                     peerId:(NSString*)peerId
                                                   accepted:(BOOL)accepted
                                            rejectionReason:(nullable NSString*)rejectionReason;

// =============================================================================
// FILE OPERATIONS
// =============================================================================

- (nullable NSDictionary*)processFileEncryptRequestWithFilePath:(NSString*)filePath
                                                          chatId:(NSString*)chatId
                                                   allowDownload:(BOOL)allowDownload
                                                    allowForward:(BOOL)allowForward
                                                      accessTime:(NSInteger)accessTime;

- (nullable NSDictionary*)processFileDecryptRequestWithPrvFile:(NSString*)prvFile
                                                         chatId:(NSString*)chatId;

- (nullable NSDictionary*)getFileAccessStatusWithChatId:(NSString*)chatId
                                                filePath:(NSString*)filePath;

// =============================================================================
// ACCESS CONTROL
// =============================================================================

- (nullable NSDictionary*)processInitAccessGrantRequestWithChatId:(NSString*)chatId
                                                          filePath:(NSString*)filePath;

- (nullable NSDictionary*)processInitAccessRevokeRequestWithChatId:(NSString*)chatId
                                                           filePath:(NSString*)filePath
                                                             reason:(NSString*)reason;

- (nullable NSDictionary*)processInitAccessDeniedWithChatId:(NSString*)chatId
                                                    filePath:(NSString*)filePath;

- (nullable NSDictionary*)processInitAccessGrantAcceptWithChatId:(NSString*)chatId
                                                         filePath:(NSString*)filePath
                                                    allowDownload:(BOOL)allowDownload
                                                     allowForward:(BOOL)allowForward
                                                       accessTime:(NSInteger)accessTime;

// =============================================================================
// USER MANAGEMENT
// =============================================================================

- (BOOL)createUserProfileWithUsername:(NSString*)username
                           profileData:(nullable NSDictionary*)profileData;

- (BOOL)selectUserProfileWithUsername:(NSString*)username useremail:(NSString*)useremail userid:(NSString*)userid;

- (nullable NSString*)getCurrentUser;

- (nullable NSArray<NSString*>*)getAvailableUsers;

- (BOOL)switchProfileWithUsername:(NSString*)username useremail:(NSString*)useremail userid:(NSString*)userid;

// =============================================================================
// CHAT OPERATIONS
// =============================================================================

- (nullable NSDictionary*)deleteChatRoomWithChatId:(NSString*)chatId;

- (BOOL)isChatProtected:(NSString*)chatId;

// =============================================================================
// BACKUP & RESTORE
// =============================================================================

- (nullable NSDictionary*)exportBackup;

- (nullable NSDictionary*)importBackupWithTarPath:(NSString*)tarPath;

// =============================================================================
// CONFIGURATION
// =============================================================================

- (BOOL)setConfigWithKey:(NSString*)key value:(NSDictionary*)value;

- (nullable NSDictionary*)getConfigWithKey:(NSString*)key;

// =============================================================================
// UNIFIED MESSAGE PROCESSING (PRIMARY METHOD)
// =============================================================================

/**
 * Process any incoming Privitty message (unified processor)
 * This is the primary method for handling all incoming Privitty PDUs
 * @param eventDataJson JSON string containing the event data
 * @return Dictionary with processing result (nullable on error)
 */
- (nullable NSDictionary*)processMessageWithData:(NSString*)eventDataJson;

/**
 * Check if a base64 string is a valid Privitty message
 * @param base64Data Base64 encoded string to validate
 * @return YES if it's a Privitty message, NO otherwise
 */
- (BOOL)isPrivittyMessageWithString:(NSString*)base64Data;

@end
