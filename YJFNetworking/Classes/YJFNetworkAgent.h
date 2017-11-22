//
//  YJFNetworkAgent.h
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YJFBaseRequest;

@interface YJFNetworkAgent : NSObject

+ (instancetype)shareInstance;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)addRequest:(YJFBaseRequest *)request;

- (void)cancleRequest:(YJFBaseRequest *)requset;

- (void)cancleAllRequests;

///  Return the constructed URL of request.
///
///  @param request The request to parse. Should not be nil.
///
///  @return The result URL.
- (NSString *)buildRequestUrl:(YJFBaseRequest *)request;


@end


NS_ASSUME_NONNULL_END
