//
//  YJFChainRequestAgent.m
//  YunES
//
//  Created by mac on 2017/11/21.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFChainRequestAgent.h"
#import "YJFChainRequest.h"

@interface YJFChainRequestAgent()

@property (strong, nonatomic) NSMutableArray<YJFChainRequest *> *requestArray;

@end

@implementation YJFChainRequestAgent

+ (YJFChainRequestAgent *)sharedAgent {
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

- (void)addChainRequest:(YJFChainRequest *)request {
    @synchronized(self) {
        [_requestArray addObject:request];
    }
}

- (void)removeChainRequest:(YJFChainRequest *)request {
    @synchronized(self) {
        [_requestArray removeObject:request];
    }
}

@end
