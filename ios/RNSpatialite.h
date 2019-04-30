
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

@interface RNSpatialite : NSObject <RCTBridgeModule>
- (void)openFromFilename:(NSString *)filename callback:(RCTResponseSenderBlock)callback;
- (void)closeDatabase:(NSString *)databaseId callback:(RCTResponseSenderBlock)callback;
- (void)prepareStatement: (NSString *)databaseId sql: (NSString *)sql andParams: (NSArray *)params callback: (RCTResponseSenderBlock)callback;
- (void)stepStatement:(NSString *)databaseId statementId: (NSString *) statementId callback:(RCTResponseSenderBlock)callback;
- (void)finalizeStatement:(NSString *)databaseId statementId: (NSString *) statementId callback:(RCTResponseSenderBlock)callback;
- (void)executeQuery:(NSString *)databaseId sql: (NSString *)sql andParams: (NSArray *)params callback: (RCTResponseSenderBlock)callback;
@end
