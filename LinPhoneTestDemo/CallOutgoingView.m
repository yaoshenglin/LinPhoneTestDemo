/* OutgoingCallViewController.m
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
 *  拨出
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "CallOutgoingView.h"
#import "UCSIPCCManager.h"

static NSTimer *timer;
@implementation CallOutgoingView

#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription
{
	if (compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"CallOutgoing"
                                                                content:@"CallOutgoingView"
                                                               stateBar:@"UIStateBar"
                                                        stateBarEnabled:true
                                                                 tabBar:@"UIMainBar"
                                                          tabBarEnabled:true
                                                             fullscreen:false
                                                          landscapeMode:false
                                                           portraitMode:true];

		compositeDescription.darkBackground = true;
	}
	return compositeDescription;
}

- (UICompositeViewDescription *)compositeViewDescription
{
	return self.class.compositeViewDescription;
}

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
    NSString *remoteAddress = [[UCSIPCCManager instance] getRemoteAddress];
    self.detailLabel.text = remoteAddress;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callReleasedEvent) name:@"UCS_Call_Released" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(callDurationUpdate) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [timer fire];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    //[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self cancelTimer];
	[NSNotificationCenter.defaultCenter removeObserver:self];
}


- (IBAction)onDeclineClick:(id)sender
{
    
    [self callReleasedEvent];
    [[UCSIPCCManager instance] hangUpCall];
}

- (IBAction)onSpeakClick:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    [[UCSIPCCManager instance] setSpeakerEnabled:sender.selected];
}

- (IBAction)setVideoStatusEvents:(UIButton *)sender
{
    BOOL status = sender.selected;
    sender.selected = !status;
    if (sender.selected) {
        [[UCSIPCCManager instance] setVideoEnable:YES];
    }else{
        [[UCSIPCCManager instance] setVideoEnable:NO];
    }
}

- (void)callReleasedEvent
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)callDurationUpdate
{
    int duration = [[UCSIPCCManager instance] getCallDuration];
    if (duration != 0) {
        self.nameLabel.text = [NSString stringWithFormat:@"%@", [UCSIPCCManager durationToString:duration]];
    }
}

- (void)cancelTimer
{
    [timer invalidate];
    timer = nil;
}

@end
