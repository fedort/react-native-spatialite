
#import <AVFoundation/AVFoundation.h>
#import "RNSpatialite.h"
#include <sqlite3.h>
#include <gaiageo.h>
#include <spatialite.h>
#import <React/RCTLog.h>

// From RCTAsyncLocalStorage, make a queue so we can serialise our interactions
static dispatch_queue_t SpatiaLiteQueue(void)
{
    static dispatch_queue_t sqliteQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // All JS is single threaded, so a serial queue is our only option.
        sqliteQueue = dispatch_queue_create("com.activeinboxhq.sqlite", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(sqliteQueue,
                                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    });

    return sqliteQueue;
}

// Private class to hold details of an open database
@interface Database : NSObject
@property (readonly) sqlite3 * db;
@property (readonly) NSMutableDictionary *statements;
@end

@implementation Database
@synthesize db = _db;
@synthesize statements = _statements;

- (id) initWithSqliteDb: (sqlite3 *) db
{
    self = [super init];
    if (self) {
        _db = db;
        _statements = [NSMutableDictionary dictionaryWithCapacity: 1];
    }
    return self;
}
@end

// Private class to hold details of an open database
@interface Statement : NSObject
@property (readonly) sqlite3_stmt * stmt;
@end

@implementation Statement
@synthesize stmt = _stmt;

- (id) initWithSqliteStmt: (sqlite3_stmt *) stmt
{
    self = [super init];
    if (self) {
        _stmt = stmt;
    }
    return self;
}
@end

@implementation RNSpatialite
{
    NSMutableDictionary *openDatabases;
    int nextId;
}

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

- (id) init
{
    self = [super init];
    if (self) {
        openDatabases = [NSMutableDictionary dictionaryWithCapacity: 1];
        nextId = 0;
    }
    return self;
}

RCT_EXPORT_METHOD(testFunction:(RCTResponseSenderBlock)callback) {
    NSString *name =  @"Thanh cong roi ban oi 111 !!!";
    callback(@[[NSNull null], name]);
}

RCT_EXPORT_METHOD(openFromFilename:(NSString *)filename callback:(RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called openFromFilename without a callback.");
        return;
    }
    dispatch_async(SpatiaLiteQueue(), ^{
        // TODO: Allow creation of database in Library or tmp
        // directories. Maybe also add an option to open read-only
        // direct from the bundle.
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *dbPath = filename;

        if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            // If the db file doesn't exist in the documents directory
            // but it does exist in the bundle then copy it over now
            NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
            NSError *error;
            if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
                [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:dbPath error:&error];
                if (error != nil) {
                    callback(@[[error localizedDescription], [NSNull null]]);
                }
            }
        }

        sqlite3 *db;
        //BOOL openDatabaseResult = sqlite3_open([dbPath UTF8String], &db);
        void *cache;

        BOOL openDatabaseResult = sqlite3_open_v2 ([dbPath UTF8String], &db,
                                                   SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);

        if(openDatabaseResult != SQLITE_OK) {
            callback(@[@"Couldn't open database", [NSNull null]]);
            return;
        }

        cache = spatialite_alloc_connection ();
        spatialite_init_ex (db, cache, 0);

        NSString *databaseId = [[NSNumber numberWithInt: nextId++] stringValue];
        Database *database = [[Database alloc] initWithSqliteDb:db];
        [openDatabases setValue:database forKey:databaseId];
        callback(@[[NSNull null], databaseId]);
    });
}

RCT_EXPORT_METHOD(closeDatabase:(NSString *)databaseId callback:(RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called openFromFilename without a callback.");
        return;
    }
    dispatch_async(SpatiaLiteQueue(), ^{
        Database *database = [openDatabases valueForKey:databaseId];
        if (database == nil) {
            callback(@[@"No open database found"]);
            return;
        }

        // Finalize any remaining statments
        for (NSString* statementId in [database statements]) {
            Statement *statement = [[database statements] objectForKey:statementId];
            sqlite3_stmt *stmt = [statement stmt];
            // We don't care about errors at this point, or at least there's nothing we can do about them
            sqlite3_finalize(stmt);
        }

        sqlite3 *db = [database db];
        sqlite3_close(db);

        [openDatabases removeObjectForKey: databaseId];
        callback(@[[NSNull null]]);
    });
}

RCT_EXPORT_METHOD(prepareStatement: (NSString *)databaseId sql: (NSString *)sql andParams: (NSArray *)params callback: (RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called prepareStatement without a callback.");
    }

    dispatch_async(SpatiaLiteQueue(), ^{
        Database *database = [openDatabases valueForKey:databaseId];
        if (database == nil) {
            callback(@[@"No open database found", [NSNull null]]);
            return;
        }
        sqlite3 *db = [database db];
        sqlite3_stmt *stmt;

        int rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL);

        if (rc != SQLITE_OK) {
            callback(@[[NSString stringWithUTF8String:sqlite3_errmsg(db)]]);
            return;
        }

        for (int i=0; i < [params count]; i++){
            NSObject *param = [params objectAtIndex: i];
            if ([param isKindOfClass: [NSString class]]) {
                NSString *str = (NSString*) param;
                int strLength = (int) [str lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
                sqlite3_bind_text(stmt, i+1, [str UTF8String], strLength, SQLITE_TRANSIENT);
            } else if ([param isKindOfClass: [NSNumber class]]) {
                sqlite3_bind_double(stmt, i+1, [(NSNumber *)param doubleValue]);
            } else if ([param isKindOfClass: [NSNull class]]) {
                sqlite3_bind_null(stmt, i+1);
            } else {
                sqlite3_finalize(stmt);
                callback(@[@"Parameters must be either numbers or strings" ]);
                return;
            }
        }

        NSString *statementId = [[NSNumber numberWithInt: nextId++] stringValue];
        Statement *statement = [[Statement alloc] initWithSqliteStmt: stmt];
        [[database statements] setValue: statement forKey:statementId];

        callback(@[[NSNull null], statementId]);
    });
}

RCT_EXPORT_METHOD(stepStatement:(NSString *)databaseId statementId: (NSString *) statementId callback:(RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called step without a callback.");
    }

    dispatch_async(SpatiaLiteQueue(), ^{
        Database *database = [openDatabases valueForKey:databaseId];
        if (database == nil) {
            callback(@[@"No open database found", [NSNull null]]);
            return;
        }
        Statement *statement = [[database statements] objectForKey:statementId];
        if (statement == nil) {
            callback(@[@"No statement found", [NSNull null]]);
            return;
        }

        sqlite3 *db = [database db];
        sqlite3_stmt *stmt = [statement stmt];

        int rc = sqlite3_step(stmt);
        if (rc == SQLITE_ROW) {
            int totalColumns = sqlite3_column_count(stmt);
            NSMutableDictionary *rowData = [NSMutableDictionary dictionaryWithCapacity: totalColumns];
            // Go through all columns and fetch each column data.
            for (int i=0; i<totalColumns; i++){
                // Convert the column data to text (characters).

                NSObject *value;
                NSData *data;
                switch (sqlite3_column_type(stmt, i)) {
                    case SQLITE_INTEGER:
                        value = [NSNumber numberWithLongLong: sqlite3_column_int64(stmt, i)];
                        break;
                    case SQLITE_FLOAT:
                        value = [NSNumber numberWithDouble: sqlite3_column_double(stmt, i)];
                        break;
                    case SQLITE_NULL:
                        value = [NSNull null];
                        break;
                    case SQLITE_BLOB:
                        data = [NSData dataWithBytes: sqlite3_column_blob(stmt, i) length: sqlite3_column_bytes16(stmt, i)];
                        value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        break;
                    case SQLITE_TEXT:
                    default:
                        data = [NSData dataWithBytes: sqlite3_column_blob(stmt, i) length: sqlite3_column_bytes16(stmt, i)];
                        value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        break;
                }
                char *columnName = (char *)sqlite3_column_name(stmt, i);
                // Convert the characters to string.
                [rowData setValue: value forKey: [NSString stringWithUTF8String: columnName]];
            }
            callback(@[[NSNull null], rowData]);
        } else if (rc == SQLITE_DONE) {
            sqlite3_finalize(stmt);
            [[database statements] removeObjectForKey: statementId];
            callback(@[[NSNull null], [NSNull null]]);
        } else {
            [[database statements] removeObjectForKey: statementId];
            sqlite3_finalize(stmt);
            callback(@[[NSString stringWithUTF8String:sqlite3_errmsg(db)], [NSNull null]]);
        }
    });
}

RCT_EXPORT_METHOD(finalizeStatement:(NSString *)databaseId statementId: (NSString *) statementId callback:(RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called step without a callback.");
    }

    dispatch_async(SpatiaLiteQueue(), ^{
        Database *database = [openDatabases valueForKey:databaseId];
        if (database == nil) {
            callback(@[@"No open database found", [NSNull null]]);
            return;
        }
        Statement *statement = [[database statements] objectForKey:statementId];
        if (statement == nil) {
            callback(@[@"No statement found", [NSNull null]]);
            return;
        }

        sqlite3 *db = [database db];
        sqlite3_stmt *stmt = [statement stmt];

        [[database statements] removeObjectForKey: statementId];

        if (sqlite3_finalize(stmt) == SQLITE_OK) {
            callback(@[[NSNull null]]);
        } else {
            callback(@[[NSString stringWithUTF8String:sqlite3_errmsg(db)]]);
        }
    });
}

RCT_EXPORT_METHOD(executeQuery:(NSString *)databaseId sql: (NSString *)sql andParams: (NSArray *)params callback: (RCTResponseSenderBlock)callback)
{
    if (!callback) {
        RCTLogError(@"Called executeQuery without a callback.");
        return;
    }
    dispatch_async(SpatiaLiteQueue(), ^{

        @try {
            // 1. prepare statement
                    // 2. step statement
                    // 3. finalize statement

                    // cache = spatialite_alloc_connection ();
                    // spatialite_init_ex (db, cache, 0);
                    // NG test implementation
//                    spatialite_init (0);
//                    printf("Spatialite version: %s\n", spatialite_version());

                    // PREPARE STATEMENT
                    Database *database = [openDatabases valueForKey:databaseId];
                            if (database == nil) {
                                callback(@[@"No open database found", [NSNull null]]);
                                return;
                            }
                     sqlite3 *db = [database db];
                     sqlite3_stmt *stmt; // todo is need?

//                     void *cache;
//
//                     cache = spatialite_alloc_connection ();
//                     spatialite_init_ex (db, cache, 0);
//                        spatialite_init (0);

                     int rc = 0;

                     @try {
                        rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL);
                     }
                     @catch (NSException *exception) {
                        NSString *errName = @"Prepare stmt error: ";
                        NSString *errorText = [errName stringByAppendingString:sql];
                        callback(@[errorText]);
                     }

                     if (rc != SQLITE_OK) {
                        NSString *divider = @"%%";
                        NSString *errName = [[NSString stringWithUTF8String:sqlite3_errmsg(db)] stringByAppendingString:divider];
                        NSString *errorText = [errName stringByAppendingString:sql];
                        callback(@[errorText]);
//                         callback(@[[NSString stringWithUTF8String:sqlite3_errmsg(db)]]);
                         return;
                     }

                     for (int i=0; i < [params count]; i++){
                         NSObject *param = [params objectAtIndex: i];
                         if ([param isKindOfClass: [NSString class]]) {
                                    NSString *str = (NSString*) param;
                                    int strLength = (int) [str lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
                                    sqlite3_bind_text(stmt, i+1, [str UTF8String], strLength, SQLITE_TRANSIENT);
                                } else if ([param isKindOfClass: [NSNumber class]]) {
                             sqlite3_bind_double(stmt, i+1, [(NSNumber *)param doubleValue]);
                         } else if ([param isKindOfClass: [NSNull class]]) {
                             sqlite3_bind_null(stmt, i+1);
                         } else {
                             sqlite3_finalize(stmt);
                             callback(@[@"Parameters must be either numbers or strings" ]);
                             return;
                         }
                     }

                     NSString *statementId = [[NSNumber numberWithInt: nextId++] stringValue];
                     Statement *statement = [[Statement alloc] initWithSqliteStmt: stmt];
                     [[database statements] setValue: statement forKey:statementId];

            //         callback(@[[NSNull null], statementId]);

                    // STEP STATEMENT

                    NSMutableArray* responseArray = [[NSMutableArray alloc] init];

                    do {

                                int rc = sqlite3_step(stmt);
                                if (rc == SQLITE_ROW) {
                                    int totalColumns = sqlite3_column_count(stmt);
                                    NSMutableDictionary *rowData = [NSMutableDictionary dictionaryWithCapacity: totalColumns];
                                    // Go through all columns and fetch each column data.
                                    for (int i=0; i<totalColumns; i++){
                                        // Convert the column data to text (characters).

                                        NSObject *value;
                                        NSData *data;
                                        switch (sqlite3_column_type(stmt, i)) {
                                            case SQLITE_INTEGER:
                                                value = [NSNumber numberWithLongLong: sqlite3_column_int64(stmt, i)];
                                                break;
                                            case SQLITE_FLOAT:
                                                value = [NSNumber numberWithDouble: sqlite3_column_double(stmt, i)];
                                                break;
                                            case SQLITE_NULL:
                                                value = [NSNull null];
                                                break;
                                            case SQLITE_BLOB:
                                                data = [NSData dataWithBytes: sqlite3_column_blob(stmt, i) length: sqlite3_column_bytes16(stmt, i)];
                                                value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                break;
                                            case SQLITE_TEXT:
                                            default:
                                                data = [NSData dataWithBytes: sqlite3_column_blob(stmt, i) length: sqlite3_column_bytes16(stmt, i)];
                                                value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                break;
                                        }
                                        char *columnName = (char *)sqlite3_column_name(stmt, i);
                                        // Convert the characters to string.
                                        NSString *utfString = [NSString stringWithUTF8String: columnName];
                                        [rowData setValue: value forKey: [utfString lowercaseString]];
                                    }
            //                           NSNumber* number = [NSNumber numberWithInt:i]; // <-- autoreleased, so you don't need to release it yourself
                                         [responseArray addObject:rowData];
            //                        callback(@[[NSNull null], rowData]);
                                } else if (rc == SQLITE_DONE) {
                                    // FINALIZE STATEMENT
                                    sqlite3_finalize(stmt);
                                    [[database statements] removeObjectForKey: statementId];
                                    break;
                                } else {
                                    [[database statements] removeObjectForKey: statementId];
                                    sqlite3_finalize(stmt);
                                    callback(@[[NSString stringWithUTF8String:sqlite3_errmsg(db)], [NSNull null]]);
                                    return;
                                    break;
                                }
                    } while(true);

                    callback(@[[NSNull null], responseArray]);

                }
                @catch (NSException *exception) {
                    NSString *errName = @"SpatiaLite error: ";
                        NSString *errorText = [errName stringByAppendingString:exception.reason];
                        callback(@[errorText]);
                }
        });
}
@end
