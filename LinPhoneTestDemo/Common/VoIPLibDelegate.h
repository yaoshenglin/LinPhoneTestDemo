//
//  VoIPLibDelegate.h
//  iFace
//
//  Created by xy on 2017/10/14.
//  Copyright © 2017年 weicontrol. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UCSIPCCManager.h"

@protocol VoIPDelegate <NSObject>

- (void)onRegisterStateChange:(UCSRegistrationState) state msgStr:(NSString *) message;

@end

@interface VoIPLibDelegate : NSObject
{
@public
    LinphoneChatRoom *currentRoom;
}

@property (nonatomic, weak) id delegate;

+ (VoIPLibDelegate *)instance;

@end
