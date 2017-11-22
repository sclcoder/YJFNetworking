//
//  YJFNetworkAgent.m
//  yunWallet
//
//  Created by mac on 2017/9/5.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import "YJFNetworkAgent.h"
#import "YJFNetworkConfig.h"
#import "YJFBaseRequest.h"
#import "YJFNetworkPrivate.h"

#import <pthread/pthread.h>


#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

// 互斥锁
#define Lock() pthread_mutex_lock(&_lock)
#define Unlock() pthread_mutex_unlock(&_lock)

#define kYJFNetworkIncompleteDownloadFolderName @"Incomplete"


@implementation YJFNetworkAgent

{
    AFHTTPSessionManager *_manager;
    YJFNetworkConfig *_config;
    // 保存request
    NSMutableDictionary <NSNumber * , YJFBaseRequest *> *_requestsRecord;
    // 互斥锁
    pthread_mutex_t _lock;
    
    AFJSONResponseSerializer *_jsonResponseSerializer;
    
    AFXMLParserResponseSerializer *_xmlParserResponseSerialzier;

    NSIndexSet *_acceptableStatusCodes;
    
    NSSet *_acceptableContentTypes;
    
    dispatch_queue_t _processingQueue;
}


+ (instancetype)shareInstance{

    static YJFNetworkAgent *shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
    
}

- (instancetype)init{

    if (self = [super init]) {
        
        // 互斥锁初始化
        pthread_mutex_init(&_lock, NULL);
        
        _config = [YJFNetworkConfig shareConfig];
        
        _manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:_config.configuration];
        
        _requestsRecord = [NSMutableDictionary dictionary];
        
        // 让AF返回的数据都是data 具体自己来解析 - 便于做缓存
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        // _manager.requestSerializer 没必要设置 因为请求序列化在本类中做好了
        _acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    
        // 响应接收的状态码
        _manager.responseSerializer.acceptableStatusCodes = _acceptableStatusCodes;
        
        // 每个解析器有不同的acceptableContentTypes集合 两者不能混用 json解析器不能搞个application/xml
        _acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html",@"text/plain", nil];
        
        _processingQueue = dispatch_queue_create("com.yunjifen.networkagent.processing", DISPATCH_QUEUE_CONCURRENT);
        /**
         The dispatch queue for `completionBlock`. If `NULL` (default), the main queue is used.
         */
        _manager.completionQueue = _processingQueue;
    }
    return self;
}


#pragma mark - ResponseSerializer的设置

- (AFJSONResponseSerializer *)jsonResponseSerializer {
    if (!_jsonResponseSerializer) {
        _jsonResponseSerializer = [AFJSONResponseSerializer serializer];
        _jsonResponseSerializer.acceptableContentTypes = _acceptableContentTypes;
        _jsonResponseSerializer.acceptableStatusCodes = _acceptableStatusCodes;
        
    }
    return _jsonResponseSerializer;
}

- (AFXMLParserResponseSerializer *)xmlParserResponseSerialzier {
    if (!_xmlParserResponseSerialzier) {
        _xmlParserResponseSerialzier = [AFXMLParserResponseSerializer serializer];
//        _xmlParserResponseSerialzier.acceptableContentTypes = _acceptableContentTypes;
        _xmlParserResponseSerialzier.acceptableStatusCodes = _acceptableStatusCodes;
    }
    return _xmlParserResponseSerialzier;
}

// 构建url
- (NSString *)buildRequestUrl:(YJFBaseRequest *)request {
    NSParameterAssert(request != nil);
    
    NSString *detailUrl = [request requestUrl];
    NSURL *temp = [NSURL URLWithString:detailUrl];
    // If detailUrl is valid URL  检测detailUrl是否是个有效的url
    if (temp && temp.host && temp.scheme) {
        return detailUrl;
    }
    // Filter URL if needed
    NSArray *filters = [_config urlFilters];
    for (id<YJFUrlFilterProtocol> f in filters) {
        // 执行回调 获取一个新的url
        detailUrl = [f filterUrl:detailUrl withRequest:request];
    }
    
    NSString *baseUrl;
    if ([request useCDN]) { // 使用cdn
        if ([request cdnUrl].length > 0) {
            baseUrl = [request cdnUrl]; // 先使用request
        } else {
            baseUrl = [_config cdnUrl]; // request没有使用全局的
        }
    } else { // 不使用cdn
        if ([request baseUrl].length > 0) {
            baseUrl = [request baseUrl];
        } else {
            baseUrl = [_config baseUrl];
        }
    }
    // URL slash compability
    NSURL *url = [NSURL URLWithString:baseUrl];
    
    if (baseUrl.length > 0 && ![baseUrl hasSuffix:@"/"]) {
        // 不是以‘/’结尾 就添加一个‘/’
        url = [url URLByAppendingPathComponent:@""];
    }
    
    // 返回完整的url
    return [NSURL URLWithString:detailUrl relativeToURL:url].absoluteString;
}

#pragma mark - YJFBaseRequest相关的动作处理

- (void)addRequest:(YJFBaseRequest *)request{

    // 这些方法最终直接调用AFURLSessionManager的dataTaskWithRequest;而不是直接调用AFHTTPSessionManager封装的请求方法

    NSParameterAssert(request != nil);
    
    NSError *__autoreleasing requestSerializationError = nil;
    
    NSURLRequest *customUrlRequest= [request buildCustomUrlRequest];
    if (customUrlRequest) {
        __block NSURLSessionDataTask *dataTask = nil;
        dataTask = [_manager dataTaskWithRequest:customUrlRequest completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            [self handleRequestResult:dataTask responseObject:responseObject error:error];
        }];
        request.requestTask = dataTask;
    } else {
        request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    }

    
    // 分类的setter
    request.requestTask = [self sessionTaskForRequest:request error:&requestSerializationError];
    
    if (requestSerializationError) {
        [self requestDidFailureWithRequest:request error:requestSerializationError];
    }
    
    NSAssert(request.requestTask != nil, @"requestTask should not be nil");
    
    
    switch (request.requestPriority) {
        case YJFRequestPriorityLow:
            
            request.requestTask.priority = NSURLSessionTaskPriorityLow;
            break;
        case YJFRequestPriorityHight:
            request.requestTask.priority = NSURLSessionTaskPriorityHigh;
            break;
        case YJFRequestPriorityDefault:
            // fall through
        default:
            //                request.requestTask.priority = NSURLSessionTaskPriorityDefault;
            break;
    }
    
    
    YJFNetLog(@"Add request: %@", NSStringFromClass([request class]));
    
    [self addRequestToRecord:request];
    
    [request.requestTask resume];
}

- (void)cancleRequest:(YJFBaseRequest *)request {
    
    NSParameterAssert(request != nil);
    Lock();
    YJFBaseRequest *tempRequest = _requestsRecord[@(request.requestTask.taskIdentifier)];
    Unlock();
    if (!tempRequest) {
        return;
    }

    YJFNetLog(@"Request cancle :%@",NSStringFromClass([request class]));
    // 如果是断点续传 取消时 保存resumeData
    if (request.resumableDownloadPath) {
        NSURLSessionDownloadTask *requestTask = (NSURLSessionDownloadTask *)request.requestTask;
        [requestTask cancelByProducingResumeData:^(NSData *resumeData) {
            NSURL *localUrl = [self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath];
            [resumeData writeToURL:localUrl atomically:YES];
        }];
    } else {
        [request.requestTask cancel];
    }
    
    [self removeRequestFromRecord:request];
    [request clearCompletionBlock];
}

- (void)cancleAllRequests {
    Lock();
    NSArray *allKeys = [_requestsRecord allKeys];
    Unlock();
    if (allKeys && allKeys.count > 0) {
        NSArray *copiedKeys = [allKeys copy];
        for (NSNumber *key in copiedKeys) {
            Lock();
            YJFBaseRequest *request = _requestsRecord[key];
            Unlock();
            // We are using non-recursive lock.
            // Do not lock `stop`, otherwise deadlock may occur.
            [request stop];
        }
    }
}

// 校验结果
- (BOOL)validateResult:(YJFBaseRequest *)request error:(NSError * _Nullable __autoreleasing *)error {
    BOOL result = [request statusCodeValidator];
    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:YJFRequestValidationErrorDomain code:YJFRequestValidationErrorInvalidStatusCode userInfo:@{NSLocalizedDescriptionKey:@"Invalid status code"}];
        }
        return result;
    }
    id json = [request responseJSONObject];
    id validator = [request jsonValidator];
    // 是jsonObject
    if (json && validator) {
        result = [YJFNetworkUtils validateJSON:json withValidator:validator];
        if (!result) {
            if (error) {
                *error = [NSError errorWithDomain:YJFRequestValidationErrorDomain code:YJFRequestValidationErrorInvalidJSONFormat userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON format"}];
            }
            return result;
        }
    }
    
    return YES;
}



#pragma mark - 处理响应结果
// 处理相应数据
- (void)handleRequestResult:(NSURLSessionTask *)task
             responseObject:(id)responseObject
                      error:(NSError *)error{
    
    
    Lock();
    YJFBaseRequest *request = _requestsRecord[@(task.taskIdentifier)];
    Unlock();
    
    // 当request被取消会从_requestsRecord中移除，这是底层的AFNetworking的失败 callback还是会回调回来,这里忽略AF的回调
    if (!request) {
        return;
    }
    
    YJFNetLog(@"Finished Request: %@", NSStringFromClass([request class]));
    
    
    NSError * __autoreleasing responseSerializationError = nil;
    NSError * __autoreleasing validationError = nil;

    NSError *requestError = nil;
    
    BOOL succeed = NO;
    
    // 这里返回的数据一定是NSData因为 manager.responseSerializer = AFHTTPResponseSerializer
    request.responseObject = responseObject;
    
    if ([request.responseObject isKindOfClass:[NSData class]]) {
        
        request.responseData = responseObject;
        // 将data转成相应字符串(json串、xml串等等)
        request.responseString = [[NSString alloc] initWithData:request.responseObject encoding:[YJFNetworkUtils stringEncodingWithRequest:request]];
        
        /** 404时的string
         <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
         <html><head>
         <title>404 Not Found</title>
         </head><body>
         <h1>Not Found</h1>
         <p>The requested URL /videos1.json was not found on this server.</p>
         </body></html>
         */
        YJFNetLog(@"ResponseString : %@",request.responseString);
        // 根据request设置解析器解析数据
        switch (request.responseSerializerType) {
                
            case YJFResponseSerializerTypeHTTP:
                // 默认设置的AFHTTPSessionManger的解析器就是AFHTTPResponseSerializer，返回就是NSData数据，以上已经处理好了 此处不做任何事情
                break;
            case YJFResponseSerializerTypeJSON:{
                /** 调用AFURLResponseSerialization解析响应的方法
                 该方法会 1.通过contentType和statusCode判断responses是否有效
                 2.有效再进行数据解析
                 */
                // oc对象
                request.responseObject = [self.jsonResponseSerializer
                                          responseObjectForResponse:task.response
                                          data:request.responseData
                                          error:&responseSerializationError];
                
                request.responseJSONObject = request.responseObject;
                
            }
                break;
                
            case YJFResponseSerializerTypeXML:{
                // 返回值是NSXMLParser
                request.responseObject = [self.xmlParserResponseSerialzier
                                          responseObjectForResponse:task.response
                                          data:request.responseData
                                          error:&responseSerializationError];
            }
                
                break;
            default:
                break;
        }
        
    }
    
    if (error) {
        succeed = NO;
        requestError = error;
    } else if (responseSerializationError){
        succeed = NO;
        requestError = responseSerializationError;
    } else {
        succeed = [self validateResult:request error:&validationError];
        requestError = validationError;
    }
    
    
    // 使用者可以针对各自返回的业务参数 进行统一处理
    if (error==nil && validationError == nil && responseSerializationError ==nil) {
        NSError *__autoreleasing  bizError = nil;
        NSArray *filters = [_config responseDataFilters];
        for (id<YJFResponseDataFilterProtocol> f in filters) {
           [f filterError:&bizError withRequest:request];
        }
        
        if (bizError) {
            succeed = NO;
            requestError = bizError;
        } else {
            succeed = YES;
        }
    }

    
    if (succeed) {
        [self requestDidSuccessWithRequest:request];
    } else {
        [self requestDidFailureWithRequest:request error:requestError];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeRequestFromRecord:request];
        [request clearCompletionBlock];
    });
}

- (void)requestDidSuccessWithRequest:(YJFBaseRequest *)request{
    
    @autoreleasepool { // 添加自动释放池
        // 请求“成功”才会缓存数据--网络成功和业务成功
        [request requestCompletePreprocessor];
    }
    // 到主线程
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [request toggleAccessoriesWillStopCallBack];
        [request requestCompleteFilter];

        if ([request.delegate respondsToSelector:@selector(requestDidFinishedSucceed:)]) {
            [request.delegate requestDidFinishedSucceed:request];
        }
        if (request.successCompletionBlock) {
            request.successCompletionBlock(request);
        }
        [request toggleAccessoriesDidStopCallBack];

    });
    
}

- (void)requestDidFailureWithRequest:(YJFBaseRequest *)request error:(NSError *)error{
    
    request.error = error;
    YJFNetLog(@"Request %@ failed, status code = %ld, error = %@",
              NSStringFromClass([request class]), (long)request.responseStatusCode, error.localizedDescription);
    
    // Save incomplete download data.
    NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    if (incompleteDownloadData) {
        [incompleteDownloadData writeToURL:[self incompleteDownloadTempPathForDownloadPath:request.resumableDownloadPath] atomically:YES];
    }
    
    // Load response from file and clean up if download task failed.
    if ([request.responseObject isKindOfClass:[NSURL class]]) {
        NSURL *url = request.responseObject;
        if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            request.responseData = [NSData dataWithContentsOfURL:url];
            request.responseString = [[NSString alloc] initWithData:request.responseData encoding:[YJFNetworkUtils stringEncodingWithRequest:request]];
            
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        request.responseObject = nil;
    }
    

    @autoreleasepool {
        [request requestFailedPreprocessor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [request toggleAccessoriesWillStopCallBack];
        [request requestFailedFilter];

        
        if (request.delegate != nil) {
            [request.delegate requestDidFinishedFailed:request];
        }
        if (request.failureCompletionBlock) {
            request.failureCompletionBlock(request);
        }
        [request toggleAccessoriesDidStopCallBack];

    });
}

- (void)addRequestToRecord:(YJFBaseRequest *)request{
    
    Lock();
    _requestsRecord[@(request.requestTask.taskIdentifier)] = request;
    Unlock();
}

- (void)removeRequestFromRecord:(YJFBaseRequest *)request {
    Lock();
    [_requestsRecord removeObjectForKey:@(request.requestTask.taskIdentifier)];
    YJFNetLog(@"Request queue size = %zd", [_requestsRecord count]);
    Unlock();
}

#pragma mark - 根据请求方法分发给相应类型的NSURLSessionTask
// 根据不同的请求方法获取NSURLSessionTask
- (NSURLSessionTask *)sessionTaskForRequest:(YJFBaseRequest *)request error:(NSError *_Nullable __autoreleasing *)error{
    
    // 获取YJFBaseRequest中信息 如果子类重写了该方法就从子类中获取
    NSString *url = [self buildRequestUrl:request];
    
    YJFRequestMethod requestMethod = request.requestMethod;
    
    AFConstructingBlock constructingBlock = [request constructingBodyBlock];
    
    AFURLSessionTaskProgressBlock downloadProgressBlock = request.resumableDownloadProgressBlock;
    
    AFURLSessionTaskProgressBlock uploadProgressBlock = request.uploadProgressBlock;

    
    NSDictionary *parameters = request.requestParameters ? :[NSDictionary new];
    // 参数加密回调
    NSArray *filters = [_config requestParametersFilters];
    for (id<YJFRequestParametersFilterProtocol> f in filters) {
       
        parameters = [f filterParameters:request.requestParameters withRequest:request];
    }
    
    // 设置AF请求解析器
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerForRequest:request];
    

    switch (requestMethod) {
            // 这里的方法 相当于越过了AFHTTPSessionManager中的常用的几个请求方法 而是直接走的AFURLSessionManager中的dataTaskWithRequest:方法
        case YJFRequestMethodGET:{
            
            if (request.resumableDownloadPath) {
                
                return [self downloadTaskWithDownloadPath:request.resumableDownloadPath
                                      requestMethodString:@"GET"
                                        requestSerializer:requestSerializer
                                                URLString:url
                                                 progress:downloadProgressBlock
                                               parameters:parameters error:error];
                
            } else {
                
                return [self dataTaskWithHTTPMethod:@"GET"
                                  requestSerializer:requestSerializer
                                          URLString:url
                                         parameters:parameters
                                              error:error];
            }
        }
            break;
            
        case YJFRequestMethodPOST:{
            
            if (request.resumableDownloadPath) {
                
                return [self downloadTaskWithDownloadPath:request.resumableDownloadPath
                                      requestMethodString:@"POST"
                                        requestSerializer:requestSerializer
                                                URLString:url
                                                 progress:downloadProgressBlock
                                               parameters:parameters error:error];
            } else {
        
                return [self dataTaskWithHTTPMethod:@"POST"
                                  requestSerializer:requestSerializer
                                          URLString:url
                                         parameters:parameters
                                           progress:uploadProgressBlock
                          constructingBodyWithBlock:constructingBlock
                                              error:error];
            }
        }
            break;
            
        case YJFRequestMethodHEAD:{
            
            return [self dataTaskWithHTTPMethod:@"HEAD" requestSerializer:requestSerializer URLString:url parameters:parameters error:error];
            
        }
            break;
            
        case YJFRequestMethodPUT:{
            
//            return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:parameters error:error];
            
            if (request.fileUrl) {
                // 目前的服务器 不支持PUT 需要配置WebDav服务器
                return [self uploadTaskFromFile:request.fileUrl requestSerializer:requestSerializer URLString:url progress:uploadProgressBlock parameters:parameters error:error];
            } else {
                return [self dataTaskWithHTTPMethod:@"PUT" requestSerializer:requestSerializer URLString:url parameters:parameters error:error];
            }
            
            
        }
            break;
        case YJFRequestMethodDELETE:{
            
            return [self dataTaskWithHTTPMethod:@"DELETE" requestSerializer:requestSerializer URLString:url parameters:parameters error:error];
            
        }
            break;
            
        case YJFRequestMethodPATCH:{
            
            return [self dataTaskWithHTTPMethod:@"PATCH" requestSerializer:requestSerializer URLString:url parameters:parameters error:error];
            
        }
            break;
            
        default:
            break;
    }

    
}


#pragma mark - 获取并设置requestSerializer
// 设置AF的请求解析器
- (AFHTTPRequestSerializer *)requestSerializerForRequest:(YJFBaseRequest *)request{

    // 将YJFBaseRequest相当于是AFHTTPRequestSerializer的数据模型
    // AFHTTPRequestSerializer是NSURLRequset的数据模型
    AFHTTPRequestSerializer *requestSerializer = nil;
    
    if (request.requestSerializerType == YJFRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (request.requestSerializerType == YJFRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
 
    requestSerializer.timeoutInterval = request.requestTimeoutInterval;
    requestSerializer.allowsCellularAccess = request.allowsCellularAccess;
    

    // If api needs server username and password
    // 需要服务器账号和密码
    NSArray<NSString *> *authorizationHeaderFieldArray = [request requestAuthorizationHeaderFieldArray];
    if (authorizationHeaderFieldArray != nil) {
        [requestSerializer setAuthorizationHeaderFieldWithUsername:authorizationHeaderFieldArray.firstObject
                                                          password:authorizationHeaderFieldArray.lastObject];
    }

    
    // If api needs to add custom value to HTTPHeaderField
    // 设置请求头HTTPHeader
    NSDictionary <NSString *, NSString *> *headerFieldValueDictionary = [request requestHeaderFieldValueDictionary] ? : [NSDictionary new];
    
    // requestHeader统一处理回调
    NSArray *filters = [_config requestHeaderFilters];
    for (id<YJFRequestHeaderFilterProtocol>f in filters) {
        headerFieldValueDictionary = [f filterHeaders:headerFieldValueDictionary withRequest:request];
    }
    
    if (headerFieldValueDictionary != nil) {
        for (NSString *httpHeaderField in headerFieldValueDictionary.allKeys) {
            NSString *value = headerFieldValueDictionary[httpHeaderField];
            [requestSerializer setValue:value forHTTPHeaderField:httpHeaderField];
        }
    }
    
    return requestSerializer;
}


#pragma mark - 创建NSURLSessionTask任务和开启

// NSURLSessionDataTask
- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                             requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                     URLString:(NSString *)URLString
                                    parameters:(id)parameters
                                         error:(NSError *__autoreleasing *)error{

    
    return [self dataTaskWithHTTPMethod:method requestSerializer:requestSerializer URLString:URLString parameters:parameters progress:nil constructingBodyWithBlock:nil error:error];
}



// 使用multipart/form-data(POST)一般的上传都能搞定
- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                               requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                        progress:(nullable void(^)(NSProgress *downloadProgress))uploadProgressBlock
                       constructingBodyWithBlock:(nullable void (^)(id <AFMultipartFormData> formData))block
                                           error:(NSError * _Nullable __autoreleasing *)error {
    NSMutableURLRequest *urlRequest = nil;
    
    // https://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.2  multipart/form-data
    // 使用传入解析器 解析为NSURLRequest（该方法是AFURLRequestSerialization提供的方法）
    if (block) {
        // 有FormData请求（表单提交）
        urlRequest = [requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:parameters constructingBodyWithBlock:block error:error];
    } else {
        // 普通请求
        urlRequest = [requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:error];
    }
    // 使用dataTaskWithRequest发起请求
    __block NSURLSessionDataTask *dataTask = nil;

    
    // 采用Post方式上传 文件上传大小服务器配置限制
    dataTask = [_manager dataTaskWithRequest:urlRequest uploadProgress:uploadProgressBlock downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
       
        [self handleRequestResult:dataTask responseObject:responseObject error: error];
    }];
    
    //    dataTask = [_manager uploadTaskWithStreamedRequest:urlRequest progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
    //        [self handleRequestResult:dataTask responseObject:responseObject error: error];
    //    }];

    
    return dataTask;
}

// NSURLSessionUploadTask

- (NSURLSessionUploadTask *)uploadTaskFromFile:(NSURL *)fileUrl
                                     requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                             URLString:(NSString *)URLString
                                              progress:(nullable void(^)(NSProgress *uploadProgress))uploadProgressBlock
                                            parameters:(id)parameters
                                                 error:(NSError *__autoreleasing *)error{
    
        NSMutableURLRequest *urlRequest = nil;
        urlRequest = [requestSerializer requestWithMethod:@"PUT" URLString:URLString parameters:parameters error:error];
        
        __block NSURLSessionUploadTask *dataTask = nil;

        dataTask =  [_manager uploadTaskWithRequest:urlRequest fromFile:fileUrl progress:uploadProgressBlock completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            
            [self handleRequestResult:dataTask responseObject:responseObject error: error];
        }];
    
        return dataTask;
}



// NSURLSessionDownloadTask
- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(NSString *)downloadPath
                                       requestMethodString:(NSString *)requestMethodString
                                         requestSerializer:(AFHTTPRequestSerializer *)requestSerializer
                                                 URLString:(NSString *)URLString
                                                  progress:(nullable void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                                parameters:(id)parameters
                                                     error:(NSError *__autoreleasing *)error{
    
    // 构建NSURLRequest
    NSMutableURLRequest *urlRequest = [requestSerializer requestWithMethod:requestMethodString URLString:URLString parameters:parameters error:error];
    

    NSString *downloadTargetPath;
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    // If targetPath is a directory, use the file name we got from the urlRequest.
    // Make sure downloadTargetPath is always a file, not directory.
    // 用的是GET请求下载 可以通过URL中的最后一部分获取文件名 但是如果是POST那就没发获取正确的名字了
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[downloadPath, fileName]];
    } else {
        downloadTargetPath = downloadPath;
    }
    // 不让传文件夹
    NSAssert(!isDirectory, @"目标路径不能是文件夹！！！");
    
    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    // https://github.com/AFNetworking/AFNetworking/issues/3775

    
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }
    
    __block NSURLSessionDownloadTask *downloadTask = nil;
    
    
    BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self incompleteDownloadTempPathForDownloadPath:downloadPath].path];
    NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:downloadPath]];
    BOOL resumeDataIsValid = [YJFNetworkUtils validateResumeData:data];
    
    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
    
    // 只有GET请求才断点下载(具体请看NSURLSessionDownloadTask)
    if (![requestMethodString isEqualToString:@"GET"]) {
        canBeResumed = NO;
    }
    BOOL resumeSucceeded = NO;
    
    
    // Try to resume with resumeData.
    // Even though we try to validate the resumeData, this may still fail and raise excecption.
    // 断点续传这里的问题比较多 目前只适合单个文件的断点续传如果是下载多个文件就找不到各自的resumeData了
    // https://github.com/yuantiku/YTKNetwork/issues/347
    if (canBeResumed) {
        @try {
            // 断点下载
            downloadTask = [_manager
                            downloadTaskWithResumeData:data
                            progress:downloadProgressBlock
                            destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                    return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
                            }
                            completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                
                                    [self handleRequestResult:downloadTask responseObject:filePath error:error];
                            }];
            
            resumeSucceeded = YES;
            
        } @catch (NSException *exception) {
            
            YJFNetLog(@"Resume download failed, reason = %@", exception.reason);
            resumeSucceeded = NO;
        }
    }
    
    if (!resumeSucceeded) {
        
        // 使用downloadTask进行下载任务 NSURLSession会将服务端的response.data写到一个临时文件中这样内存不会爆增加(相当于NSURLSession的处理了)
        // 如果使用普通的dataTask进行下载 内存会爆炸,因为AF内部在内存中将data拼接了起来的
        downloadTask = [_manager
                        downloadTaskWithRequest:urlRequest
                        progress:downloadProgressBlock
                        destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                            
                                return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
                        }
                        completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                            
                            
                            YJFNetLog(@"filePath:%@  response:%@  error:%@ ",filePath,response,error);
                            
                            [self handleRequestResult:downloadTask responseObject:filePath error:error];
                        }];
    }
    return downloadTask;


}

#pragma mark - Resumable Download


- (NSString *)incompleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;
    
    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kYJFNetworkIncompleteDownloadFolderName];
    }
    
    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        YJFNetLog(@"Failed to create cache directory at %@", cacheFolder);
        cacheFolder = nil;
    }
    return cacheFolder;
}

- (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLString = [YJFNetworkUtils md5StringFromString:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}



@end
