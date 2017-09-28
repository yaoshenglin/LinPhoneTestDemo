//
//  ViewController.m
//  LinPhoneTestDemo
//
//  Created by xy on 2017/8/30.
//  Copyright © 2017年 xy. All rights reserved.
//

#import "ViewController.h"
#import "CTB.h"
#import "MBProgressHUD.h"
#import "UCSIPCCManager.h"
#import "UCSUserDefaultManager.h"
#import "CallIncomingView.h"
#import "CallOutgoingView.h"

@interface ViewController () <UCSIPCCDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initCapacity];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)initCapacity
{
    NSString *barTitle = @"登录";
    self.navigationItem.rightBarButtonItem = [CTB BarButtonWithTitle:barTitle target:self tag:1];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //[CTB addObserver:self selector:@selector(buttonType) name:kLinphoneCallUpdate object:nil];
    [CTB addTarget:self action:@selector(ButtonEvents:) button:_btnCall,_btnCallVideo, nil];
    
    UCSIPCCManager *sipCCManager = [UCSIPCCManager instance];
    [sipCCManager startUCSphone];
    sipCCManager.delegate = self;
    if (!sipCCManager.speakerEnabled) {
        [sipCCManager setSpeakerEnabled:YES];
    }
}

- (BOOL)isLogin
{
    NSString *name = [UCSUserDefaultManager GetLocalDataString:@"login_user_name"];
    NSString *password = [UCSUserDefaultManager GetLocalDataString:@"login_password"];
    NSString *domain = [UCSUserDefaultManager GetLocalDataString:@"login_domain"];
    NSString *port = [UCSUserDefaultManager GetLocalDataString:@"login_port"];
    //NSString *transport = [UCSUserDefaultManager GetLocalDataString:@"login_transport"];
    //NSString *displayName = [UCSUserDefaultManager GetLocalDataString:@"login_displayName"];
    
    if (name.length != 0 && password.length != 0 && domain.length != 0 && port.length != 0) {
        // 自动设置注册信息
        return YES;
    }
    
    return NO;
}

#pragma mark - --------ButtonEvents------------------------
- (void)ButtonEvents:(UIButton *)button
{
    NSString *btnTitle = nil;
    if ([button isKindOfClass:[UIButton class]]) {
        btnTitle = button.currentTitle;
    }
    if (button.tag == 1) {
        btnTitle = ((UIBarButtonItem *)button).title;
        if ([btnTitle isEqualToString:@"登录"]) {
            
            // 获取登陆信息
            Class class = NSClassFromString(@"SettingViewController");
            id vc = [[class alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        else if ([btnTitle isEqualToString:@"注销"]) {
            [[UCSIPCCManager instance] removeAccount];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"removeConfigSucceed" object:nil];
        }
    }
    else if (button.tag == 2) {
        [self callEventsWithEnableVideo:NO];
    }
    else if (button.tag == 3) {
        [self callEventsWithEnableVideo:YES];
    }
}

- (void)callEventsWithEnableVideo:(BOOL)enable
{
    if (![[UCSIPCCManager instance] isUCSReady]) {
        return;
    }
    
    NSString *address = _txtDomain.text;
    
    // 获取昵称
    NSString *displayName = [UCSUserDefaultManager GetLocalDataString:@"login_displayName"];
    
    if( [address length] == 0) {
        address = [UCSUserDefaultManager GetLocalDataString:@"Last_Call_Address"];
        _txtDomain.text = address;
        return;
    }
    
    if( [address length] > 0) {
        [UCSUserDefaultManager SetLocalDataString:address key:@"Last_Call_Address"];
        [[UCSIPCCManager instance] call:address displayName:displayName transfer:NO enableVideo:enable];
    }
}

#pragma mark - --------UCSIPCCDelegate------------------------
//  登陆状态变化回调
- (void)onRegisterStateChange:(UCSRegistrationState) state message:(const char*) message
{
    NSString *stateMsg = [LinphoneManager getStateMsg:state];
    NSString *msg = message ? [NSString stringWithUTF8String:message] : @"message is nil";
    NSLog(@"登陆状态改变, state %@ , message = %@",stateMsg,msg);
    
    if (state == UCSRegistrationOk) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"登录成功" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        alert.tag = state;
        [alert show];
    }
    else if (state == UCSRegistrationFailed) {
        NSString *msgs = msg.length > 0 ? [@"登录失败" stringByAppendingFormat:@"\n%@",msg] : @"登录失败";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:msgs delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        alert.tag = state;
        [alert show];
        [self.view.window makeToast:msg];
    }
    else if (state == UCSRegistrationCleared) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"注销成功" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        alert.tag = state;
        [alert show];
    }
}

// 发起来电回调
- (void)onOutgoingCall:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    NSLog(@"发起来电, state = %d , message = %@",state,[message stringForFormat]);
    
    //呼叫开始
    CallOutgoingView *vc = [CallOutgoingView new];
    [self presentViewController:vc animated:YES completion:^{}];
}

// 收到来电回调
- (void)onIncomingCall:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    NSLog(@"收到来电, state = %d , message = %@",state,[message stringForFormat]);
    
    CallIncomingView *vc = [CallIncomingView new];
    vc.call = call;
    [self presentViewController:vc animated:YES completion:^{}];
    
    const LinphoneCallParams *params = linphone_call_get_remote_params(call);
    if (linphone_call_params_video_enabled(params)) {
        linphone_call_enable_camera(call, YES);
        NSLog(@"启用相机");
    }
}

// 接听回调
-(void)onAnswer:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    NSLog(@"接听, state = %d , message = %@",state,[message stringForFormat]);
}

// 释放通话回调
- (void)onHangUp:(UCSCall *)call withState:(UCSCallState)state withMessage:(NSDictionary *) message
{
    //结束呼叫
    NSLog(@"结束通话, state = %d , message = %@",state,[message stringForFormat]);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UCS_Call_Released" object:nil userInfo:nil];
    
    if (state != UCSCallReleased) {
        return;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"呼叫结束" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

// 呼叫失败回调
- (void)onDialFailed:(UCSCallState)state withMessage:(NSDictionary *) message
{
    NSLog(@"呼叫失败, state = %d , message = %@",state,[message stringForFormat]);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"请输入正确的号码" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

#pragma mark
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == UCSRegistrationOk) {
        [CTB postNoticeName:@"RegistrationOk" object:nil];
    }
    else if (alertView.tag == UCSRegistrationCleared) {
        [CTB postNoticeName:@"RegistrationCleared" object:nil];
    }
    else if (alertView.tag == UCSRegistrationFailed) {
        NSString *message = nil;
        if ([alertView.message containString:@"\n"]) {
            NSArray *listMsg = [alertView.message componentsSeparatedByString:@"\n"];
            message = listMsg.lastObject;
        }
        [CTB postNoticeName:@"RegistrationFailed" object:message];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
