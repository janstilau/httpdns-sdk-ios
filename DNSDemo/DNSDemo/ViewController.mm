//
//  ViewController.m
//  DNSDemo
//
//  Created by liuguoqiang on 2023/3/15.
//

#import "ViewController.h"
#import <MSDKDns_C11/MSDKDns.h>
/*
 DES加密    支持中
 密钥
 EAUr0zW5
 
 AES加密    支持中
 密钥
 ULEK7rPGDaP788Eh
 
 HTTPS加密    支持中
 Token
 711886787
 
 标签
 应用名称    备注             iOS APPID               安卓 APPID        创建时间
 Yami    Yami 点餐系统    3246PPDWT0X92DYE    44T7XRWKTLWR0MFI    2023-03-15 14:30:42
 */

/*
 DES加密    支持中
 密钥
 EAUr0zW5
 
 AES加密    支持中
 密钥
 ULEK7rPGDaP788Eh
 
 HTTPS加密    支持中
 Token
 711886787
 
 
 应用名称    备注         iOS APPID           安卓 APPID            创建时间
 Wisdom    智慧教育    TPUY9Z8F73PNOLK8    F02OCLZCTI094YS3    2023-03-15 20:33:00
 */

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    DnsConfig *config = new DnsConfig();
    config->dnsIp = @"119.29.29.99";
    config->dnsId = 7330;
    config->token = @"711886787";
    config->encryptType = HttpDnsEncryptTypeHTTPS;
    config->debug = YES;
    config->addressType = HttpDnsAddressTypeDual;
    config->timeout = 2000;
//    config->routeIp = @"查询线路ip";
    [[MSDKDns sharedInstance] initConfig: config];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self asyncGet];
}

- (void)syncGet {
    NSArray *youdaoResult =  [[MSDKDns sharedInstance] WGGetHostByName:@"youdao.com"];
    NSLog(@"单个得到结果 %@", youdaoResult);
    
    NSDictionary *multiResult = [[MSDKDns sharedInstance] WGGetHostsByNames:@[@"hardware.youdao.com", @"youdao.com", @"qq.com"]];
    NSLog(@"多个得到结果 %@", multiResult);
}

- (void)asyncGet {
    [[MSDKDns sharedInstance] WGGetHostByNameAsync:@"hardware.youdao.com" returnIps:^(NSArray *ipsArray) {
        NSLog(@"异步获取单个结果, %@", ipsArray);
    }];
    
    [[MSDKDns sharedInstance] WGGetHostsByNamesAsync:@[@"hardware.youdao.com", @"youdao.com", @"qq.com"] returnIps:^(NSDictionary *ipsDictionary) {
        NSLog(@"异步获取多个结果, %@", ipsDictionary);
    }];
}


@end
