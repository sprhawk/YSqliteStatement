//
//  YSqliteStatement.m
//  Nikita
//
//  Created by YANG HONGBO on 2013-1-22.
//  Copyright (c) 2013年 YANG HONGBO. All rights reserved.
//

#import "YSqliteStatement.h"
#import "ysqlite.h"

NSString * const YSqliteStatementException = @"YSqliteStatementException";

#define MakeYSqliteStatementException(_reason, _userInfo) [NSException exceptionWithName:YSqliteStatementException reason:_reason userInfo:_userInfo]
#define ThrowYSqliteStatementException(reason, userInfo) @throw MakeYSqliteStatementException(reason, userInfo)


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
    id stat = [[[self class] alloc] initWithSql:sql ysqlite:ysqlite];
    return stat;
}

+ (id)statementWithYSqlite:(YSqlite *)ysqlite
{
    id stat = [[[self class] alloc] initWithYSqlite:ysqlite];
    return stat;
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
        const char * zTail = NULL;
        int ret = sqlite3_prepare_v2(self.ysqlite.sqlite, zSql, [self.sql length], &_sqlite_stmt, &zTail);
        if (zTail) {
        }
        if (SQLITE_OK == ret) {
            self.status = YSqliteStatmentStatusPrepared;
        }
        else {
            [self logError];
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
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
}

- (BOOL)execute
{
    BOOL executed = NO;
    [self prepare];
    if ([self isPrepared]) {
        int ret = sqlite3_step(_sqlite_stmt);
        if (SQLITE_DONE == ret) {
            executed = YES;
            //self.lastInsertRowid = sqlite3_last_insert_rowid(self.ysqlite.sqlite);
            self.status = YSqliteStatmentStatusDone;
        }
        else if (SQLITE_ROW == ret) {
            executed = YES;
            self.status = YSqliteStatmentStatusHasRow;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
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
                [self logError];
                self.status = YSqliteStatemntStatusError;
            }
        }
    }
}

- (void)logError
{
    if (self.ysqlite.sqlite) {
        const char * errmsg = sqlite3_errmsg(self.ysqlite.sqlite);
        YLOG(@"sqlite3:%s", errmsg);
    }
    self.error = nil;
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
        [self logError];
        ThrowYSqliteStatementException(@"No bound name", nil);
    }
    return index;
}

- (BOOL)bindTimestamp:(NSDate *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindTimestamp:value column:index];
}

- (BOOL)bindTimestamp:(NSDate *)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        NSInteger timestamp = (NSInteger)[value timeIntervalSince1970];
        int ret = sqlite3_bind_int(_sqlite_stmt, column, timestamp);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindInt:(int)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindInt:value column:index];
}

- (BOOL)bindInt:(int)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_int(_sqlite_stmt, column, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindInt64:(sqlite3_int64)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindInt64:value column:index];
}

- (BOOL)bindInt64:(sqlite3_int64)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_int64(_sqlite_stmt, column, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindDouble:(double)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindDouble:value column:index];
}

- (BOOL)bindDouble:(double)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        int ret = sqlite3_bind_double(_sqlite_stmt, column, value);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindText:(NSString *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindText:value column:index];
}

- (BOOL)bindText:(NSString *)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        const char * text = [value cStringUsingEncoding:NSUTF8StringEncoding];
        int ret = sqlite3_bind_text(_sqlite_stmt, column, text, -1, SQLITE_TRANSIENT);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
            self.status = YSqliteStatemntStatusError;
        }
    }
    return bound;
}

- (BOOL)bindBlob:(NSData *)value key:(NSString *)key
{
    int index = [self indexForKey:key];
    return [self bindBlob:value column:index];
}

- (BOOL)bindBlob:(NSData *)value column:(int)column
{
    BOOL bound = NO;
    if (![self isPrepared]) {
        [self prepare];
    }
    if ([self isPrepared]) {
        const void * data = [value bytes];
        int ret = sqlite3_bind_text(_sqlite_stmt, column, data, [value length], SQLITE_TRANSIENT);
        if (SQLITE_OK == ret) {
            bound = YES;
        }
        else {
            [self logError];
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
        @throw NSGenericException;
    }
    const char * name = sqlite3_column_name(_sqlite_stmt, index);
    return [NSString stringWithUTF8String:name];
}

- (int)intValueAtIndex:(int)index
{
    if (![self hasRow]) {
        @throw NSGenericException;
    }
    return sqlite3_column_int(_sqlite_stmt, index);
}

- (double)doubleValueAtIndex:(int)index
{
    if (![self hasRow]) {
        @throw NSGenericException;
    }
    return sqlite3_column_double(_sqlite_stmt, index);
}

- (id)valueAtIndex:(int)index
{
    if (![self hasRow]) {
        @throw NSGenericException;
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
        @throw NSGenericException;
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

@end