//
//  YJFBatchRequest.m
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFBatchRequest.h"
#import "YJFNetworkPrivate.h"
#import "YJFBatchRequestAgent.h"
#import "YJFCacheableRequest.h"

@interface YJFBatchRequest() <YJFRequestDelegate>

@property (nonatomic) NSInteger finishedCount;

@end

@implementation YJFBatchRequest

- (instancetype)initWithRequestArray:(NSArray<YJFCacheableRequest *> *)requestArray {
    self = [super init];
    if (self) {
        _requestArray = [requestArray copy];
        _finishedCount = 0;
        for (YJFCacheableRequest * req in _requestArray) {
            if (![req isKindOfClass:[YJFCacheableRequest class]]) {
                YJFNetLog(@"Error, request item must be YJFCacheableRequest instance.");
                return nil;
            }
        }
    }
    return self;
}

- (void)start {
    if (_finishedCount > 0) {
        YJFNetLog(@"Error! Batch request has already started.");
        return;
    }
    _failedRequest = nil;
    [[YJFBatchRequestAgent sharedAgent] addBatchRequest:self];
    [self toggleAccessoriesWillStartCallBack];
    for (YJFCacheableRequest * req in _requestArray) {
        req.delegate = self;
        [req clearCompletionBlock];
        [req start];
    }
}

- (void)stop {
    [self toggleAccessoriesWillStopCallBack];
    _delegate = nil;
    [self clearRequest];
    [self toggleAccessoriesDidStopCallBack];
    [[YJFBatchRequestAgent sharedAgent] removeBatchRequest:self];
}

- (void)startWithCompletionBlockWithSuccess:(void (^)(YJFBatchRequest *batchRequest))success
                                    failure:(void (^)(YJFBatchRequest *batchRequest))failure {
    [self setCompletionBlockWithSuccess:success failure:failure];
    [self start];
}

- (void)setCompletionBlockWithSuccess:(void (^)(YJFBatchRequest *batchRequest))success
                              failure:(void (^)(YJFBatchRequest *batchRequest))failure {
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}

- (void)clearCompletionBlock {
    // nil out to break the retain cycle.
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}

- (BOOL)isDataFromCache {
    BOOL result = YES;
    for (YJFCacheableRequest *request in _requestArray) {
        if (!request.isDataFromCache) {
            result = NO;
        }
    }
    return result;
}


- (void)dealloc {
    [self clearRequest];
}

#pragma mark - Network Request Delegate

- (void)requestFinished:(YJFCacheableRequest *)request {
    _finishedCount++;
    if (_finishedCount == _requestArray.count) {
        [self toggleAccessoriesWillStopCallBack];
        if ([_delegate respondsToSelector:@selector(batchRequestFinished:)]) {
            [_delegate batchRequestFinished:self];
        }
        if (_successCompletionBlock) {
            _successCompletionBlock(self);
        }
        [self clearCompletionBlock];
        [self toggleAccessoriesDidStopCallBack];
        [[YJFBatchRequestAgent sharedAgent] removeBatchRequest:self];
    }
}

- (void)requestFailed:(YJFCacheableRequest *)request {
    _failedRequest = request;
    [self toggleAccessoriesWillStopCallBack];
    // Stop
    for (YJFCacheableRequest *req in _requestArray) {
        [req stop];
    }
    // Callback
    if ([_delegate respondsToSelector:@selector(batchRequestFailed:)]) {
        [_delegate batchRequestFailed:self];
    }
    if (_failureCompletionBlock) {
        _failureCompletionBlock(self);
    }
    // Clear
    [self clearCompletionBlock];
    
    [self toggleAccessoriesDidStopCallBack];
    [[YJFBatchRequestAgent sharedAgent] removeBatchRequest:self];
}

- (void)clearRequest {
    for (YJFCacheableRequest * req in _requestArray) {
        [req stop];
    }
    [self clearCompletionBlock];
}

#pragma mark - Request Accessoies

- (void)addAccessory:(id<YJFRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}

@end

