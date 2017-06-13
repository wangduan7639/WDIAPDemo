//
//  WDIAPManager.m
//  WDIAPDemo
//
//  Created by wd on 2017/6/13.
//  Copyright © 2017年 wd. All rights reserved.
//

#import "WDIAPManager.h"

@interface WDIAPManager ()<SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, assign) BOOL requestFinished; //请求是否完成
@property (nonatomic, copy) NSString *receipt; //交易成功后拿到的一个base64编码字符串

@end

@implementation WDIAPManager

+ (WDIAPManager *)sharedManager {
    static WDIAPManager * manager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)launchManager {
    dispatch_queue_t iap_as_queue = dispatch_queue_create("com.wdiap.queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(iap_as_queue, ^{
        self.requestFinished = YES;
        //设置监听
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
    });
}

- (void)stopManager {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    });
}

- (void)wd_requestProductWithId:(NSString *)productId {
    if (self.requestFinished) {
        if ([SKPaymentQueue canMakePayments]) { //用户允许app内购
            if (productId.length) {
                self.requestFinished = NO; //正在请求
                NSArray *product = [[NSArray alloc] initWithObjects:productId, nil];
                NSSet *set = [NSSet setWithArray:product];
                SKProductsRequest *productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
                productRequest.delegate = self;
                [productRequest start];
                
            } else {
                //商品为空
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"AppStore不存在此商品" forKey:NSLocalizedDescriptionKey];

                [self failedWithErrorCode:WDIAPErrorCodeType_NoExistProduce error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
                self.requestFinished = YES; //完成请求
            }
            
        } else { //用户不允许app内购
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"用户不允许APP内购" forKey:NSLocalizedDescriptionKey];
            [self failedWithErrorCode:WDIAPErrorCodeType_UnablePay error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
            
            self.requestFinished = YES; //完成请求
        }
        
    } else {
        
        NSLog(@"上次请求还未完成，请稍等");
    }
}

#pragma mark SKProductsRequestDelegate 查询成功后的回调
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    NSArray *product = response.products;
    
    if (product.count == 0) {
        //无法获取商品信息
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"无法获取商品信息" forKey:NSLocalizedDescriptionKey];
        [self failedWithErrorCode:WDIAPErrorCodeType_EmptyProduceList error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
        self.requestFinished = YES; //失败，请求完成
        
    } else {
        //发起购买请求
        SKPayment *payment = [SKPayment paymentWithProduct:product[0]];
        
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

#pragma mark SKProductsRequestDelegate 查询失败后的回调
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"查询商品信息失败" forKey:NSLocalizedDescriptionKey];
    [self failedWithErrorCode:WDIAPErrorCodeType_QueryFailure error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
    self.requestFinished = YES; //失败，请求完成
}

#pragma Mark 购买操作后的回调
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
    
    for (SKPaymentTransaction *transaction in transactions) {
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing://正在交易
                break;
            case SKPaymentTransactionStatePurchased://交易完成
                [self getReceipt:transaction]; //获取交易成功后的购买凭证
                [self sendAppStoreRequestBuy:transaction];//把self.receipt发送到服务器验证是否有效
                break;
                
            case SKPaymentTransactionStateFailed://交易失败
                [self failedTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateRestored://已经购买过该商品
                [self restoreTransaction:transaction];
                break;
                
            default:
                
                break;
        }
    }
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    self.requestFinished = YES; //成功，请求完成
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}


- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if(transaction.error.code != SKErrorPaymentCancelled) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"购买失败" forKey:NSLocalizedDescriptionKey];
        [self failedWithErrorCode:WDIAPErrorCodeType_BugFailure error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
        
    }else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"用户取消购买" forKey:NSLocalizedDescriptionKey];
        [self failedWithErrorCode:WDIAPErrorCodeType_UserCancel error:[NSError errorWithDomain:kErrorDomain code:0 userInfo:userInfo]];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    self.requestFinished = YES; //失败，请求完成
}


- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    self.requestFinished = YES; //恢复购买，请求完成
}

#pragma mark 获取交易成功后的购买凭证

- (void)getReceipt:(SKPaymentTransaction *)transaction {
    
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    NSData *receipt = nil;
    if ([[NSBundle mainBundle] respondsToSelector:@selector(appStoreReceiptURL)]) {
        NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
        receipt = [NSData dataWithContentsOfURL:receiptUrl];
    }else {
        if ([transaction respondsToSelector:@selector(transactionReceipt)]) {
            // iOS7之前 使用
            receipt = [transaction transactionReceipt];
        }
    }
    self.receipt = [receiptData base64EncodedStringWithOptions:0];
}


#pragma mark 将获取到的凭证发送给自己的服务端，服务端发送给苹果服务器验证，成功后返回给客户端，客户端finish
-(void)sendAppStoreRequestBuy:(SKPaymentTransaction *)currentPaymentTransaction {
    
    //这里的参数请根据自己公司后台服务器接口定制  包含凭证之类的信息
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    self.receipt,@"receipt",
                                     nil];
    
    //TODO 将凭证发送给服务器
    [self completeTransaction:currentPaymentTransaction];
    
}

#pragma mark 错误信息反馈
- (void)failedWithErrorCode:(NSInteger)code error:(NSError *)error {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(wd_buyFailedWithErrorCode:andError:)]) {
        [self.delegate wd_buyFailedWithErrorCode:code andError:error];
    }
}

@end
