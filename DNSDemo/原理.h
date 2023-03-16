//
//  原理.h
//  DNSDemo
//
//  Created by liuguoqiang on 2023/3/15.
//

#ifndef ___h
#define ___h

/*
 
 客户端直接访问移动解析 HTTPDNS 接口，获取域名的最优 IP。（基于容灾考虑，建议保留使用运营商 LocalDNS 解析域名的方式作为备选。）
 客户端获取到业务 IP 后，直接向此 IP 发送业务协议请求。以 HTTP 请求为例，通过在 header 中指定 host 字段，向移动解析 HTTPDNS 返回的 IP 发送标准的 HTTP 请求即可。

 考虑到服务 IP 防攻击之类的安全风险，为保障服务可用性，我们同时提供多个服务 IP，如您直接通过 API 接口请求 HTTPDNS 服务，请加入 技术支持群 或者 提交工单 联系我们，我们将根据您的具体使用场景，为您提供多个服务 IP 和相关的安全建议。
 入口 IP 的切换逻辑：当接入 IP 访问超时，或者返回的结果非 IP 格式，或者返回为空的时候，请采用其他入口 IP 接入，若所有 IP 均出现异常，请兜底至 LocalDNS 进行域名解析。

 缓存策略
 移动互联网用户的网络环境比较复杂，为了尽可能地减少由于域名解析导致的延迟，建议在本地进行缓存。缓存规则如下：

 缓存时间：缓存时间建议设置为120s至600s，不可低于60s。
 缓存更新：
 缓存更新应在以下两种情形下进行：
 用户网络状态发生变化时：
 移动互联网用户的网络状态由3G切换 Wi-Fi，Wi-Fi 切换3G的情况下，其接入点的网络归属可能发生变化，用户的网络状态发生变化时，需要重新向 HTTPDNS 发起域名解析请求，以获得用户当前网络归属下的最优指向。
 缓存过期时：
 当域名解析的结果缓存时间到期时，客户端应该向 HTTPDNS 重新发起域名解析请求以获取最新的域名对应的 IP。为了减少用户在缓存过期后重新进行域名解析时的等待时间，建议在 75%TTL 时就开始进行域名解析。例如，本地缓存的 TTL 为600s，那么在第600 * 0.75 = 450s 时，客户端就应该进行域名解析。
 
 
 腾讯云建议:
 请尽量将不同功能用同样域名，资源区分通过 url 来实现，减少域名解析次数（用户体验好，容灾切换方便。多一个域名，即使域名已命中缓存，至少多100ms的访问延迟）。
 设置的缓存 TTL 值不可太低（不可低于60s），防止频繁进行 HTTPDNS 请求。
 接入移动解析 HTTPDNS 的业务需要保留用户本地 LocalDNS 作为容灾通道，当 HTTPDNS 无法正常服务时（移动网络不稳定或 HTTPDNS 服务出现问题），可以使用 LocalDNS 进行解析。
 Android 程序中可能出现404错误，但浏览器中正常，可能为权限问题或者其他问题。详情请参考 Android 请求返回 404。
 bytetohex&hextobyte，需自己实现接口，进行16进制字符串与字节的转换。
 HTTPS 问题，需在客户端 hook 客户端检查证书的 domain 域和扩展域看是否包含本次请求的 host 的过程，将 IP 直接替换成原来的域名，再执行证书验证。或者忽略证书认证，类似于 curl -k 参数。
 HTTPDNS 请求建议超时时间2 - 5s左右。
 在网络类型变化时，例如，4G切换到 Wi-Fi，不同 Wi-Fi 间切换等，需要重新执行 HTTPDNS 请求刷新本地缓存。
 
 
 */
#endif /* ___h */
