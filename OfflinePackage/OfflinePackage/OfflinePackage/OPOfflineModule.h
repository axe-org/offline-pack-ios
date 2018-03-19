//
//  OPOfflineModule.h
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import <Foundation/Foundation.h>


extern NSErrorDomain const OPDownloadErrorDomain;
NS_ERROR_ENUM(OPDownloadErrorDomain)
{
    OPDownloadError =                       -1, // 通用异常。
    OPDownloadErrorNetwork =                -2,//网络异常
    OPDownloadErrorServer =                 -3,//后台异常， 目前只有一个，即未找到模块。
    OPDownloadErrorDownload =               -4, // 下载包文件失败。
    OPDownloadErrorFileSystem =             -5, // 文件异常 ，可能是由于磁盘没有空间，导致文件操作异常。
    OPDownloadErrorPatchFailed =            -6, // bspatch 合成包失败，但更可能是磁盘空间问题。
    OPDownloadErrorUnzipFailed =            -7, // 解压失败。 可能是文件格式有问题，但更可能是磁盘空间问题。
    OPDownloadErrorSignature =              -8, // 签名校验失败。
    OPDownloadErrorUnknow =                 -1000 //未知异常。
};

@class OPOfflineModule;
/**
  模块强制更新时， 设置代理，以处理回调。
 */
@protocol OPOfflineDownloadDelegate<NSObject>


/**
  提供下载进度，以供外部展示

 @param module 当前下载模块
 @param progress 下载进度，为0->100的整数。
 进度说明 :
 10 : 检测更新
 20 : 接收到离线包
 20 - 70 : 下载离线包
 80 : 差分合成。
 90 : 解压到路径
 100 : 验证签名。
 */
- (void)module:(OPOfflineModule *)module didDownloadProgress:(NSInteger)progress;


/**
  下载完成。 内部会稍微处理一下， 保证 didDownloadProgress到100后，过0.1秒再完成。。。

 @param module 模块
 */
- (void)moduleDidFinishDownload:(OPOfflineModule *)module;


/**
  下载失败 。
 @param module 模块
 @param error  一般来说 会是网络错误。 然后可能是配置上的错误，如文件无法合成，或者签名验证失败。
 */
- (void)module:(OPOfflineModule *)module didFailLoadWithError:(NSError *)error;

@end




/**
  一个单独的离线包模块。
  当前可用的模块信息。
 */
@interface OPOfflineModule : NSObject


/**
 模块的名称
 */
@property (nonatomic,readonly,strong) NSString *name;


/**
 模块版本号
 */
@property (nonatomic,readonly,assign) NSInteger version;


/**
 主要的是路径 ， 其他的内容都不重要。
 */
@property (nonatomic,readonly,strong) NSString *path;



/**
 当需要检测更新时， 如旧的设置为 强制更新，或者当前获取到的设置为 强制更新， 或者没有本地包时。
 如果是其他形式的静默更新，则不会设置needCheckUpdate
 当检测到该选项后， 需要设置一个delegate ，弹出一个对话框，以处理下载进度。
 */
@property (nonatomic,readonly,assign) BOOL needCheckUpdate;


/**
  当需要检测更新时，需要设置 delegate ，以监听下载进度，展示进度条。
 */
@property (nonatomic,weak) id<OPOfflineDownloadDelegate> delegate;

@end
