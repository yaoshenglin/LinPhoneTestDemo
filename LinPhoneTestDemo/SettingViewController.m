//
//  SettingViewController.m
//  UCS_IPCC_Demo
//
//  Created by Jozo.Chan on 16/7/1.
//  Copyright © 2016年 i.Jozo. All rights reserved.
//

#import "SettingViewController.h"
#import "UCSIPCCManager.h"
#import "UIView+Convenience.h"
#import "CTB.h"
#import "MBProgressHUD.h"

static NSTimer *timer;
@interface SettingViewController () <UITextFieldDelegate>
{
    int timeCounter;
    
    MBProgressHUD *hudView;
}

@property (weak, nonatomic) IBOutlet UIButton *bt_ready;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (weak, nonatomic) IBOutlet UITextField *text_userName;
@property (weak, nonatomic) IBOutlet UITextField *text_password;
@property (weak, nonatomic) IBOutlet UITextField *text_domain;
@property (weak, nonatomic) IBOutlet UITextField *text_port;
@property (weak, nonatomic) IBOutlet UITextField *text_displayName;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UIView *bgView;
@property (nonatomic, assign) CGFloat oldFrameY;

@property (weak, nonatomic) IBOutlet UISegmentedControl *transportPicker;

@end

@implementation SettingViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        timer = 0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"登录";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self stuptapToHidKeyBoard];
    
    if (self.navigationItem) {
        //_btnCancel.hidden = YES;
    }
    
    self.stateLabel.textColor = [UIColor colorWithRed:0.9765 green:0.4039 blue:0.0 alpha:1.0];
    timeCounter = 0;
    
    self.oldFrameY = self.bgView.frameY;
    
    self.text_userName.text = [UCSUserDefaultManager GetLocalDataString:@"login_user_name"];
    self.text_password.text = [UCSUserDefaultManager GetLocalDataString:@"login_password"];
    self.text_domain.text = [UCSUserDefaultManager GetLocalDataString:@"login_domain"];
    self.text_port.text = [UCSUserDefaultManager GetLocalDataString:@"login_port"];
    self.text_displayName.text = [UCSUserDefaultManager GetLocalDataString:@"login_displayName"];
    
    NSString *transport = [UCSUserDefaultManager GetLocalDataString:@"login_transport"];
    NSArray *tempArr = @[@"UDP", @"TCP", @"TLS"];
    self.transportPicker.tintColor = [UIColor colorWithRed:0.9888 green:0.4661 blue:0.4063 alpha:1.0];
    self.transportPicker.selectedSegmentIndex = [tempArr indexOfObject:transport];
    
    [CTB addObserver:self selector:@selector(RegistrationEvents:) name:@"RegistrationOk" object:nil];
    [CTB addObserver:self selector:@selector(RegistrationEvents:) name:@"RegistrationCleared" object:nil];
    [CTB addObserver:self selector:@selector(RegistrationEvents:) name:@"RegistrationFailed" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self cancelTimer];
}

- (void)loginTimer
{
    [timer destroy];
    timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                             target:self
                                           selector:@selector(timeGoes)
                                           userInfo:nil
                                            repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [timer fire];
}

- (void)timeGoes
{
    NSArray *arr = @[@"", @".", @"..", @"..."];
    self.stateLabel.text = [NSString stringWithFormat:@"· 登录中%@", arr[timeCounter %4]];
    timeCounter ++;
}

- (IBAction)readyToSip:(id)sender
{
    //Login
    if (self.text_userName.text.length == 0 || self.text_password.text.length == 0  || self.text_domain.text.length == 0) {
        return;
    }
    
    // 存储登陆信息
    [UCSUserDefaultManager SetLocalDataString:self.text_userName.text key:@"login_user_name"];
    [UCSUserDefaultManager SetLocalDataString:self.text_password.text key:@"login_password"];
    [UCSUserDefaultManager SetLocalDataString:self.text_domain.text key:@"login_domain"];
    [UCSUserDefaultManager SetLocalDataString:self.text_port.text key:@"login_port"];
    [UCSUserDefaultManager SetLocalDataString:self.text_displayName.text key:@"login_displayName"];
    NSString *transport = [UCSUserDefaultManager GetLocalDataString:@"login_transport"];
    
    [self loginTimer];
    [[UCSIPCCManager instance] addProxyConfig:self.text_userName.text password:self.text_password.text displayName:self.text_displayName.text domain:self.text_domain.text port:self.text_port.text withTransport:transport];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"addConfigSucceed" object:nil];
    
    hudView = hudView ?: [MBProgressHUD showRuningView:self.view];
    [hudView show:YES];
}


- (IBAction)logoutFromSip:(id)sender
{
    //logout
    [[UCSIPCCManager instance] removeAccount];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"removeConfigSucceed" object:nil];
}

- (IBAction)cancelLogin:(UIButton *)sender
{
    //取消(返回上一页)
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [UCSUserDefaultManager SetLocalDataString:@"" key:@"login_user_name"];
    [UCSUserDefaultManager SetLocalDataString:@"" key:@"login_password"];
    [UCSUserDefaultManager SetLocalDataString:@"" key:@"login_domain"];
    [UCSUserDefaultManager SetLocalDataString:@"" key:@"login_port"];
    [UCSUserDefaultManager SetLocalDataString:@"" key:@"login_displayName"];
    
    [[UCSIPCCManager instance] removeAccount];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"removeConfigSucceed" object:nil];
}


- (void)stuptapToHidKeyBoard
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    UITapGestureRecognizer *singleTapGR =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(tapAnywhereToDismissKeyboard:)];
    
    __weak UIViewController *weakSelf = self;
    
    NSOperationQueue *mainQuene =[NSOperationQueue mainQueue];
    [nc addObserverForName:UIKeyboardWillShowNotification
                    object:nil
                     queue:mainQuene
                usingBlock:^(NSNotification *note){
                    [weakSelf.view addGestureRecognizer:singleTapGR];
                }];
    [nc addObserverForName:UIKeyboardWillHideNotification
                    object:nil
                     queue:mainQuene
                usingBlock:^(NSNotification *note){
                    [weakSelf.view removeGestureRecognizer:singleTapGR];
                }];
}

- (void)tapAnywhereToDismissKeyboard:(UIGestureRecognizer *)gestureRecognizer
{
    //此method会将self.view里所有的subview的first responder都resign掉
    [self.view endEditing:YES];
}

- (IBAction)transportPick:(UISegmentedControl *)sender
{
    NSInteger index = sender.selectedSegmentIndex;
    NSArray *tempArr = @[@"UDP", @"TCP", @"TLS"];
    [UCSUserDefaultManager SetLocalDataString:tempArr[index] key:@"login_transport"];
}

#pragma mark - 编辑时视图变化
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
//    [UIView animateWithDuration:0.3 animations:^{
//        self.bgView.frameY = self.oldFrameY;
//    }];
}

- (void)RegistrationEvents:(NSNotification *)notice
{
    if ([notice.name isEqualToString:@"RegistrationOk"]) {
        [timer destroy];
        [hudView hide:YES];
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if ([notice.name isEqualToString:@"RegistrationCleared"]) {
        [timer destroy];
        [hudView hide:YES];
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if ([notice.name isEqualToString:@"RegistrationFailed"]) {
        [timer destroy];
        [hudView hide:YES];
        [self.navigationController popViewControllerAnimated:YES];
        if (notice.object) {
            [self.view.window makeToast:notice.object];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)cancelTimer
{
    [timer destroy];
    timer = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
