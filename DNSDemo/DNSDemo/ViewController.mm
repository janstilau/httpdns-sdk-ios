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
    config->dnsIp = @"HTTPDNS 服务器IP";
    config->dnsId = 12;
    config->dnsKey = @"加密密钥";
    config->encryptType = HttpDnsEncryptTypeDES;
    config->debug = YES;
    config->timeout = 2000;
    config->routeIp = @"查询线路ip";
    [[MSDKDns sharedInstance] initConfig: config];
    
}


@end
