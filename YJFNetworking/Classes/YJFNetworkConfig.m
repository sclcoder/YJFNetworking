//
//  YJFNetworkConfig.m
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFNetworkConfig.h"

// __has_include  此宏传入一个你想引入文件的名称作为参数,如果该文件能够被引入则返回1,否则返回0.

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>  // 使用cocoaPods管理文件时 使用<>来引用
#else
#import "AFNetworking.h"
#endif

// 配置文件不能改动
@implementation YJFNetworkConfig{
    
    NSMutableArray<id<YJFUrlFilterProtocol>> *_urlFilters;
    NSMutableArray<id<YJFCacheDirPathFilterProtocol>> *_cacheDirPathFilters;
    NSMutableArray<id<YJFRequestParametersFilterProtocol>> *_requestParametersFilters;
    NSMutableArray<id<YJFRequestHeaderFilterProtocol>> *_requestHeaderFilters;
    NSMutableArray<id<YJFResponseDataFilterProtocol>> *_responseDataFilters;
}

+ (instancetype)shareConfig{
    
    static YJFNetworkConfig *shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    
    return shareInstance;
}

- (instancetype)init{

    if (self = [super init]) {
        // 
        _baseUrl = @"";
        _cdnUrl = @"";
        _urlFilters = [NSMutableArray array];
        _cacheDirPathFilters = [NSMutableArray array];
        _requestParametersFilters = [NSMutableArray array];
        _requestHeaderFilters = [NSMutableArray array];
        _responseDataFilters = [NSMutableArray array];
        _securityPolicy = [AFSecurityPolicy defaultPolicy];
        _debugLogEnabled = NO;
        
    }
    return self;
}


// 此处使用的设计模式还是代理--只不过这次的代理没有暴露delegate属性而已,采取的方式是暴露一个方法，在该方法中将遵守协议的对象获取到然后在需要的时候调用该对象的的协议方法。
- (void)addCacheDirPathFilter:(id<YJFCacheDirPathFilterProtocol>)filter {
    [_cacheDirPathFilters addObject:filter];
}

- (NSArray<id<YJFCacheDirPathFilterProtocol>> *)cacheDirPathFilters {
    return [_cacheDirPathFilters copy];
}

- (void)clearCacheDirPathFilter {
    [_cacheDirPathFilters removeAllObjects];
}


// 处理url
- (void)addUrlFilter:(id<YJFUrlFilterProtocol>)filter {
    [_urlFilters addObject:filter];
}

- (NSArray<id<YJFUrlFilterProtocol>> *)urlFilters {
    return [_urlFilters copy];
}

- (void)clearUrlFilter {
    [_urlFilters removeAllObjects];
}

// 处理请求参数
- (void)addRequestParametersFilter:(id<YJFRequestParametersFilterProtocol>)filter{
    [_requestParametersFilters addObject:filter];
}

- (NSArray<id<YJFRequestParametersFilterProtocol>> *)requestParametersFilters{
    return [_requestParametersFilters copy];
}

// 处理header参数
- (void)addRequestHeadesFilter:(id<YJFRequestHeaderFilterProtocol>)filter{
    [_requestHeaderFilters addObject:filter];
}

- (NSArray<id<YJFRequestHeaderFilterProtocol>> *)requestHeaderFilters{
    return [_requestHeaderFilters copy];
}

// 处理返回数据
- (void)addResponseDataFilters:(id<YJFResponseDataFilterProtocol>)filter{
    [_responseDataFilters addObject:filter];
}

- (NSArray<id<YJFResponseDataFilterProtocol>> *)responseDataFilters{
    return [_responseDataFilters copy];
}



#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ baseURL: %@ } { cdnURL: %@ }", NSStringFromClass([self class]), self, self.baseUrl, self.cdnUrl];
}



@end
