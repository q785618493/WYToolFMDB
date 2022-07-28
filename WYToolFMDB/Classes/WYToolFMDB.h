//
//  WYToolFMDB.h
//  
//
//  Created by macWangYuan on 2022/7/28.
//  Copyright © 2022 孙超
//

#import <UIKit/UIKit.h>

#import "WYToolParameters.h"


@class FMDatabase;

@class WYToolFMDB;

// 数据库支持的类型(如果不满足条件以下条件，那么在后续会增加)
typedef NS_ENUM(NSUInteger, WYToolFMDBValueType) {
    WYToolFMDBValueTypeString,     // 字符串
    WYToolFMDBValueTypeInteger,    // 整型，长整型，bool值也可以作为integer
    WYToolFMDBValueTypeFloat,      // 浮点型,double
    WYToolFMDBValueTypeData,       // 二进制数据
};

// 数学运算的类型
typedef NS_ENUM(NSUInteger, WYToolFMDBMathType) {
    WYToolFMDBMathTypeSum,         // 总和
    WYToolFMDBMathTypeAvg,         // 平均值
    WYToolFMDBMathTypeMax,         // 最大值
    WYToolFMDBMathTypeMin,         // 最小值
};

NS_ASSUME_NONNULL_BEGIN

@interface WYToolFMDB : NSObject

#pragma mark - 创建单例
/**
 *  此2个方法是通过单例来创建数据库，路径默认是在NSDocumentDirectory()，名称为WYToolFMDB.sqlite，此2个方法是一个单例方法，为此，只要使用任何一个创建成功之后，返回值都是同一个实例对象
 *  推荐使用@selector(shareDatabase)
 dataBaseName 数据库的名称，比如可以设置为"Project.sqlite",也可以设置为nil。但是，如果dataBaseName == nil，那么数据库的名称就会默认是WYToolFMDB.sqlite
 dataBasePath 数据库的文件夹路径，如果dataBasePath == nil,那么默认就是NSDocumentDirectory()
 *  @return 返回当前的单例对象
 */
+ (instancetype)shareDatabase;
+ (instancetype)shareDatabaseForName:(NSString * _Nullable)dataBaseName path:(NSString * _Nullable)dataBasePath;

#pragma mark - 数据库相关属性

/**
 *  当前的数据库
 */
@property (nonatomic, readonly, copy)   FMDatabase *currentDatabase;

/**
 *  当前的数据库所在路径
 */
@property (nonatomic, readonly, copy)   NSString *currentDatabasePath;

/**
 *  获取到数据库中的主键的key，返回"WYTool_pkID",在配置WYToolParameters时可能会用到
 */
@property (nonatomic, readonly, copy)   NSString *primaryKey;

#pragma mark - 是否打印log
/**
 *  是否打印log，默认是NO
 */
@property (nonatomic, assign) BOOL shouldOpenDebugLog;

#pragma mark - 根据ModelClass去创建表

/**
 *  根据传入的Model去创建表(推荐使用此方法) 表名必须字母在前数字在后
 *  @param modelClass 根据传入的Model的class去创建表，其中表名就是model的类名。
 同时，model里面的属性名称就作为表的key值,属性的value的类型也就是表里面的value的类型，如value可以是NSString，integer，float，bool等，详情请参考WYToolFMDBValueType
 *  @param excludedProperties 被排除掉属性，这些属性被排除掉之后则不会存在数据库当中
 *  @param tableName    表名，不可以为nil
 *  @return 是否创建成功
 */
- (BOOL)createTableWithModelClass:(Class _Nonnull)modelClass excludedProperties:(NSArray<NSString *> * _Nullable)excludedProperties tableName:(NSString * _Nonnull)tableName;

#pragma mark - 插入数据

/**
 *  插入一条数据（推荐使用）
 *  @param model        需要插入Model
 *  @param tableName    表名，不可以为nil
 *  @return             是否插入成功
 */
- (BOOL)insertWithModel:(id _Nonnull)model tableName:(NSString * _Nonnull)tableName;

/**
 *  插入多条数据
 *  @param models       需要插入的存放Model的数组。其中必须要保证数组内的Model都是同一类型的Model
 *  @param tableName    表名，不可以为nil
 *  在连续插入多条数据的时候，很有可能会出现插入不成功的情况，如果想要联调，请将shouldOpenDebugLog设为YES
 */
- (void)insertWithModels:(NSArray *)models tableName:(NSString * _Nonnull)tableName;

#pragma mark - 删除数据

/**
 *  根据参数删除表中的数据
 *  @param tableName    表的名字。如果是自定义的表名，那么就传入自定义的表名，如果未自定义，那么传入model的类名，如NSStringFromClass([Model class]).不可以为nil
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类.
 *  如果parameters = nil，或者parameters仅仅是一个实例对象，而没有执行WYToolParameters的方法进行参数配置，那么parameters.whereParameters就会不存在默认删除数据
 *  @return 是否删除成功
 */
- (BOOL)deleteFromTable:(NSString * _Nonnull)tableName whereParameters:(WYToolParameters *)parameters;

/**
 *  删除所有数据
 *  @param tableName    同上
 *  @return             同上
 */
- (BOOL)deleteAllDataFromTable:(NSString * _Nonnull)tableName;

#pragma mark - 更改数据

/**
 *  根据参数更新表中的数据
 *  @param tableName    表的名字,不可以为nil
 *  @param dictionary   要更新的key-value.在我经验来看，更改数据只是更新部分数据，而不是全部，所以这里使用的是字典，而不是传入的model,而且这样还会增加效率
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类
 */
- (BOOL)updateTable:(NSString * _Nonnull)tableName dictionary:(NSDictionary * _Nonnull)dictionary whereParameters:(WYToolParameters *)parameters;

#pragma mark - 查询数据
/**
 *  根据参数查询表中的数据
 *  @param tableName    表的名字,不可以为nil
 *  @param modelClass   modelClass里面的属性名称就作为表的key值,属性的value的类型也就是表里面的value的类型，如value可以是NSString，integer，float，bool等，详情请参考WYToolFMDBValueType
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类
 *  @return             返回所有符合条件的数据
 */
- (NSArray *)queryFromTable:(NSString * _Nonnull)tableName model:(Class _Nonnull)modelClass whereParameters:(WYToolParameters *)parameters;

/**
 *  根据参数倒序查询表中-指定条数的数据(顺序返回)
 *  @param tableName    表的名字,不可以为nil
 *  @param modelClass   modelClass里面的属性名称就作为表的key值,属性的value的类型也就是表里面的value的类型，如value可以是NSString，integer，float，bool等，详情请参考WYToolFMDBValueType
 *  @param orderBy     排序条件(model的属性名称)
 *  @param limitCount     limitCount数据条数
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类
 *  @return             返回所有符合条件的数据
 */
- (NSArray *)invertedOrderQueryFromTable:(NSString * _Nonnull)tableName model:(Class _Nonnull)modelClass orderBy:(NSString *_Nonnull)orderBy limitCount:(NSInteger)limitCount whereParameters:(WYToolParameters *)parameters;

/**
 *  (顺序返回)倒序查找指定数量数据
 *  @param count        数据条数
 *  @param kclass   modelClass里面的属性名称就作为表的key值,属性的value的类型也就是表里面的value的类型，如value可以是NSString，integer，float，bool等，详情请参考WYToolFMDBValueType
 *  @param fileName    表的名字,不可以为nil
 *  @param orderBy     排序条件(model的属性名称)
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类
 *  @return             返回所有符合条件的数据
 */
- (NSArray *)getDataWithCount:(NSUInteger)count withModelClass:(Class _Nonnull)kclass withFileName:(NSString *_Nonnull)fileName orderBy:(NSString *_Nonnull)orderBy whereParameters:(WYToolParameters *_Nonnull)parameters;

/**
 *  (倒序返回)倒序查找指定数量数据
 *  @param count        数据条数
 *  @param kclass   modelClass里面的属性名称就作为表的key值,属性的value的类型也就是表里面的value的类型，如value可以是NSString，integer，float，bool等，详情请参考WYToolFMDBValueType
 *  @param fileName    表的名字,不可以为nil
 *  @param orderBy     排序条件(model的属性名称)
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类
 *  @return             返回所有符合条件的数据
 */
- (NSArray *)getDataReverseOrderWithCount:(NSUInteger)count withModelClass:(Class _Nonnull)kclass withFileName:(NSString *_Nonnull)fileName orderBy:(NSString *_Nonnull)orderBy whereParameters:(WYToolParameters *_Nonnull)parameters;

#pragma mark - 除去增删改查之外常用的功能

/**
 *  打开数据库
 */
- (BOOL)openDatabase;

/**
 *  关闭数据库
 */
- (BOOL)closeDatabase;

/**
 *  表是否存在
 *  @param tableName    表的名字
 *  @return             表是否存在
 */
- (BOOL)existTable:(NSString * _Nonnull)tableName;

/**
 *  为一个表增加字段
 *  @param tableName    表的名字
 *  @param column       要增加的字段
 *  @param type         增加的字段类型
 *  @return             是否添加成功
 */
- (BOOL)alterTable:(NSString * _Nonnull)tableName column:(NSString * _Nonnull)column type:(WYToolFMDBValueType)type;

/**
 *  删除一张表
 *  @param tableName    表的名字
 *  @return             是否删除成功
 */
- (BOOL)dropTable:(NSString * _Nonnull)tableName;

/**
 *  获取某一个表中所有的字段名
 *  @param tableName    表的名字
 *  @return             所有字段名
 */
- (NSArray<NSString *> *)getAllColumnsFromTable:(NSString * _Nonnull)tableName;

/**
 *  获取表中有多少条数据
 *  @param tableName    表的名字
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类.如果parameters = nil，或者parameters.whereParameters为空，那么就是获得列表中所有的数据个数
 *  @return             数据的个数
 */
- (long long int)numberOfItemsFromTable:(NSString * _Nonnull)tableName whereParameters:(WYToolParameters * _Nullable)parameters;

/**
 *  数学相关操作
 *  @param type         数学运算的type，决定如何运算,请参考WYToolFMDBMathType枚举
 *  @param tableName    表的名字
 *  @param parameters   参数，WYToolParameters决定了sql语句"where"后面的参数。具体用法参考WYToolParameters类.如果parameters = nil，或者parameters.whereParameters为空，那么默认是列表中所有符合条件的数据
 *  @return             计算的值
 */
- (double)numberWithMathType:(WYToolFMDBMathType)type table:(NSString * _Nonnull)tableName column:(NSString * _Nonnull)column whereParameters:(WYToolParameters * _Nullable)parameters;

#pragma mark - 线程安全操作

// FMDB所提供的接口并不是线程安全的，而在使用过程当中，为了线程安全的操作，必须要与队列相关联才行。使用以下两个方法可以是的线程安全

/**
 *  线程队列的使用
 *  @param block    block，将数据库操作放到block里执行可以保证线程安全
 */
- (void)inDatabase:(dispatch_block_t)block;

/**
 *  事务的使用
 *  @param block    block，将数据库操作放到block里执行可以保证线程安全
 */
- (void)inTransaction:(void(^)(BOOL *rollback))block;

/// id数据 转 json串
+ (NSString *)nativeDataParseJson:(id _Nonnull)obj;

/// json串 转 id数据
+ (id)nativeDataWithJsonString:(NSString *_Nonnull)jsonString;

/// 根据存储的信息转为对应的变量类型
+ (id)getIDVariableValueTypesWithString:(NSString *_Nonnull)string;

/// 根据id变量类型转化为对应string以供存储
+ (NSString *)setIDVariableToString:(id _Nonnull)value;

/* 删除本地文件 **/
+ (void)imRemoveLocalFilePath:(NSString *)filePath;


@end

NS_ASSUME_NONNULL_END
