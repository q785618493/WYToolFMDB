//
//  WYModel.h
//  WYToolFMDB_Example
//
//  Created by macWangYuan on 2022/7/28.
//  Copyright © 2022 785618493@qq.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WYModel : NSObject

@property (copy, nonatomic) NSString *name;

@property (assign, nonatomic) BOOL judgeBool;

@property (assign, nonatomic) NSInteger age;

@property (assign, nonatomic) CGFloat height;

/* 数据时间戳 **/
@property (assign, nonatomic) int64_t msgTime;

@end

NS_ASSUME_NONNULL_END
