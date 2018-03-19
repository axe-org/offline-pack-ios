# offline-pack-ios

offline-package manager module in iOS 

## iOS 离线包管理模块

对接 [offline-pack-server](https://github.com/CodingForMoney/offline-pack-server)

提供基础的 检测更新、下载差分、签名校验等功能。

## 示例：

通过 `Cocoapods`引入 ：

	pod 'OfflinePackage'
	
示例代码：

	[OPOfflineManager sharedManager].buildInModules = @[@"23734cd52ad4a4fb877d8a1e26e5df5f.zip"];
    [[OPOfflineManager sharedManager] setUpWithPublicPKCS8Pem:@"-----BEGIN PUBLIC KEY-----\r\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4YXOMN8CxfZqDy2lpV+kbUgE4knWCG4k0M5/+lzOoEWl9eoohXw0Ln3dY0Cjx2EGsVCR5KzZVIfjRCiyQwdd8QYpmXwkXwbSq4hLtRPMN/411WN/zTgycaDEXlgqz5YZ3RReQzdzqj/KkLvwjFvaW6Q57CeEM52VaRhtYzMIU0WJuUwhsDKODg8jYzAOp3n+gKdUToOGiC/wG9HyU/0qt37gA/eHgRjOUcNJ1KT085+ddTGKHyopN+cTtNQ0nq+nzj5ZhF3Zl6iQ92JWSV9ERE62CvX+dPnyVWjOc/1jmcDgcaejJldFGLc2DjRMn148LM93kLDeCw35vhZTQeS+AwIDAQAB-----END PUBLIC KEY-----" baseURL:@"http://localhost:2677/app/"];
    OPOfflineModule *module = [[OPOfflineManager sharedManager] moduleForName:@"abc"];
    if (module.needCheckUpdate) {
        module.delegate = self;
    }else {
    	NSLog(@"path : %@",module.path);
    }
    
详细使用与接入，请参考[axe]()项目