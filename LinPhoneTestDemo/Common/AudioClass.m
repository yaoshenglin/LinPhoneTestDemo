//
//  AudioClass.m
//  LinPhoneTestDemo
//
//  Created by xy on 2017/9/28.
//  Copyright © 2017年 xy. All rights reserved.
//

/*1.AVAudioSessionCategoryAmbient
 用于非以语音为主的应用，使用这个category的应用会随着静音键和屏幕关闭而静音。并且不会中止其它应用播放声音，可以和其它自带应用如iPod，safari等同时播放声音。注意：该Category无法在后台播放声音
 
 2.AVAudioSessionCategorySoloAmbient
 类似于AVAudioSessionCategoryAmbient不同之处在于它会中止其它应用播放声音。 这个category为默认category。该Category无法在后台播放声音
 
 3.AVAudioSessionCategoryPlayback
 用于以语音为主的应用，使用这个category的应用不会随着静音键和屏幕关闭而静音。可在后台播放声音
 
 4.AVAudioSessionCategoryRecord
 用于需要录音的应用，设置该category后，除了来电铃声，闹钟或日历提醒之外的其它系统声音都不会被播放。该Category只提供单纯录音功能。
 
 5. AVAudioSessionCategoryPlayAndRecord
 用于既需要播放声音又需要录音的应用，语音聊天应用(如微信）应该使用这个category。该Category提供录音和播放功能。如果你的应用需要用到iPhone上的听筒，该category是你唯一的选择，在该Category下声音的默认出口为听筒（在没有外接设备的情况下）。
 
 注意：并不是一个应用只能使用一个category，程序应该根据实际需要来切换设置不同的category，举个例子，录音的时候，需要设置为AVAudioSessionCategoryRecord，当录音结束时，应根据程序需要更改category为AVAudioSessionCategoryAmbient，AVAudioSessionCategorySoloAmbient或AVAudioSessionCategoryPlayback中的一种。*/

#import "AudioClass.h"

@implementation AudioClass

-(BOOL) isOtherAudioPlaying {
    //设置Category
    NSError *setCategoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance]
                    setCategory: AVAudioSessionCategoryAmbient
                    error: &setCategoryError];
    
    if (!success) { /* handle the error in setCategoryError */ }
    return success;
}

- (void)initCapacity
{
    //Activate & Deactivate AudioSession
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL ret = [audioSession setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"%s - activate audio session failed with error %@", __func__,[error description]);
    }
    
    //Note: Set AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation to resume other apps' audio.
    ret = [audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (!ret)
    {
    }
    
    //修改Category的默认行为:
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    //OverrideOutputAudioPort
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
}

@end
