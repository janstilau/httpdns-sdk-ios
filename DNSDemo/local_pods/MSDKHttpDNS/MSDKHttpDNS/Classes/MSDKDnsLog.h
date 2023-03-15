/**
 * Copyright (c) Tencent. All rights reserved.
 */

#import <Foundation/Foundation.h>

// 宏, 就是调用单例来进行使用. 
#ifndef MSDKDNSLOG
#define MSDKDNSLOG(xx, ...) [[MSDKDnsLog sharedInstance] msdkDnsLog:[NSString stringWithFormat:@"%s*** " xx, __PRETTY_FUNCTION__, ##__VA_ARGS__]]
#endif

@interface MSDKDnsLog : NSObject

@property (nonatomic,assign) BOOL enableLog;

+ (MSDKDnsLog *)sharedInstance;
- (void)msdkDnsLog:(NSString *)format;

@end
