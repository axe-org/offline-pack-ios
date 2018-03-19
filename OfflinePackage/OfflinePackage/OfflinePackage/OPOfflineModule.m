//
//  OPOfflineModule.m
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import "OPOfflineModule.h"
#import "OPOfflineModule+private.h"
#import "OPOfflineManager.h"
#import "OPOfflinePatchUtil.h"
#import "SSZipArchive.h"
#import "MXRSA.h"

NSErrorDomain const OPDownloadErrorDomain = @"org.axe.offline-pack.error";

static NSString *const OfflinePackServerKeyModuleName = @"moduleName";


@interface OPOfflineManager(private)

@property (nonatomic,strong) NSURLSession *session;

@property (nonatomic,strong) dispatch_queue_t queue;

@property (nonatomic,copy) NSString *publicPem;

@property (nonatomic,strong) NSFileManager *fileManager;

@property (nonatomic,strong) NSURL *queryTaskUrl;
/// 缓冲路径
@property (nonatomic,strong) NSString *tmpPath;

/// 目录所在路径
@property (nonatomic,strong) NSString *mainPath;

- (BOOL)checkHashs:(NSDictionary *)hashs inPath:(NSString *)path;

@end

@implementation OPOfflineModule

- (instancetype)init {
    if (self = [super init]) {
        _version = -1;
        _needCheckUpdate = NO;
        _setting = OPOfflineModuleUpdateSettingDefault;
        _verified = NO;
        _needCheckUpdate = NO;
        _newVersion = -1;
        _needPatch = NO;
        _checkState = OPOfflineCheckStateWaiting;
        _lastCheckTime = [NSDate dateWithTimeIntervalSince1970:0];
        _lastProgressDate = _lastCheckTime;
    }
    return self;
}


- (void)startCheck {
    // 检测
    if (_checkState != OPOfflineCheckStateWaiting) {
        return;
    }
    _checkState = OPOfflineCheckStateChecking;
    NSString *url = [[[OPOfflineManager sharedManager].queryTaskUrl absoluteString] stringByAppendingFormat:@"?%@=%@",OfflinePackServerKeyModuleName,_name];
    [[[OPOfflineManager sharedManager].session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"检测更新网络异常 : %@",error);
            [self endWithErrorCode:OPDownloadErrorNetwork message:@"检测更新网络异常 ！！！"];
        }else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                NSLog(@"解析后台数据出错 ！！！ %@",error);
                [self endWithErrorCode:OPDownloadErrorNetwork message:@"检测更新网络异常 ！！！"];
                return;
            }
            NSString *errorInfo = [json objectForKey:OfflinePackServerKeyError];
            if (errorInfo) {
                NSLog(@"后台异常报错 ：%@",errorInfo);
                [self endWithErrorCode:OPDownloadErrorServer message:errorInfo];
                return;
            }
            _lastCheckTime = [NSDate date];// 请求正常的情况下，才记录, 以保证每次有问题的模块，都会请求检测更新。
            // 进行单独的检测更新，必定是需要去下载的。
            NSInteger newVersion = [[json objectForKey:OfflinePackServerKeyVersion] integerValue];
            if (newVersion > _version) {
                _newVersion = newVersion;
                [self printProcess:10];// 检测完成，为10%进度。
                _setting = [[json objectForKey:OfflinePackServerKeyUpdateSetting] integerValue];
                NSDictionary *patchsInfo = [json objectForKey:OfflinePackServerKeyPatchsInfo];
                NSString *downloadURL = [patchsInfo objectForKey:[@(_version) stringValue]];
                if (downloadURL) {
                    _needPatch = YES;
                } else {
                    _needPatch = NO;
                    downloadURL = [json objectForKey:OfflinePackServerKeyDownloadURL];
                }
                _downloadURL = downloadURL;
                _checkState = OPOfflineCheckStateBeforeDownload;
                [self startDownload];
            } else {
                // 则不需要进行更新。
                [self successEnd];
            }
        }
    }] resume];
}


- (void)startDownload {
    // 下载
    if (_checkState != OPOfflineCheckStateBeforeDownload) {
        return;
    }
    _checkState = OPOfflineCheckStateDownloading;
    _downloadSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSURLSessionDownloadTask *task = [_downloadSession downloadTaskWithURL:[NSURL URLWithString:_downloadURL]];
    [task resume];
}

- (void)setDelegate:(id<OPOfflineDownloadDelegate>)delegate {
    // 正常情况下， 会在检测更新开始后， 设置 delegate , 但是为了防止由于异步导致下载先处理完成， 所以做下判断
    if (_checkState == OPOfflineCheckStateWaiting) {
        // TODO 但是这个地方还是要考虑一下，万一调用者的界面没有弹出来，就 调用了delegate ,会怎么样。。。
        if (_path) {
            // 如果有路径，则表示成功
            if ([delegate respondsToSelector:@selector(moduleDidFinishDownload:)]) {
                [delegate moduleDidFinishDownload:self];
            }
        } else {
            // 如果没有路径，则表示失败。
            if ([delegate respondsToSelector:@selector(module:didFailLoadWithError:)]) {
                NSError *error = [NSError errorWithDomain:OPDownloadErrorDomain code:OPDownloadError userInfo:@{@"description" : @"模块检测下载失败！！！"}];
                [delegate module:self didFailLoadWithError:error];
            }
        }
    } else {
        // 只有状态正常，才会设置成功。
        _delegate = delegate;
    }
}

// 确保在主线程中执行。
- (void)endWithErrorCode:(NSInteger)code message:(NSString *)message {
    _checkState = OPOfflineCheckStateWaiting;
    _needCheckUpdate = NO;
    _needPatch = NO;
    if ([_delegate respondsToSelector:@selector(module:didFailLoadWithError:)]) {
        NSError *error = [NSError errorWithDomain:OPDownloadErrorDomain code:code userInfo:@{@"description" : message}];
        id<OPOfflineDownloadDelegate> delegate = _delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate module:self didFailLoadWithError:error];
        });
    }
    _delegate = nil;
}

- (void)successEnd {
    _checkState = OPOfflineCheckStateWaiting;
    _needCheckUpdate = NO;
    _needPatch = NO;
    if ([_delegate respondsToSelector:@selector(moduleDidFinishDownload:)]) {
        id<OPOfflineDownloadDelegate> delegate = _delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate moduleDidFinishDownload:self];
        });
    }
    _delegate = nil;
}

- (void)printProcess:(NSInteger)progress {
    // 展示进度， 这里处理一下间隔问题，即进度变化必须要超过 0.2秒，才做处理，
    // 过于频繁的进度直接省略,毕竟这里用于给界面展示进度条。
    NSDate *now = [NSDate date];
    if (progress == 100 || [now timeIntervalSinceDate:_lastProgressDate] > 0.2) {
        _lastProgressDate = now;
        if ([_delegate respondsToSelector:@selector(module:didDownloadProgress:)]) {
            id<OPOfflineDownloadDelegate> delegate = _delegate;
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate module:self didDownloadProgress:progress];
            });
        }
    }
}


- (void)processDownloadPack:(NSString *)packPath {
    // 处理下载的包。
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (_needPatch) {
        // 如果是增量包，则进行patch合成。
        NSString *oldPackPath = [_path stringByAppendingPathComponent:OPOfflineLocalBackFileName];
        if (![fileManager fileExistsAtPath:oldPackPath]) {
            NSLog(@"本地未找到保存的旧包 %@ , 请检查 !!!",oldPackPath);
            [self endWithErrorCode:OPDownloadErrorUnknow message:@"未找到旧包文件！！！"];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        NSString *newPackPath = [NSUUID UUID].UUIDString;// 随机起名。。。
        newPackPath = [[OPOfflineManager sharedManager].tmpPath stringByAppendingPathComponent:newPackPath];
        // 使用bspatch 合成新包。
        BOOL patchSuccess = [OPOfflinePatchUtil patchBaseFile:oldPackPath withDiff:packPath toTargetPath:newPackPath];
        if (!patchSuccess) {
            NSLog(@"bspatch 合成包失败 ！！！");
            [self endWithErrorCode:OPDownloadErrorPatchFailed message:@"bspatch 合成包失败 ！"];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        [fileManager removeItemAtPath:packPath error:nil];
        packPath = newPackPath;
        [self printProcess:80];
    }
    // 然后进行解压
    NSString *randomName = [NSUUID UUID].UUIDString;
    NSString *unzipPath = [[OPOfflineManager sharedManager].tmpPath stringByAppendingPathComponent:randomName];
    if([SSZipArchive unzipFileAtPath:packPath toDestination:unzipPath]) {
        [self printProcess:90];
        // 校验签名。
        NSString *signatureFile = [unzipPath stringByAppendingPathComponent:@".axe_pack_sign"];
        if (![fileManager fileExistsAtPath:signatureFile]) {
            NSLog(@"签名校验失败！！！");
            [self endWithErrorCode:OPDownloadErrorSignature message:@"签名校验失败！"];
            [fileManager removeItemAtPath:unzipPath error:nil];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        // 读取签名文件
        NSData *sign = [NSData dataWithContentsOfFile:signatureFile];
        NSData *plainData = [MXRSA decryptData:sign usingPlulicKeyString:[OPOfflineManager sharedManager].publicPem];
        if (!plainData) {
            NSLog(@"签名校验失败！！！");
            [self endWithErrorCode:OPDownloadErrorSignature message:@"签名校验失败！"];
            [fileManager removeItemAtPath:unzipPath error:nil];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        // 解析
        NSError *error;
        NSMutableDictionary *moduleInfo = [NSJSONSerialization JSONObjectWithData:plainData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            NSLog(@"签名校验失败！！！");
            [self endWithErrorCode:OPDownloadErrorSignature message:@"签名校验失败！"];
            [fileManager removeItemAtPath:unzipPath error:nil];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        // 检测签名文件中的md5值。
        if (![[OPOfflineManager sharedManager] checkHashs:moduleInfo inPath:unzipPath]) {
            NSLog(@"签名校验失败！！！");
            [self endWithErrorCode:OPDownloadErrorSignature message:@"签名校验失败！"];
            [fileManager removeItemAtPath:unzipPath error:nil];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        // 签名校验通过。
        [self printProcess:98];
        
        // 将包保存一份在目录下。
        NSString *backFilePath = [unzipPath stringByAppendingPathComponent:OPOfflineLocalBackFileName];
        [fileManager moveItemAtPath:packPath toPath:backFilePath error:&error];
        if (error) {
            // 如果出错， 则
            NSLog(@"文件处理异常 ： %@",error);
            [self endWithErrorCode:OPDownloadErrorFileSystem message:[NSString stringWithFormat:@"文件处理异常 ：%@",error]];
            [fileManager removeItemAtPath:unzipPath error:nil];
            [fileManager removeItemAtPath:packPath error:nil];
            return;
        }
        // 最后移动文件到main目录。
        NSString *finalPath = [[OPOfflineManager sharedManager].mainPath stringByAppendingPathComponent:randomName];
        [fileManager moveItemAtPath:unzipPath toPath:finalPath error:&error];
        [fileManager removeItemAtPath:unzipPath error:nil];
        [fileManager removeItemAtPath:packPath error:nil];
        if (error) {
            // 最后移动文件，应该不会出错。
            NSLog(@"文件处理异常 ： %@",error);
            [self endWithErrorCode:OPDownloadErrorFileSystem message:[NSString stringWithFormat:@"文件处理异常 ：%@",error]];
        } else {
            // 彻底处理成功，设置完成。
            [self printProcess:100];
            // 之前提到的，完成在 100% 之后。。。。
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 更新数据。
                _version = _newVersion;
                _downloadURL = nil;
                _verified = YES;
                _path = finalPath;
                _url = [NSURL URLWithString:[@"file://" stringByAppendingString:finalPath]];
                [self successEnd];
            });
        }
    }else {
        [fileManager removeItemAtPath:unzipPath error:nil];
        [fileManager removeItemAtPath:packPath error:nil];
        NSLog(@"解压包失败！！！");
        [self endWithErrorCode:OPDownloadErrorUnzipFailed message:@"解压包失败 ！！！"];
    }
    // 处理完成后， 不进行删除， 因为当前可能这些文件正在被使用，重启时再做旧包删除。
}

#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    // 移动文件到tmp文件夹。
    NSString *tmpPath = [[OPOfflineManager sharedManager].tmpPath stringByAppendingPathComponent:[location lastPathComponent]];
    NSString *tmpURL = [@"file://" stringByAppendingString:tmpPath];
    NSError *error;
    [[OPOfflineManager sharedManager].fileManager moveItemAtURL:location toURL:[NSURL URLWithString:tmpURL] error:&error];
    if (error) {
        [self endWithErrorCode:OPDownloadErrorFileSystem message:[NSString stringWithFormat:@"文件操作异常 ：%@",error]];
    } else {
        [self printProcess:71];
        dispatch_async([OPOfflineManager sharedManager].queue, ^{
            [self processDownloadPack:tmpPath];
        });
    }
    // 关闭session.
    [session invalidateAndCancel];
    self.downloadSession = nil;
}


- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSInteger progress = totalBytesWritten / (double)totalBytesExpectedToWrite * 50 + 20;
    [self printProcess:progress];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    // 关闭session.
    if (error) {
        [session invalidateAndCancel];
        self.downloadSession = nil;
        NSLog(@"下载包文件出错 ：%@",error);
        [self endWithErrorCode:OPDownloadErrorDownload message:@"下载包文件失败 ！！！"];
    }
}




@end
