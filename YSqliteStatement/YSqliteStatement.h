//
//  YSqliteStatement.h
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

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#define MakeYSqliteStatementException(_name, _reason, _userInfo) [NSException exceptionWithName:@"YSqliteStatement"@#_name"Exception" reason:_reason userInfo:_userInfo]
#define ThrowYSqliteStatementException(reason, userInfo) @throw MakeYSqliteStatementException(Normal, reason, userInfo)
#define ThrowYSqliteStatementWrongColumnTypeException(reason, userInfo) @throw MakeYSqliteStatementException(WrongColumnType, reason, userInfo)
#define ThrowYSqliteStatementNoRowException(reason, userInfo) {YLOG(@"");@throw MakeYSqliteStatementException(NoRow, reason, userInfo);}

@class YSqlite;

typedef enum YSqliteStatmentStatus
{
    YSqliteStatmentStatusInitialized,
    YSqliteStatmentStatusPrepared,
    YSqliteStatmentStatusHasRow,
    YSqliteStatmentStatusDone,
    YSqliteStatmentStatusFinished,
    YSqliteStatemntStatusError,
}YSqliteStatmentStatus;


@interface YSqliteStatement : NSObject
{
    sqlite3_stmt * _sqlite_stmt;
}
@property (nonatomic, copy, readonly) NSString * sql;
@property (nonatomic, strong, readonly) YSqlite * ysqlite;
@property (nonatomic, assign, readonly) YSqliteStatmentStatus status;
@property (nonatomic, strong, readonly) NSError * error;
@property (nonatomic, assign, readonly) sqlite3_int64 lastInsertRowid;
@property (nonatomic, assign, readwrite) NSUInteger maxRetryCount;

+ (id)statementWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite;
+ (id)statementWithYSqlite:(YSqlite *)ysqlite;
+ (id)statementWithURL:(NSURL *)url encoding:(NSStringEncoding)encoding ysqlite:(YSqlite *)ysqlite;
+ (id)statementWithResource:(NSString *)name extension:(NSString *)extension bundle:(NSBundle *)bnd ysqlite:(YSqlite *)ysqlite;

- (id)initWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite;
- (id)initWithYSqlite:(YSqlite *)ysqlite;
- (BOOL)prepareSQL:(NSString *)sql;
- (BOOL)prepare;
- (BOOL)execute;
- (void)finish;
- (BOOL)isPrepared;
- (BOOL)isFinished;
- (BOOL)hasRow;
- (BOOL)step;
- (void)reset;
- (BOOL)bindInt:(int)value index:(int)index;
- (BOOL)bindInt:(int)value key:(NSString *)key;
- (BOOL)bindInt64:(sqlite3_int64)value index:(int)index;
- (BOOL)bindInt64:(sqlite3_int64)value key:(NSString *)key;
- (BOOL)bindDouble:(double)value index:(int)index;
- (BOOL)bindDouble:(double)value key:(NSString *)key;
- (BOOL)bindBlob:(NSData *)value index:(int)index;
- (BOOL)bindBlob:(NSData *)value key:(NSString *)key;
- (BOOL)bindText:(NSString *)value index:(int)index;
- (BOOL)bindText:(NSString *)value key:(NSString *)key;
- (BOOL)bindValue:(id)value key:(NSString *)key;
//- (BOOL)bindValuesAndKeysAndTypes:(id)firstValue, ...;
- (BOOL)bindValue:(id)value index:(int)index;
- (BOOL)bindDate:(NSDate *)value index:(int)index;
- (BOOL)bindDate:(NSDate *)value key:(NSString *)key;
- (BOOL)bindNullIndex:(int)index;
- (BOOL)bindNullKey:(NSString *)key;

- (void)clearBindings;

//
- (NSArray *)currentValues;
- (NSError *)lastError;
- (int)columnCount;
- (id)valueAtIndex:(int)index;
- (double)doubleValueAtIndex:(int)index;
- (int)intValueAtIndex:(int)index;
- (sqlite3_int64)int64ValueAtIndex:(int)index;
- (NSDate *)dateAtIndex:(int)index;
- (NSString *)columnNameAtIndex:(int)index;
- (NSString *)textValueAtIndex:(int)index;
- (int)numberOfRowsChanged;
@end