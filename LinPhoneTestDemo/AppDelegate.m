//
//  AppDelegate.m
//  LinPhoneTestDemo
//
//  Created by xy on 2017/8/30.
//  Copyright © 2017年 xy. All rights reserved.
//

#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import "UCSIPCCManager.h"
#import "CallIncomingView.h"
#import "CallOutgoingView.h"
#import "CTB.h"

@interface AppDelegate () <UCSIPCCDelegate>
{
    BOOL startedInBackground;
    UIBackgroundTaskIdentifier bgStartId;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    [UCSUserDefaultManager SetLocalDataString:@"UDP" key:@"login_transport"];   // 默认UDP接入,TLS
    [self setNotification:application];
    [self setUCSSDK];
    
    return YES;
}

- (void)setNotification:(UIApplication *)application
{
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callStateUpdateEvent:) name:kUCSCallUpdate object:nil];
    
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registrationUpdateEvent:) name:kUCSRegistrationUpdate object:nil];
    
    //iOS8 - iOS10
    [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeSound | UIUserNotificationTypeBadge categories:nil]];
    
    //iOS10
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert;
    [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
        
    }];
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)setUCSSDK
{
    [[UCSIPCCManager instance] startUCSphone];
    
    //[[UCSIPCCManager instance] setDelegate:self];
    
    NSString *name = [UCSUserDefaultManager GetLocalDataString:@"login_user_name"];
    NSString *password = [UCSUserDefaultManager GetLocalDataString:@"login_password"];
    NSString *domain = [UCSUserDefaultManager GetLocalDataString:@"login_domain"];
    NSString *port = [UCSUserDefaultManager GetLocalDataString:@"login_port"];
    NSString *transport = [UCSUserDefaultManager GetLocalDataString:@"login_transport"];
    NSString *displayName = [UCSUserDefaultManager GetLocalDataString:@"login_displayName"];
    
    if (name.length != 0 && password.length != 0 && domain.length != 0 && port.length != 0) {
        // 自动设置注册信息
        [[UCSIPCCManager instance] addProxyConfig:name password:password displayName:displayName domain:domain port:port withTransport:transport];
    }
}

#pragma mark
- (void)userConfigSucceedEvent
{
    
}

- (void)goConfigEvent
{
    // 进入信息设置
    NSLog(@"信息设置");
}

#pragma mark - --------
/**
 @author Jozo, 16-06-30 15:06:51
 
 呼叫成功回调
 
 @param notif 通知传参
 */
- (void)callStateUpdateEvent:(NSNotification *)notif
{
    NSDictionary *userInfo = notif.userInfo;
    NSLog(@"AppDelegate %@", [userInfo stringForFormat]);
    UCSCallState state = [[userInfo objectForKey: @"state"] intValue];
    UCSCall *call = [[userInfo objectForKey: @"call"] pointerValue];
    [self callStateUpdate:state andCall:call];
}



- (void)callStateUpdate:(UCSCallState)state andCall:(UCSCall *)call
{
    switch (state) {
        case UCSCallOutgoingInit: {
            NSLog(@"AppDelegate 呼出电话初始化");
            break;
        }

        case UCSCallIncomingReceived: {
            NSLog(@"AppDelegate 收到来电");
            break;
        }
            
        case UCSCallStreamsRunning:
        {
            NSLog(@"AppDelegate 媒体流已建立");
            //[[LinphoneManager instance] setVideoEnabled:YES];//视频通话
        }


        case UCSCallConnected: {
            NSLog(@"AppDelegate 通话连接成功");
            break;
        }

        case UCSCallEnd: {
            NSLog(@"AppDelegate 通话被释放");
            break;
        }

        default:
            break;

    }
}

#pragma mark - PushNotification Functions

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"%@ : %@", NSStringFromSelector(_cmd), deviceToken);
    [LinphoneManager.instance setPushNotificationToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"%@ : %@", NSStringFromSelector(_cmd), [error localizedDescription]);
    [LinphoneManager.instance setPushNotificationToken:nil];
}

#pragma mark
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    
    //LOGI(@"%@", NSStringFromSelector(_cmd));
    LinphoneCall *call = linphone_core_get_current_call([LinphoneManager getLc]);
    
    if (call) {
        /* save call context */
        LinphoneManager *instance = LinphoneManager.instance;
        instance->currentCallContextBeforeGoingBackground.call = call;
        instance->currentCallContextBeforeGoingBackground.cameraIsEnabled = linphone_call_camera_enabled(call);
        
        const LinphoneCallParams *params = linphone_call_get_current_params(call);
        if (linphone_call_params_video_enabled(params)) {
            linphone_call_enable_camera(call, false);
        }
    }
    
    if (![LinphoneManager.instance resignActive]) {
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[LinphoneManager instance] enterBackgroundMode];
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    //LOGI(@"%@", NSStringFromSelector(_cmd));
    
    if (startedInBackground) {
        startedInBackground = FALSE;
    }
    LinphoneManager *instance = LinphoneManager.instance;
    [instance becomeActive];
    
    LinphoneCore *LC = [LinphoneManager getLc];
    
    if (instance.fastAddressBook.needToUpdate) {
        NSLog(@"Update address book for external changes");
        //Update address book for external changes
        //if (PhoneMainView.instance.currentView == ContactsListView.compositeViewDescription || PhoneMainView.instance.currentView == ContactDetailsView.compositeViewDescription) {
        //    [PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
        //}
        [instance.fastAddressBook reload];
        instance.fastAddressBook.needToUpdate = FALSE;
        const MSList *lists = linphone_core_get_friends_lists(LC);
        while (lists) {
            linphone_friend_list_update_subscriptions(lists->data);
            lists = lists->next;
        }
    }
    
    LinphoneCall *call = linphone_core_get_current_call(LC);
    
    if (call) {
        if (call == instance->currentCallContextBeforeGoingBackground.call) {
            const LinphoneCallParams *params = linphone_call_get_current_params(call);
            if (linphone_call_params_video_enabled(params)) {
                linphone_call_enable_camera(call, instance->currentCallContextBeforeGoingBackground.cameraIsEnabled);
            }
            instance->currentCallContextBeforeGoingBackground.call = 0;
        } else if (linphone_call_get_state(call) == LinphoneCallIncomingReceived) {
            LinphoneCallAppData *data = (__bridge LinphoneCallAppData *)linphone_call_get_user_data(call);
            if (data && data->timer) {
                [data->timer invalidate];
                data->timer = nil;
            }
            if ((floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max)) {
                if ([LinphoneManager.instance lpConfigBoolForKey:@"autoanswer_notif_preference"]) {
                    linphone_call_accept(call);
                    //[PhoneMainView.instance changeCurrentView:CallView.compositeViewDescription];
                } else {
                    //[PhoneMainView.instance displayIncomingCall:call];
                }
            } else if (linphone_core_get_calls_nb(LC) > 1) {
                //[PhoneMainView.instance displayIncomingCall:call];
            }
            
            // in this case, the ringing sound comes from the notification.
            // To stop it we have to do the iOS7 ring fix...
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        }
    }
    //[LinphoneManager.instance.iapManager check];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
