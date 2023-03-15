//
//  ViewController.m
//  DNSDemo
//
//  Created by liuguoqiang on 2023/3/15.
//

#import "ViewController.h"
#import <MSDKDns_C11/MSDKDns.h>

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
