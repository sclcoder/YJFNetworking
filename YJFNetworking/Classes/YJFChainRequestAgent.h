//
//  YJFChainRequestAgent.h
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@class YJFChainRequest;

///  YJFChainRequestAgent handles chain request management. It keeps track of all
///  the chain requests.
@interface YJFChainRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Get the shared chain request agent.
+ (YJFChainRequestAgent *)sharedAgent;

///  Add a chain request.
- (void)addChainRequest:(YJFChainRequest *)request;

///  Remove a previously added chain request.
- (void)removeChainRequest:(YJFChainRequest *)request;

@end

NS_ASSUME_NONNULL_END

