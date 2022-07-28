//
//  WYToolFMDB.m
//  
//
//  Created by macWangYuan on 2022/7/28.
//  Copyright © 2022
//

#import "WYToolFMDB.h"

#import <FMDB/FMDB.h>
#import <objc/runtime.h>

@interface WYToolFMDB ()

@property (nonatomic, copy)     NSString *databasePath;

@property (nonatomic, strong)   FMDatabaseQueue *databaseQueue;

@property (nonatomic, strong)   FMDatabase *database;

@end

@implementation WYToolFMDB
{
    // 保证创建sql语句时的线程安全
    dispatch_semaphore_t _sqlLock;
}

static NSString * const WYTool_primary_key  = @"WYTool_pkID";     // 主键
static NSString * const WYTool_sql_text    = @"text";          // 字符串
static NSString * const WYTool_sql_real    = @"real";          // 浮点型
static NSString * const WYTool_sql_blob    = @"blob";          // 二进制
static NSString * const WYTool_sql_integer = @"integer";       // 整型

#pragma mark - Override Methods

- (FMDatabaseQueue *)databaseQueue {
    if (!_databaseQueue) {
        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.databasePath];
        // 关闭当前数据库
        [self.database close];
        // 将FMDatabaseQueue当中的数据库替换掉当前的数据库
        self.database = [_databaseQueue valueForKey:@"_db"];
    }
    
    return _databaseQueue;
}

#pragma mark - 创建单例
+ (instancetype)shareDatabase {
    return [self shareDatabaseForName:nil path:nil];
}

+ (instancetype)shareDatabaseForName:(NSString *)dataBaseName path:(NSString *)dataBasePath {
    static dispatch_once_t onceToken;
    static WYToolFMDB *toolFMDB = nil;
    dispatch_once(&onceToken, ^{
        toolFMDB = [[WYToolFMDB alloc] init];
        
        NSString *dbName = dataBaseName ? : @"WYToolFMDB.sqlite";
        NSString *dbPath = nil;
        if (dataBasePath) {
            dbPath = [dataBasePath stringByAppendingPathComponent:dbName];
        }
        else {
            dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject] stringByAppendingPathComponent:dbName];
        }
        
        FMDatabase *dataBase = [FMDatabase databaseWithPath:dbPath];
        toolFMDB.database = dataBase;
        toolFMDB.databasePath = dbPath;
    });
    
    if (![toolFMDB.database open]) {
        [toolFMDB log:@"数据库未能打开"];
    }
    
    return toolFMDB;
}

- (instancetype)init {
    if (self = [super init]) {
        _sqlLock = dispatch_semaphore_create(1);
    }
    
    return self;
}

#pragma mark - 数据库相关属性
- (FMDatabase *)currentDatabase {
    return self.database;
}

- (NSString *)currentDatabasePath {
    return self.databasePath;
}

- (NSString *)primaryKey {
    return WYTool_primary_key;
}

#pragma mark - 根据ModelClass去创建表
- (BOOL)createTableWithModelClass:(Class)modelClass excludedProperties:(NSArray<NSString *> *)excludedProperties tableName:(NSString *)tableName {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    WYToolLock(_sqlLock);
    NSString *pkID = WYTool_primary_key;
    NSMutableString *sqliteString = [NSMutableString  stringWithFormat:@"create table if not exists %@ (%@ integer primary key", tableName, pkID];
    WYToolUnlock(_sqlLock);
    
    // 基于runtime获取model的所有属性以及类型
    NSDictionary *properties = [self getPropertiesWithModel:modelClass];
    for (NSString *key in properties) {
        if ([excludedProperties containsObject:key]) {
            continue;
        }
        
        [sqliteString appendFormat:@", %@ %@", key, properties[key]];
    }
    [sqliteString appendString:@")"];
    
    BOOL isSuccess = [self.database executeUpdate:sqliteString];
    
    return isSuccess;
}

#pragma mark - 插入
- (BOOL)insertWithModel:(id)model tableName:(NSString *)tableName {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    if (model) {
        WYToolLock(_sqlLock);
        NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"insert into %@ (", tableName];
        NSArray *columns = [self getAllColumnsFromTable:tableName dataBase:self.database isIncludingPrimaryKey:NO];
        NSMutableArray *values = [NSMutableArray array];
        for (int index = 0; index < columns.count; index++) {
            [values addObject:@"?"];
        }
        [sqliteString appendFormat:@"%@) values (%@)", [columns componentsJoinedByString:@","], [values componentsJoinedByString:@","]];
        WYToolUnlock(_sqlLock);
        
        NSArray *arguments = [self getValuesFromModel:model columns:columns];
        BOOL isSuccess = [self.database executeUpdate:sqliteString withArgumentsInArray:arguments];
        
        if (!isSuccess) {
            [self log:[NSString stringWithFormat:@"插入数据失败，错误的model = %@", model]];
        }
        
        return isSuccess;
    }
    else {
        return NO;
    }
}

- (void)insertWithModels:(NSArray *)models tableName:(NSString *)tableName {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return;
    }
    
    if (models && [models isKindOfClass:[NSArray class]] && models.count > 0) {
        // 这里实际上可以与上面的方法混合使用，但是这个样子的话，初始化sqlite语句的时候就会出现多次运算，为了效率，这里与上面的方法进行了解耦
        WYToolLock(_sqlLock);
        NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"insert into %@ (", tableName];
        
        NSArray *columns = [self getAllColumnsFromTable:tableName dataBase:self.database isIncludingPrimaryKey:NO];
        NSMutableArray *values = [NSMutableArray array];
        for (int index = 0; index < columns.count; index++) {
            [values addObject:@"?"];
        }
        [sqliteString appendFormat:@"%@) values (%@)", [columns componentsJoinedByString:@","], [values componentsJoinedByString:@","]];
        WYToolUnlock(_sqlLock);
        
        for (id model in models) {
            NSArray *arguments = [self getValuesFromModel:model columns:columns];
            
            BOOL isSuccess = [self.database executeUpdate:sqliteString withArgumentsInArray:arguments];
            if (!isSuccess) {
                [self log:[NSString stringWithFormat:@"插入数据失败，错误的model = %@", model]];
            }
        }
    }
    else {
        [self log:@"插入数据的数据源有误"];
    }
}

#pragma mark - 删除
- (BOOL)deleteFromTable:(NSString *)tableName whereParameters:(WYToolParameters *)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    WYToolLock(_sqlLock);
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"delete from %@", tableName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    
    BOOL isSuccess = [self.database executeUpdate:sqliteString];
    
    return isSuccess;
}

- (BOOL)deleteAllDataFromTable:(NSString *)tableName {
    return [self deleteFromTable:tableName whereParameters:nil];
}

#pragma mark - 更改数据
- (BOOL)updateTable:(NSString *)tableName dictionary:(NSDictionary *)dictionary whereParameters:(WYToolParameters *)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    if (dictionary.allKeys.count <= 0) {
        [self log:@"要更新的数据不能为nil"];
        return NO;
    }
    
    WYToolLock(_sqlLock);
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"update %@ set ", tableName];
    NSMutableArray *values = [NSMutableArray array];
    for (NSString *key in dictionary) {
        if ([key isEqualToString:WYTool_primary_key]) {
            continue;
        }
        
        [sqliteString appendFormat:@"%@ = ? ", key];
        [values addObject:dictionary[key]];
    }
    WYToolUnlock(_sqlLock);
    
    if (values.count > 0) {
        if (WYToolIsStringValid(parameters.whereParameters)) {
            [sqliteString appendFormat:@"where %@", parameters.whereParameters];
        }
        else {
            [self log:@"sql语句当中,where后面的参数为nil"];
            [sqliteString deleteCharactersInRange:NSMakeRange(sqliteString.length-1, 1)];
        }
        
        return [self.database executeUpdate:sqliteString withArgumentsInArray:values];
    }
    else {
        [self log:@"要更新的数据不能仅仅含有主键"];
        
        return NO;
    }
}

#pragma mark - 查询数据
- (NSArray *)queryFromTable:(NSString *)tableName model:(Class)modelClass whereParameters:(WYToolParameters *)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return nil;
    }
    
    WYToolLock(_sqlLock);
    NSMutableArray *array = [NSMutableArray array];
    
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"SELECT * FROM %@", tableName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    
    NSDictionary *properties = [self getPropertiesWithModel:modelClass];
    FMResultSet *resultSet = [self.database executeQuery:sqliteString];
    while ([resultSet next]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        for (NSString *key in properties) {
            NSString *type = properties[key];
            // 根据数据类型从数据库当中获取数据
            if ([type isEqualToString:WYTool_sql_text]) {
                // 字符串
                dict[key] = [resultSet stringForColumn:key] ? : @"";
            }
            else if ([type isEqualToString:WYTool_sql_integer]) {
                // 整型
                dict[key] = @([resultSet longLongIntForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_real]) {
                // 浮点型
                dict[key] = @([resultSet doubleForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_blob]) {
                // 二进制
                id value = [resultSet dataForColumn:key];
                if (value) {
                    dict[key] = value;
                }
            }
        }
        id objc = [[[modelClass class] alloc] init];
        objc = [self getModel:modelClass withDataDic:dict];
        [array addObject:objc];
    }
    
    return (array.count > 0 ? array : nil);
}

#pragma mark - 根据参数倒序查询表中-指定条数的数据(顺序返回)
- (NSArray *)invertedOrderQueryFromTable:(NSString * _Nonnull)tableName model:(Class _Nonnull)modelClass orderBy:(NSString *_Nonnull)orderBy limitCount:(NSInteger)limitCount whereParameters:(WYToolParameters *)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return nil;
    }
    parameters.limitCount = limitCount;
    [parameters orderByColumn:orderBy orderType:(WYToolParametersOrderTypeDesc)];
    
    WYToolLock(_sqlLock);
    NSMutableArray *array = [NSMutableArray array];
    
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"SELECT * FROM %@", tableName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    
    NSDictionary *properties = [self getPropertiesWithModel:modelClass];
    FMResultSet *resultSet = [self.database executeQuery:sqliteString];
    while ([resultSet next]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        for (NSString *key in properties) {
            NSString *type = properties[key];
            // 根据数据类型从数据库当中获取数据
            if ([type isEqualToString:WYTool_sql_text]) {
                // 字符串
                dict[key] = [resultSet stringForColumn:key] ? : @"";
            }
            else if ([type isEqualToString:WYTool_sql_integer]) {
                // 整型
                dict[key] = @([resultSet longLongIntForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_real]) {
                // 浮点型
                dict[key] = @([resultSet doubleForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_blob]) {
                // 二进制
                id value = [resultSet dataForColumn:key];
                if (value) {
                    dict[key] = value;
                }
            }
        }
        id objc = [[[modelClass class] alloc] init];
        objc = [self getModel:modelClass withDataDic:dict];
        [array addObject:objc];
    }
    NSArray *dataArray = [[array reverseObjectEnumerator] allObjects];
    return (dataArray.count > 0 ? dataArray : nil);
}

#pragma mark - (顺序返回)倒序查找指定数量数据
- (NSArray *)getDataWithCount:(NSUInteger)count withModelClass:(Class)kclass withFileName:(NSString *)fileName orderBy:(NSString *)orderBy whereParameters:(WYToolParameters *)parameters {
    
    if (!WYToolIsStringValid(fileName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return nil;
    }
    
    WYToolLock(_sqlLock);
    NSMutableArray *array = [NSMutableArray array];
    
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"select * from %@", fileName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    
    NSDictionary *properties = [self getPropertiesWithModel:kclass];
    FMResultSet *resultSet = [self.database executeQuery:[NSString stringWithFormat:@"%@ ORDER BY %@ DESC LIMIT %zd", sqliteString, orderBy, count]];
    while ([resultSet next]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        [[resultSet resultDictionary] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *type = properties[key];
            // 根据数据类型从数据库当中获取数据
            if ([type isEqualToString:WYTool_sql_text]) {
                // 字符串
                dict[key] = [resultSet stringForColumn:key] ? : @"";
            }
            else if ([type isEqualToString:WYTool_sql_integer]) {
                // 整型
                dict[key] = @([resultSet longLongIntForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_real]) {
                // 浮点型
                dict[key] = @([resultSet doubleForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_blob]) {
                // 二进制
                id value = [resultSet dataForColumn:key];
                if (value) {
                    dict[key] = value;
                }
            }
        }];
        
        //        [properties enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        //            NSString *type = properties[key];
        //            // 根据数据类型从数据库当中获取数据
        //            if ([type isEqualToString:WYTool_sql_text]) {
        //                // 字符串
        //                dict[key] = [resultSet stringForColumn:key] ? : @"";
        //            } else if ([type isEqualToString:WYTool_sql_integer]) {
        //                // 整型
        //                dict[key] = @([resultSet longLongIntForColumn:key]);
        //            } else if ([type isEqualToString:WYTool_sql_real]) {
        //                // 浮点型
        //                dict[key] = @([resultSet doubleForColumn:key]);
        //            } else if ([type isEqualToString:WYTool_sql_blob]) {
        //                // 二进制
        //                id value = [resultSet dataForColumn:key];
        //                if (value) {
        //                    dict[key] = value;
        //                }
        //            }
        //        }];
        
        //        for (NSString *key in properties) {
        //            NSString *type = properties[key];
        //            // 根据数据类型从数据库当中获取数据
        //            if ([type isEqualToString:WYTool_sql_text]) {
        //                // 字符串
        //                dict[key] = [resultSet stringForColumn:key] ? : @"";
        //            } else if ([type isEqualToString:WYTool_sql_integer]) {
        //                // 整型
        //                dict[key] = @([resultSet longLongIntForColumn:key]);
        //            } else if ([type isEqualToString:WYTool_sql_real]) {
        //                // 浮点型
        //                dict[key] = @([resultSet doubleForColumn:key]);
        //            } else if ([type isEqualToString:WYTool_sql_blob]) {
        //                // 二进制
        //                id value = [resultSet dataForColumn:key];
        //                if (value) {
        //                    dict[key] = value;
        //                }
        //            }
        //        }
        id objc = [[[kclass class] alloc] init];
        objc = [self getModel:kclass withDataDic:dict];
        [array addObject:objc];
    }
    
    NSArray *dataArray = [[array reverseObjectEnumerator] allObjects];
    
    return dataArray;
}

#pragma mark - (倒序返回)倒序查找指定数量数据
- (NSArray *)getDataReverseOrderWithCount:(NSUInteger)count withModelClass:(Class)kclass withFileName:(NSString *)fileName orderBy:(NSString *)orderBy whereParameters:(WYToolParameters *)parameters {
    
    if (!WYToolIsStringValid(fileName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return nil;
    }
    
    WYToolLock(_sqlLock);
    NSMutableArray *array = [NSMutableArray array];
    
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"select * from %@", fileName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    
    NSDictionary *properties = [self getPropertiesWithModel:kclass];
    FMResultSet *resultSet = [self.database executeQuery:[NSString stringWithFormat:@"%@ ORDER BY %@ DESC LIMIT %zd", sqliteString, orderBy, count]];
    while ([resultSet next]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        [[resultSet resultDictionary] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *type = properties[key];
            // 根据数据类型从数据库当中获取数据
            if ([type isEqualToString:WYTool_sql_text]) {
                // 字符串
                dict[key] = [resultSet stringForColumn:key] ? : @"";
            }
            else if ([type isEqualToString:WYTool_sql_integer]) {
                // 整型
                dict[key] = @([resultSet longLongIntForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_real]) {
                // 浮点型
                dict[key] = @([resultSet doubleForColumn:key]);
            }
            else if ([type isEqualToString:WYTool_sql_blob]) {
                // 二进制
                id value = [resultSet dataForColumn:key];
                if (value) {
                    dict[key] = value;
                }
            }
        }];
        
        id objc = [[[kclass class] alloc] init];
        objc = [self getModel:kclass withDataDic:dict];
        [array addObject:objc];
    }
    
    return array;
}

#pragma mark - 通过字典获取模型数据
- (id)getModel:(Class)kclass withDataDic:(NSDictionary *)kDic {
    id objc = [[[kclass class] alloc] init];
    
    unsigned int methodCount = 0;
    NSString *kvarsKey = @"";   //获取成员变量的名字
    NSString *kvarsType = @"";  //成员变量类型
    
    Ivar * ivars = class_copyIvarList([kclass class], &methodCount);
    for (NSInteger i = 0 ; i < methodCount; i ++) {
        Ivar ivar = ivars[i];
        kvarsKey = [NSString stringWithUTF8String:ivar_getName(ivar)];
        if ([kvarsKey hasPrefix:@"_"]) {
            kvarsKey = [kvarsKey stringByReplacingOccurrencesOfString:@"_" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 1)];
        }
        kvarsType = [NSString stringWithUTF8String:ivar_getTypeEncoding(ivar)];
        
        NSString *ivarValueString = [NSString stringWithFormat:@"%@",[kDic objectForKey:kvarsKey]];
        
        if (!ivarValueString) { continue; }
        
        //实例变量值
        id ivarValue = ivarValueString;
        
        /*  类型码判断
         根据当前Model的成员变量类型,来给变量赋值.
         */
        //c - char
        if ([kvarsType isEqualToString:@"c"])
            ivarValue = [NSNumber numberWithChar:[ivarValueString intValue]];
        //i - int
        else if ([kvarsType isEqualToString:@"i"])
            ivarValue = [NSNumber numberWithInt:[ivarValueString intValue]];
        //s - short
        else if ([kvarsType isEqualToString:@"s"])
            ivarValue = [NSNumber numberWithShort:[ivarValueString intValue]];
        //l - long
        else if ([kvarsType isEqualToString:@"l"])
            ivarValue = [NSNumber numberWithLong:[ivarValueString integerValue]];
        //q - long long
        else if ([kvarsType isEqualToString:@"q"])
            ivarValue = [NSNumber numberWithLongLong:[ivarValueString longLongValue]];
        //C - unsigned char
        else if ([kvarsType isEqualToString:@"C"])
            ivarValue = [NSNumber numberWithUnsignedChar:[ivarValueString intValue]];
        //I - unsigned int
        else if ([kvarsType isEqualToString:@"I"])
            ivarValue = [NSNumber numberWithUnsignedInt:[ivarValueString intValue]];
        //S - unsigned short
        else if ([kvarsType isEqualToString:@"S"])
            ivarValue = [NSNumber numberWithUnsignedShort:[ivarValueString intValue]];
        //L - unsigned long
        else if ([kvarsType isEqualToString:@"L"])
            ivarValue = [NSNumber numberWithUnsignedLong:[ivarValueString integerValue]];
        //Q - unsigned long long
        else if ([kvarsType isEqualToString:@"Q"])
            ivarValue = [NSNumber numberWithUnsignedLongLong:[ivarValueString longLongValue]];
        //f - float
        else if ([kvarsType isEqualToString:@"f"])
            ivarValue = [NSNumber numberWithFloat:[ivarValueString floatValue]];
        //d - double
        else if ([kvarsType isEqualToString:@"d"])
            ivarValue = [NSNumber numberWithDouble:[ivarValueString doubleValue]];
        //B - bool or a C99 _Bool
        else if ([kvarsType isEqualToString:@"B"]) {
            if ([ivarValueString isEqualToString:@"1"]) {
                ivarValue = [NSNumber numberWithBool:YES];
            }
            else {
                ivarValue = [NSNumber numberWithBool:NO];
            }
        }
        //v - void
        //        else if ([kvarsType isEqualToString:@"v"]) {}
        //* - char *
        //        else if ([kvarsType isEqualToString:@"*"]) {}
        //@ - id
        else if ([kvarsType isEqualToString:@"@"]) {
            ivarValue = [WYToolFMDB getIDVariableValueTypesWithString:ivarValueString];
        }
        //# - Class
        //        else if ([kvarsType isEqualToString:@"#"]) {}
        //: - SEL
        //        else if ([kvarsType isEqualToString:@":"]) {}
        //@"NSArray" - array
        else if ([kvarsType containsString:@"NSArray"]          ||
                 [kvarsType containsString:@"NSMutableArray"]   ||
                 [kvarsType containsString:@"NSDictionary"]     ||
                 [kvarsType containsString:@"NSMutableDictionary"]) {
            
            ivarValue = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithBase64EncodedString:[kDic objectForKey:kvarsKey] options:0] options:NSJSONReadingMutableLeaves error:nil];
        }
        //? - unknown type
        else {
            ivarValue = ivarValueString;
        }
        
        [objc setValue:ivarValue forKey:kvarsKey];
    }
    free(ivars);
    return objc;
}

#pragma mark - 除去增删改查之外常用的功能
- (BOOL)openDatabase {
    return [self.database open];
}

- (BOOL)closeDatabase {
    return [self.database close];
}

- (BOOL)existTable:(NSString *)tableName {
    if (WYToolIsStringValid(tableName)) {
        FMResultSet *resultSet = [self.database executeQuery:@"select count(*) as 'count' from sqlite_master where type ='table' and name = ?", tableName];
        while ([resultSet next]) {
            NSInteger count = [resultSet intForColumn:@"count"];
            return ((count == 0) ? NO : YES);
        }
        
        return NO;
    }
    else {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
}

- (BOOL)alterTable:(NSString *)tableName column:(NSString *)column type:(WYToolFMDBValueType)type {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    if (!WYToolIsStringValid(column)) {
        [self log:@"要新增的column必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    WYToolLock(_sqlLock);
    NSString *typeString = nil;
    switch (type) {
        case WYToolFMDBValueTypeString:
            typeString = WYTool_sql_text;
            break;
        case WYToolFMDBValueTypeInteger:
            typeString = WYTool_sql_integer;
            break;
        case WYToolFMDBValueTypeFloat:
            typeString = WYTool_sql_real;
            break;
        case WYToolFMDBValueTypeData:
            typeString = WYTool_sql_blob;
            break;
        default:
            typeString = @"";
            break;
    }
    NSString *sqliteString = [NSString stringWithFormat:@"alter table %@ add column %@ %@", tableName, column, typeString];
    WYToolUnlock(_sqlLock);
    
    return [self.database executeUpdate:sqliteString];
}

- (BOOL)dropTable:(NSString *)tableName {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return NO;
    }
    
    WYToolLock(_sqlLock);
    NSString *sqliteString = [NSString stringWithFormat:@"drop table %@", tableName];
    WYToolUnlock(_sqlLock);
    
    return [self.database executeUpdate:sqliteString];
}

- (NSArray<NSString *> *)getAllColumnsFromTable:(NSString *)tableName {
    return [self getAllColumnsFromTable:tableName dataBase:self.database isIncludingPrimaryKey:YES];
}

- (long long int)numberOfItemsFromTable:(NSString *)tableName whereParameters:(WYToolParameters * _Nullable)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
    }
    
    WYToolLock(_sqlLock);
    NSMutableString *sqliteString = [NSMutableString stringWithFormat:@"select count(*) as 'count' from %@", tableName];
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    FMResultSet *resultSet = [self.database executeQuery:sqliteString];
    while ([resultSet next]) {
        return [resultSet longLongIntForColumn:@"count"];
    }
    
    return 0;
}

- (double)numberWithMathType:(WYToolFMDBMathType)type table:(NSString *)tableName column:(NSString *)column whereParameters:(WYToolParameters *)parameters {
    if (!WYToolIsStringValid(tableName)) {
        [self log:@"tableName必须是字符串，且不能为nil"];
        
        return 0.0;
    }
    
    if (!WYToolIsStringValid(column)) {
        [self log:@"要新增的column必须是字符串，且不能为nil"];
        
        return 0.0;
    }
    
    WYToolLock(_sqlLock);
    NSMutableString *sqliteString = nil;
    NSString *operation = nil;
    switch (type) {
        case WYToolFMDBMathTypeSum:
            operation = @"sum";
            break;
        case WYToolFMDBMathTypeAvg:
            operation = @"avg";
            break;
        case WYToolFMDBMathTypeMax:
            operation = @"max";
            break;
        case WYToolFMDBMathTypeMin:
            operation = @"min";
            break;
        default:
            break;
    }
    if (WYToolIsStringValid(operation)) {
        sqliteString = [NSMutableString stringWithFormat:@"select %@(%@) %@Count from %@", operation, column, operation, tableName];
    }
    else {
        [self log:@"不支持当前运算"];
    }
    
    if (parameters && WYToolIsStringValid(parameters.whereParameters)) {
        [sqliteString appendFormat:@" where %@", parameters.whereParameters];
    }
    WYToolUnlock(_sqlLock);
    FMResultSet *resultSet = [self.database executeQuery:sqliteString];
    double value = 0.0;
    while ([resultSet next]) {
        value = [resultSet doubleForColumn:[NSString stringWithFormat:@"%@Count", operation]];
    }
    
    return value;
}

#pragma mark - 线程安全操作
- (void)inDatabase:(dispatch_block_t)block {
    [self.databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if (block) {
            block();
        }
    }];
}

- (void)inTransaction:(void (^)(BOOL *))block {
    [self.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        if (block) {
            block(rollback);
        }
    }];
}

#pragma mark - 数据库相关操作
// 获取数据库里的所有元素
- (NSArray<NSString *> *)getAllColumnsFromTable:(NSString *)tableName dataBase:(FMDatabase *)dataBase isIncludingPrimaryKey:(BOOL)isIncluding {
    NSMutableArray *columns = [NSMutableArray array];
    
    FMResultSet *resultSet = [dataBase getTableSchema:tableName];
    while ([resultSet next]) {
        NSString *columnName = [resultSet stringForColumn:@"name"];
        if ([columnName isEqualToString:WYTool_primary_key] && !isIncluding) {
            continue;
        }
        [columns addObject:columnName];
    }
    
    return columns;
}

#pragma mark - Private Method

/**
 *  基于runtime获取model的所有属性以及类型
 *  根据传入的ModelClass去获取所有的属性的key以及类型type，返回值的字典的key就是modelClass的属性，value就是modelClass的属性对应的type
 */
- (NSDictionary *)getPropertiesWithModel:(Class)modelClass {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList(modelClass, &count);
    for (int index = 0; index < count; index++) {
        objc_property_t property = propertyList[index];
        NSString *key = [NSString stringWithFormat:@"%s", property_getName(property)];
        NSString *type = nil;
        NSString *attributes = [NSString stringWithFormat:@"%s", property_getAttributes(property)];
        
        if ([attributes hasPrefix:@"T@\"NSString\""]) {
            type = WYTool_sql_text;
        }
        else if ([attributes hasPrefix:@"Tf"] || [attributes hasPrefix:@"Td"]) {
            type = WYTool_sql_real;
        }
        else if ([attributes hasPrefix:@"T@\"NSData\""]) {
            type = WYTool_sql_blob;
        }
        else if ([attributes hasPrefix:@"Ti"] || [attributes hasPrefix:@"TI"] || [attributes hasPrefix:@"Tl"] || [attributes hasPrefix:@"TL"] || [attributes hasPrefix:@"Tq"] || [attributes hasPrefix:@"TQ"] || [attributes hasPrefix:@"Ts"] || [attributes hasPrefix:@"TS"] || [attributes hasPrefix:@"TB"] || [attributes hasPrefix:@"T@\"NSNumber\""]) {
            type = WYTool_sql_integer;
        }
        
        if (type) {
            [dict setObject:type forKey:key];
        }
        else {
            [self log:[NSString stringWithFormat:@"不支持的属性:key = %@, attributes = %@", key, attributes]];
        }
    }
    
    free(propertyList);
    
    return dict;
}

// 根据keys获取到model里面的所有values
- (NSArray *)getValuesFromModel:(id _Nonnull)model columns:(NSArray *)columns {
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *column in columns) {
        id value = [model valueForKey:column];
        [array addObject:value ? : @""];
    }
    
    return array;
}

BOOL WYToolIsStringValid(id object) {
    return [object isKindOfClass:[NSString class]] && ((NSString*)object).length > 0;
}

// 加锁
void WYToolLock(dispatch_semaphore_t semaphore) {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

// 解锁
void WYToolUnlock(dispatch_semaphore_t semaphore) {
    dispatch_semaphore_signal(semaphore);
}

// 打印log
- (void)log:(NSString *)string {
    if (self.shouldOpenDebugLog) {
        NSLog(@"%@", string);
    }
}

/// id数据 转 json
+ (NSString *)nativeDataParseJson:(id)obj {
    if ([obj isKindOfClass:[NSNull class]] || !obj) {
        return @"obj数据类型错误 或者 obj为nil";
    }
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:&parseError];
    if (parseError) {
        return @"obj数据解析错误";
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

/// json 转 id数据
+ (id)nativeDataWithJsonString:(NSString *)jsonString {
    if (![jsonString isKindOfClass:[NSString class]] || 0 == jsonString.length) {
        NSLog(@" JSON串数据类型错误 或者 JSON串为空 ");
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
    
    if (err) {
        NSLog(@"json解析失败Error == %@", err.localizedDescription);
        return nil;
    }
    return obj;
}

//根据存储的信息转为对应的变量类型
+ (id)getIDVariableValueTypesWithString:(NSString *)string {
    NSString *idValueType = [[string componentsSeparatedByString:@":"] lastObject];
    NSString *idValue = [string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@":%@",idValueType] withString:@""];
    
    if ([idValueType isEqualToString:@"NSNumber"]) {
        return [NSNumber numberWithInteger:[idValue integerValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberChar"]) {
        return [NSNumber numberWithChar:[idValue intValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberFloat"]) {
        return [NSNumber numberWithFloat:[idValue floatValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberDouble"]) {
        return [NSNumber numberWithDouble:[idValue doubleValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberShort"]) {
        return [NSNumber numberWithShort:[idValue intValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberInt"]) {
        return [NSNumber numberWithInt:[idValue intValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberLong"]) {
        return [NSNumber numberWithLong:[idValue integerValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberLongLong"]) {
        return [NSNumber numberWithLongLong:[idValue longLongValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberNSInteger"]) {
        return [NSNumber numberWithInteger:[idValue integerValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberNSUInteger"]) {
        return [NSNumber numberWithUnsignedInteger:[idValue longLongValue]];
    }
    else if ([idValueType isEqualToString:@"NSNumberBOOL"]) {
        return [NSNumber numberWithBool:[idValue boolValue]];
    }
    else if ([idValueType isEqualToString:@"UIView"]) {
        return NSClassFromString(idValue);
    }
    else if ([idValueType isEqualToString:@"NSString"]) {
        return idValue;
    }
    return @"";
}


//根据id变量类型转化为对应string以供存储
+ (NSString *)setIDVariableToString:(id)varialeValue {
    //NSString类型
    if ([varialeValue isKindOfClass:[NSString class]]) {
        return varialeValue?[NSString stringWithFormat:@"%@:NSString",varialeValue]:@"";
    }
    //BOOL类型
    else if ([[NSString stringWithFormat:@"%@",[varialeValue class]] isEqualToString:@"__NSCFBoolean"]) {
        return varialeValue?[NSString stringWithFormat:@"%@:NSNumberBOOL",varialeValue]:@"";
    }
    //NSSNumber类型
    else if ([varialeValue isKindOfClass:[NSNumber class]]) {
        
        NSString *memberValueType = @":NSNumber";
        
        if (strcmp([varialeValue objCType], @encode(char)) == 0 ||
            strcmp([varialeValue objCType], @encode(unsigned char)) == 0) {
            memberValueType = @":NSNumberChar";
        }
        else if (strcmp([varialeValue objCType], @encode(short)) == 0 ||
                 strcmp([varialeValue objCType], @encode(unsigned short)) == 0) {
            memberValueType = @":NSNumberShort";
        }
        else if (strcmp([varialeValue objCType], @encode(int)) == 0 ||
                 strcmp([varialeValue objCType], @encode(unsigned int)) == 0) {
            memberValueType = @":NSNumberInt";
        }
        else if (strcmp([varialeValue objCType], @encode(long)) == 0 ||
                 strcmp([varialeValue objCType], @encode(unsigned long)) == 0) {
            memberValueType = @":NSNumberLong";
        }
        else if (strcmp([varialeValue objCType], @encode(long long)) == 0 ||
                 strcmp([varialeValue objCType], @encode(unsigned long long)) == 0) {
            memberValueType = @":NSNumberLongLong";
        }
        else if (strcmp([varialeValue objCType], @encode(float)) == 0) {
            memberValueType = @":NSNumberFloat";
        }
        else if (strcmp([varialeValue objCType], @encode(double)) == 0) {
            memberValueType = @":NSNumberDouble";
        }
        else if (strcmp([varialeValue objCType], @encode(NSInteger)) == 0) {
            memberValueType = @":NSNumberNSInteger";
        }
        else if (strcmp([varialeValue objCType], @encode(NSUInteger)) == 0) {
            memberValueType = @":NSNumberNSUInteger";
        }
        
        return varialeValue?[NSString stringWithFormat:@"%@%@",varialeValue,memberValueType]:@"";
    }
    //UIView类型
    else if ([[varialeValue class] isSubclassOfClass:[UIView class]] || [[varialeValue class] isKindOfClass:[UIView class]]) {
        return varialeValue?[NSString stringWithFormat:@"%@:UIView",varialeValue]:@"";
    }
    
    return varialeValue?[NSString stringWithFormat:@"%@:id",varialeValue]:@"";
}

#pragma mark - 删除本地文件
+ (void)imRemoveLocalFilePath:(NSString *)filePath {
    NSError *error;
    BOOL judge = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    if (judge && !error) {
        NSLog(@" 本地聊天记录文件--删除成功 ");
    }
    else {
        NSLog(@" 删除失败--本地聊天记录文件 ");
    }
}

@end
