//
//  YJFBatchRequestAgent.m
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFBatchRequestAgent.h"
#import "YJFBatchRequest.h"

@interface YJFBatchRequestAgent()

@property (strong, nonatomic) NSMutableArray<YJFBatchRequest *> *requestArray;

@end

@implementation YJFBatchRequestAgent

+ (YJFBatchRequestAgent *)sharedAgent {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestArray = [NSMutableArray array];
    }
    return self;
}

- (void)addBatchRequest:(YJFBatchRequest *)request {
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeBatchRequest:(YJFBatchRequest *)request {
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end
