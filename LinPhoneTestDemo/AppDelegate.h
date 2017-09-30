//
//  AppDelegate.h
//  LinPhoneTestDemo
//
//  Created by xy on 2017/8/30.
//  Copyright © 2017年 xy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PushKit/PushKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property PKPushRegistry* voipRegistry;
@property (nonatomic , strong) PKPushRegistry *pushRegistry;

@end

