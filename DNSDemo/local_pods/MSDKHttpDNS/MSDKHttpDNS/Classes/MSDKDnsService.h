/**
 * Copyright (c) Tencent. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "msdkdns_local_ip_stack.h"

@interface MSDKDnsService : NSObject

// 真正进行 Http 查询 ip 地址的服务.
// 里面包装的就是网络请求.
- (void)getHostByName:(NSString *)domain TimeOut:(float)timeOut DnsId:(int)dnsId DnsKey:(NSString *)dnsKey NetStack:( MSDKDNS_TLocalIPStack)netStack encryptType:(NSInteger)encryptType returnIps:(void (^)())handler;

- (void)getHostsByNames:(NSArray *)domains TimeOut:(float)timeOut DnsId:(int)dnsId DnsKey:(NSString *)dnsKey NetStack:( MSDKDNS_TLocalIPStack)netStack encryptType:(NSInteger)encryptType returnIps:(void (^)())handler;

@end
