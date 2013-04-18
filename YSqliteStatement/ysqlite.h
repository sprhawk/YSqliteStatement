//
//  ysqlite.h
//  ysqlite
//
//  Created by YANG HONGBO on 2012-11-8.
//  Copyright (c) 2012年 YANG HONGBO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class YSqliteStatement;
@interface YSqlite : NSObject

- (id)initWithURL:(NSURL *)url;
- (BOOL)openDB;
- (void)closeDB;
- (BOOL)executeSql:(NSString *)sql;

- (YSqliteStatement *)statementWithSql:(NSString *)sql;
- (sqlite3 *)sqlite;
@end

