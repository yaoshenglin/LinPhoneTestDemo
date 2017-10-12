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

@interface AppDelegate () <PKPushRegistryDelegate,UNUserNotificationCenterDelegate>
{
    BOOL startedInBackground;
    UIBackgroundTaskIdentifier bgStartId;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    NSLog(@"程序启动, statusBarFrame:%@, statusBarOrientationAnimationDuration:%@",[application valueForKey:@"statusBarFrame"],[application valueForKey:@"statusBarOrientationAnimationDuration"]);
    [UCSUserDefaultManager SetLocalDataString:@"TLS" key:@"login_transport"];   // 默认UDP接入,TLS
    [self setNotification:application];
    [self setUCSSDK];
    
    return YES;
}

- (void)setNotification:(UIApplication *)application
{
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callStateUpdateEvent:) name:kUCSCallUpdate object:nil];
    
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registrationUpdateEvent:) name:kUCSRegistrationUpdate object:nil];
    
    //iOS8 - iOS10
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
    [application registerUserNotificationSettings:notificationSettings];
    
    //iOS10
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert;
    [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
        
    }];
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    
    //linphone
    
    //设置push
    _pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    _pushRegistry.delegate = self;
    _pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    UIApplication *app = [UIApplication sharedApplication];
    UIApplicationState state = app.applicationState;
    
    [app setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    LinphoneManager *instance = [LinphoneManager instance];
    
    BOOL background_mode = [instance lpConfigBoolForKey:@"backgroundmode_preference"];
    BOOL start_at_boot = [instance lpConfigBoolForKey:@"start_at_boot_preference"];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_9_x_Max) {
//        self.del = [[ProviderDelegate alloc] init];
//        [LinphoneManager.instance setProviderDelegate:self.del];
    }
    
    if (state == UIApplicationStateBackground) {
        
        if (!start_at_boot || !background_mode) {
            NSLog(@"Linphone launch doing nothing because start_at_boot or background_mode are not activated.", NULL);
            return;
        }
    }
    
    bgStartId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"Background task for application launching expired.");
        [[UIApplication sharedApplication] endBackgroundTask:bgStartId];
    }];
    //[application registerForRemoteNotifications];
    [LinphoneManager.instance startLibLinphone];
    
    if (bgStartId!=UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:bgStartId];
        NSLog(@"结束后台进程");
    }
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
        [[UCSIPCCManager instance] addProxyConfig:name password:password displayName:displayName domain:domain port:nil withTransport:transport];
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

#pragma mark UIApplicationDelegate
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    
    //LOGI(@"%@", NSStringFromSelector(_cmd));
    [LinphoneManager.instance appWillResignActive];
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
    [LinphoneManager.instance appDidBecomeActive];
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    [LinphoneManager.instance appWillTerminate];
}

#pragma mark - pushKit - UNUser - Delegate
#pragma mark - PushKit Functions
#pragma mark - PKPushRegistryDelegate
- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type
{
    NSLog(@"PushKit Token invalidated");
    dispatch_async(dispatch_get_main_queue(), ^{[LinphoneManager.instance setPushNotificationToken:nil];});
}

- (void)pushRegistry:(PKPushRegistry *)registry
didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
             forType:(NSString *)type
{
    NSLog(@"PushKit : incoming voip notfication: %@", payload.dictionaryPayload);
    NSLog(@"pushkit --- voip信息通知");
    NSLog(@"后台或者关闭能接受到voip-push？来来来测试一下");
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        
    }else{
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_9_x_Max) { // Call category
            UNNotificationAction *act_ans =
            [UNNotificationAction actionWithIdentifier:@"Answer"
                                                 title:NSLocalizedString(@"Answer", nil)
                                               options:UNNotificationActionOptionForeground];
            UNNotificationAction *act_dec = [UNNotificationAction actionWithIdentifier:@"Decline"
                                                                                 title:NSLocalizedString(@"Decline", nil)
                                                                               options:UNNotificationActionOptionNone];
            UNNotificationCategory *cat_call =
            [UNNotificationCategory categoryWithIdentifier:@"call_cat"
                                                   actions:[NSArray arrayWithObjects:act_ans, act_dec, nil]
                                         intentIdentifiers:[[NSMutableArray alloc] init]
                                                   options:UNNotificationCategoryOptionCustomDismissAction];
            // Msg category
            UNTextInputNotificationAction *act_reply =
            [UNTextInputNotificationAction actionWithIdentifier:@"Reply"
                                                          title:NSLocalizedString(@"Reply", nil)
                                                        options:UNNotificationActionOptionNone];
            UNNotificationAction *act_seen =
            [UNNotificationAction actionWithIdentifier:@"Seen"
                                                 title:NSLocalizedString(@"Mark as seen", nil)
                                               options:UNNotificationActionOptionNone];
            UNNotificationCategory *cat_msg =
            [UNNotificationCategory categoryWithIdentifier:@"msg_cat"
                                                   actions:[NSArray arrayWithObjects:act_reply, act_seen, nil]
                                         intentIdentifiers:[[NSMutableArray alloc] init]
                                                   options:UNNotificationCategoryOptionCustomDismissAction];
            
            // Video Request Category
            UNNotificationAction *act_accept =
            [UNNotificationAction actionWithIdentifier:@"Accept"
                                                 title:NSLocalizedString(@"Accept", nil)
                                               options:UNNotificationActionOptionForeground];
            
            UNNotificationAction *act_refuse = [UNNotificationAction actionWithIdentifier:@"Cancel"
                                                                                    title:NSLocalizedString(@"Cancel", nil)
                                                                                  options:UNNotificationActionOptionNone];
            UNNotificationCategory *video_call =
            [UNNotificationCategory categoryWithIdentifier:@"video_request"
                                                   actions:[NSArray arrayWithObjects:act_accept, act_refuse, nil]
                                         intentIdentifiers:[[NSMutableArray alloc] init]
                                                   options:UNNotificationCategoryOptionCustomDismissAction];
            
            // ZRTP verification category
            UNNotificationAction *act_confirm = [UNNotificationAction actionWithIdentifier:@"Confirm"
                                                                                     title:NSLocalizedString(@"Accept", nil)
                                                                                   options:UNNotificationActionOptionNone];
            
            UNNotificationAction *act_deny = [UNNotificationAction actionWithIdentifier:@"Deny"
                                                                                  title:NSLocalizedString(@"Deny", nil)
                                                                                options:UNNotificationActionOptionNone];
            UNNotificationCategory *cat_zrtp =
            [UNNotificationCategory categoryWithIdentifier:@"zrtp_request"
                                                   actions:[NSArray arrayWithObjects:act_confirm, act_deny, nil]
                                         intentIdentifiers:[[NSMutableArray alloc] init]
                                                   options:UNNotificationCategoryOptionCustomDismissAction];
            
            [UNUserNotificationCenter currentNotificationCenter].delegate = self;
            [[UNUserNotificationCenter currentNotificationCenter]
             requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound |
                                              UNAuthorizationOptionBadge)
             completionHandler:^(BOOL granted, NSError *_Nullable error) {
                 // Enable or disable features based on authorization.
                 if (error) {
                     NSLog(@"%@",error.description);
                 }
             }];
            NSSet *categories = [NSSet setWithObjects:cat_call, cat_msg, video_call, cat_zrtp, nil];
            [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:categories];
        }else{
            UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.body =[NSString localizedUserNotificationStringForKey:[NSString
                                                                           stringWithFormat:@"%@%@", @"测试name",
                                                                           @"邀请你进行通话。。。。"] arguments:nil];;
            UNNotificationSound *customSound = [UNNotificationSound soundNamed:@"voip_call.caf"];
            content.sound = customSound;
            UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                          triggerWithTimeInterval:1 repeats:NO];
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"Voip_Push"
                                                                                  content:content trigger:trigger];
            [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                
            }];
        }
        [LinphoneManager.instance setupNetworkReachabilityCallback];
        
        dispatch_async(dispatch_get_main_queue(), ^{
//            [self processRemoteNotification:payload.dictionaryPayload];
            
        });
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type
{
    NSLog(@"PushKit credentials updated");
    NSLog(@"voip token: %@", (credentials.token));
    
    /*
     参数：{
     "clientType":2147483647,
     "deviceType":2147483647,
     "salt":"字符串内容",
     "sipAccount":"字符串内容",
     "sipToken":"字符串内容",
     "voipPushToken":"字符串内容"
     }
     
     */
    
    //推送token到服务器
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [LinphoneManager.instance setPushNotificationToken:credentials.token];
    });
}

#pragma mark - UNUserNotifications Framework
- (void) userNotificationCenter:(UNUserNotificationCenter *)center
        willPresentNotification:(UNNotification *)notification
          withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler
{
    NSLog(@"UN : response received");
    NSLog(@"%@",response.description);
    
    NSString *callId = (NSString *)[response.notification.request.content.userInfo objectForKey:@"CallId"];
    if (!callId) {
        return;
    }
    LinphoneCall *call = [LinphoneManager.instance callByCallId:callId];
    if (call) {
        LinphoneCallAppData *data = (__bridge LinphoneCallAppData *)linphone_call_get_user_data(call);
        if (data->timer) {
            [data->timer invalidate];
            data->timer = nil;
        }
    }
    
    if ([response.actionIdentifier isEqual:@"Answer"]) {
        // use the standard handler
        //        [PhoneMainView.instance changeCurrentView:CallView.compositeViewDescription];
        //        linphone_call_accept(call);
    } else if ([response.actionIdentifier isEqual:@"Decline"]) {
        //        linphone_call_decline(call, LinphoneReasonDeclined);
    } else if ([response.actionIdentifier isEqual:@"Reply"]) {
        LinphoneCore *lc = [LinphoneManager getLc];
        NSString *replyText = [(UNTextInputNotificationResponse *)response userText];
        NSString *from = [response.notification.request.content.userInfo objectForKey:@"from_addr"];
        LinphoneChatRoom *room = linphone_core_get_chat_room_from_uri(lc, [from UTF8String]);
        if (room) {
            LinphoneChatMessage *msg = linphone_chat_room_create_message(room, replyText.UTF8String);
            linphone_chat_room_send_chat_message(room, msg);
            
            if (linphone_core_lime_enabled(LC) == LinphoneLimeMandatory && !linphone_chat_room_lime_available(room)) {
                //[LinphoneManager.instance alertLIME:room];
            }
            linphone_chat_room_mark_as_read(room);
            //            TabBarView *tab = (TabBarView *)[PhoneMainView.instance.mainViewController
            //                                             getCachedController:NSStringFromClass(TabBarView.class)];
            //            [tab update:YES];
            //            [PhoneMainView.instance updateApplicationBadgeNumber];
        }
    }else if ([response.actionIdentifier isEqual:@"Seen"]) {
        NSString *from = [response.notification.request.content.userInfo objectForKey:@"from_addr"];
        LinphoneChatRoom *room = linphone_core_get_chat_room_from_uri(LC, [from UTF8String]);
        if (room) {
            linphone_chat_room_mark_as_read(room);
            //            TabBarView *tab = (TabBarView *)[PhoneMainView.instance.mainViewController
            //                                             getCachedController:NSStringFromClass(TabBarView.class)];
            //            [tab update:YES];
            //            [PhoneMainView.instance updateApplicationBadgeNumber];
        }
    }
    else if ([response.actionIdentifier isEqual:@"Cancel"]) {
        NSLog(@"User declined video proposal");
        if (call == linphone_core_get_current_call(LC)) {
            LinphoneCallParams *params = linphone_core_create_call_params(LC, call);
            
            //linphone_core_accept_call_update(LC, call, params);
            linphone_call_accept_update(call, params);
            
            linphone_call_params_unref(params);
        }
    }else if ([response.actionIdentifier isEqual:@"Accept"]) {
        NSLog(@"User accept video proposal");
        if (call == linphone_core_get_current_call(LC)) {
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
            //[PhoneMainView.instance changeCurrentView:CallView.compositeViewDescription];
            LinphoneCallParams *params = linphone_core_create_call_params(LC, call);
            linphone_call_params_enable_video(params, TRUE);
            //linphone_call_accept_update(call, params);
            //linphone_core_accept_call_update(LC, call, params);
            linphone_call_accept_update(call, params);
            //linphone_call_params_destroy(params);
            linphone_call_params_unref(params);
        }
    }else if ([response.actionIdentifier isEqual:@"Confirm"]) {
        if (linphone_core_get_current_call(LC) == call) {
            linphone_call_set_authentication_token_verified(call, YES);
        }
    }else if ([response.actionIdentifier isEqual:@"Deny"]) {
        if (linphone_core_get_current_call(LC) == call) {
            linphone_call_set_authentication_token_verified(call, NO);
        }
    }else if ([response.actionIdentifier isEqual:@"Call"]) {
        
    }else { // in this case the value is : com.apple.UNNotificationDefaultActionIdentifier
        if ([response.notification.request.content.categoryIdentifier isEqual:@"call_cat"]) {
            //            [PhoneMainView.instance displayIncomingCall:call];
        }else if ([response.notification.request.content.categoryIdentifier isEqual:@"msg_cat"]) {
            //            [PhoneMainView.instance changeCurrentView:ChatsListView.compositeViewDescription];
        }else if ([response.notification.request.content.categoryIdentifier isEqual:@"video_request"]) {
            //            [PhoneMainView.instance changeCurrentView:CallView.compositeViewDescription];
//            NSTimer *videoDismissTimer = nil;
//            
//            UIConfirmationDialog *sheet =
//            [UIConfirmationDialog ShowWithMessage:response.notification.request.content.body
//                                    cancelMessage:nil
//                                   confirmMessage:NSLocalizedString(@"ACCEPT", nil)
//                                    onCancelClick:^()
//             {
//                 LOGI(@"User declined video proposal");
//                 if (call == linphone_core_get_current_call(LC)) {
//                     LinphoneCallParams *params = linphone_core_create_call_params(LC, call);
//                     //                                            linphone_call_accept_update(call, params);
//                     //linphone_core_accept_call_update(LC, call, params);
//                     linphone_call_accept_update(call, params);
//                     //                                            linphone_call_params_destroy(params);
//                     linphone_call_params_unref(params);
//                     [videoDismissTimer invalidate];
//                 }
//             }
//                              onConfirmationClick:^()
//             {
//                 LOGI(@"User accept video proposal");
//                 if (call == linphone_core_get_current_call(LC)) {
//                     LinphoneCallParams *params = linphone_core_create_call_params(LC, call);
//                     linphone_call_params_enable_video(params, TRUE);
//                     //linphone_call_accept_update(call, params);
//                     //linphone_core_accept_call_update(LC, call, params);
//                     linphone_call_accept_update(call, params);
//                     //linphone_call_params_destroy(params);
//                     linphone_call_params_unref(params);
//                     [videoDismissTimer invalidate];
//                 }
//             }
//                                     inController:[UIApplication sharedApplication].keyWindow.rootViewController];
//            
////            videoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:30
////                                                                 target:self
////                                                               selector:@selector(dismissVideoActionSheet:)
////                                                               userInfo:sheet
////                                                                repeats:NO];
//        }else if ([response.notification.request.content.categoryIdentifier isEqual:@"zrtp_request"]) {
//            NSString *code = [NSString stringWithUTF8String:linphone_call_get_authentication_token(call)];
//            NSString *myCode;
//            NSString *correspondantCode;
//            if (linphone_call_get_dir(call) == LinphoneCallIncoming) {
//                myCode = [code substringToIndex:2];
//                correspondantCode = [code substringFromIndex:2];
//            } else {
//                correspondantCode = [code substringToIndex:2];
//                myCode = [code substringFromIndex:2];
//            }
//            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Confirm the following SAS with peer:\n"
//                                                                             @"Say : %@\n"
//                                                                             @"Your correspondant should say : %@",
//                                                                             nil),
//                                 myCode, correspondantCode];
//            
//            NSLog(@"zrtp_request --- > %@",message);
//            
//            
//            [UIConfirmationDialog ShowWithMessage:message
//                                    cancelMessage:NSLocalizedString(@"DENY", nil)
//                                   confirmMessage:NSLocalizedString(@"ACCEPT", nil)
//                                    onCancelClick:^() {
//                                        if (linphone_core_get_current_call(LC) == call) {
//                                            linphone_call_set_authentication_token_verified(call, NO);
//                                        }
//                                    }
//                              onConfirmationClick:^() {
//                                  if (linphone_core_get_current_call(LC) == call) {
//                                      linphone_call_set_authentication_token_verified(call, YES);
//                                  }
//                              }];
//        }else if ([response.notification.request.content.categoryIdentifier isEqual:@"lime"]) {
//            return;
//        }else { // Missed call
//            //            [PhoneMainView.instance changeCurrentView:HistoryListView.compositeViewDescription];
        }
    }
}

- (void)dismissVideoActionSheet:(NSTimer *)timer
{
//    UIConfirmationDialog *sheet = (UIConfirmationDialog *)timer.userInfo;
//    [sheet dismiss];
}

//获取呼叫通知:
- (UIUserNotificationCategory*)getCallNotificationCategory
{
    UIMutableUserNotificationAction* answer = [[UIMutableUserNotificationAction alloc] init];
    answer.identifier = @"answer";
    answer.title = NSLocalizedString(@"Answer", nil);
    answer.activationMode = UIUserNotificationActivationModeForeground;
    answer.destructive = NO;
    answer.authenticationRequired = YES;
    
    //下降，跟挂断和取消差不多
    UIMutableUserNotificationAction* decline = [[UIMutableUserNotificationAction alloc] init];
    decline.identifier = @"decline";
    decline.title = NSLocalizedString(@"Decline", nil);
    decline.activationMode = UIUserNotificationActivationModeBackground;
    decline.destructive = YES;//当该操作被显示的时候是否标示为销毁状态的
    /*
     此操作是否安全，并且在执行之前需要解锁。(如果激活模式是UIUserNotificationActivationModeForeground(即是上面设置的activationMode)，则该操作被认为是安全的，此属性将被忽略)
     */
    decline.authenticationRequired = NO;
    
    
    //接听（呼叫） ， 销毁（挂断）
    NSArray* localRingActions = @[decline, answer];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[UIMutableUserNotificationCategory alloc] init];
    localRingNotifAction.identifier = @"incoming_call";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];//普通情况下的通知动作
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];//当空间有限是通知动作
    
    return localRingNotifAction;
}

//获取信息通知:
- (UIUserNotificationCategory*)getMessageNotificationCategory
{
    UIMutableUserNotificationAction* reply = [[UIMutableUserNotificationAction alloc] init];
    reply.identifier = @"reply";
    reply.title = NSLocalizedString(@"Reply", nil);
    reply.activationMode = UIUserNotificationActivationModeForeground;
    reply.destructive = NO;
    reply.authenticationRequired = YES;
    
    UIMutableUserNotificationAction* mark_read = [[UIMutableUserNotificationAction alloc] init];
    mark_read.identifier = @"mark_read";
    mark_read.title = NSLocalizedString(@"Mark Read", nil);
    mark_read.activationMode = UIUserNotificationActivationModeBackground;
    mark_read.destructive = NO;
    mark_read.authenticationRequired = NO;
    
    NSArray* localRingActions = @[mark_read, reply];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[UIMutableUserNotificationCategory alloc] init];
    localRingNotifAction.identifier = @"incoming_msg";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];//空间有限是通知
    
    return localRingNotifAction;
}

- (void)registerForNotifications:(UIApplication *)app
{
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.voipRegistry.delegate = self;
    
    // Initiate registration.
    self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_9_x_Max) {
        // Call category
        UNNotificationAction *act_ans =
        [UNNotificationAction actionWithIdentifier:@"Answer"
                                             title:NSLocalizedString(@"Answer", nil)
                                           options:UNNotificationActionOptionForeground];
        UNNotificationAction *act_dec = [UNNotificationAction actionWithIdentifier:@"Decline"
                                                                             title:NSLocalizedString(@"Decline", nil)
                                                                           options:UNNotificationActionOptionNone];
        UNNotificationCategory *cat_call =
        [UNNotificationCategory categoryWithIdentifier:@"call_cat"
                                               actions:[NSArray arrayWithObjects:act_ans, act_dec, nil]
                                     intentIdentifiers:[[NSMutableArray alloc] init]
                                               options:UNNotificationCategoryOptionCustomDismissAction];
        
        // Msg category
        UNTextInputNotificationAction *act_reply =
        [UNTextInputNotificationAction actionWithIdentifier:@"Reply"
                                                      title:NSLocalizedString(@"Reply", nil)
                                                    options:UNNotificationActionOptionNone];
        UNNotificationAction *act_seen =
        [UNNotificationAction actionWithIdentifier:@"Seen"
                                             title:NSLocalizedString(@"Mark as seen", nil)
                                           options:UNNotificationActionOptionNone];
        UNNotificationCategory *cat_msg =
        [UNNotificationCategory categoryWithIdentifier:@"msg_cat"
                                               actions:[NSArray arrayWithObjects:act_reply, act_seen, nil]
                                     intentIdentifiers:[[NSMutableArray alloc] init]
                                               options:UNNotificationCategoryOptionCustomDismissAction];
        
        // Video Request Category
        UNNotificationAction *act_accept =
        [UNNotificationAction actionWithIdentifier:@"Accept"
                                             title:NSLocalizedString(@"Accept", nil)
                                           options:UNNotificationActionOptionForeground];
        
        UNNotificationAction *act_refuse = [UNNotificationAction actionWithIdentifier:@"Cancel"
                                                                                title:NSLocalizedString(@"Cancel", nil)
                                                                              options:UNNotificationActionOptionNone];
        UNNotificationCategory *video_call =
        [UNNotificationCategory categoryWithIdentifier:@"video_request"
                                               actions:[NSArray arrayWithObjects:act_accept, act_refuse, nil]
                                     intentIdentifiers:[[NSMutableArray alloc] init]
                                               options:UNNotificationCategoryOptionCustomDismissAction];
        
        // ZRTP verification category
        UNNotificationAction *act_confirm = [UNNotificationAction actionWithIdentifier:@"Confirm"
                                                                                 title:NSLocalizedString(@"Accept", nil)
                                                                               options:UNNotificationActionOptionNone];
        
        UNNotificationAction *act_deny = [UNNotificationAction actionWithIdentifier:@"Deny"
                                                                              title:NSLocalizedString(@"Deny", nil)
                                                                            options:UNNotificationActionOptionNone];
        UNNotificationCategory *cat_zrtp =
        [UNNotificationCategory categoryWithIdentifier:@"zrtp_request"
                                               actions:[NSArray arrayWithObjects:act_confirm, act_deny, nil]
                                     intentIdentifiers:[[NSMutableArray alloc] init]
                                               options:UNNotificationCategoryOptionCustomDismissAction];
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound |
                                          UNAuthorizationOptionBadge)
         completionHandler:^(BOOL granted, NSError *_Nullable error) {
             // Enable or disable features based on authorization.
             if (error) {
                 NSLog(@"%@",error.description);
             }
         }];
        NSSet *categories = [NSSet setWithObjects:cat_call, cat_msg, video_call, cat_zrtp, nil];
        [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:categories];
    }
}

- (void)switchCallViewControllerWithInitBlock:(void (^)(BOOL isWakeUp))initblock
                                  rejectBlock:(void (^)(UILabel *label))rejBlock
                                 receiveBlock:(void (^)(UILabel *label))reveiceBlock
                                setttingBlock:(BOOL (^)())settingblock
{
    
//    VistorCallUp_ViewController *vc = [[VistorCallUp_ViewController alloc] initWithReceiveBlock:reveiceBlock andRejectBlock:rejBlock initialBlock:initblock];
//    
//    self.window.rootViewController = vc;
//    [vc receiveCall_changeUI:vc.call_up_btn];
}

@end
