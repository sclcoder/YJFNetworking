//
//  YJFBaseRequest.h
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const YJFRequestValidationErrorDomain;

NS_ENUM(NSInteger) {
    YJFRequestValidationErrorInvalidStatusCode = -8,
    YJFRequestValidationErrorInvalidJSONFormat = -9,
};


typedef NS_ENUM(NSInteger , YJFRequestMethod) {

    YJFRequestMethodGET = 0,
    YJFRequestMethodPOST,
    YJFRequestMethodHEAD,
    YJFRequestMethodPUT,
    YJFRequestMethodDELETE,
    YJFRequestMethodPATCH
};
// AF内部支持者三种RequestSerializerType
typedef NS_ENUM(NSInteger,YJFRequestSerializerType){
    // encodingData
    YJFRequestSerializerTypeHTTP = 0,
    // JsonData
    YJFRequestSerializerTypeJSON,
    /**
     // PlistData
     YJFRequestSerializerTypePLIST,
     */
    
};

typedef NS_ENUM(NSInteger,YJFResponseSerializerType){
    // NSData type (AFHTTPResponseSerializer: AF中这个解析器只是验证了是否是可接受的contentType和statusCode 如果是就将data直接返回了)
    YJFResponseSerializerTypeHTTP = 0,
    // 以下的解析器时继承自AFHTTPResponseSerializer
    // Json object type (AFJSONResponseSerializer: AF中这个解析器返回JsonObject)
    YJFResponseSerializerTypeJSON,
    
     // NSXMLParser type (AFXMLParserResponseSerializer: AF中这个解析器返回一个XML解析器 需要自己解析)
    YJFResponseSerializerTypeXML,
    
    /**
     // Plist object type (AFPropertyListResponseSerializer: AF中这个解析器返回 plistObject
     AFPropertyListResponseSerializer,
     // image type
     AFImageResponseSerializer,
     // 组合类型
     AFCompoundResponseSerializer,
     */
 
    
};

typedef NS_ENUM(NSInteger,YJFRequestPriority){
    // 请求优先级
    YJFRequestPriorityLow = -4L,
    YJFRequestPriorityDefault = 0,
    YJFRequestPriorityHight = 4,
};


@protocol AFMultipartFormData;
// formData
typedef void (^AFConstructingBlock)(id<AFMultipartFormData> formData);

// 下载进度跟进(AF内部有这样一个block这里命名成一样的了)
typedef void(^AFURLSessionTaskProgressBlock)(NSProgress *progress);

@class YJFBaseRequest;
// block回调
typedef void(^YJFRequestCompletionBlock)(__kindof YJFBaseRequest *request);

@protocol YJFRequestDelegate <NSObject>

@optional
// 请求成功
- (void)requestDidFinishedSucceed:(__kindof YJFBaseRequest *)request;
// 请求失败
- (void)requestDidFinishedFailed:(__kindof YJFBaseRequest *)request;

@end


@protocol YJFRequestAccessory <NSObject>
@optional
// 请求即将开始
- (void)requestWillStart:(id)request;
// 请求即将结束
- (void)requestWillStop:(id)request;
// 请求结束
- (void)requestDidStop:(id)request;

@end

@interface YJFBaseRequest : NSObject

#pragma mark - Request and Response Information
///=============================================================================
/// @name Request Configuration
///============================================================================

///  @warning This value is actually nil and should not be accessed before the request starts.

@property(nonatomic,strong,readonly) NSURLSessionTask *requestTask;
// NSData
@property(nonatomic,strong,readonly,nullable) NSData *responseData;
// 字符串
@property(nonatomic,strong,readonly,nullable) NSString *responseString;
// oc对象
@property(nonatomic,strong,readonly,nullable)  id responseObject;
// JsonObject(oc对象 一般jsonObject为 NSArray、NSDictionary)
@property (nonatomic,strong,readonly,nullable) id responseJSONObject;

@property (nonatomic,strong,readonly,nullable) NSError *error;

///  Shortcut for `requestTask.currentRequest`.
@property(nonatomic,strong,readonly) NSURLRequest *currentRequest;
///  Shortcut for `requestTask.originalRequest`.
@property(nonatomic,strong,readonly) NSURLRequest *originalRequest;
///  Shortcut for `requestTask.response`.
@property(nonatomic,strong,readonly) NSHTTPURLResponse *response;
///  The response status code.
@property(nonatomic,assign,readonly) NSInteger responseStatusCode;
///  The response header fields.
@property(nonatomic,strong,readonly,nullable) NSDictionary *responseHeaders;

@property (nonatomic,readonly,getter=isCancelled) BOOL cancelled;

@property (nonatomic,readonly, getter=isExecuting) BOOL executing;




#pragma mark - Request Configuration

@property(nonatomic,assign) NSInteger tag;

//@property(nonatomic,strong,nullable) NSDictionary *useInfo;

@property(nonatomic,weak,nullable) id<YJFRequestDelegate> delegate;

@property(nonatomic,copy,nullable) YJFRequestCompletionBlock successCompletionBlock;
@property(nonatomic,copy,nullable) YJFRequestCompletionBlock failureCompletionBlock;

@property(nonatomic,assign) YJFRequestPriority requestPriority;


- (void)setCompletionBlockWithSuceess:(nullable YJFRequestCompletionBlock)success
                              failure:(nullable YJFRequestCompletionBlock)failure;

// 清空
- (void)clearCompletionBlock;

///  Convenience method to add request accessory. See also `requestAccessories`.
- (void)addAccessory:(id<YJFRequestAccessory>)accessory;



// 下载相关
///  This value is used to perform resumable download request. Default is nil.
///
///  @discussion NSURLSessionDownloadTask is used when this value is not nil.
///              The exist file at the path will be removed before the request starts. If request succeed, file will
///              be saved to this path automatically, otherwise the response will be saved to `responseData`
///              and `responseString`. For this to work, server must support `Range` and response with
///              proper `Last-Modified` and/or `Etag`. See `NSURLSessionDownloadTask` for more detail.

@property (nonatomic, strong, nullable) NSString *resumableDownloadPath;

///  You can use this block to track the download progress. See also `resumableDownloadPath`.
// 下载进度跟进
@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock resumableDownloadProgressBlock;

// 上传相关
// POST请求中用来构建HTTP body,默认是nil
@property(nonatomic,copy,nullable) AFConstructingBlock constructingBodyBlock;

// 通过文件URL上传 (需要服务器支持)
@property(nonatomic,strong) NSURL*fileUrl;

// 上传进度跟进
@property (nonatomic, copy, nullable) AFURLSessionTaskProgressBlock uploadProgressBlock;



//  辅助工具
///  This can be used to add several accossories object. Note if you use `addAccessory` to add acceesory
///  this array will be automatically created. Default is nil.
@property (nonatomic, strong, nullable) NSMutableArray<id<YJFRequestAccessory>> *requestAccessories;


#pragma mark - Request Action

///=============================================================================
/// @name Request Action
///=============================================================================

///  Append self to request queue and start the request.
- (void)start;

///  Remove self from request queue and cancel the request.
- (void)stop;

- (void)startWithCompletionBlockWithSuccess:(YJFRequestCompletionBlock)success
                                    failure:(YJFRequestCompletionBlock)failure;



#pragma mark - Subclass Override
///=============================================================================
/// @name Subclass Override
///=============================================================================

///  Called on background thread after request succeded but before switching to main thread. Note if
///  cache is loaded, this method WILL be called on the main thread, just like `requestCompleteFilter`.
- (void)requestCompletePreprocessor;

///  Called on the main thread after request succeeded.
- (void)requestCompleteFilter;

///  Called on background thread after request failed but before switching to main thread. See also
///  `requestCompletePreprocessor`.
- (void)requestFailedPreprocessor;

///  Called on the main thread when request failed.
- (void)requestFailedFilter;


- (NSString *)baseUrl;

- (NSString *)requestUrl;

- (NSString *)cdnUrl;

// 请求方法
- (YJFRequestMethod)requestMethod;
// 请求参数
- (nullable id)requestParameters;

///  Override this method to filter requests with certain arguments when caching.
- (id)cacheFileNameFilterForRequestParameters:(id)parameters;

// 授权（需要服务器账户和密码）
- (NSArray *)requestAuthorizationHeaderFieldArray;
// 请求头
- (nullable NSDictionary<NSString *, NSString *> *)requestHeaderFieldValueDictionary;

///  Use this to build custom request. If this method return non-nil value, `requestUrl`, `requestTimeoutInterval`,
///  `requestArgument`, `allowsCellularAccess`, `requestMethod` and `requestSerializerType` will all be ignored.
- (nullable NSURLRequest *)buildCustomUrlRequest;

// 超时时间
- (NSInteger)requestTimeoutInterval;

// 这两个在YJFNetworkAgent中直接使用(没有给AFNHTTPSessionManager使用)
- (YJFRequestSerializerType)requestSerializerType;

- (YJFResponseSerializerType)responseSerializerType;

// 是否允许蜂窝网路
- (BOOL)allowsCellularAccess;

// 内容分发网络
- (BOOL)useCDN;

// 校验json是否有效
///  The validator will be used to test if `responseJSONObject` is correctly formed.
- (nullable id)jsonValidator;

///  This validator will be used to test if `responseStatusCode` is valid.
- (BOOL)statusCodeValidator;

@end


NS_ASSUME_NONNULL_END
