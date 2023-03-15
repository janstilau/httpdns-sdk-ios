/**
 * Copyright (c) Tencent. All rights reserved.
 */

#ifndef HttpsDnsResolver_h
#define HttpsDnsResolver_h

#import "MSDKDnsResolver.h"
#import "msdkdns_local_ip_stack.h"

@interface HttpsDnsResolver : MSDKDnsResolver

@property (nonatomic, assign) NSInteger statusCode;

- (void)startWithDomains:(NSArray *)domains TimeOut:(float)timeOut DnsId:(int)dnsId DnsKey:(NSString *)dnsKey NetStack:( MSDKDNS_TLocalIPStack)netStack encryptType:(NSInteger)encryptType;

@end

#endif /* HttpsResolver_h */
