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

// Objective-C API for Privitty Core
@interface PrivittyCore : NSObject

// Initialization
- (instancetype)initWithBaseDirectory:(NSString*)baseDirectory;
- (instancetype)init;

// Core lifecycle
- (BOOL)initialize;
- (BOOL)isInitialized;

// System status
- (NSDictionary*)getSystemStatus;
- (NSDictionary*)getHealthStatus;
- (NSDictionary*)getVersion;

// Event processing
- (NSDictionary*)createPeerAddRequestWithChatId:(NSString*)chatId
                                        peerName:(NSString*)peerName
                                       peerEmail:(NSString*)peerEmail
                                          peerId:(NSString*)peerId;

- (NSDictionary*)processPeerAddResponseWithChatId:(NSString*)chatId
                                            peerId:(NSString*)peerId
                                          accepted:(BOOL)accepted
                                   rejectionReason:(NSString*)rejectionReason;

- (NSDictionary*)processFileEncryptRequestWithFileId:(NSString*)fileId
                                             fileName:(NSString*)fileName
                                             filePath:(NSString*)filePath
                                           targetPeer:(NSString*)targetPeer
                                               chatId:(NSString*)chatId
                                        allowDownload:(BOOL)allowDownload
                                         allowForward:(BOOL)allowForward
                                           accessTime:(NSInteger)accessTime
                                        encryptionKey:(NSString*)encryptionKey
                                             metadata:(NSString*)metadata;

- (NSDictionary*)processFileDecryptRequestWithFileId:(NSString*)fileId
                                             filePath:(NSString*)filePath
                                       decryptionKeys:(NSString*)decryptionKeys;

// User management
- (BOOL)createUserProfileWithUsername:(NSString*)username
                           profileData:(NSDictionary*)profileData;

- (BOOL)selectUserProfileWithUsername:(NSString*)username;

- (NSString*)getCurrentUser;

- (NSArray*)getAvailableUsers;

// Profile switching
- (BOOL)switchProfileWithUsername:(NSString*)username;

// Chat operations
- (BOOL)isChatProtected:(NSString*)chatId;

- (NSDictionary*)deleteChatRoomWithChatId:(NSString*)chatId;

// Configuration management
- (BOOL)setConfigWithKey:(NSString*)key value:(NSDictionary*)value;

- (NSDictionary*)getConfigWithKey:(NSString*)key;

// Unified message processing
- (NSDictionary*)processMessageWithData:(NSString*)eventDataJson;

// Message validation
- (BOOL)isPrivittyMessageWithString:(NSString*)base64Data;

@end
