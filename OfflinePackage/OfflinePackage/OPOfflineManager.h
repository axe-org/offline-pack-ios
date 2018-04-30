//
//  OPOfflineManager.h
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPOfflineModule.h"

/**
  前缀是 OP  , 该类是主要接口。
 
  不支持包的撤销， 即一个包下载后， 撤销该包，只会阻止新的下载，并不会删掉本地的旧包。 只有提供了新的版本并下载完成后，才会删除旧包。
 
 */
@interface OPOfflineManager : NSObject



/**
  检测时间间隔， 默认为 10 分钟。  进入前后台时，检测全部模块。
  秒数。。
 */
@property (nonatomic,assign) NSTimeInterval checkTimeInterval;


/**
  支持跟随APP打包。 这里需要在setUp 方法调用之前，设置跟随APP打包的包的文件名。
  测试时需要注意， 只有APP升级版本号的情况下， 才会去加载这些本地包，以避免重复处理。
 
 */
@property (nonatomic,strong) NSArray<NSString *> *buildInModules;

/**
 单例
 */
+ (instancetype)sharedManager;


/**
  tags , 标签匹配
 */
@property (nonatomic,copy) NSArray<NSString *> *tags;


/**
  APP版本号，三段式， 默认获取Info.plist的版本号。
 */
@property (nonatomic,assign) NSString *appVersion;

/**
 初始化，加载本地数据，以及检测更新
 @param pubicPem 公钥字符串， pkcs8格式，即 BEGIN PUBLIC KEY 开头的。
 @param baseURL 服务器地址。 如 http://offline.luoxianming.cn/ 则两个请求的地址分别为 http://offline.luoxianming.cn/full 和 http://offline.luoxianming.cn/pack
 */
- (void)setUpWithPublicPKCS8Pem:(NSString *)pubicPem baseURL:(NSString *)baseURL;

/**
 获取 module

 @param name 模块名
 @return 模块， 需要验证模块是否需要检测更新。
 */
- (OPOfflineModule *)moduleForName:(NSString *)name;

@end
