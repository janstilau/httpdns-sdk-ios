#import "MSDKDnsNetworkManager.h"
#import "MSDKDnsLog.h"
#import "MSDKDnsInfoTool.h"
#import "MSDKDnsManager.h"
#import "MSDKDnsParamsManager.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <arpa/inet.h>

@interface MSDKDnsNetworkManager ()

@property (strong, nonatomic) MSDKDnsReachability *reachability;
@property (strong, nonatomic, readwrite) NSString *networkType;

@end

@implementation MSDKDnsNetworkManager

static MSDKDnsNetworkManager *manager = nil;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.reachability stopNotifier];
    [self setReachability:nil];
    [self setNetworkType:nil];
}

// 这个类方法, 其实就是触发单例的创建.
// 这其实是一个很常见的代码编写方式.
+ (void)start
{
    [MSDKDnsNetworkManager shareInstance];
}

+ (instancetype)shareInstance
{
    @synchronized(self)
    {
        if (!manager)
        {
            manager = [[MSDKDnsNetworkManager alloc] init];
        }
    }
    
    return manager;
}

- (instancetype)init
{
    @synchronized(self)
    {
        // 多线程环境下的 Double Check 机制.
        if (manager)
        {
            return manager;
        }
        
        if (self = [super init])
        {
            manager = self;
            
            [self setupObservers];
            _reachability = [MSDKDnsReachability reachabilityForInternetConnection];
            [_reachability startNotifier];
        }
        // 通过以上的监控, 至少在 APP 的相应事件, 完成了 IP 的刷新. 
        
        return self;
    }
}

- (void)setupObservers {
    // 在这里, 监听了网络连接状况的改变.
    [NSNotificationCenter.defaultCenter addObserverForName:kMSDKDnsReachabilityChangedNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *note)
     {
        // 这里的代码, 都是网络发生变化了做的情况.
        // 首先是清除缓存. 文档建议是, 网络发生变化, 直接清理, 不要复用.
        MSDKDNSLOG(@"Network did changed,clear MSDKDns cache");
        [[MSDKDnsManager shareInstance] clearAllCache];
        
        // 对保活域名发送解析请求
        // 然后是对保活的域名, 重新进行请求.
        // 每次发生网络变化, 都是重新刷新 Domain 的 Ip 地址.
        [self refreshAllKeepAliveDomains];
        //重置ip指针
        [[MSDKDnsManager shareInstance] switchToMainServer];
    }];
    
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *note)
     {
        BOOL expiredIPEnabled = [[MSDKDnsParamsManager shareInstance] msdkDnsGetExpiredIPEnabled];
        if (!expiredIPEnabled) {
            MSDKDNSLOG(@"Application did enter background,clear MSDKDns cache");
            //进入后台时清除缓存，暂停网络监测
            [[MSDKDnsManager shareInstance] clearAllCache];
        }
        [self.reachability stopNotifier];
    }];
    
    // 在重新进入前台后, 进行刷新. 
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillEnterForegroundNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *note)
     {
        //进入前台时，开启网络监测
        [self.reachability startNotifier];
        //对保活域名发送解析请求
        [self refreshAllKeepAliveDomains];
    }];
}

- (BOOL)networkAvailable
{
    float sys = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (sys >= 8.0) {
        if (self.reachability) {
            return self.reachability.currentReachabilityStatus != MSDKDnsNotReachable;
        } else {
            return NO;
        }
    } else {
        return [self is_networkAvaliable];
    }
}

static SCNetworkConnectionFlags ana_connectionFlags;
-(BOOL) is_networkAvaliable{
#ifdef ANA_UNIT_TEST
    return YES;
#else
    //	BOOL ignoreAdHocWiFi = NO;
    //	struct sockaddr_in ipAddress;
    //	bzero(&ipAddress, sizeof(ipAddress));
    //	ipAddress.sin_len = sizeof(ipAddress);
    //	ipAddress.sin_family = AF_INET;
    //	ipAddress.sin_addr.s_addr = htonl(ignoreAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
    //
    //	SCNetworkReachabilityRef defaultRouteReachablilty = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&ipAddress);
    SCNetworkReachabilityRef defaultRouteReachablilty = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.qq.com");
    // Determines if the specified network target is reachable using the current network configuration.
    // 使用 www.qq.com 来进行当前的网络判断. 屮.
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachablilty, &ana_connectionFlags);
    
    CFRelease(defaultRouteReachablilty);
    if(!didRetrieveFlags) {
        printf("Error. Could not recover flags\n");
    }
    BOOL isReachable = ((ana_connectionFlags & kSCNetworkFlagsReachable) != 0);
    BOOL needConnection = ((ana_connectionFlags & kSCNetworkFlagsConnectionRequired) != 0);
    return (isReachable && !needConnection) ? YES : NO;
#endif
}

- (MSDKDnsNetworkStatus)networkStatus
{
    if (self.reachability) {
        return self.reachability.currentReachabilityStatus;
    } else {
        return MSDKDnsNotReachable;
    }
}

- (NSString*)networkType{
#if TARGET_IPHONE_SIMULATOR
    return @"iphonesimulator";
#else
    NSString *networkType = @"unknown";
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        if (self.networkStatus == MSDKDnsReachableViaWiFi)
        {
            networkType = @"wifi";
            return networkType;
        }
    } else {
        if ([self activeWLAN]) {
            MSDKDNSLOG(@"The NetType is WIFI");
            return @"wifi";
        }
    }
    if ([self activeWWAN]) {
#ifdef __IPHONE_7_0
        //iOS7及以上版本可获取到，以下版本不获取
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
            NSString *networkModel = telephonyInfo.currentRadioAccessTechnology;
            if ([networkModel isEqualToString:CTRadioAccessTechnologyLTE]){
                networkType = @"4G";
            } else if ([networkModel isEqualToString:CTRadioAccessTechnologyGPRS] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyEdge]) {
                networkType = @"2G";
            } else if ([networkModel isEqualToString:CTRadioAccessTechnologyWCDMA] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyEdge] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyHSDPA] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyHSUPA] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyCDMA1x] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB] ||
                       [networkModel isEqualToString:CTRadioAccessTechnologyeHRPD]){
                networkType = @"3G";
            }
        }
#else
        else {
            networkType = @"3G";
            if ([GSDKInfoTool is2G]) {
                networkType = @"2G";
            }
        }
#endif
    }
    return networkType;
#endif
}

-(BOOL) activeWLAN {
    
    if (![self is_networkAvaliable]) return NO;
    return ([self localWiFiIPAddress] != nil) ? YES : NO;
}

-(BOOL) activeWWAN {
#ifdef ANA_UNIT_TEST
    return YES;
#else
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        if (self.networkStatus == MSDKDnsReachableViaWWAN)
        {
            return YES;
        } else {
            return NO;
        }
    }
    if (![self is_networkAvaliable]) return NO;
    return ((ana_connectionFlags & kSCNetworkReachabilityFlagsIsWWAN) != 0) ? YES : NO;
#endif
}

-(BOOL) is2G {
    if (![self is_networkAvaliable]) {
        return NO;
    }
    if ((ana_connectionFlags & kSCNetworkReachabilityFlagsIsWWAN) == 0) {
        return NO;
    }
    if((ana_connectionFlags & kSCNetworkReachabilityFlagsTransientConnection) == kSCNetworkReachabilityFlagsTransientConnection)  {
        return YES;
    }
    return NO;
}

-(NSString*) localWiFiIPAddress {
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    NSString * waddr = nil;
    
    success = (getifaddrs(&addrs) == 0);
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0) {
                NSString * name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"]) {//Wifi adapter
                    char addrNamev4[INET_ADDRSTRLEN];
                    const struct sockaddr_in * ipv4 = (const struct sockaddr_in *)cursor->ifa_addr;
                    waddr = [NSString stringWithUTF8String:inet_ntop(ipv4->sin_family, &(ipv4->sin_addr), addrNamev4, INET_ADDRSTRLEN)];
                }
            }
            else if (cursor->ifa_addr->sa_family == AF_INET6 && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
            {
                NSString * name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"]) {//Wifi adapter
                    char addrNamev6[INET6_ADDRSTRLEN];
                    const struct sockaddr_in6 * ipv6 = (const struct sockaddr_in6*)cursor->ifa_addr;
                    waddr = [NSString stringWithUTF8String:inet_ntop(ipv6->sin6_family, &(ipv6->sin6_addr), addrNamev6, INET6_ADDRSTRLEN)];
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return waddr;
}

// 当重新进入前台, 或者网络环境发生变化之后, 会调用到这里. 所以, 超时重新刷新的逻辑, 没有在库的内部, SDK 认为这是业务端应该完成的功能. 
- (void)refreshAllKeepAliveDomains{
    //对保活域名发送解析请求
    dispatch_async([MSDKDnsInfoTool msdkdns_queue], ^{
        NSArray *keepAliveDomains = [[MSDKDnsParamsManager shareInstance] allKeepAliveDomains];
        BOOL enableKeepDomainsAlive = [[MSDKDnsParamsManager shareInstance] shouldRefreshAllKeepAliveDomainIps];
        if (enableKeepDomainsAlive && keepAliveDomains && keepAliveDomains.count > 0) {
            [[MSDKDnsManager shareInstance] refreshCacheDelay:keepAliveDomains clearDispatchTag:NO];
        }
    });
}

@end
