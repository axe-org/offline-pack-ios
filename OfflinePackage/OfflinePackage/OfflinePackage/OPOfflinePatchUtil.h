//
//  OPOfflinePatchUtil.h
//  OfflinePackage
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
  patch util ，进行补丁合成， 使用 bspatch
 */
@interface OPOfflinePatchUtil : NSObject



/**
 使用bspatch进行包的合成

 @param basePath 旧包地址
 @param diffPath diff文件
 @param targetPath 新包地址
 @return 如果失败，返回 NO.
 */
+ (BOOL)patchBaseFile:(NSString *)basePath withDiff:(NSString *)diffPath toTargetPath:(NSString *)targetPath;

@end
