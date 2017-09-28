/* UICallCell.m
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
 *  GNU Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import <QuartzCore/QuartzCore.h>

#import "UCSIPCCManager.h"
#import "UCSIPCCManager.h"
#import "UICallCell.h"

@implementation UICallCellData

@synthesize address;
@synthesize image;

- (id)init:(UCSCall*)acall minimized:(BOOL)minimized{
    self = [super init];
    if(self != nil) {
        self->minimize = minimized;
        self->view = UICallCellOtherView_Avatar;
        self->call = acall;
        image = [UIImage imageNamed:@"avatar_unknown.png"];
        address = NSLocalizedString(@"Unknown",nil);
        [self update];
    }
    return self;
}

- (void)update {
    if(call == NULL) {
        
        return;
    }
//    const LinphoneAddress* addr = linphone_call_get_remote_address(call);

//    if(addr != NULL) {
//        BOOL useLinphoneAddress = true;
//        // contact name
//        char* lAddress = linphone_address_as_string_uri_only(addr);
//        if(lAddress) {
//            NSString *normalizedSipAddress = [FastAddressBook normalizeSipURI:[NSString stringWithUTF8String:lAddress]];
//            ABRecordRef contact = [[[LinphoneManager instance] fastAddressBook] getContact:normalizedSipAddress];
//            if(contact) {
//                useLinphoneAddress = false;
//                self.address = [FastAddressBook getContactDisplayName:contact];
//                UIImage *tmpImage = [FastAddressBook getContactImage:contact thumbnail:false];
//                if(tmpImage != nil) {
//                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^(void) {
//                        UIImage *tmpImage2 = [UIImage decodedImageWithImage:tmpImage];
//                        dispatch_async(dispatch_get_main_queue(), ^{
//                            [self setImage: tmpImage2];
//                        });
//                    });
//                }
//            }
//            ms_free(lAddress);
//        }
//        if(useLinphoneAddress) {
//            const char* lDisplayName = linphone_address_get_display_name(addr);
//            const char* lUserName = linphone_address_get_username(addr);
//            if (lDisplayName)
//                self.address = [NSString stringWithUTF8String:lDisplayName];
//            else if(lUserName)
//                self.address = [NSString stringWithUTF8String:lUserName];
//        }
//    }
}


@end

@implementation UICallCell

@synthesize data;

@synthesize headerBackgroundImage;
@synthesize headerBackgroundHighlightImage;

@synthesize addressLabel;
@synthesize stateLabel;
@synthesize stateImage;
@synthesize avatarImage;
@synthesize removeButton;

@synthesize headerView;
@synthesize avatarView;

@synthesize audioStatsView;

@synthesize audioCodecLabel;
@synthesize audioCodecHeaderLabel;
@synthesize audioUploadBandwidthLabel;
@synthesize audioUploadBandwidthHeaderLabel;
@synthesize audioDownloadBandwidthLabel;
@synthesize audioDownloadBandwidthHeaderLabel;
@synthesize audioIceConnectivityLabel;
@synthesize audioIceConnectivityHeaderLabel;

@synthesize videoStatsView;

@synthesize videoCodecLabel, videoCodecHeaderLabel;
@synthesize videoUploadBandwidthLabel, videoUploadBandwidthHeaderLabel;
@synthesize videoDownloadBandwidthLabel, videoDownloadBandwidthHeaderLabel;
@synthesize videoIceConnectivityLabel, videoIceConnectivityHeaderLabel;

@synthesize videoRecvSizeHeaderLabel, videoRecvSizeLabel;
@synthesize videoSentSizeHeaderLabel, videoSentSizeLabel;

@synthesize otherView;

@synthesize firstCell;
@synthesize conferenceCell;
@synthesize currentCall;
@synthesize detailsLeftSwipeGestureRecognizer;
@synthesize detailsRightSwipeGestureRecognizer;


#pragma mark - Lifecycle Functions

- (id)initWithIdentifier:(NSString*)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier]) != nil) {
        NSArray *arrayOfViews = [[NSBundle mainBundle] loadNibNamed:@"UICallCell"
                                                              owner:self
                                                            options:nil];

        if ([arrayOfViews count] >= 1) {
			//resize cell to match .nib size. It is needed when resized the cell to
			//correctly adapt its height too
			UIView *sub = ((UIView*)[arrayOfViews objectAtIndex:0]);
			[self setFrame:CGRectMake(0, 0, sub.frame.size.width, sub.frame.size.height)];
            [self addSubview:sub];
        }

        self->currentCall = FALSE;

        self->detailsRightSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(doDetailsSwipe:)];
        [detailsRightSwipeGestureRecognizer setDirection:UISwipeGestureRecognizerDirectionLeft];
        [otherView addGestureRecognizer:detailsRightSwipeGestureRecognizer];

        self->detailsRightSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(doDetailsSwipe:)];
        [detailsRightSwipeGestureRecognizer setDirection:UISwipeGestureRecognizerDirectionRight];
        [otherView addGestureRecognizer:detailsRightSwipeGestureRecognizer];

        [self->avatarView setHidden:TRUE];
        [self->audioStatsView setHidden:TRUE];
        [self->videoStatsView setHidden:TRUE];

        [UICallCell adaptSize:audioCodecHeaderLabel field:audioCodecLabel];
        [UICallCell adaptSize:audioDownloadBandwidthHeaderLabel field:audioDownloadBandwidthLabel];
        [UICallCell adaptSize:audioUploadBandwidthHeaderLabel field:audioUploadBandwidthLabel];
        [UICallCell adaptSize:audioIceConnectivityHeaderLabel field:audioIceConnectivityLabel];

        [UICallCell adaptSize:videoCodecHeaderLabel field:videoCodecLabel];
        [UICallCell adaptSize:videoDownloadBandwidthHeaderLabel field:videoDownloadBandwidthLabel];
        [UICallCell adaptSize:videoUploadBandwidthHeaderLabel field:videoUploadBandwidthLabel];
        [UICallCell adaptSize:videoIceConnectivityHeaderLabel field:videoIceConnectivityLabel];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

}


#pragma mark - Properties Functions

- (void)setData:(UICallCellData *)adata {
    if(adata == data) {
        return;
    }
    if(data != nil) {
        
        data = nil;
    }
    if(adata != nil) {
        data = adata;
    }
}

- (void)setCurrentCall:(BOOL) val {
    currentCall = val;
    if (currentCall && ![self isBlinkAnimationRunning:@"blink" target:headerBackgroundHighlightImage]) {
        [self startBlinkAnimation:@"blink" target:headerBackgroundHighlightImage];
    }
    if (!currentCall) {
        [self stopBlinkAnimation:@"blink" target:headerBackgroundHighlightImage];
    }
}


#pragma mark - Static Functions

+ (int)getMaximizedHeight {
	return 300;
}

+ (int)getMinimizedHeight {
	return 63;
}

+ (void)adaptSize:(UILabel*)label field:(UIView*)field {
    //
    // Adapt size
    //
    CGRect labelFrame = [label frame];
    CGRect fieldFrame = [field frame];

    fieldFrame.origin.x -= labelFrame.size.width;

    // Compute firstName size
    CGSize contraints;
    contraints.height = [label frame].size.height;
    contraints.width = ([field frame].size.width + [field frame].origin.x) - [label frame].origin.x;
    CGSize firstNameSize = [[label text] sizeWithFont:[label font] constrainedToSize: contraints];
    labelFrame.size.width = firstNameSize.width;

    // Compute lastName size & position
    fieldFrame.origin.x += labelFrame.size.width;
    fieldFrame.size.width = (contraints.width + [label frame].origin.x) - fieldFrame.origin.x;

    [label setFrame: labelFrame];
    [field setFrame: fieldFrame];
}


//+ (NSString*)iceToString:(LinphoneIceState)state {
//    switch (state) {
//        case LinphoneIceStateNotActivated:
//            return NSLocalizedString(@"Not activated", @"ICE has not been activated for this call");
//            break;
//        case LinphoneIceStateFailed:
//            return NSLocalizedString(@"Failed", @"ICE processing has failed");
//            break;
//        case LinphoneIceStateInProgress:
//            return NSLocalizedString(@"In progress", @"ICE process is in progress");
//            break;
//        case LinphoneIceStateHostConnection:
//            return NSLocalizedString(@"Direct connection", @"ICE has established a direct connection to the remote host");
//            break;
//        case LinphoneIceStateReflexiveConnection:
//            return NSLocalizedString(@"NAT(s) connection", @"ICE has established a connection to the remote host through one or several NATs");
//            break;
//        case LinphoneIceStateRelayConnection:
//            return NSLocalizedString(@"Relay connection", @"ICE has established a connection through a relay");
//            break;
//    }
//}


#pragma mark - Event Functions

- (void)applicationWillEnterForeground:(NSNotification*)notif {
    if (currentCall) {
        [self startBlinkAnimation:@"blink" target:headerBackgroundHighlightImage];
    }
}


#pragma mark - Animation Functions

- (void)startBlinkAnimation:(NSString *)animationID  target:(UIView *)target {
//    if( [[LinphoneManager instance] lpConfigBoolForKey:@"animations_preference"]){
    CABasicAnimation *blink = [CABasicAnimation animationWithKeyPath:@"opacity"];
    blink.duration = 1.0;
    blink.fromValue = [NSNumber numberWithDouble:0.0f];
    blink.toValue = [NSNumber numberWithDouble:1.0f];
    blink.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    blink.autoreverses = TRUE;
    blink.repeatCount = HUGE_VALF;
    [target.layer addAnimation:blink forKey:animationID];
//    } else {
//        [target setAlpha:1.0f];
//    }
}

- (BOOL)isBlinkAnimationRunning:(NSString *)animationID target:(UIView *)target {
    return [target.layer animationForKey:animationID] != nil;
}

- (void)stopBlinkAnimation:(NSString *)animationID target:(UIView *)target {
    if( [self isBlinkAnimationRunning:animationID target:target] ){
    [target.layer removeAnimationForKey:animationID];
    }
    [target setAlpha:0.0f];
}


#pragma mark -

- (void)update {
    if(data == nil || data->call == NULL) {
        
        return;
    }
    UCSCall *call = data->call;
    [addressLabel setText:data.address];
    [avatarImage setImage:data.image];

    UCSCallState state = [[UCSIPCCManager instance] getCallState:call];
    if(!conferenceCell) {
        if(state == UCSCallOutgoingRinging) {
            [stateImage setImage:[UIImage imageNamed:@"call_state_ringing_default.png"]];
            [stateImage setHidden:false];
//            [pauseButton setHidden:true];
        } else if(state == UCSCallOutgoingInit || state == UCSCallOutgoingProgress){
            [stateImage setImage:[UIImage imageNamed:@"call_state_outgoing_default.png"]];
            [stateImage setHidden:false];
//            [pauseButton setHidden:true];
        } else {
            [stateImage setHidden:true];
//            [pauseButton setHidden:false];
//            [pauseButton update];
        }
        [removeButton setHidden:true];
        if(firstCell) {
            [headerBackgroundImage setImage:[UIImage imageNamed:@"cell_call_first.png"]];
            [headerBackgroundHighlightImage setImage:[UIImage imageNamed:@"cell_call_first_highlight.png"]];
        } else {
            [headerBackgroundImage setImage:[UIImage imageNamed:@"cell_call.png"]];
            [headerBackgroundHighlightImage setImage:[UIImage imageNamed:@"cell_call_highlight.png"]];
        }
    } else {
        [stateImage setHidden:true];
//        [pauseButton setHidden:true];
        [removeButton setHidden:false];
        [headerBackgroundImage setImage:[UIImage imageNamed:@"cell_conference.png"]];
    }

    int duration = [[UCSIPCCManager instance] getCallDuration:call];
    [stateLabel setText:[NSString stringWithFormat:@"%02i:%02i", (duration/60), (duration%60), nil]];

    if(!data->minimize) {
        CGRect frame = [self frame];
        frame.size.height = [UICallCell getMaximizedHeight];
        [self setFrame:frame];
		frame = otherView.frame;
		frame.size.height = [UICallCell getMaximizedHeight];
        [otherView setHidden:false];
		otherView.frame = frame;
    } else {
        CGRect frame = [self frame];
        frame.size.height = [headerView frame].size.height;
        [self setFrame:frame];
        [otherView setHidden:true];
    }

    [self updateStats];

    [self updateDetailsView];
}

- (void)updateStats {
    if(data == nil || data->call == NULL) {
        return;
    }
    UCSCall *call = data->call;

//    const LinphoneCallParams *params = linphone_call_get_current_params(call);
//    {
//        const PayloadType* payload = linphone_call_params_get_used_audio_codec(params);
//        if(payload != NULL) {
//            [audioCodecLabel setText:[NSString stringWithFormat:@"%s/%i/%i", payload->mime_type, payload->clock_rate, payload->channels]];
//        } else {
//            [audioCodecLabel setText:NSLocalizedString(@"No codec", nil)];
//        }
//        const LinphoneCallStats *stats = linphone_call_get_audio_stats(call);
//        if(stats != NULL) {
//            [audioUploadBandwidthLabel setText:[NSString stringWithFormat:@"%1.1f kbits/s", stats->upload_bandwidth]];
//            [audioDownloadBandwidthLabel setText:[NSString stringWithFormat:@"%1.1f kbits/s", stats->download_bandwidth]];
//            [audioIceConnectivityLabel setText:[UICallCell iceToString:stats->ice_state]];
//        } else {
//            [audioUploadBandwidthLabel setText:@""];
//            [audioDownloadBandwidthLabel setText:@""];
//            [audioIceConnectivityLabel setText:@""];
//        }
//    }
}


- (void)updateDetailsView {
    if(data == nil || data->call == NULL) {
        
        return;
    }
    if(data->view == UICallCellOtherView_Avatar && avatarView.isHidden) {
        [self->avatarView setHidden:FALSE];
        [self->audioStatsView setHidden:TRUE];
        [self->videoStatsView setHidden:TRUE];
    } else if(data->view == UICallCellOtherView_AudioStats && audioStatsView.isHidden) {
        [self->avatarView setHidden:TRUE];
        [self->audioStatsView setHidden:FALSE];
        [self->videoStatsView setHidden:TRUE];
    } else if(data->view == UICallCellOtherView_VideoStats && videoStatsView.isHidden) {
        [self->avatarView setHidden:TRUE];
        [self->audioStatsView setHidden:TRUE];
        [self->videoStatsView setHidden:FALSE];
    }
}

- (void)selfUpdate {
    UITableView *parentTable = (UITableView *)self.superview;

    while( parentTable != nil && ![parentTable isKindOfClass:[UITableView class]] ) parentTable = (UITableView *)[parentTable superview];

    if(parentTable != nil) {
       NSIndexPath *index= [parentTable indexPathForCell:self];
        if(index != nil) {
            [parentTable reloadRowsAtIndexPaths:@[index] withRowAnimation:false];
        }
    }
}


#pragma mark - Action Functions

- (IBAction)doHeaderClick:(id)sender {
    if(data) {
        data->minimize = !data->minimize;
        [self selfUpdate];
    }
}

- (IBAction)doRemoveClick:(id)sender {
    if(data != nil && data->call != NULL) {
//        linphone_core_remove_from_conference([LinphoneManager getLc], data->call);
    }
}

- (IBAction)doDetailsSwipe:(UISwipeGestureRecognizer *)sender {
    CATransition* trans = nil;
    if(data != nil) {
        if (sender.direction == UISwipeGestureRecognizerDirectionLeft) {
            if(data->view == UICallCellOtherView_MAX - 1) {
                data->view = 0;
            } else {
                ++data->view;
            }
            trans = [CATransition animation];
            [trans setType:kCATransitionPush];
            [trans setDuration:0.35];
            [trans setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [trans setSubtype:kCATransitionFromRight];
        } else if (sender.direction == UISwipeGestureRecognizerDirectionRight) {
            if(data->view == 0) {
                data->view = UICallCellOtherView_MAX - 1;
            } else {
                --data->view;
            }
            trans = [CATransition animation];
            [trans setType:kCATransitionPush];
            [trans setDuration:0.35];
            [trans setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [trans setSubtype:kCATransitionFromLeft];
        }
        if(trans) {
            [otherView.layer removeAnimationForKey:@"transition"];
            [otherView.layer addAnimation:trans forKey:@"transition"];
            [self updateDetailsView];
        }
    }
}

@end
