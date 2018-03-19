//
//  AppDelegate.m
//  Example
//
//  Created by 罗贤明 on 2018/3/18.
//  Copyright © 2018年 罗贤明. All rights reserved.
//

#import "AppDelegate.h"
#import "OPOfflineManager.h"

@interface AppDelegate ()

@end

static NSString *pem = @"-----BEGIN PUBLIC KEY-----\r\n\
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4YXOMN8CxfZqDy2lpV+k\
bUgE4knWCG4k0M5/+lzOoEWl9eoohXw0Ln3dY0Cjx2EGsVCR5KzZVIfjRCiyQwdd\
8QYpmXwkXwbSq4hLtRPMN/411WN/zTgycaDEXlgqz5YZ3RReQzdzqj/KkLvwjFva\
W6Q57CeEM52VaRhtYzMIU0WJuUwhsDKODg8jYzAOp3n+gKdUToOGiC/wG9HyU/0q\
t37gA/eHgRjOUcNJ1KT085+ddTGKHyopN+cTtNQ0nq+nzj5ZhF3Zl6iQ92JWSV9E\
RE62CvX+dPnyVWjOc/1jmcDgcaejJldFGLc2DjRMn148LM93kLDeCw35vhZTQeS+\
AwIDAQAB\
-----END PUBLIC KEY-----";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    int64_t o = [[NSDate date] timeIntervalSince1970] * 1000;
    [[OPOfflineManager sharedManager] setUpWithPublicPKCS8Pem:@"-----BEGIN PUBLIC KEY-----\r\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4YXOMN8CxfZqDy2lpV+kbUgE4knWCG4k0M5/+lzOoEWl9eoohXw0Ln3dY0Cjx2EGsVCR5KzZVIfjRCiyQwdd8QYpmXwkXwbSq4hLtRPMN/411WN/zTgycaDEXlgqz5YZ3RReQzdzqj/KkLvwjFvaW6Q57CeEM52VaRhtYzMIU0WJuUwhsDKODg8jYzAOp3n+gKdUToOGiC/wG9HyU/0qt37gA/eHgRjOUcNJ1KT085+ddTGKHyopN+cTtNQ0nq+nzj5ZhF3Zl6iQ92JWSV9ERE62CvX+dPnyVWjOc/1jmcDgcaejJldFGLc2DjRMn148LM93kLDeCw35vhZTQeS+AwIDAQAB-----END PUBLIC KEY-----" baseURL:@"http://localhost:2677/app/"];
    int64_t k = [[NSDate date] timeIntervalSince1970] * 1000;
    NSLog(@"最终解析耗时 %@ ", @(k - o));
    NSLog(@"module abc's path : %@",[[OPOfflineManager sharedManager] moduleForName:@"abc"].path);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"module abc's path : %@",[[OPOfflineManager sharedManager] moduleForName:@"abc"].path);
    });
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
