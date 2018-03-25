//
//  OPOfflineManager.m
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import "OPOfflineManager.h"
#import "MXRSA.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import "OPOfflineModule+private.h"
#import "SSZipArchive.h"

NSString *const OfflinePackServerKeyError = @"error";
NSString *const OfflinePackServerKeyName = @"name";
NSString *const OfflinePackServerKeyVersion = @"version";
NSString *const OfflinePackServerKeyUpdateSetting = @"setting";
NSString *const OfflinePackServerKeyDownloadURL = @"download_url";
NSString *const OfflinePackServerKeyPatchsInfo = @"patch_urls";
NSString *const OPOfflineLocalBackFileName = @".axe-offline-pack";
@interface OPOfflineManager ()


/// 根目录
@property (nonatomic,strong) NSString *rootPath;

/// 缓冲路径
@property (nonatomic,strong) NSString *tmpPath;

/// 目录所在路径
@property (nonatomic,strong) NSString *mainPath;

@property (nonatomic,copy) NSString *publicPem;
@property (nonatomic,strong) NSURL *queryAllUrl;
@property (nonatomic,strong) NSURL *queryTaskUrl;

@property (nonatomic,strong) NSMutableDictionary<NSString *,OPOfflineModule *> *modules;

@property (nonatomic,strong) NSURLSession *session;

@property (nonatomic,strong) dispatch_queue_t queue;

@property (nonatomic,strong) NSDate *lastCheckTime;

@property (nonatomic,strong) NSFileManager *fileManager;

@end

@implementation OPOfflineManager

+ (instancetype)sharedManager {
    static OPOfflineManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[OPOfflineManager alloc] init];
        manager.checkTimeInterval = 600;
        manager.appID = @"abc";
        manager.appVersion = 1;
        manager.lastCheckTime = [NSDate dateWithTimeIntervalSince1970:0];
    });
    return manager;
}

- (void)setUpWithPublicPKCS8Pem:(NSString *)pubicPem baseURL:(NSString *)baseURL {
    NSParameterAssert([pubicPem isKindOfClass:[NSString class]]);
    NSParameterAssert([baseURL isKindOfClass:[NSString class]]);
    _publicPem = [pubicPem copy];
    NSURL *url = [NSURL URLWithString:baseURL];
    _queryAllUrl = [url URLByAppendingPathComponent:@"allPacks"];
    _queryAllUrl = [NSURL URLWithString:[[_queryAllUrl absoluteString] stringByAppendingFormat:@"?appID=%@&appVersion=%@",_appID,@(_appVersion)]];
    _queryTaskUrl = [url URLByAppendingPathComponent:@"pack"];
    _queryTaskUrl = [NSURL URLWithString:[[_queryTaskUrl absoluteString] stringByAppendingFormat:@"?appID=%@&appVersion=%@",_appID,@(_appVersion)]];
    // 进行初始化。
    [self initPath];
    // 检测 主路径下模块
    NSArray *subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_mainPath error:nil];
    NSMutableArray *moduleList = [[NSMutableArray alloc] initWithCapacity:subpaths.count];
    for (NSString *path in subpaths) {
        OPOfflineModule *module = [self checkModuleInPath:path];
        if (module) {
            [moduleList addObject:module];
        }
    }
    NSMutableDictionary *moduleMaps = [[NSMutableDictionary alloc] initWithCapacity:moduleList.count];
    // 删除旧版本。
    for (OPOfflineModule *module in moduleList) {
        OPOfflineModule *otherVersion = moduleMaps[module.name];
        if (otherVersion) {
            // 如果有其他版本，则检测两个版本，哪个版本更高。
            if (module.version > otherVersion.version) {
                [[NSFileManager defaultManager] removeItemAtPath:otherVersion.path error:nil];
                moduleMaps[module.name] = module;
            } else {
                [[NSFileManager defaultManager] removeItemAtPath:module.path error:nil];
            }
        } else {
            moduleMaps[module.name] = module;
        }
    }
    // 最后保存经过检验的包信息。
    _modules = moduleMaps;
    _queue = dispatch_queue_create("org.axe.offline-pack.queue", 0);
    
    // 在更新之前，再检测跟随APP打包情况。
    if (_buildInModules.count) {
        NSString *lastVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"axe-offline-pack-version-flag"];
        NSString *newVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        if (![newVersion isEqualToString:lastVersion]) {
            [_buildInModules enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self checkBuildInModule:obj];
            }];
            [[NSUserDefaults standardUserDefaults] setObject:newVersion forKey:@"axe-offline-pack-version-flag"];
            CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
        }
    }
    // 检测更新。
    [self checkUpdate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkUpdate) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkUpdate) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)initPath {
    // 初始化文件目录。
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPaths = [docPaths objectAtIndex:0];
    _rootPath = [documentPaths stringByAppendingPathComponent:@"axe_offline_package"];
    _fileManager = [NSFileManager defaultManager];
    if(![_fileManager fileExistsAtPath:_rootPath isDirectory:nil]) {
        [_fileManager createDirectoryAtPath:_rootPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    // 对于 tmp 目录， 每次启动的时候，都进行清空，以清理可能存在的出错文件。
    _tmpPath = [_rootPath stringByAppendingPathComponent:@"tmp"];
    [_fileManager removeItemAtPath:_tmpPath error:nil];
    [_fileManager createDirectoryAtPath:_tmpPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    _mainPath = [_rootPath stringByAppendingPathComponent:@"main"];
    if(![_fileManager fileExistsAtPath:_mainPath isDirectory:nil]) {
        [_fileManager createDirectoryAtPath:_mainPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
}

- (void)checkBuildInModule:(NSString *)moduleFileName {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:moduleFileName ofType:nil];
    if (!filePath) {
        return;
    }
    NSString *randomName = [NSUUID UUID].UUIDString;
    NSString *unzipPath = [_mainPath stringByAppendingPathComponent:randomName];
    if([SSZipArchive unzipFileAtPath:filePath toDestination:unzipPath]) {
        OPOfflineModule *module = [self checkModuleInPath:randomName];
        if (module) {
            // 检测本地是否有旧包
            OPOfflineModule *oldModule = [_modules objectForKey:module.name];
            if (module.version > oldModule.version) {
                // 如果打包版本号大于本地版本号，则更新替换。
                // 保存一份备份到目录下。
                NSString *backupPath = [module.path stringByAppendingPathComponent:OPOfflineLocalBackFileName];
                NSError *error;
                [_fileManager copyItemAtPath:filePath toPath:backupPath error:&error];
                if (error) {
                    NSLog(@"文件处理出错 ：%@",error);
                    [_fileManager removeItemAtPath:unzipPath error:nil];
                    return;
                }
                // 备份完成后，在更新记录。
                [_modules setObject:module forKey:module.name];
            } else {
                // 否则，表示打包版本较旧，需要删除。
                [_fileManager removeItemAtPath:unzipPath error:nil];
            }
        }
    }else {
        [_fileManager removeItemAtPath:unzipPath error:nil];
        NSLog(@"解压包失败！！");
    }
}

- (OPOfflineModule *)checkModuleInPath:(NSString *)path {
    // 检测指定路径下的 模块信息。
    path = [_mainPath stringByAppendingPathComponent:path];
    BOOL isDirectory = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
        // 是文件夹，则进行处理。
        NSString *signatureFile = [path stringByAppendingPathComponent:@".axe_pack_sign"];
        if (![fileManager fileExistsAtPath:signatureFile]) {
            NSLog(@"当前文件夹下没有签名文件， 删除该文件夹 %@",path);
            [fileManager removeItemAtPath:path error:nil];
            return nil;
        }
        // 读取签名文件
        NSData *sign = [NSData dataWithContentsOfFile:signatureFile];
        NSData *plainData = [MXRSA decryptData:sign usingPlulicKeyString:_publicPem];
        if (!plainData) {
            NSLog(@"签名文件验证失败， 删除文件夹 %@",path);
            [fileManager removeItemAtPath:path error:nil];
            return nil;
        }
        // 解析
        NSError *error;
        NSMutableDictionary *moduleInfo = [NSJSONSerialization JSONObjectWithData:plainData options:NSJSONReadingMutableContainers error:&error];
        if(error) {
            NSLog(@"签名文件验证失败， 删除文件夹 %@",path);
            [fileManager removeItemAtPath:path error:nil];
            return nil;
        }
        NSString *name = [moduleInfo objectForKey:OfflinePackServerKeyName];
        NSString *version = [moduleInfo objectForKey:OfflinePackServerKeyVersion];
        NSString *setting = [moduleInfo objectForKey:OfflinePackServerKeyUpdateSetting];
        OPOfflineModule *module = [[OPOfflineModule alloc] init];
        module.name = name;
        module.version = [version integerValue];
        module.setting = [setting integerValue];
        
        [moduleInfo removeObjectForKey:OfflinePackServerKeyName];
        [moduleInfo removeObjectForKey:OfflinePackServerKeyVersion];
        [moduleInfo removeObjectForKey:OfflinePackServerKeyUpdateSetting];
        module.md5Hashs = moduleInfo;
        module.path = path;
        module.url = [NSURL URLWithString:[@"file://" stringByAppendingString:path]];
        return module;
    }
    
    return nil;
}

- (NSURLSession *)session {
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    return _session;
}

- (void)checkUpdate {
    // 检测更新
    NSDate *checkTime = [NSDate date];
    if ([checkTime timeIntervalSinceDate:_lastCheckTime] < _checkTimeInterval) {
        // 检测时间间隔。
        return;
    }
    _lastCheckTime = checkTime;
    [[self.session dataTaskWithURL:_queryAllUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"检测更新网络异常 ： %@",error);
        } else {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                NSLog(@"后台数据解析失败 ！！！ %@", error);
            } else {
                NSString *serverError = [json objectForKey:OfflinePackServerKeyError];
                if (serverError) {
                    NSLog(@"后台返回异常 ： %@" ,serverError);
                    return;
                }
                // 接口正常返回，解析获取最新的包信息。
                [json enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *info, BOOL * _Nonnull stop) {
                    OPOfflineModule *current;
                    @synchronized(self) {
                        current = [self->_modules objectForKey:key];
                        if (!current) {
                            current = [[OPOfflineModule alloc] init];
                            current.name = key;
                            self->_modules[key] = current;// 存储新模块。
                        }
                    }
                    // 记录一下检测更新时间。
                    current.lastCheckTime = checkTime;
                    // 如果当前有包，则检测更新。
                    NSInteger version = [[info objectForKey:OfflinePackServerKeyVersion] integerValue];
                    if (version > current.version && version > current.newVersion) {
                        current.newVersion = version;
                        // 则表示要检测更新。
                        if (current.checkState != OPOfflineCheckStateWaiting) {
                            // 如果当前模块自己也在进行检测或者下载，则不处理。
                            return;
                        }
                        NSInteger setting = [[info objectForKey:OfflinePackServerKeyUpdateSetting] integerValue];
                        current.setting = setting;
                        NSDictionary *patchs = [info objectForKey:OfflinePackServerKeyPatchsInfo];
                        
                        NSString *downloadURL = [patchs objectForKey:[@(current.version) stringValue]];
                        // 检测是否有增量包。
                        if (downloadURL) {
                            // 如果
                            current.needPatch = YES;
                        } else {
                            current.needPatch = NO;
                            downloadURL = [info objectForKey:OfflinePackServerKeyDownloadURL];
                        }
                        current.downloadURL = downloadURL;
                        current.checkState = OPOfflineCheckStateBeforeDownload;
                        if (current.setting != OPOfflineModuleUpdateSettingOnlyUse) {
                            // 开始下载。
                            dispatch_async(self->_queue, ^{
                                [current startDownload];
                            });
                        }
                    }
                }];
            }
        }
    }] resume];
    
    
}



- (OPOfflineModule *)moduleForName:(NSString *)name {
    NSParameterAssert([name isKindOfClass:[NSString class]]);
    OPOfflineModule *module;
    @synchronized(self) {
        module = [_modules objectForKey:name];
        if (!module) {
            module = [[OPOfflineModule alloc] init];
            module.name = name;
            [_modules setObject:module forKey:name];
        }
    }
    BOOL needCheck = NO;// 判断是否需要检测更新。
    NSDate *now = [NSDate date];
    // 是否需要
    if (module.checkState != OPOfflineCheckStateWaiting) {
        // 如果已在下载过程中，则继续下载。但是判断一下前端是否要弹出更新弹框
        if (module.version < 0) {
            // 如果模块没有本地内容
            module.needCheckUpdate = YES;
        } else if(module.setting == OPOfflineModuleUpdateSettingForce) {
            // 如果设置了强制更新。
            module.needCheckUpdate = YES;
        }
        if (module.checkState == OPOfflineCheckStateBeforeDownload) {
            if ([now timeIntervalSinceDate:module.lastCheckTime] > _checkTimeInterval) {
                // 如果超时，则再检测一次。
                needCheck = YES;
            }
        }
    } else {
        if ([now timeIntervalSinceDate:module.lastCheckTime] > _checkTimeInterval) {
            // 查看检测时间。 如果超时，则需要检测
            if (module.version < 0) {
                // 如果模块没有本地内容
                module.needCheckUpdate = YES;
            } else if(module.setting == OPOfflineModuleUpdateSettingForce) {
                // 如果设置了强制更新。
                module.needCheckUpdate = YES;
            }
            needCheck = YES;
        } else if(module.newVersion && module.downloadURL){
            // 如果没有超时，且设置了下载链接，则重置为要现在状态。
            module.checkState = OPOfflineCheckStateBeforeDownload;
            if (module.version < 0) {
                // 如果模块没有本地内容
                module.needCheckUpdate = YES;
            } else if(module.setting == OPOfflineModuleUpdateSettingForce) {
                // 如果设置了强制更新。
                module.needCheckUpdate = YES;
            }
        }else {
            // 剩下的， 都应该是已有本地内容的模块
            if (module.version < 0) {
                // 剩下的时， 已经检测过，但是没有找到下载地址， 还保存到本地的异常模块。
                NSLog(@"模块 %@ 并未配置，无法找到 ！！！",name);
                return nil;
            }
        }
    }
    // 如果模块存在本地内容， 则检测是否需要校验哈希
    if (module.path && !module.verified) {
        // 校验本地内容。
        if ([self checkHashs:module.md5Hashs inPath:module.path]) {
            module.verified = YES;// 只检测一次。
        } else {
            NSLog(@"签名校验失败 ！！！ 删除文件夹 %@",module.path);
            [_fileManager removeItemAtPath:module.path error:nil];
            @synchronized(self) {
                // 删除模块信息。
                [_modules removeObjectForKey:module.name];
            }
            // 如果失败，返回空，包出错。 或者可以考虑重新检测更新。
            //return [self moduleForName:name];
            return nil;
        }
    }
    // 触发检测与下载。
    if (needCheck &&
        (module.checkState == OPOfflineCheckStateWaiting || module.checkState == OPOfflineCheckStateBeforeDownload)) {
        [module startCheck];
    }else if(module.checkState == OPOfflineCheckStateBeforeDownload) {
        [module startDownload];
    }
    return module;
}


- (BOOL)checkHashs:(NSDictionary *)hashs inPath:(NSString *)path {
    // 校验文件md5值
    __block BOOL hashChecked = YES;
    [hashs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *hash, BOOL * _Nonnull stop) {
        NSString *filePath = [path stringByAppendingPathComponent:key];
        BOOL isDirectory = NO;
        if([self->_fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
            NSString *md5 = [OPOfflineManager hashFromFile:filePath];
            if(![md5 isEqualToString:hash]) {
                *stop = YES;
                hashChecked = NO;
            }
        }
    }];
    return hashChecked;
}

+ (NSString *)hashFromFile:(NSString *)filePath {
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    CC_MD5(data.bytes, (CC_LONG)data.length, md5Buffer);
    NSMutableString *output = [NSMutableString stringWithCapacity:12];
    for(int i = CC_MD5_DIGEST_LENGTH - 6; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x",md5Buffer[i]];
    }
    return output;
}

@end
