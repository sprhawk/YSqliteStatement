//
//  YSqliteStatement.h
//  Nikita
//
//  Created by YANG HONGBO on 2013-1-22.
//  Copyright (c) 2013年 YANG HONGBO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

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

+ (id)statementWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite;
+ (id)statementWithYSqlite:(YSqlite *)ysqlite;

- (id)initWithSql:(NSString *)sql ysqlite:(YSqlite *)ysqlite;
- (id)initWithYSqlite:(YSqlite *)ysqlite;
- (BOOL)prepareSQL:(NSString *)sql;
- (BOOL)prepare;
- (BOOL)execute;
- (void)finish;
- (BOOL)isPrepared;
- (BOOL)isFinished;
- (BOOL)hasRow;
- (void)reset;
- (BOOL)bindInt:(int)value column:(int)column;
- (BOOL)bindInt:(int)value key:(NSString *)key;
- (BOOL)bindInt64:(sqlite3_int64)value column:(int)column;
- (BOOL)bindInt64:(sqlite3_int64)value key:(NSString *)key;
- (BOOL)bindDouble:(double)value column:(int)column;
- (BOOL)bindDouble:(double)value key:(NSString *)key;
- (BOOL)bindBlob:(NSData *)value column:(int)column;
- (BOOL)bindBlob:(NSData *)value key:(NSString *)key;
- (BOOL)bindText:(NSString *)value column:(int)column;
- (BOOL)bindText:(NSString *)value key:(NSString *)key;
- (BOOL)bindValue:(id)value key:(NSString *)key type:(NSString *)type;
- (BOOL)bindValuesAndKeysAndTypes:(id)firstValue, ...;

- (BOOL)bindTimestamp:(NSDate *)value column:(int)column;
- (BOOL)bindTimestamp:(NSDate *)value key:(NSString *)key;

//
- (NSArray *)currentValues;
- (int)columnCount;
- (id)valueAtIndex:(int)index;
- (double)doubleValueAtIndex:(int)index;
- (int)intValueAtIndex:(int)index;
- (NSString *)columnNameAtIndex:(int)index;
@end