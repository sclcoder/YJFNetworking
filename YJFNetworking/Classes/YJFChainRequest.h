//
//  YJFChainRequest.h
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YJFChainRequest;
@class YJFBaseRequest;
@protocol YJFRequestAccessory;

///  The YJFChainRequestDelegate protocol defines several optional methods you can use
///  to receive network-related messages. All the delegate methods will be called
///  on the main queue. Note the delegate methods will be called when all the requests
///  of chain request finishes.
@protocol YJFChainRequestDelegate <NSObject>

@optional
///  Tell the delegate that the chain request has finished successfully.
///
///  @param chainRequest The corresponding chain request.
- (void)chainRequestFinished:(YJFChainRequest *)chainRequest;

///  Tell the delegate that the chain request has failed.
///
///  @param chainRequest The corresponding chain request.
///  @param request      First failed request that causes the whole request to fail.
- (void)chainRequestFailed:(YJFChainRequest *)chainRequest failedBaseRequest:(YJFBaseRequest*)request;

@end

typedef void (^YJFChainCallback)(YJFChainRequest *chainRequest, YJFBaseRequest *baseRequest);

///  YJFBatchRequest can be used to chain several YJFCachableRequest so that one will only starts after another finishes.
///  Note that when used inside YJFChainRequest, a single YJFCachableRequest will have its own callback and delegate
///  cleared, in favor of the batch request callback.
@interface YJFChainRequest : NSObject

///  All the requests are stored in this array.
- (NSArray<YJFBaseRequest *> *)requestArray;

///  The delegate object of the chain request. Default is nil.
@property (nonatomic, weak, nullable) id<YJFChainRequestDelegate> delegate;

///  This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
///  this array will be automatically created. Default is nil.
@property (nonatomic, strong, nullable) NSMutableArray<id<YJFRequestAccessory>> *requestAccessories;

///  Convenience method to add request accessory. See also `requestAccessories`.
- (void)addAccessory:(id<YJFRequestAccessory>)accessory;

///  Start the chain request, adding first request in the chain to request queue.
- (void)start;

///  Stop the chain request. Remaining request in chain will be cancelled.
- (void)stop;

///  Add request to request chain.
///
///  @param request  The request to be chained.
///  @param callback The finish callback
- (void)addRequest:(YJFBaseRequest *)request callback:(nullable YJFChainCallback)callback;

@end

NS_ASSUME_NONNULL_END

