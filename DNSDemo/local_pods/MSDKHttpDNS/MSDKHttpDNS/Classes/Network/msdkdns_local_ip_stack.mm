// Tencent is pleased to support the open source community by making Mars available.
// Copyright (C) 2016 THL A29 Limited, a Tencent company. All rights reserved.

// Licensed under the MIT License (the "License"); you may not use this file except in 
// compliance with the License. You may obtain a copy of the License at
// http://opensource.org/licenses/MIT

// Unless required by applicable law or agreed to in writing, software distributed under the License is
// distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions and
// limitations under the License.


#include "msdkdns_local_ip_stack.h"
#include "../MSDKDnsLog.h"
#include <strings.h>
#include <errno.h>
#include <endian.h>
#include <unistd.h>

/*
 * Connect a UDP socket to a given unicast address. This will cause no network
 * traffic, but will fail fast if the system has no or limited reachability to
 * the destination (e.g., no IPv4 address, no IPv6 default route, ...).
 */
/*
 这段代码定义了一个名为 msdkdns_sockaddr_union 的联合体，它包含了三种不同类型的套接字地址结构：sockaddr、sockaddr_in 和 sockaddr_in6。此外，还定义了两个静态函数：msdkdns_test_connect() 和 msdkdns_have_ipv6()。

 函数 msdkdns_test_connect() 用于测试给定协议族（由参数 pf 指定）和套接字地址（由参数 addr 指定）是否能够成功建立连接。它首先使用 socket() 函数创建一个数据报套接字，然后使用 connect() 函数尝试建立连接。如果连接成功，则返回 1；否则返回 0。

 函数 msdkdns_have_ipv6() 用于测试当前系统是否支持 IPv6 协议。它首先创建一个 IPv6 套接字地址结构，并将其初始化为指向一个特定的 IPv6 地址（即 [0x20::]）。然后，它使用前面定义的联合体将该地址转换为通用套接字地址，并调用 msdkdns_test_connect() 函数测试是否能够成功建立连接。如果能够成功建立连接，则返回 1；否则返回 0。

 类似地，函数 msdkdns_have_ipv4() 用于测试当前系统是否支持 IPv4 协议。它与上面的函数类似，只是将 IPv6 地址替换为了一个特定的 IPv4 地址（即 8.8.8.8）。
 */
static const unsigned int kMaxLoopCount = 10;

typedef union msdkdns_sockaddr_union {
    struct sockaddr msdkdns_generic;
    struct sockaddr_in msdkdns_in;
    struct sockaddr_in6 msdkdns_in6;
} msdkdns_sockaddr_union;


static int msdkdns_test_connect(int pf, struct sockaddr * addr, size_t addrlen) {
    int s = socket(pf, SOCK_DGRAM, IPPROTO_UDP);
    if (s < 0) {
        return 0;
    }
    int ret;
    unsigned int loop_count = 0;
    do {
        ret = connect(s, addr, addrlen);
    } while(ret < 0 && errno == EINTR && loop_count++ < kMaxLoopCount);
    if (loop_count >= kMaxLoopCount) {
        MSDKDNSLOG(@"connect error. loop_count = %d", loop_count);
    }
    int success = (ret == 0);
    loop_count = 0;
    do {
        ret = close(s);
    } while(ret < 0 && errno == EINTR && loop_count++ < kMaxLoopCount);
    if (loop_count >= kMaxLoopCount) {
        MSDKDNSLOG(@"close error. loop_count = %d", loop_count);
    }
    return success;
}

static int msdkdns_have_ipv6() {
    static struct sockaddr_in6 sin6_test = {0};
    sin6_test.sin6_family = AF_INET6;
    sin6_test.sin6_port = 80;
    sin6_test.sin6_flowinfo = 0;
    sin6_test.sin6_scope_id = 0;
    bzero(sin6_test.sin6_addr.s6_addr, sizeof(sin6_test.sin6_addr.s6_addr));
    sin6_test.sin6_addr.s6_addr[0] = 0x20;
    // union
    msdkdns_sockaddr_union addr = {.msdkdns_in6 = sin6_test};
    return msdkdns_test_connect(PF_INET6, &addr.msdkdns_generic, sizeof(addr.msdkdns_in6));
}

static int msdkdns_have_ipv4() {
    static struct sockaddr_in sin_test = {0};
    sin_test.sin_family = AF_INET;
    sin_test.sin_port = 80;
    sin_test.sin_addr.s_addr = htonl(0x08080808L); // 8.8.8.8
    // union
    msdkdns_sockaddr_union addr = {.msdkdns_in = sin_test};
    return msdkdns_test_connect(PF_INET, &addr.msdkdns_generic, sizeof(addr.msdkdns_in));
}


/*
 * The following functions determine whether IPv4 or IPv6 connectivity is
 * available in order to implement AI_ADDRCONFIG.
 *
 * Strictly speaking, AI_ADDRCONFIG should not look at whether connectivity is
 * available, but whether addresses of the specified family are "configured
 * on the local system". However, bionic doesn't currently support getifaddrs,
 * so checking for connectivity is the next best thing.
 */

MSDKDNS_TLocalIPStack  msdkdns_detect_local_ip_stack() {
    MSDKDNSLOG(@"detect local ip stack");
    int have_ipv4 = msdkdns_have_ipv4();
    int have_ipv6 = msdkdns_have_ipv6();
    int local_stack = 0;
    if (have_ipv4) {
        local_stack |=  MSDKDNS_ELocalIPStack_IPv4;
    }
    if (have_ipv6) {
        local_stack |=  MSDKDNS_ELocalIPStack_IPv6;
    }
    MSDKDNSLOG(@"have_ipv4:%d have_ipv6:%d", have_ipv4, have_ipv6);
    return ( MSDKDNS_TLocalIPStack) local_stack;
}
