//
//  YSqliteStatement.m
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

#import "YSqliteStatement.h"
#import "ysqlite.h"
#import <ytoolkit/ymacros.h>

#define DEFAULT_RETRYCOUNT 0

@interface YSqliteStatement ()
{
    
}
@property (nonatomic, copy, readwrite) NSString * sql;
@property (nonatomic, strong, readwrite) YSqlite * ysqlite;
@property (nonatomic, assign, readwrite) YSqliteStatmentStatus status;
@property (nonatomic, strong, readwrite) NSError * error;
@property (nonatomic, assign, readwrite) sqlite3_int64 lastInsertRowid;
@end

@implementation YSqliteStatement

+ (id)statementWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite
{
    id stmt = [[[self class] alloc] initWithSql:sql ysqlite:ysqlite];
    return stmt;
}

+ (id)statementWithYSqlite:(YSqlite *)ysqlite
{
    id stmt = [[[self class] alloc] initWithYSqlite:ysqlite];
    return stmt;
}


+ (id)statementWithURL:(NSURL *)url encoding:(NSStringEncoding)encoding ysqlite:(YSqlite *)ysqlite
{
    NSError * error = nil;
    NSString * sql = [[NSString alloc] initWithContentsOfURL:url encoding:encoding error:&error];
    return [[[self class] alloc] initWithSql:sql ysqlite:ysqlite];
}

+ (id)statementWithResource:(NSString *)name extension:(NSString *)extension bundle:(NSBundle *)bnd ysqlite:(YSqlite *)ysqlite
{
    NSBundle * bundle = bnd;
    if (!bundle) {
        bundle = [NSBundle mainBundle];
    }
    NSURL * url = [bundle URLForResource:name withExtension:extension];
    return [self statementWithURL:url encoding:NSUTF8StringEncoding ysqlite:ysqlite];
}

- (id)initWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite
{
    self = [super init];
    if (nil == sql || nil == ysqlite) {
        self = nil;
    }
    if (self) {
        self.sql = sql;
        self.ysqlite = ysqlite;
        self.maxRetryCount = DEFAULT_RETRYCOUNT;
    }
    return self;
}

- (id)initWithYSqlite:(YSqlite *)ysqlite
{
    self = [super init];
    if (nil == ysqlite) {
        self = nil;
    }
    if (self) {
        self.ysqlite = ysqlite;
    }
    return self;
}


- (BOOL)prepareSQL:(NSString *)sql
{
    if (sql) {
        self.sql = sql;
        if (![self isFinished]) {
            [self finish];
        }
        [self prepare];
    }
    return NO;
}

- (void)dealloc
{
    [self finish];
}

- (BOOL)prepare
{
    if (![self isPrepared]) {
        const char * zSql = [self.sql cStringUsingEncoding:NSUTF8StringEncoding];
        size_t len = strlen(zSql) + 1;
        const char * zTail = NULL;
        int ret = sqlite3_prepare_v2(self.ysqlite.sqlite, zSql, len, &_sqlite_stmt, &zTail);
        if (zTail) {
        }
        if (SQLITE_OK == ret) {
            self.status = YSqliteStatmentStatusPrepared;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:prepare_v2:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return YSqliteStatmentStatusPrepared == self.status;
}

- (void)reset
{
    if (_sqlite_stmt) {
        int ret = sqlite3_reset(_sqlite_stmt);
        if (SQLITE_OK == ret) {
            self.status = YSqliteStatmentStatusPrepared;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:reset:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
}

- (BOOL)execute
{
    [self prepare];
    if ([self isPrepared]) {
        [self reset];
        BOOL ret = [self step];
        return ret;
    }
    return NO;
}

- (BOOL)step
{
    [self prepare];
    BOOL executed = YES;
    int retryCount = 0;
    if ([self isPrepared] || [self hasRow]) {
        do {
            int ret = sqlite3_step(_sqlite_stmt);
            if (SQLITE_DONE == ret) {
                self.status = YSqliteStatmentStatusDone;
                [self reset];
            }
            else if (SQLITE_ROW == ret) {
                self.status = YSqliteStatmentStatusHasRow;
            }
            else if (SQLITE_BUSY == ret || SQLITE_LOCKED == ret) {
                executed = NO;
                retryCount ++;
                [NSThread sleepForTimeInterval:0.003];
                if (self.maxRetryCount && retryCount > self.maxRetryCount) {
                    YLOG(@"YSqliteStatement:step:retry timed out!");
                    break;
                }
            }
            else {
                NSError * error = [self lastError];
                YLOG(@"sqlite3:step:%@", [error localizedDescription]);
                self.status = YSqliteStatemntStatusError;
                [self reset];
            }
        }while (!executed);
    }
    return executed;
}

- (sqlite3_int64)updateLastInsertRowid
{
    self.lastInsertRowid = sqlite3_last_insert_rowid(self.ysqlite.sqlite);
    return self.lastInsertRowid;
}

- (void)finish
{
    if (YSqliteStatmentStatusInitialized != self.status) {
        if (_sqlite_stmt) {
            int ret = sqlite3_finalize(_sqlite_stmt);
            if (SQLITE_OK == ret) {
                self.status = YSqliteStatmentStatusFinished;
                _sqlite_stmt = NULL;
            }
            else {
                NSError * error = [self lastError];
                YLOG(@"sqlite3:%@", [error localizedDescription]);
                self.status = YSqliteStatemntStatusError;
            }
        }
    }
}

- (NSError *)lastError
{
    const char * errmsg = sqlite3_errmsg(self.ysqlite.sqlite);
    NSString * description = [NSString stringWithUTF8String:errmsg];
    NSDictionary * userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                               description, NSLocalizedDescriptionKey, nil];
                               
    NSError * error = [NSError errorWithDomain:@"YSqliteError" code:0 userInfo:userInfo];
    return error;
}

- (BOOL)hasRow
{
    return YSqliteStatmentStatusHasRow == self.status;
}

- (BOOL)isPrepared
{
    return (YSqliteStatmentStatusPrepared == self.status
            || YSqliteStatmentStatusHasRow == self.status);
}

- (BOOL)isFinished
{
    return YSqliteStatmentStatusFinished == self.status;
}

#pragma mark - Bind functions
- (int)indexForKey:(NSString *)key
{
    const char * name = [key cStringUsingEncoding:NSUTF8StringEncoding];
    if (![self isPrepared]) {
        [self prepare];
    }
    int index = sqlite3_bind_parameter_index(_sqlite_stmt, name);
    if (!index) {
        NSError * error = [self lastError];
        YLOG(@"sqlite3:%@", [error localizedDescription]);
        ThrowYSqliteStatementException(@"No bound name", nil);
    }
    return index;
}

- (BOOL)bindDate:(NSDate *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindDate:value index:index];
}

- (BOOL)bindDate:(NSDate *)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        NSInteger timestamp = (NSInteger)[value timeIntervalSince1970];
        int ret = sqlite3_bind_int(_sqlite_stmt, index, timestamp);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindInt:(int)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindInt:value index:index];
}

- (BOOL)bindInt:(int)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_int(_sqlite_stmt, index, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindInt64:(sqlite3_int64)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindInt64:value index:index];
}

- (BOOL)bindInt64:(sqlite3_int64)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_int64(_sqlite_stmt, index, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindDouble:(double)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindDouble:value index:index];
}

- (BOOL)bindDouble:(double)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_double(_sqlite_stmt, index, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindText:(NSString *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindText:value index:index];
}

- (BOOL)bindText:(NSString *)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        const char * text = [value cStringUsingEncoding:NSUTF8StringEncoding];
        int ret = sqlite3_bind_text(_sqlite_stmt, index, text, -1, SQLITE_TRANSIENT);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindBlob:(NSData *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindBlob:value index:index];
}

- (BOOL)bindBlob:(NSData *)value index:(int)index
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        const void * data = [value bytes];
        int ret = sqlite3_bind_text(_sqlite_stmt, index, data, [value length], SQLITE_TRANSIENT);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            NSError * error = [self lastError];
            YLOG(@"sqlite3:%@", [error localizedDescription]);
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}



- (BOOL)bindValue:(id)value key:(NSString *)key type:(NSString *)type
{
    BOOL bound = NO;
    if ([type isEqualToString:@"int"]) {
        if (YIS_INSTANCE_OF(value, NSNumber)) {
            [self bindInt:[value integerValue] key:key];
        }
        else {
            @throw NSInvalidArgumentException;
        }
    }
    return bound;
}


- (BOOL)bindValuesAndKeysAndTypes:(id)firstValue, ...
{
    id eachObject;
    va_list argumentList;
    BOOL bound = NO;
    if (firstValue)
    {
        va_start(argumentList, firstValue); // Start scanning for arguments after firstObject.
        id key = va_arg(argumentList, id);
        id type = va_arg(argumentList, id);
        if (nil == key || nil == type) {
            @throw NSInvalidArgumentException;
        }
        bound = [self bindValue:firstValue key:key type:type];
        
        while (bound && (eachObject = va_arg(argumentList, id))) {
            key = va_arg(argumentList, id);
            type = va_arg(argumentList, id);
            if (key && type) {
                bound = [self bindValue:eachObject key:key type:type];
            }
            else {
                @throw NSInvalidArgumentException;
            }
        }
        va_end(argumentList);
    }
    return bound;
}

- (NSString *)columnNameAtIndex:(int)index
{
    if (![self hasRow]) {
        ThrowYSqliteStatementNoRowException(nil, nil);
    }
    const char * name = sqlite3_column_name(_sqlite_stmt, index);
    return [NSString stringWithUTF8String:name];
}

- (int)intValueAtIndex:(int)index
{
    if (![self hasRow]) {
        ThrowYSqliteStatementNoRowException(nil, nil);
    }
    return sqlite3_column_int(_sqlite_stmt, index);
}

- (double)doubleValueAtIndex:(int)index
{
    if (![self hasRow]) {
        ThrowYSqliteStatementNoRowException(nil, nil);
    }
    return sqlite3_column_double(_sqlite_stmt, index);
}

- (NSString *)textValueAtIndex:(int)index
{
    id value = [self valueAtIndex:index];
    if (YIS_INSTANCE_OF(value, NSString)) {
        return value;
    }
    else if (value == [NSNull null]) {
        return @"";
    }
    ThrowYSqliteStatementWrongColumnTypeException(nil, nil);
    return nil;
}

- (NSDate *)dateAtIndex:(int)index
{
    NSUInteger time = (NSUInteger)[self intValueAtIndex:index];
    return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)time];
}

- (id)valueAtIndex:(int)index
{
    if (![self hasRow]) {
        ThrowYSqliteStatementNoRowException(nil, nil);
    }
    int type = sqlite3_column_type(_sqlite_stmt, index);
    id returnedValue = nil;
    switch (type) {
        case SQLITE_INTEGER:
        {
            int value = sqlite3_column_int(_sqlite_stmt, index);
            NSNumber * number = [NSNumber numberWithInteger:value];
            returnedValue = number;
        }
            break;
        case SQLITE_FLOAT:
        {
            double value = sqlite3_column_double(_sqlite_stmt, index);
            NSNumber * number = [NSNumber numberWithDouble:value];
            returnedValue = number;
        }
            break;
        case SQLITE_TEXT:
        {
            const unsigned char * value = sqlite3_column_text(_sqlite_stmt, index);
            NSString * string = [NSString stringWithUTF8String:(const char *)value];
            returnedValue = string;
        }
            break;
        case SQLITE_BLOB:
        {
            int bytes = sqlite3_column_bytes(_sqlite_stmt, index);
            const void * blob = sqlite3_column_blob(_sqlite_stmt, index);
            NSData * data = [NSData dataWithBytes:blob length:bytes];
            returnedValue = data;
        }
            break;
        case SQLITE_NULL:
        {
            returnedValue = [NSNull null];
        }
            break;
        default:
            break;
    }
    
    return returnedValue;
}

- (int)columnCount
{
    if (![self hasRow]) {
        ThrowYSqliteStatementNoRowException(nil, nil);
    }
    return sqlite3_column_count(_sqlite_stmt);
}

- (NSArray *)currentValues
{
    int column = [self columnCount];
    NSMutableArray * result = [NSMutableArray arrayWithCapacity:column];
    for (int i = 0; i < column; i ++) {
        id value = [self valueAtIndex:i];
        [result addObject:value];
    }
    return result;
};

- (void)clearBindings
{
    sqlite3_clear_bindings(_sqlite_stmt);
}
@end