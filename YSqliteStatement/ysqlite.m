//
//  ysqlite.m
//  ysqlite
//
//  Created by YANG HONGBO on 2012-11-8.
//  Copyright (c) 2012年 YANG HONGBO. All rights reserved.
//

#import "ysqlite.h"
#import "YSqliteStatement.h"

NSString * const YSqliteException = @"YSqliteException";

#define MakeYSqliteException(_reason, _userInfo) [NSException exceptionWithName:YSqliteException reason:_reason userInfo:_userInfo]
#define ThrowYSqliteException(reason, userInfo) @throw MakeYSqliteException(reason, userInfo)

@interface YSqlite ()
{
    sqlite3 * _sqlite3;
}
@property (nonatomic, retain, readwrite) NSURL * url;


@end

@implementation YSqlite
- (id)initWithURL:(NSURL *)url
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sqlite3_initialize();
    });
    self = [super init];
    if (self) {
        if (![url isFileURL]) {
            self = nil;
            return self;
        }
        self.url = url;
    }
    return self;
}

- (void)dealloc
{
    [self closeDB];
}

- (sqlite3 *)sqlite
{
    [self openDB];
    return _sqlite3;
}

- (BOOL)openDB
{
    if (NULL == _sqlite3 && self.url) {
        NSString * path = [self.url path];
        const char * dbpath = [path cStringUsingEncoding:NSUTF8StringEncoding];
        int flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI;
        int ret = sqlite3_open_v2(dbpath, &_sqlite3, flags, NULL);
        if (SQLITE_OK != ret) {
            if (_sqlite3) {
                const char * errmsg = sqlite3_errmsg(_sqlite3);
                
                NSString * reason = [NSString stringWithFormat:@"cannot open db:%s:%@", errmsg, path];
                //YLOG(reason);
                [self closeDB];
                ThrowYSqliteException(reason, nil);
            }
            else {
                NSString * reason = @"cannot alloc memory for sqlite3";
                //YLOG(reason);
                ThrowYSqliteException(reason, nil);
            }
            return NO;
        }
        
        return YES;
    }
    return NO;
}

- (void)closeDB
{
    sqlite3_close(_sqlite3);
    _sqlite3 = NULL;
}

- (BOOL)executeSql:(NSString *)sql
{
    YSqliteStatement * stat = [self statementWithSql:sql];
    return [stat execute];
}

- (void)logError
{
    if (_sqlite3) {
        const char * errmsg = sqlite3_errmsg(_sqlite3);
        YLOG(@"sqlite3:%s", errmsg);
    }
}

+ (void)shutdown
{
    sqlite3_shutdown();
}

- (YSqliteStatement *)statementWithSql:(NSString *)sql
{
    YSqliteStatement * statement = [YSqliteStatement statementWithSql:sql ysqlite:self];
    return statement;
}

@end

