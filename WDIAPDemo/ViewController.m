//
//  ViewController.m
//  WDIAPDemo
//
//  Created by wd on 2017/6/13.
//  Copyright © 2017年 wd. All rights reserved.
//

#import "ViewController.h"
#import "WDIAPManager.h"

@interface ViewController ()<WDIAPManagerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [WDIAPManager sharedManager].delegate = self;
    //自己的商品id
    [[WDIAPManager sharedManager] wd_requestProductWithId:@"com.wd.....xxxxx"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark WDIAPManagerDelegate
- (void)wd_buyFailedWithErrorCode:(NSInteger)errorCode andError:(NSError *)error {
    
}

- (void)wd_buySuccessWithResponseData:(id)data {
    
}

@end
