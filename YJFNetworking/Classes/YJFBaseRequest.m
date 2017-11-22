//
//  YJFBaseRequest.m
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFBaseRequest.h"
#import "YJFNetworkPrivate.h"

#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

#import "YJFNetworkAgent.h"

NSString *const YJFRequestValidationErrorDomain = @"com.yunjifen.request.validation";

@interface YJFBaseRequest ()

@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite) NSData *responseData;
@property (nonatomic, strong, readwrite) id responseJSONObject;
@property (nonatomic, strong, readwrite) id responseObject;
@property (nonatomic, strong, readwrite) NSString *responseString;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation YJFBaseRequest

#pragma mark - Request and Response Information

- (NSHTTPURLResponse *)response{

    return (NSHTTPURLResponse *)self.requestTask.response;
}

- (NSInteger)responseStatusCode{
    
    return self.response.statusCode;
}

- (NSDictionary *)responseHeaders{

    return self.response.allHeaderFields;
}

- (NSURLRequest *)currentRequest{
    return self.requestTask.currentRequest;
}

- (NSURLRequest *)originalRequest{
    return self.requestTask.originalRequest;
}

- (BOOL)isCancelled {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateCanceling;
}

- (BOOL)isExecuting {
    if (!self.requestTask) {
        return NO;
    }
    return self.requestTask.state == NSURLSessionTaskStateRunning;
}


#pragma mark - Request Configuration
// 一个request一个回调completionBlcok
- (void)setCompletionBlockWithSuceess:(YJFRequestCompletionBlock)success
                              failure:(YJFRequestCompletionBlock)failure{

    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
}


- (void)clearCompletionBlock{
    // 打破循环引用
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
}


- (void)addAccessory:(id<YJFRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}

#pragma mark - Request Action

- (void)start{

    // 请求将要开始
    [self toggleAccessoriesWillStartCallBack];
    
    [[YJFNetworkAgent shareInstance] addRequest:self];
}

- (void)stop{
    
    [self toggleAccessoriesWillStopCallBack];
    
    self.delegate = nil;
    [[YJFNetworkAgent shareInstance] cancleRequest:self];
    
    [self toggleAccessoriesDidStopCallBack];

}

- (void)startWithCompletionBlockWithSuccess:(YJFRequestCompletionBlock)success
                                    failure:(YJFRequestCompletionBlock)failure{

    [self setCompletionBlockWithSuceess:success failure:failure];
    [self start];
}


#pragma mark - Subclass Override

// 请求完成预处理
- (void)requestCompletePreprocessor {
}

- (void)requestCompleteFilter {
}

- (void)requestFailedPreprocessor {
    
}

- (void)requestFailedFilter {
    
}


- (NSString *)requestUrl{

    return @"";
}

- (NSString *)baseUrl{
    return @"";
}

- (NSString *)cdnUrl{
    return @"";
}

- (YJFRequestMethod)requestMethod{
    return YJFRequestMethodPOST;
}

- (YJFRequestSerializerType)requestSerializerType{
    return YJFRequestSerializerTypeJSON;
}

- (YJFResponseSerializerType)responseSerializerType{

    return YJFResponseSerializerTypeJSON;
}

// 授权（需要服务器账户和密码）
- (NSArray *)requestAuthorizationHeaderFieldArray {
    return nil;
}

// 请求头
- (NSDictionary *)requestHeaderFieldValueDictionary{
    return nil;
}

- (NSURLRequest *)buildCustomUrlRequest {
    return nil;
}

// 请求参数
- (id)requestParameters{
    return nil;
}

- (id)cacheFileNameFilterForRequestParameters:(id)parameters{
    return parameters;
}


- (NSInteger)requestTimeoutInterval{
    return 60;
}


- (BOOL)allowsCellularAccess{
    return YES;
}

- (BOOL)useCDN{
    return NO;
}


// 校验JSON数据相关
- (id)jsonValidator {
    return nil;
}

// 是200-299的才校验数据
- (BOOL)statusCodeValidator {
    NSInteger statusCode = [self responseStatusCode];
    return (statusCode >= 200 && statusCode <= 299);
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ } { arguments: %@ }", NSStringFromClass([self class]), self, self.currentRequest.URL, self.currentRequest.HTTPMethod, self.requestParameters];
}

@end
