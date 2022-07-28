//
//  WYViewController.m
//  WYToolFMDB
//
//  Created by 785618493@qq.com on 07/28/2022.
//  Copyright (c) 2022 785618493@qq.com. All rights reserved.
//

#import "WYViewController.h"

#ifdef DEBUG //调试阶段

#define ZDY_LOG(FORMAT, ...) fprintf(stderr, "   %s     %d \n%s \n",[[[NSString stringWithUTF8String:__FILE__]lastPathComponent]UTF8String],__LINE__,[[NSString stringWithFormat:FORMAT,##__VA_ARGS__]UTF8String]);

#else //发布阶段

#define ZDY_LOG(...)

#endif


#import "WYToolFMDB.h"

#import "WYModel.h"

@interface WYViewController ()

@property (weak, nonatomic) IBOutlet UILabel *showSaveLabel;

@property (weak, nonatomic) IBOutlet UILabel *showGetLabel;

@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@property (weak, nonatomic) IBOutlet UIButton *getButton;

/* 数据库 **/
@property (strong, nonatomic) WYToolFMDB *toolFmdb;

/* 创建的表名(规则为:大小写字母 和 数字) **/
@property (copy, nonatomic) NSString *tableName;

@end

@implementation WYViewController

- (WYToolFMDB *)toolFmdb {
    if (!_toolFmdb) {
        _toolFmdb = [WYToolFMDB shareDatabase];
    }
    return _toolFmdb;
}

/* 创建的表名 (规则为: 大小写字母) **/
- (NSString *)tableName {
    if (!_tableName) {
        _tableName = @"PersonInfo";
    }
    return _tableName;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self createView];
}

- (void)createView {
    self.title = @"WYToolFMDB";
    
    // 判断本地是否存在表名为 self.tableName 的表
    if (![self.toolFmdb existTable:self.tableName]) {
        BOOL judge = [self.toolFmdb createTableWithModelClass:[WYModel class] excludedProperties:nil tableName:self.tableName];
        if (judge) {
            ZDY_LOG(@" 成功创建表 ");
        }
        else {
            ZDY_LOG(@" 创建表失败 ");
        }
    }
    else {
        ZDY_LOG(@" 本地存在表名为 == %@ ", self.tableName);
    }
}

#pragma mark - Button Action
- (IBAction)buttonTouchActionSave:(UIButton *)sender {
    WYModel *model = [[WYModel alloc] init];
    model.name = [WYViewController produceRandomStringEighteenth];
    model.judgeBool = true;
    model.age = arc4random() % 100;
    model.height = 188.28;
    model.msgTime = [WYViewController getThisMachineTheTimeStamp];
    BOOL judge = [self.toolFmdb insertWithModel:model tableName:self.tableName];
    
    NSString *string = @"结果";
    if (judge) {
        string = @" 存储成功 -- 新建Model ";
    }
    else {
        string = @" 新建Model == 存储失败 ";
    }
    self.showSaveLabel.text = string;
    ZDY_LOG(@" %@ ", string);
}

- (IBAction)buttonTouchActionGet:(UIButton *)sender {
    WYToolParameters *par = [[WYToolParameters alloc] init];
    
    [par andWhere:@"judgeBool" value:@"1" relationType:WYToolParametersRelationTypeEqualTo];
    
    /* 排序 生效必须设置1个 and(&&，与)操作 andWhere:  或者 or(||，或)操作 orWhere:**/
    [par orderByColumn:@"msgTime" orderType:(WYToolParametersOrderTypeDesc)];
    
    NSArray *dbArray = [self.toolFmdb queryFromTable:self.tableName model:[WYModel class] whereParameters:par];
    
    if (dbArray.count) {
        self.showGetLabel.text = [NSString stringWithFormat:@"本地有%zd条数据", dbArray.count];
    }
    else {
        self.showGetLabel.text = @"暂无数据请先保存一条数据";
    }
}

#pragma mark - 产生随机18位字符串(数字，大小写字母)
+ (NSString *)produceRandomStringEighteenth {
    static NSInteger kNumber = 18;
    NSString *sourceStr = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    NSMutableString *resultStr = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < kNumber; i ++) {
        NSInteger index = arc4random() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }
    return resultStr;
}

#pragma mark - 13位当前时间戳
+ (NSInteger)getThisMachineTheTimeStamp {
    NSUInteger dateInt = [[NSDate date] timeIntervalSince1970] * 1000;
    return dateInt;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
