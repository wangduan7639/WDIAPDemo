//
//  WDIAPManager.h
//  WDIAPDemo
//
//  Created by wd on 2017/6/13.
//  Copyright © 2017年 wd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#define kErrorDomain @"www.wd.IAP"

typedef NS_ENUM(NSInteger, WDIAPErrorCodeType){
    WDIAPErrorCodeType_QueryFailure = 0,        //苹果返回查询失败
    WDIAPErrorCodeType_UnablePay ,              //用户禁止应用内付费购买
    WDIAPErrorCodeType_EmptyProduceList,        //付费商品列表为空
    WDIAPErrorCodeType_NoExistProduce,          //商店不存在此商品
    WDIAPErrorCodeType_BugFailure,              //购买失败。
    WDIAPErrorCodeType_UserCancel               //用户取消交易
};

@protocol WDIAPManagerDelegate;
@interface WDIAPManager : NSObject

@property (nonatomic, weak) id<WDIAPManagerDelegate> delegate;
/**
  单例
 */
+ (WDIAPManager *)sharedManager;

/**
  启动manager
 */
- (void)launchManager;

/**
 停止manager
 */
- (void)stopManager;

/**
 请求商品并购买
 */
- (void)wd_requestProductWithId:(NSString *)productId;

@end


@protocol WDIAPManagerDelegate <NSObject>

/**
 购买失败回调
 */
- (void)wd_buyFailedWithErrorCode:(NSInteger)errorCode andError:(NSError *)error;
/**
 购买成功回调  date为自己服务器向苹果服务器校验成功后返回给客户端的数据，
 */
- (void)wd_buySuccessWithResponseData:(id)data;
@end
