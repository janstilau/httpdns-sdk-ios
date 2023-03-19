/**
 * Copyright (c) Tencent. All rights reserved.
 */

#import "MSDKDnsTCPSpeedTester.h"
#import "MSDKDnsParamsManager.h"
#import "MSDKDnsLog.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <fcntl.h>
#import <arpa/inet.h>
#import <netdb.h>
#include <sys/time.h>

static NSString *const testSpeedKey = @"testSpeed";
static NSString *const ipKey = @"ip";

@implementation MSDKDnsTCPSpeedTester

/**
 *
 - IP池在2个到9个范围内，才进行测速逻辑。
 -
 */
- (NSArray<NSString *> *)ipRankingWithIPs:(NSArray<NSString *> *)IPs host:(NSString *)host {
    if (!IPs || !host) {
        return nil;
    }
    if (IPs.count < 2 || IPs.count > 9) {
        return nil;
    }
    
    NSDictionary *dataSource = [[MSDKDnsParamsManager shareInstance] msdkDnsGetIPRankData];
    NSArray *allHost = [dataSource allKeys];
    if (!allHost || allHost.count == 0) {
        return nil;
    }
    if (![allHost containsObject:host]) {
        return nil;
    }
    
    int16_t port = 80; // 默认就是 80 了.
    @try {
        id port_ = dataSource[host];
        port = [port_ integerValue];
    } @catch (NSException *exception) {}
    
    NSMutableArray<NSDictionary *> *IPSpeeds = [NSMutableArray arrayWithCapacity:IPs.count];
    for (NSString *ip in IPs) {
        float testSpeed =  [self testSpeedOf:ip port:port];
        MSDKDNSLOG(@"%@:%hd speed is %f",ip,port,testSpeed);
        if (testSpeed == 0) {
            testSpeed = MSDKDns_SOCKET_CONNECT_TIMEOUT_RTT;
        }
        NSMutableDictionary *IPSpeed = [NSMutableDictionary dictionaryWithCapacity:2];
        [IPSpeed setObject:@(testSpeed) forKey:testSpeedKey];
        [IPSpeed setObject:ip forKey:ipKey];
        [IPSpeeds addObject:IPSpeed];
    }
    
    NSArray *sortedIPSpeedsArray = [IPSpeeds sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSNumber *data1 = [NSNumber numberWithFloat:[[obj1 valueForKey:testSpeedKey] floatValue]];
        NSNumber *data2 = [NSNumber numberWithFloat:[[obj2 valueForKey:testSpeedKey] floatValue]];
        return [data1 compare:data2];
    }];
    
    NSMutableArray<NSString *> *sortedArrayIPs = [NSMutableArray arrayWithCapacity:IPs.count];
    for (NSDictionary *dict in sortedIPSpeedsArray) {
        NSString *ip = [dict objectForKey:ipKey];
        [sortedArrayIPs addObject:ip];
    }
    //保证数量一致，
    if (sortedArrayIPs.count == IPs.count) {
        return [sortedArrayIPs copy];
    }
    return nil;
}

/**
 *  @return 测速结果，单位时毫秒，MSDKDns_SOCKET_CONNECT_TIMEOUT_RTT 代表超时。
 */
/*
 这段代码是用来测量连接到指定IP地址和端口的时间
 。
 它创建一个套接字并尝试连接到指定的IP地址和端口。连接时间被记录并返回作为往返时间（RTT）。如果连接超时，则返回预定义的超时RTT值。
 
 当然。这段代码首先创建一个套接字，然后使用 connect 函数尝试连接到指定的IP地址和端口。如果连接成功，connect 函数将返回0，并且代码将关闭套接字并返回1。
 
 如果连接不成功，则代码将使用 select 函数等待连接完成或超时。如果 select 函数返回0，则表示连接超时，代码将关闭套接字并返回预定义的超时RTT值。
 
 如果 select 函数返回一个正值，则表示连接已完成。
 代码将使用 getsockopt 函数检查是否有错误。如果没有错误，则计算连接时间并将其作为RTT值返回。否则，代码将关闭套接字并返回0。
 
 
 
 
 
 
 客户端调用 connect() 发起对服务端的 socket 连接，
 如果客户端的 socket 描述符为阻塞模式，则 connect() 会阻塞到连接建立成功或连接建立超时
 （Linux 内核中对 connect 的超时时间限制是 75s， Soliris 9 是几分钟，因此通常认为是 75s 到几分钟不等）。
 如果为非阻塞模式，则调用 connect() 后函数立即返回，
 如果连接不能马上建立成功（返回 -1），则 errno 设置为 EINPROGRESS，此时 TCP 三次握手仍在继续。
 此时可以调用 select() 检测非阻塞 connect 是否完成。
 select 指定的超时时间可以比 connect 的超时时间短，因此可以防止连接线程长时间阻塞在 connect 处。

 select 判断规则：
 1）如果 select() 返回 0，表示在 select() 超时，超时时间内未能成功建立连接，
 也可以再次执行 select() 进行检测，如若多次超时，需返回超时错误给用户。

 2）如果 select() 返回大于 0 的值，则说明检测到可读或可写的套接字描述符。
 源自 Berkeley 的实现有两条与 select 和非阻塞 I/O 相关的规则：
     A) 当连接建立成功时，套接口描述符变成 可写（连接建立时，写缓冲区空闲，所以可写）
     B) 当连接建立出错时，套接口描述符变成 既可读又可写（由于有未决的错误，从而可读又可写）
 
 从上面的描述可以看出, select 可以设置等待时间. 而阻塞式的需要建立连接完成之后才返回.
 */
- (float)testSpeedOf:(NSString *)ip port:(int16_t)port {
    NSString *oldIp = ip;
    //request time out
    float rtt = 0.0;
    
    //sock：将要被设置或者获取选项的套接字。
    int s = 0;
    struct sockaddr_in saddr;
    saddr.sin_family = AF_INET;
    saddr.sin_port = htons(port); // htons 主要是进行地址转化的.
    saddr.sin_addr.s_addr = inet_addr([ip UTF8String]); // 套接字的地址.
    if( (s = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        MSDKDNSLOG(@"ERROR:%s:%d, create socket failed.",__FUNCTION__,__LINE__);
        return 0;
    }
    
    NSDate *startTime = [NSDate date];
    NSDate *endTime;
    // 最终, 是通过这两个值来完成的计算.
    
    //为了设置connect超时 把socket设置称为非阻塞
    int flags = fcntl(s, F_GETFL,0);
    // #define F_SETFL         4               /* set file status flags */
    // s 返回了一个 socket 的句柄, 通过fcntl可以改变已打开的文件性质
    fcntl(s, F_SETFL, flags | O_NONBLOCK);
    int i = connect(s,(struct sockaddr*)&saddr, sizeof(saddr));
    if(i == 0) {
        //建立连接成功，返回rtt时间。 因为connect是非阻塞，所以这个时间就是一个函数执行的时间，毫秒级，没必要再测速了。
        close(s);
        return 1;
    }
    
    
    // tv 这里是在进行设置超时的时间.
    struct timeval tv;
    int valopt;
    socklen_t lon;
    tv.tv_sec = MSDKDns_SOCKET_CONNECT_TIMEOUT;
    tv.tv_usec = 0;
    
    fd_set myset;
    FD_ZERO(&myset);
    FD_SET(s, &myset);
    
    // MARK: - 使用select函数，对套接字的IO操作设置超时。
    /**
     select函数
     select是一种IO多路复用机制，它允许进程指示内核等待多个事件的任何一个发生，并且在有一个或者多个事件发生或者经历一段指定的时间后才唤醒它。
     connect本身并不具有设置超时功能，如果想对套接字的IO操作设置超时，可使用select函数。
     **/
    int maxfdp = s+1;
    int j = select(maxfdp, NULL, &myset, NULL, &tv);
    
    if (j == 0) {
        // 超时了, rtt 赋值为默认超时时间.
        MSDKDNSLOG(@"INFO:%s:%d, test rtt of (%@) timeout.",__FUNCTION__,__LINE__, oldIp);
        rtt = MSDKDns_SOCKET_CONNECT_TIMEOUT_RTT;
        close(s);
        return rtt;
    }
    
    if (j < 0) {
        // 出错了.
        MSDKDNSLOG(@"ERROR:%s:%d, select function error.",__FUNCTION__,__LINE__);
        rtt = 0;
        close(s);
        return rtt;
    }
    /**
     对于select和非阻塞connect，注意两点：
     [1] 当连接成功建立时，描述符变成可写； [2] 当连接建立遇到错误时，描述符变为即可读，也可写，遇到这种情况，可调用getsockopt函数。
     **/
    lon = sizeof(int);
    //valopt 表示错误信息。 getsockopt 用来进行是否出错的判断.
    getsockopt(s, SOL_SOCKET, SO_ERROR, (void*)(&valopt), &lon);
    if (valopt) {
        MSDKDNSLOG(@"ERROR:%s:%d, select function error.",__FUNCTION__,__LINE__);
        rtt = 0;
    } else {
        endTime = [NSDate date];
        rtt = [endTime timeIntervalSinceDate:startTime] * 1000;
    }
    close(s);
    return rtt;
}

@end
