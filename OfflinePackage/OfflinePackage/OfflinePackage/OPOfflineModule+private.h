//
//  OPOfflineModule.h
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPOfflineModule.h"


// 当本地模块找不到，或者未下载时， 都是强制更新，需要弹出下载框
typedef NS_ENUM(NSUInteger, OPOfflineModuleUpdateSetting) {
    OPOfflineModuleUpdateSettingDefault = 0, // 静态更新， 即检测到更新后，立即静默下载更新。
    OPOfflineModuleUpdateSettingOnlyUse = 1, // 只有在页面启动时，才进行更新。但是也是静默下载。
    OPOfflineModuleUpdateSettingForce = 2, // 强制更新， 在页面启动时， 如果需要检测更新，则会立即更新，且弹出阻断式弹框。
};

typedef NS_ENUM(NSUInteger, OPOfflineCheckState) {
    OPOfflineCheckStateWaiting = 0,// 正常的等待状态， 即没有检测更新时。
    OPOfflineCheckStateChecking, // 检测中
    OPOfflineCheckStateBeforeDownload,// 等待下载更新
    OPOfflineCheckStateDownloading, // 下载中。
};



/**
  私有接口。
 */
@interface OPOfflineModule () <NSURLSessionDelegate>


/**
  模块的名称
 */
@property (nonatomic,strong) NSString *name;

/**
  模块版本号
 */
@property (nonatomic,assign) NSInteger version;
/**
  主要的是路径 ， 其他的内容都不重要。
 */
@property (nonatomic,strong) NSString *path;
@property (nonatomic,strong) NSURL *url;
/**
  更新设置。 如果优先以网络返回值为准， 但是如果网络没有返回，则以本地为准。
 */
@property (nonatomic,assign) OPOfflineModuleUpdateSetting setting;

/**
  hash内容， 等待加载时校验哈希
 */
@property (nonatomic,strong) NSDictionary *md5Hashs;

#pragma mark - 判断

/**
 通过初始化的签名检测。
 加载时，才做签名校验，如果校验失败，则删除，重新请求服务器。
 */
@property (nonatomic,assign) BOOL verified;

/**
 当需要检测更新时， 如旧的设置为 强制更新，或者当前获取到的设置为 强制更新， 或者没有本地包时。
 如果是其他形式的静默更新，则不会设置needCheckUpdate
 当检测到该选项后， 需要设置一个delegate ，弹出一个对话框，以处理下载进度。
 */
@property (nonatomic,assign) BOOL needCheckUpdate;

/// 上次检测时间。
@property (nonatomic,strong) NSDate *lastCheckTime;

// 或者直接自己管理下载。
// 新版本号。
@property (nonatomic,assign) NSInteger newVersion;
// 下载URL
@property (nonatomic,strong) NSString *downloadURL;
/// 是否是补丁包，是否需要合成操作。
@property (nonatomic,assign) BOOL needPatch;
/**
   检测状态， 正常情况为0，即没有检测和下载任务。
 */
@property (nonatomic,assign) OPOfflineCheckState checkState;

/**
   开始检测
 */
- (void)startCheck;


/**
  开始下载
 */
- (void)startDownload;



/**
  现在使用session, 下载完成要进行释放。
 */
@property (nonatomic,strong) NSURLSession *downloadSession;

@property (nonatomic,strong) NSDate *lastProgressDate;
@end


extern NSString *const OfflinePackServerKeyError;
extern NSString *const OfflinePackServerKeyName;
extern NSString *const OfflinePackServerKeyVersion;
extern NSString *const OfflinePackServerKeyUpdateSetting;
extern NSString *const OfflinePackServerKeyDownloadURL;
extern NSString *const OfflinePackServerKeyPatchsInfo;
extern NSString *const OPOfflineLocalBackFileName;
