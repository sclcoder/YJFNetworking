//
//  YJFNetworkConfig.h
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN // 处理swift混编


@class YJFBaseRequest;
@class AFSecurityPolicy;

///  YTKUrlFilterProtocol can be used to append common parameters to requests before sending them.
@protocol YJFUrlFilterProtocol <NSObject>
///  Preprocess request URL before actually sending them.
///
///  @param originUrl request's origin URL, which is returned by `requestUrl`
///  @param request   request itself
///
///  @return A new url which will be used as a new `requestUrl`
- (NSString *)filterUrl:(NSString *)originUrl withRequest:(YJFBaseRequest *)request;

@end

///  YTKCacheDirPathFilterProtocol can be used to append common path components when caching response results
@protocol YJFCacheDirPathFilterProtocol <NSObject>

///  Preprocess cache path before actually saving them.
///
///  @param originPath original base cache path, which is generated in `YTKRequest` class.
///  @param request    request itself
///
///  @return A new path which will be used as base path when caching.
- (NSString *)filterCacheDirPath:(NSString *)originPath withRequest:(YJFBaseRequest *)request;

@end


@protocol YJFRequestParametersFilterProtocol <NSObject>
// 该方法在拼接request参数之前调用
// 统一处理请求参数
- (NSDictionary *)filterParameters:(NSDictionary *)parameters withRequest:(YJFBaseRequest *)request;

@end

@protocol YJFRequestHeaderFilterProtocol <NSObject>
// 统一处理requestHeader
- (NSDictionary *)filterHeaders:(NSDictionary *)headers withRequest:(YJFBaseRequest *)request;

@end

@protocol YJFResponseDataFilterProtocol<NSObject>
// 该方法在响应数据返回和缓存之前调用
// 统一处理返回数据
- (YJFBaseRequest *)filterError:(NSError *__autoreleasing*)error withRequest:(YJFBaseRequest *)request;

@end


///  YJFNetworkConfig stored global network-related configurations, which will be used in `YJFNetworkAgent`
///  to form and filter requests, as well as caching response.
@interface YJFNetworkConfig : NSObject

+ (instancetype)shareConfig;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new  NS_UNAVAILABLE;

@property(nonatomic,copy) NSString *baseUrl;

@property(nonatomic,copy) NSString *cdnUrl;

// Security policy will be used by AFNetworking.
@property(nonatomic,strong) AFSecurityPolicy *securityPolicy;

@property (nonatomic) BOOL debugLogEnabled;

// 用来初始化AFHTTPSessionManager
@property(nonatomic,strong) NSURLSessionConfiguration *configuration;


@property (nonatomic, strong, readonly) NSArray<id<YJFCacheDirPathFilterProtocol>> *cacheDirPathFilters;
///  Add a new cache path filter
- (void)addCacheDirPathFilter:(id<YJFCacheDirPathFilterProtocol>)filter;
///  Clear all cache path filters.
- (void)clearCacheDirPathFilter;


///  URL filters. See also `YJFUrlFilterProtocol`.
@property (nonatomic, strong, readonly) NSArray<id<YJFUrlFilterProtocol>> *urlFilters;
///  Cache path filters. See also `YJFCacheDirPathFilterProtocol`.
///  Add a new URL filter.
- (void)addUrlFilter:(id<YJFUrlFilterProtocol>)filter;
///  Remove all URL filters.
- (void)clearUrlFilter;


// 参数加密
@property (nonatomic, strong, readonly) NSArray<id<YJFRequestParametersFilterProtocol>> *requestParametersFilters;

- (void)addRequestParametersFilter:(id<YJFRequestParametersFilterProtocol>)filter;

// 统一处理requestHeader
@property (nonatomic, strong, readonly) NSArray<id<YJFRequestHeaderFilterProtocol>> *requestHeaderFilters;

- (void)addRequestHeadesFilter:(id<YJFRequestHeaderFilterProtocol>)filter;


@property (nonatomic, strong, readonly) NSArray<id<YJFResponseDataFilterProtocol>> *responseDataFilters;

- (void)addResponseDataFilters:(id<YJFResponseDataFilterProtocol>)filter;


@end

NS_ASSUME_NONNULL_END
