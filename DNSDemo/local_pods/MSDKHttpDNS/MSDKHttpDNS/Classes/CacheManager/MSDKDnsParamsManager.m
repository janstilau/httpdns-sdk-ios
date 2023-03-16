/**
 * Copyright (c) Tencent. All rights reserved.
 */

#import "MSDKDnsParamsManager.h"
#import "MSDKDnsInfoTool.h"
#import "MSDKDnsPrivate.h"
#import "MSDKDnsLog.h"
#if defined(__has_include)
    #if __has_include("httpdnsIps.h")
        #include "httpdnsIps.h"
    #endif
#endif

/*
 这就是一个纯纯的数据类, 在进行数据改变的时候, 有着线程控制.
 */
@interface MSDKDnsParamsManager()

@property (strong, nonatomic, readwrite) NSString * msdkDnsIp;
@property (strong, nonatomic, readwrite) NSString * msdkDnsOpenId;
@property (strong, nonatomic, readwrite) NSString * msdkDnsAppId;
@property (strong, nonatomic, readwrite) NSString * msdkDnsToken;
@property (assign, nonatomic, readwrite) int msdkDnsId;
@property (strong, nonatomic, readwrite) NSString * msdkDnsKey;
@property (assign, nonatomic, readwrite) int msdkDnsTimeOut;
@property (assign, nonatomic, readwrite) HttpDnsEncryptType msdkEncryptType;
@property (strong, nonatomic, readwrite) NSString *msdkDnsRouteIp;
@property (assign, nonatomic, readwrite) BOOL httpOnly;
@property (strong, nonatomic, readwrite) NSArray* serverArray;
@property (assign, nonatomic, readwrite) NSUInteger retryTimesBeforeSwitchServer;
@property (assign, nonatomic, readwrite) NSUInteger minutesBeforeSwitchToMain;
@property (strong, nonatomic, readwrite) NSArray * backupServerIps;
@property (assign, nonatomic, readwrite) BOOL enableReport;
@property (strong, nonatomic, readwrite) NSArray* preResolvedDomains;
@property (assign, nonatomic, readwrite) HttpDnsAddressType msdkAddressType;
@property (strong, nonatomic, readwrite) NSArray* keepAliveDomains;
@property (strong, nonatomic, readwrite) NSDictionary* IPRankData;
@property (assign, nonatomic, readwrite) BOOL enableKeepDomainsAlive;
@property (assign, nonatomic, readwrite) BOOL expiredIPEnabled;
@property (assign, nonatomic, readwrite) BOOL persistCacheIPEnabled;

@end

@implementation MSDKDnsParamsManager

static MSDKDnsParamsManager * _sharedInstance = nil;

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[MSDKDnsParamsManager alloc] init];
    });
    return _sharedInstance;
}

- (id) init {
    if (self = [super init]) {
        _msdkDnsOpenId = HTTP_DNS_UNKNOWN_STR;
        _msdkDnsAppId = HTTP_DNS_UNKNOWN_STR;
        _retryTimesBeforeSwitchServer = 3;
        _minutesBeforeSwitchToMain = 10;
        _enableReport = NO;
        _msdkAddressType = HttpDnsAddressTypeAuto;
        _enableKeepDomainsAlive = YES;
        _expiredIPEnabled = NO;
    }
    return self;
}

#pragma mark - setter

// 这个值也是外界传入的. 也就是用户设置.
- (void)msdkDnsSetMDnsIp:(NSString *) msdkDnsIp {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkDnsIp = msdkDnsIp;
        self.serverArray = [NSArray arrayWithObjects:msdkDnsIp, nil];

        // 实际上, 可以有很多的 Ip 来当做 DNS 解析. 
        if (self.backupServerIps && [self.backupServerIps count] > 0) {
            self.serverArray = [self.serverArray arrayByAddingObjectsFromArray:self.backupServerIps];
        } else {
#ifdef httpdnsIps_h
            if (self.msdkEncryptType == HttpDnsEncryptTypeHTTPS) {
                self.serverArray = [self.serverArray arrayByAddingObjectsFromArray:httpsServerIps];
            } else {
                self.serverArray = [self.serverArray arrayByAddingObjectsFromArray:httpServerIps];
            }
#endif
        }
    });
}

- (void)msdkDnsSetMOpenId:(NSString *) mdnsOpenId {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkDnsOpenId = mdnsOpenId;
    });
}

- (void)msdkDnsSetMAppId:(NSString *) mdnsAppId MTimeOut:(int)mdnsTimeOut MEncryptType:(HttpDnsEncryptType)mdnsEncryptType
{
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkDnsAppId = mdnsAppId;
        self.msdkDnsTimeOut = mdnsTimeOut;
        self.msdkEncryptType = mdnsEncryptType;
    });
}

// 这些值都是用户主动设置过来的. 
- (void)msdkDnsSetMDnsId:(int) mdnsId MDnsKey:(NSString *)mdnsKey MToken:(NSString* )mdnsToken{
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkDnsId = mdnsId;
        self.msdkDnsKey = mdnsKey;
        self.msdkDnsToken = mdnsToken;
    });
}

- (void)msdkDnsSetRouteIp:(NSString *)routeIp {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkDnsRouteIp = routeIp;
    });
}

- (void)msdkDnsSetHttpOnly:(BOOL)httpOnly {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.httpOnly = httpOnly;
    });
}

// 设置切换ip之前重试次数
- (void)msdkDnsSetRetryTimesBeforeSwitchServer:(NSUInteger)times {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.retryTimesBeforeSwitchServer = times;
    });
}

// 设置切回主ip间隔时长
- (void)msdkDnsSetMinutesBeforeSwitchToMain:(NSUInteger)minutes {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.minutesBeforeSwitchToMain = minutes;
    });
}

// 设置备份ip
- (void)msdkDnsSetBackupServerIps: (NSArray *)ips {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.backupServerIps = ips;
        self.serverArray = [NSArray arrayWithObjects:self.msdkDnsIp, nil];
        self.serverArray = [self.serverArray arrayByAddingObjectsFromArray:ips];
    });
}

- (void)msdkDnsSetEnableReport: (BOOL)enableReport {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.enableReport = enableReport;
    });
}

- (void)msdkDnsSetPreResolvedDomains: (NSArray *)domains {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.preResolvedDomains = [domains copy];
    });
}

// 赋值的时候, 进行了队列控制.
- (void)msdkDnsSetAddressType: (HttpDnsAddressType)addressType {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.msdkAddressType = addressType;
    });
}

- (void)msdkDnsSetKeepAliveDomains: (NSArray *)domains {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.keepAliveDomains = [domains copy];
    });
}

- (void)msdkDnsSetIPRankData: (NSDictionary *)IPRankData {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.IPRankData = [IPRankData copy];
    });
}

- (void)msdkDnsSetEnableKeepDomainsAlive: (BOOL)enableKeepDomainsAlive {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        self.enableKeepDomainsAlive = enableKeepDomainsAlive;
    });
}

- (void)msdkDnsSetExpiredIPEnabled: (BOOL)enable {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
       self.expiredIPEnabled = enable;
    });
}

- (void)msdkDnsSetPersistCacheIPEnabled: (BOOL)enable {
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
       self.persistCacheIPEnabled = enable;
    });
}

// 但是 get 的时候, 其实都没有进行队列控制 .
#pragma mark - getter

- (BOOL)msdkDnsGetHttpOnly {
    return _httpOnly;
}

- (NSString *) msdkDnsGetMDnsIp {
    return _msdkDnsIp;
}

- (NSString *) msdkDnsGetMOpenId {
    return [_msdkDnsOpenId copy];
}

- (NSString *) msdkDnsGetMAppId {
    return [_msdkDnsAppId copy];
}

- (NSString *) msdkDnsGetMToken {
    return [_msdkDnsToken copy];
}

- (int) msdkDnsGetMDnsId {
    return _msdkDnsId;
}

- (NSString *) msdkDnsGetMDnsKey {
    return [_msdkDnsKey copy];
}

// 这里存储了获取 DNS 的最大时长. 
- (float) msdkDnsGetMTimeOut {
    float timeOut = 0;
    if (_msdkDnsTimeOut > 0) {
        timeOut = _msdkDnsTimeOut / 1000.0;
    } else {
        timeOut = 2.0;
    }
    return timeOut;
}

- (HttpDnsEncryptType)msdkDnsGetEncryptType
{
    return _msdkEncryptType;
}

- (NSString *)msdkDnsGetRouteIp {
    return _msdkDnsRouteIp;
}

- (NSArray *)msdkDnsGetServerIps {
    return _serverArray;
}

- (NSUInteger)msdkDnsGetRetryTimesBeforeSwitchServer {
    return _retryTimesBeforeSwitchServer;
}

- (NSUInteger)msdkDnsGetMinutesBeforeSwitchToMain {
    return _minutesBeforeSwitchToMain;
}

- (BOOL)msdkDnsGetEnableReport {
    return _enableReport;
}

- (NSArray *)msdkDnsGetPreResolvedDomains {
    return _preResolvedDomains;
}

- (HttpDnsAddressType)msdkDnsGetAddressType {
    return _msdkAddressType;
}

- (NSArray *)msdkDnsGetKeepAliveDomains {
    return _keepAliveDomains;
}

- (NSDictionary *)msdkDnsGetIPRankData {
    return _IPRankData;
}

- (BOOL)msdkDnsGetEnableKeepDomainsAlive {
    return _enableKeepDomainsAlive;
}

- (BOOL)msdkDnsGetExpiredIPEnabled {
    // _expiredIPEnabled 这个值就没有 YES 过, 所有这个方法就是返回 NO
    return _expiredIPEnabled;
}

- (BOOL)msdkDnsGetPersistCacheIPEnabled {
    return _persistCacheIPEnabled;
}
 
@end
