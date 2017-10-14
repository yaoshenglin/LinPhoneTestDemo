//
//  VoIPLibDelegate.m
//  iFace
//
//  Created by xy on 2017/10/14.
//  Copyright © 2017年 weicontrol. All rights reserved.
//

#import "VoIPLibDelegate.h"
#import "AppDelegate.h"
//#import "Bussiness.h"

static VoIPLibDelegate *theVoIPLibDelegate = nil;

@interface VoIPLibDelegate () <UCSIPCCDelegate>
{
    LinphoneChatRoom *currentRoom;
}

@end

@implementation VoIPLibDelegate

+ (VoIPLibDelegate *)instance
{
    if(!theVoIPLibDelegate) {
        theVoIPLibDelegate = [[VoIPLibDelegate alloc] init];
    }
    return theVoIPLibDelegate;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        UCSIPCCManager.instance.delegate = self;
        [CTB addObserver:self selector:@selector(onkLinphoneTextReceived:) name:kLinphoneTextReceived object:nil];
    }
    
    return self;
}

- (void)callEvents:(NSNotification *)notice
{
    LinphoneCall *call = [[notice.userInfo objectForKey: @"call"] pointerValue];
    LinphoneCallState state = [[notice.userInfo objectForKey: @"state"] intValue];
    
    if (call) {
        switch (state) {
            case LinphoneCallUpdatedByRemote:
            {
                //对方主动请求会回调这个状态
                break;
            }
            case LinphoneCallEnd: {
                NSLog(@"LinphoneCallEnd ------>");
            }
            case LinphoneCallError: {
                NSLog(@"LinphoneCallError ------>");
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"呼叫结束" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
                [alert show];
                break;
            }
            default:
                break;
        }
    }
}

#pragma mark - --------UCSIPCCDelegate------------------------
- (void)onRegisterStateChange:(UCSRegistrationState) state message:(const char*) message
{
    //  登陆状态变化回调
    NSString *stateMsg = [LinphoneManager getStateMsg:state];
    NSString *msg = message ? [NSString stringWithUTF8String:message] : @"";
    NSLog(@"登陆状态改变, state %@ , message = %@",stateMsg,msg);
    
    //Bussiness *buss = [Bussiness getBuss];
    
    if (state == UCSRegistrationOk) {
        //buss.voipLogin.isLogin = YES;
        //[LinphoneManager.instance setPushNotificationToken:buss.voipLogin.token];
    }
    else if (state == UCSRegistrationFailed) {
        //buss.voipLogin.isLogin = NO;
    }
    else if (state == UCSRegistrationCleared) {
        
        //buss.voipLogin.isLogin = NO;
    }
    
    if ([_delegate respondsToSelector:@selector(onRegisterStateChange:msgStr:)]) {
        [_delegate onRegisterStateChange:state msgStr:msg];
    }
}

- (void)onOutgoingCall:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 发起来电回调
    NSLog(@"发起来电, state = %d , message = %@",state,[message stringForFormat]);
    
    //呼叫开始
    AppDelegate *app = [UIApplication sharedApplicationDelegate];
    id vc = [[NSClassFromString(@"CallOutgoingView") alloc] init];
    [app.window.rootViewController presentViewController:vc animated:YES completion:^{}];
}

- (void)onIncomingCall:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 收到来电回调
    NSLog(@"收到来电, state = %d , message = %@",state,[message stringForFormat]);
    
    //CallIncomingView *vc = [CallIncomingView new];
    //vc.call = call;
    //[self presentViewController:vc animated:YES completion:^{}];
    
    const LinphoneCallParams *params = linphone_call_get_remote_params(call);
    if (linphone_call_params_video_enabled(params)) {
        linphone_call_enable_camera(call, YES);
        NSLog(@"启用相机");
    }
    
    AppDelegate *app = [UIApplication sharedApplicationDelegate];
    id vc = [[NSClassFromString(@"CallIncomingView") alloc] init];
    [app.window.rootViewController presentViewController:vc animated:YES completion:nil];
}

- (void)onAnswer:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 接听回调
    NSLog(@"接听, state = %d , message = %@",state,[message stringForFormat]);
}

- (void)onStreamsRunning:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 媒体流已建立
    NSLog(@"视频, state = %d , message = %@",state,[message stringForFormat]);
    //启用视频接听
    const LinphoneCallParams *remoteParams = linphone_call_get_remote_params(call);
    const LinphoneCallParams *currentParams = linphone_call_get_current_params(call);
    if (linphone_call_params_video_enabled(remoteParams) && !linphone_call_params_video_enabled(currentParams)) {
        [[UCSIPCCManager instance] setVideoEnable:YES];
        NSLog(@"视频流已经启动////////////////////////////////");
    }
}

- (void)onHangUp:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 释放通话回调,结束呼叫
    NSLog(@"结束通话, state = %d , message = %@",state,[message stringForFormat]);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UCS_Call_Released" object:nil userInfo:nil];
    
    if (state != UCSCallReleased) {
        return;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"呼叫结束" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

- (void)onDialFailed:(UCSCallState)state withMessage:(NSDictionary *) message
{
    // 呼叫失败回调
    NSLog(@"呼叫失败, state = %d , message = %@",state,[message stringForFormat]);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"请输入正确的号码" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

#pragma mark - --------收到消息------------------------
- (void)onkLinphoneTextReceived:(NSNotification *)notice
{
    //收到消息
    NSDictionary *dict = notice.userInfo;
    LinphoneChatMessage *message = [[dict objectForKey:@"message"] pointerValue];
    LinphoneChatMessageState state = linphone_chat_message_get_state(message);
    NSLog(@"msg state = %d",state);
    
    NSString *textMsg = [UCSIPCCManager TextMessageForChat:message];
    NSLog(@"textMsg = %@",textMsg);
    
    NSString *replyText = @"收到消息";
    currentRoom = linphone_chat_message_get_chat_room(message);
    [UCSIPCCManager sendTextWithRoom:currentRoom message:replyText];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
