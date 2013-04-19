//
//  ysqlite.m
//  YSqliteStatement
//
//
//Copyright (c) 2013, Hongbo Yang (hongbo@yang.me)
//All rights reserved.
//
//1. Redistribution and use in source and binary forms, with or without modification, are permitted
//provided that the following conditions are met:
//
//2. Redistributions of source code must retain the above copyright notice, this list of conditions
//and
//the following disclaimer.
//
//3. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
//and the following disclaimer in the documentation and/or other materials provided with the
//distribution.
//
//Neither the name of the Hongbo Yang nor the names of its contributors may be used to endorse or
//promote products derived from this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
//CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ysqlite.h"
#import "YSqliteStatement.h"
#import <ytoolkit/ymacros.h>

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
        int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI;
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

- (BOOL)openOrCreateWithBlock:(void (^)(YSqlite * ysqlite))initializationBlock
{
    if (NULL == _sqlite3 && self.url) {
        NSString * path = [self.url path];
        const char * dbpath = [path cStringUsingEncoding:NSUTF8StringEncoding];
        
        int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI;
        
        NSFileManager * mgr = [[NSFileManager alloc] init];
        if (![mgr fileExistsAtPath:[NSString stringWithUTF8String:dbpath]]) {
            flags |= SQLITE_OPEN_CREATE;
        }
        int ret = sqlite3_open_v2(dbpath, &_sqlite3, flags, NULL);
        if (SQLITE_OK != ret) {
            if (_sqlite3) {
                const char * errmsg = sqlite3_errmsg(_sqlite3);
                
                NSString * reason = [NSString stringWithFormat:@"cannot open db:%s:%@", errmsg, path];
                YLOG(@"%@", reason);
                [self closeDB];
                ThrowYSqliteException(reason, nil);
            }
            else {
                NSString * reason = @"cannot alloc memory for sqlite3";
                YLOG(@"%@", reason);
                ThrowYSqliteException(reason, nil);
            }
            return NO;
        }
        if (initializationBlock) {
            initializationBlock(self);
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

- (BOOL)executeSql:(NSString *)sql withError:(NSError * __autoreleasing *)error
{
    YSqliteStatement * stat = [self statementWithSql:sql];
    BOOL ret = [stat execute];
    if (!ret) {
        if (error) {
            *error = [stat lastError];
        }
    }
    return ret;
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

+ (BOOL)loadBatchStatementsAtURL:(NSURL *)url execution:(BOOL (^)(NSString * sqlstmt))execution error:(NSError * __autoreleasing *)error
{
    BOOL finished = YES;
    NSFileHandle * handle = [NSFileHandle fileHandleForReadingFromURL:url error:error];
    if (handle) {
        if (execution) {
            const NSUInteger bufferSize = 128;
            NSMutableString * buffer = [NSMutableString stringWithCapacity:bufferSize * 2];
            BOOL dataIsFinished = NO;
            NSData * data = nil;
            do {
                NSRange rng = {NSNotFound, 0};
                do {
                    data = [handle readDataOfLength:bufferSize];
                    if (0 == data.length) {
                        dataIsFinished = YES;
                        break;
                    }
                    NSString * string = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
                    [buffer appendString:string];
                    rng = [buffer rangeOfString:@";" ];
                    if (NSNotFound != rng.location) {
                        break;
                    }
                } while (data.length);
                
                if (buffer.length) {
                    NSString * stmt = nil;
                    if (NSNotFound == rng.location) {
                        rng.location = 0;
                        rng.length = buffer.length;
                    }
                    
                    stmt = [buffer substringToIndex:rng.location+1];
                    stmt = [stmt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (stmt.length) {
                        BOOL cont = execution(stmt);
                        if (NO == cont) {
                            finished = NO;
                            break;
                        }
                    }
                    [buffer deleteCharactersInRange:NSMakeRange(0, rng.location + 1)];
                    NSString * newstring = [buffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    [buffer setString:newstring];
                }
                
            }while(!dataIsFinished);
        }
        [handle closeFile];
    }
    
    return finished;
}

- (BOOL)loadBatchStatementsAtURL:(NSURL *)url error:(NSError *__autoreleasing *)error
{
    return [[self class] loadBatchStatementsAtURL:url execution:^BOOL(NSString *sqlstmt) {
        NSError * stmtError = nil;
        BOOL rslt = [self executeSql:sqlstmt withError:&stmtError];
        if (!rslt) {
            if (stmtError) {
                if (error) {
                    *error = stmtError;
                }
            }
            return NO;
        }
        return YES;
    } error:error];
}

- (int)userVersion
{
    int version = -1;
    YSqliteStatement * stmt = [self statementWithSql:@"PRAGMA user_version;"];
    BOOL ret = [stmt execute];
    if (ret) {
        version = [stmt intValueAtIndex:0];
    }
    else {
        ThrowYSqliteException(@"User Version Wrong", nil);
    }
    return version;
}

- (BOOL)setUserVersion:(int)version
{
    BOOL ret = NO;
    NSString * sql = [NSString stringWithFormat:@"PRAGMA user_version=%d;", version];
    YSqliteStatement * stmt = [self statementWithSql:sql];
    ret = [stmt execute];
    if (!ret) {
        NSError * error = [stmt lastError];
        if (error) {
            YLOG(@"set user_version failed:%@", error);
        }
    }
    return ret;
}
@end

