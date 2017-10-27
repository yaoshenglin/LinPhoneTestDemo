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
#import "VoIPLibDelegate.h"

@interface ViewController () <UCSIPCCDelegate,UITextFieldDelegate>
{
    VoIPLibDelegate *voipDelegate;
}

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
    //设置窗口亮度大小  范围是0.1 -1.0
    [[UIScreen mainScreen] setBrightness:0.3];
    //设置屏幕常亮
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    NSString *barTitle = @"登录";
    self.navigationItem.rightBarButtonItem = [CTB BarButtonWithTitle:barTitle target:self tag:1];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [CTB addObserver:self selector:@selector(callEvents:) name:kLinphoneCallUpdate object:nil];
    [CTB addTarget:self action:@selector(ButtonEvents:) button:_btnCall,_btnCallVideo,_btnSend, nil];
    
    voipDelegate = [VoIPLibDelegate instance];
    voipDelegate.delegate = self;
    
    UCSIPCCManager *sipCCManager = [UCSIPCCManager instance];
    [sipCCManager startUCSphone];
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
        //登录
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
        //主动呼叫(不开启视频)
        [self callEventsWithEnableVideo:NO];
    }
    else if (button.tag == 3) {
        //主动呼叫(开启视频)
        [self callEventsWithEnableVideo:YES];
    }
    else if (button.tag == 4) {
        //发送消息
        NSString *replyText = _txtTextMsg.text;
        LinphoneChatRoom *currentRoom = voipDelegate->currentRoom;
        if (![self isLogin]) {
            [self.view makeToast:@"请先登录"];
            return;
        }
        else if (!currentRoom) {
            [self.view makeToast:@"获取房间号失败"];
            return;
        }
        else if (replyText.length <= 0) {
            [self.view makeToast:@"发送内容不能为空"];
            return;
        }
        [UCSIPCCManager sendTextWithRoom:currentRoom message:replyText];
    }
}

- (void)callEventsWithEnableVideo:(BOOL)enable
{
    //主动呼叫
    if (![[UCSIPCCManager instance] isUCSReady]) {
        return;
    }
    
    NSString *addressStr = _txtDomain.text;
    
    // 获取昵称
    NSString *displayName = [UCSUserDefaultManager GetLocalDataString:@"login_displayName"];
    
    if( [addressStr length] == 0) {
        addressStr = [UCSUserDefaultManager GetLocalDataString:@"Last_Call_Address"];
        _txtDomain.text = addressStr;
        return;
    }
    
    if( [addressStr length] > 0) {
        [UCSUserDefaultManager SetLocalDataString:addressStr key:@"Last_Call_Address"];
        [[UCSIPCCManager instance] call:addressStr displayName:displayName transfer:NO enableVideo:enable];
    }
}

#pragma mark - --------UITextFieldDelegate------------------------
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
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
- (void)onRegisterStateChange:(UCSRegistrationState) state msgStr:(NSString *)message
{
    //  登陆状态变化回调
    NSString *msg = message ?: @"message is nil";
    
    if (state == UCSRegistrationOk) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"登录成功" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        alert.tag = state;
        [alert show];
        
        const char *name = linphone_core_get_identity(LC);
        printf("name = %s\n",name);
        if (name) {
            NSString *userName = [UCSIPCCManager.instance getAccount];
            NSLog(@"userName = %@",userName);
        }
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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
