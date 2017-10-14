/* IncomingCallViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  接听
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "CallIncomingView.h"

static NSTimer *timer;

@implementation CallIncomingView

#pragma mark - ViewController Functions

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        timer = 0;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callReleasedEvent) name:@"UCS_Call_Released" object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callStateUpdateEvent:) name:kUCSCallUpdate object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self cancelTimer];
    //[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

- (void)viewDidLoad {
    self.speakButton.hidden = YES;
    _call = linphone_core_get_current_call(LC);
    
    NSString *remoteAddress = [[UCSIPCCManager instance] getRemoteAddress];
    NSString *remoteDisplayName = [[UCSIPCCManager instance] getRemoteDisplayName];
    self.addressLabel.text = remoteDisplayName.length == 0 ? remoteAddress : remoteDisplayName;
    
        
}

#pragma mark - UICompositeViewDelegate Functions

//static UICompositeViewDescription *compositeDescription = nil;
//
//+ (UICompositeViewDescription *)compositeViewDescription {
//	if (compositeDescription == nil) {
//        compositeDescription = [[UICompositeViewDescription alloc] init:@"CallIncoming"
//                                                                content:@"CallIncomingView"
//                                                               stateBar:@"UIStateBar"
//                                                        stateBarEnabled:true
//                                                                 tabBar:@"UIMainBar"
//                                                          tabBarEnabled:true
//                                                             fullscreen:false
//                                                          landscapeMode:false
//                                                           portraitMode:true];
//		compositeDescription.darkBackground = true;
//	}
//	return compositeDescription;
//}
//
//- (UICompositeViewDescription *)compositeViewDescription {
//	return self.class.compositeViewDescription;
//}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

}

#pragma mark - Event Functions

- (void)callStateUpdateEvent:(NSNotification *)notif {
    UCSCall *acall = [[notif.userInfo objectForKey:@"call"] pointerValue];
	UCSCallState astate = [[notif.userInfo objectForKey:@"state"] intValue];
	[self callUpdate:acall state:astate];
}

- (void)callUpdate:(UCSCall *)acall state:(UCSCallState)astate {
	if (_call == acall && (astate == UCSCallEnd || astate == UCSCallError)) {
		[_delegate incomingCallAborted:_call];
        [self onDeclineClick:nil];
	}
    else if (_call == acall && astate == UCSCallConnected){
        // 点击了接听且连接, 改变UI
        timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(callDurationUpdate) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [timer fire];
        
        self.speakButton.hidden = NO;
        self.acceptButton.hidden = YES;
	}
    else if (_call == acall && astate == LinphoneCallUpdatedByRemote)
    {
        //对方主动请求会回调这个状态
        NSLog(@"对方响应 ------>");
        const LinphoneCallParams* current = linphone_call_get_current_params(_call);
        const LinphoneCallParams* remote = linphone_call_get_remote_params(_call);
        
        /* remote wants to add video */
        if (linphone_core_video_enabled(LC) && !linphone_call_params_video_enabled(current) &&
            linphone_call_params_video_enabled(remote)&& !linphone_core_get_video_policy(LC)->automatically_accept) {
            [self displayAskToEnableVideoCall:_call];
        }
        else if (linphone_call_params_video_enabled(current) && !linphone_call_params_video_enabled(remote)) {
            //[self displayTableCall:animated];
        }
    }
    else if (acall && astate == LinphoneCallUpdating) {
        NSLog(@"自己响应 ------>");
    }
}

//发起请求相关
- (void)displayAskToEnableVideoCall:(LinphoneCall*) call
{
    linphone_call_defer_update(call);
    if (linphone_core_get_video_policy(LC)->automatically_accept) {
        NSLog(@"自动接受视频对讲!!");
        return;
    }
    
    //视频允许播放:
    const LinphoneCallParams *cp = linphone_call_get_current_params(call);
    LinphoneCallParams* paramsCopy = linphone_call_params_copy(cp);
    linphone_call_params_enable_video(paramsCopy, TRUE);
    linphone_call_accept_update(call, paramsCopy);
    linphone_call_params_unref(paramsCopy);
    NSLog(@"开始视频对讲!!");
    
    //linphone_core_enable_audio_adaptive_jittcomp(LC, true);
}

#pragma mark -

- (void)update {
//	const LinphoneAddress *addr = linphone_call_get_remote_address(_call);
//	[ContactDisplay setDisplayNameLabel:_nameLabel forAddress:addr];
//	char *uri = linphone_address_as_string_uri_only(addr);
//	_addressLabel.text = [NSString stringWithUTF8String:uri];
//	ms_free(uri);
//	[_avatarImage setImage:[FastAddressBook imageForAddress:addr thumbnail:NO] bordered:YES withRoundedRadius:YES];
//
//	_tabBar.hidden = linphone_call_params_video_enabled(linphone_call_get_remote_params(_call));
//	_tabVideoBar.hidden = !_tabBar.hidden;
}

#pragma mark - Property Functions

//- (void)setCall:(id)call {
//	_call = call;
//	[self update];
//}

#pragma mark - Action Functions

- (IBAction)onAcceptClick:(id)event
{
    //接听
	[[UCSIPCCManager instance] acceptCall:_call enableVideo:NO];
}

- (IBAction)onVideoAcceptClick:(UIButton *)sender
{
    //启用视频接听
    [[UCSIPCCManager instance] acceptCall:_call enableVideo:YES];
}


- (IBAction)onDeclineClick:(id)event
{
    //挂断
    [self callReleasedEvent];
	[[UCSIPCCManager instance] hangUpCall];
    
}

- (IBAction)onSpeakClick:(UIButton *)sender
{
    //声音控制开关
    sender.selected = !sender.selected;
    [[UCSIPCCManager instance] setSpeakerEnabled:sender.selected];
}

- (IBAction)setVideoSateEvents:(UIButton *)sender
{
    //启用视频
    BOOL status = sender.selected;
    sender.selected = !status;
    if (sender.selected) {
        [[UCSIPCCManager instance] setVideoEnable:YES];
    }else{
        [[UCSIPCCManager instance] setVideoEnable:NO];
    }
}

- (void)callReleasedEvent {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)callDurationUpdate {
    
    int duration = [[UCSIPCCManager instance] getCallDuration];
    if (duration != 0) {
        self.nameLabel.text = [NSString stringWithFormat:@"%@", [UCSIPCCManager durationToString:duration]];
    }
}

- (void)cancelTimer {
    
    [timer invalidate];
    timer = nil;
    
}
@end
