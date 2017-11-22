//
//  YJFBatchRequestAgent.h
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YJFBatchRequest;

///  YJFBatchRequestAgent handles batch request management. It keeps track of all
///  the batch requests.
@interface YJFBatchRequestAgent : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

///  Get the shared batch request agent.
+ (YJFBatchRequestAgent *)sharedAgent;

///  Add a batch request.
- (void)addBatchRequest:(YJFBatchRequest *)request;

///  Remove a previously added batch request.
- (void)removeBatchRequest:(YJFBatchRequest *)request;

@end

NS_ASSUME_NONNULL_END

