//
//  WYViewController.m
//  WYToolFMDB
//
//  Created by 785618493@qq.com on 07/28/2022.
//  Copyright (c) 2022 785618493@qq.com. All rights reserved.
//

#import "WYViewController.h"

#import "WYToolFMDB.h"

@interface WYViewController ()

@end

@implementation WYViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self createView];
}

- (void)createView {
    self.title = @"WYToolFMDB";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
