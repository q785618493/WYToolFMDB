//
//  WYToolParameters.m
// 
//
//  Created by macWangYuan on 2022/7/28.
//  Copyright © 2022 
//

#import "WYToolParameters.h"

@interface WYToolParameters ()

// and参数
@property (strong, nonatomic) NSMutableArray <NSString *> *andParameters;

// or参数
@property (strong, nonatomic) NSMutableArray <NSString *> *orParameters;

/// 排序语句
@property (copy, nonatomic)   NSString *orderString;

@end

@implementation WYToolParameters

#pragma mark - Override Methods
- (NSMutableArray<NSString *> *)andParameters {
    if (!_andParameters) {
        _andParameters = [NSMutableArray array];
    }
    
    return _andParameters;
}

- (NSMutableArray<NSString *> *)orParameters {
    if (!_orParameters) {
        _orParameters = [NSMutableArray array];
    }
    
    return _orParameters;
}

- (NSString *)whereParameters {
    if (_whereParameters) {
        return _whereParameters;
    }
    else {
        NSMutableString *string = [NSMutableString string];
        NSString *andString = [self.andParameters componentsJoinedByString:@" and "];
        NSString *orString  = [self.orParameters componentsJoinedByString:@" or "];
        if (andString && andString.length > 0) {
            [string appendFormat:@"%@", andString];
        }
        
        if (orString && orString.length > 0) {
            [string appendFormat:@"%@%@", (string.length > 0 ? @" or " : @""), orString];
        }
        
        if (self.orderString) {
            [string appendFormat:@" %@", self.orderString];
        }
        
        if (self.limitCount > 0) {
            [string appendFormat:@" limit %ld", (long)self.limitCount];
        }
        
        return (NSString *)(string.length > 0 ? string : nil);
    }
}

#pragma mark - 配置参数
- (void)andWhere:(NSString *)column value:(id)value relationType:(WYToolParametersRelationType)relationType {
    NSString *string = nil;
    switch (relationType) {
        case WYToolParametersRelationTypeEqualTo:
            string = [NSString stringWithFormat:@"%@ = %@", column, value];
            break;
        case WYToolParametersRelationTypeUnequalTo:
            string = [NSString stringWithFormat:@"%@ != %@", column, value];
            break;
        case WYToolParametersRelationTypeGreaterThan:
            string = [NSString stringWithFormat:@"%@ > %@", column, value];
            break;
        case WYToolParametersRelationTypeGreaterThanOrEqualTo:
            string = [NSString stringWithFormat:@"%@ >= %@", column, value];
            break;
        case WYToolParametersRelationTypeLessThan:
            string = [NSString stringWithFormat:@"%@ < %@", column, value];
            break;
        case WYToolParametersRelationTypeLessThanOrEqualTo:
            string = [NSString stringWithFormat:@"%@ <= %@", column, value];
            break;
        case WYToolParametersRelationTypeLike:
            string = [NSString stringWithFormat:@"%@ like '%@'", column, value];
            break;
        case WYToolParametersRelationTypeContains:
            string = [NSString stringWithFormat:@"%@ like '%%%@%%'", column, value];
            break;
        default:
            break;
    }
    if (string) {
        [self.andParameters addObject:string];
    }
}

- (void)orWhere:(NSString *)column value:(id)value relationType:(WYToolParametersRelationType)relationType {
    NSString *string = nil;
    switch (relationType) {
        case WYToolParametersRelationTypeEqualTo:
            string = [NSString stringWithFormat:@"%@ = %@", column, value];
            break;
        case WYToolParametersRelationTypeUnequalTo:
            string = [NSString stringWithFormat:@"%@ != %@", column, value];
            break;
        case WYToolParametersRelationTypeGreaterThan:
            string = [NSString stringWithFormat:@"%@ > %@", column, value];
            break;
        case WYToolParametersRelationTypeGreaterThanOrEqualTo:
            string = [NSString stringWithFormat:@"%@ >= %@", column, value];
            break;
        case WYToolParametersRelationTypeLessThan:
            string = [NSString stringWithFormat:@"%@ < %@", column, value];
            break;
        case WYToolParametersRelationTypeLessThanOrEqualTo:
            string = [NSString stringWithFormat:@"%@ <= %@", column, value];
            break;
        default:
            break;
    }
    if (string) {
        [self.orParameters addObject:string];
    }
}

- (void)orderByColumn:(NSString *)column orderType:(WYToolParametersOrderType)orderType {
    if (orderType == WYToolParametersOrderTypeAsc) {
        self.orderString = [NSString stringWithFormat:@"order by %@ asc", column];
    }
    else if (orderType == WYToolParametersOrderTypeDesc) {
        self.orderString = [NSString stringWithFormat:@"order by %@ desc", column];
    }
}

@end
