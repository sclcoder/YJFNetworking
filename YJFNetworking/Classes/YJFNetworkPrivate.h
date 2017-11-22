//
//  YJFNetworkPrivate.h
//  yunWallet
//
//  Created by 孙春磊 on 2017/9/8.
//  Copyright © 2017年 yunjifen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "YJFBaseRequest.h"
#import "YJFCacheableRequest.h"
#import "YJFBatchRequest.h"
#import "YJFChainRequest.h"
#import "YJFNetworkAgent.h"
#import "YJFNetworkConfig.h"


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void YJFNetLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

@interface YJFNetworkUtils : NSObject

+ (BOOL)validateJSON:(id)json withValidator:(id)jsonValidator;

+ (void)addDoNotBackupAttribute:(NSString *)path;

+ (NSString *)md5StringFromString:(NSString *)string;

+ (NSString *)appVersionString;

+ (NSStringEncoding)stringEncodingWithRequest:(YJFBaseRequest *)request;

+ (BOOL)validateResumeData:(NSData *)data;

@end

// 接口暴露的是readonly 现在写个setter分类 这个私有文件YJFNetworkPrivate就可以访问setter了
// 在这里增加的方法 最终会调用YJFBaseRequest相关的setter和getter这样就能访问成员变量了
@interface YJFBaseRequest (Setter)
// 使用分类添加方法（注意分类只能添加方法不会生成成员变量）
// 分类中使用@property只生成相关属性的setter和getter声明
@property (nonatomic, strong, readwrite) NSURLSessionTask *requestTask;
@property (nonatomic, strong, readwrite, nullable) NSData *responseData;
@property (nonatomic, strong, readwrite, nullable) id responseJSONObject;
@property (nonatomic, strong, readwrite, nullable) id responseObject;
@property (nonatomic, strong, readwrite, nullable) NSString *responseString;
@property (nonatomic, strong, readwrite, nullable) NSError *error;

@end




@interface YJFCacheableRequest (Getter)

- (NSString *)cacheBasePath;

@end

// 辅助工具
@interface YJFBaseRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack;
- (void)toggleAccessoriesWillStopCallBack;
- (void)toggleAccessoriesDidStopCallBack;

@end


@interface YJFBatchRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack;
- (void)toggleAccessoriesWillStopCallBack;
- (void)toggleAccessoriesDidStopCallBack;

@end

@interface YJFChainRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack;
- (void)toggleAccessoriesWillStopCallBack;
- (void)toggleAccessoriesDidStopCallBack;

@end




NS_ASSUME_NONNULL_END
