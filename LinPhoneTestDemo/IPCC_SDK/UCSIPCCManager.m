//
//  UCSIPCCManager.m
//  ucsipccsdk
//
//  Created by Jozo.Chan on 16/6/29.
//  Copyright © 2016年 i.Jozo. All rights reserved.
//

#import "UCSIPCCManager.h"
#import "Utils.h"

@interface UCSIPCCManager() {
@public
    NSDictionary *dict;
    NSDictionary *changedDict;
}

@end

@implementation UCSIPCCManager

static UCSIPCCManager* theUCSIPCCManager = nil;
static id _ucsIPCCDelegate = nil; //代理对象，用于回调

/**
 @author Jozo, 16-06-30 11:06:07
 
 实例化
 */
+ (UCSIPCCManager*)instance {
    if(theUCSIPCCManager == nil) {
        theUCSIPCCManager = [UCSIPCCManager new];
    }
    return theUCSIPCCManager;
}

- (id)init {
    self = [super init];
    if (self) {
        dict = [[NSMutableDictionary alloc] init];
        changedDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/**
 @author Jozo, 16-07-01 15:07:51
 
 扬声器状态
 */
- (BOOL)speakerEnabled
{
    return [LinphoneManager instance].speakerEnabled;
}

- (void)setSpeakerEnabled:(BOOL)speakerEnabled
{
    [UCSIPCCSDKLog saveDemoLogInfo:[NSString stringWithFormat:@"设置扬声器为%d", speakerEnabled] withDetail:nil];
    [[LinphoneManager instance] setSpeakerEnabled:speakerEnabled];
}


/**
 @author Jozo, 16-07-01 15:07:37
 
 获取当前通话
 */
- (UCSCall *)currentCall {
    return linphone_core_get_current_call(LC) ? linphone_core_get_current_call(LC) : nil;
}


/**
 @author Jozo, 16-07-01 15:07:06
 
 UCS是否已经准备好
 */
- (BOOL)isUCSReady
{
     return [LinphoneManager isLcReady];
}


/*!
 *  @brief  设置代理
 */
//- (void)setDelegate:(id<UCSIPCCDelegate>)delegate
//{
//    [UCSIPCCManager instance].delegate = delegate;
////    _ucsIPCCDelegate = delegate;
//}


/**
 @author Jozo, 16-06-30 11:06:18
 
 初始化
 */
- (void)startUCSphone {
    
    [[LinphoneManager instance] startLibLinphone];
    [UCSIPCCSDKLog saveDemoLogInfo:@"初始化成功" withDetail:@"startLinphone"];
    NSLog(@"linphone version : %s",linphone_core_get_version());
}

/**
 设置来电超时自动挂断时间
 */
- (void)setTimeOut
{
    //默认30s
    LinphoneCore *lc = [LinphoneManager getLc];
    linphone_core_set_inc_timeout(lc,60);// 来电超时自动挂断时间设置
}


- (int)getTimeout
{
    LinphoneCore *lc = [LinphoneManager getLc];
    int sections = linphone_core_get_inc_timeout(lc);
    return sections;
}


/**
 @author Jozo, 16-06-30 11:06:13
 
 登陆
 
 @param username  用户名
 @param password  密码
 @param displayName  昵称
 @param domain    域名或IP
 @param port      端口
 @param transport 连接方式

 */
- (BOOL)addProxyConfig:(NSString*)username password:(NSString*)password displayName:(NSString *)displayName domain:(NSString*)domain port:(NSString *)port withTransport:(NSString*)transport
{
    LinphoneCore* lc = [LinphoneManager getLc];
    
    if (lc == nil) {
        [self startUCSphone];
        lc = [LinphoneManager getLc];
    }
    
    LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config(lc);
    NSString* server_address = domain;
    
    char *normalizedUserName = (char *)username.UTF8String;
    //linphone_proxy_config_normalize_number(proxyCfg, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
    linphone_proxy_config_normalize_phone_number(proxyCfg, [username cStringUsingEncoding:[NSString defaultCStringEncoding]]);
    
    
    const char *identity = [[NSString stringWithFormat:@"sip:%@@%@", username, domain] cStringUsingEncoding:NSUTF8StringEncoding];
    
    LinphoneAddress* linphoneAddress = linphone_address_new(identity);
    linphone_address_set_username(linphoneAddress, normalizedUserName);
    if (displayName && displayName.length != 0) {
        linphone_address_set_display_name(linphoneAddress, (displayName.length ? displayName.UTF8String : NULL));
    }
    if( domain && [domain length] != 0) {
        if( transport != nil ){
            NSString *value = [NSString stringWithFormat:@"%@:%@;transport=%@", server_address, port, [transport lowercaseString]];
            if (port.length <= 0) {
                value = [NSString stringWithFormat:@"%@;transport=%@", server_address, [transport lowercaseString]];
            }
            
            server_address = value;
#ifdef DEBUG
            NSLog(@"server_address = %@",server_address);
#endif
        }
        // when the domain is specified (for external login), take it as the server address
        linphone_proxy_config_set_server_addr(proxyCfg, [server_address UTF8String]);
        linphone_address_set_domain(linphoneAddress, [domain UTF8String]);
        
    }
    
    // 添加了昵称后的identity(此处是大坑！大坑！大坑)
    identity = linphone_address_as_string(linphoneAddress);
    
    LinphoneAuthInfo* info = linphone_auth_info_new([username UTF8String]
                                                    , NULL, [password UTF8String]
                                                    , NULL
                                                    , linphone_proxy_config_get_realm(proxyCfg)
                                                    ,linphone_proxy_config_get_domain(proxyCfg));
    
    [self setDefaultSettings:proxyCfg];
    
    [self clearProxyConfig];
    
    //linphone_proxy_config_set_identity(proxyCfg, identity);
    linphone_proxy_config_set_identity_address(proxyCfg, linphoneAddress);//会崩溃
    linphone_proxy_config_set_expires(proxyCfg, 2000);
    linphone_proxy_config_enable_register(proxyCfg, true);
    linphone_core_add_auth_info(lc, info);
    linphone_core_add_proxy_config(lc, proxyCfg);
    linphone_core_set_default_proxy_config(lc, proxyCfg);
    
    //linphone_address_destroy(linphoneAddress);
    linphone_address_unref(linphoneAddress);
    ms_free((void *)identity);
    
    
    [UCSIPCCSDKLog saveDemoLogInfo:@"登陆信息配置成功" withDetail:[NSString stringWithFormat:@"username:%@,\npassword:%@,\ndisplayName:%@\ndomain:%@,\nport:%@\ntransport:%@", username, password, displayName, domain, port, transport]];
    

    
    return TRUE;
}


/**
 @author Kohler, 16-07-04 17:07:33
 
 注销登陆信息
 */
- (void)removeAccount
{
    [UCSIPCCSDKLog saveDemoLogInfo:@"注销登陆信息" withDetail:nil];
    if (self.isUCSReady == YES) {
        [self clearProxyConfig];
        //[[LinphoneManager instance] destroyLibLinphone];
        [[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"pushnotification_preference"];
        
        LinphoneCore *lc = [LinphoneManager getLc];
        LinphoneSipTransports transportValue = {5060,5060,-1,-1};
        
        if (linphone_core_set_sip_transports(lc, &transportValue)) {
            [LinphoneLogger logc:LinphoneLoggerError format:"cannot set transport"];
        }
        
        [[LinphoneManager instance] lpConfigSetString:@"" forKey:@"sharing_server_preference"];
        [[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"ice_preference"];
        [[LinphoneManager instance] lpConfigSetString:@"" forKey:@"stun_preference"];
        linphone_core_set_stun_server(lc, NULL);
        //linphone_core_set_firewall_policy(lc, LinphonePolicyNoFirewall);
        linphone_core_set_nat_policy(lc, LinphonePolicyNoFirewall);
    }
}


- (void)clearProxyConfig
{
    linphone_core_clear_proxy_config([LinphoneManager getLc]);
    linphone_core_clear_all_auth_info([LinphoneManager getLc]);
}


- (void)setDefaultSettings:(LinphoneProxyConfig*)proxyCfg
{
    LinphoneManager* lm = [LinphoneManager instance];
    
    [lm configurePushTokenForProxyConfig:proxyCfg];
    
}


/**
 获取登录账号
 
 @return 用户名
 */
- (NSString *)getAccount
{
    NSString *username = nil;
    LinphoneProxyConfig *defaultProxy = linphone_core_get_default_proxy_config(LC);
    if (defaultProxy) {
        const LinphoneAddress *address = linphone_proxy_config_get_identity_address(defaultProxy);
        const char *name = linphone_address_get_username(address);
        username = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        
        //const char *identity = linphone_proxy_config_get_identity(defaultProxy);
        //NSLog(@"identity = %@",[NSString stringWithUTF8String:identity]);
    }
    
    return username;
}


/**
 @author Jozo, 16-06-30 11:06:52
 
 拨打电话
 
 @param address     ID
 @param displayName 昵称
 @param transfer    transfer
 */
- (void)call:(NSString *)address displayName:(NSString*)displayName transfer:(BOOL)transfer enableVideo:(BOOL)enable
{
    // 号码有效性判断
    if (address.length <= 0) {
        
        [UCSIPCCSDKLog saveDemoLogInfo:@"请输入正确的号码" withDetail:[NSString stringWithFormat:@"address:%@,\ndisplayName:%@", address, displayName]];
        NSDictionary *dic = [NSDictionary dictionaryWithObject:@"号码错误，请输入正确的号码" forKey:@"message"];
        [self.delegate onDialFailed:UCSCallNumberError withMessage:dic];
        return;
    }
    
    if (![address containsString:@"@"]) {
        address = [address stringByAppendingString:@"@sip.linphone.org"];
    }
    
    [[LinphoneManager instance] call:address displayName:displayName transfer:transfer enableVideo:enable];
    [UCSIPCCSDKLog saveDemoLogInfo:@"拨打电话操作" withDetail:[NSString stringWithFormat:@"address:%@,\ndisplayName:%@", address, displayName]];
}


/**
 @author Jozo, 16-06-30 20:06:43
 
 接听电话
 */
- (void)acceptCall:(UCSCall *)call enableVideo:(BOOL)enable
{
    const LinphoneCallParams *params = linphone_call_get_remote_params(call);
    if (linphone_call_params_video_enabled(params)) {
        linphone_call_enable_camera(call, YES);
        NSLog(@"linphone_call_enable_camera");
    }else{
        enable = NO;
    }
    
    [[LinphoneManager instance] acceptCall:call enableVideo:enable];
    [UCSIPCCSDKLog saveDemoLogInfo:@"接听电话操作" withDetail:nil];
}


/**
 @author Jozo, 16-06-30 11:06:41
 
 挂断电话
 */
- (void)hangUpCall {
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* currentcall = linphone_core_get_current_call(lc);
    if (linphone_core_is_in_conference(lc) || // In conference
        (linphone_core_get_conference_size(lc) > 0) // Only one conf
        ) {
        linphone_core_terminate_conference(lc);
    } else if(currentcall != NULL) { // In a call
        //主动挂断
        //linphone_core_terminate_call(lc, currentcall);
        linphone_call_terminate(currentcall);
    } else {
        //被动挂断
        const MSList* calls = linphone_core_get_calls(lc);
        if (bctbx_list_size(calls) == 1) {
            // Only one call
            //linphone_core_terminate_call(lc,(LinphoneCall*)(calls->data));
            linphone_call_terminate((LinphoneCall*)(calls->data));
        }
    }
}


/**
 @author Jozo, 16-06-30 17:06:47
 
 获取通话状态
 */
- (UCSCallState)getCallState:(UCSCall *)call {
    return (UCSCallState)linphone_call_get_state(call);
}


/**
 @author Jozo, 16-06-30 18:06:06
 
 获取通话时长
 */
- (int)getCallDuration {
    if (LC == nil || self.isUCSReady == NO) {
        return 0;
    }
    int duration =
    linphone_core_get_current_call(LC) ? linphone_call_get_duration(linphone_core_get_current_call(LC)) : 0;
    
    return duration;
}


/**
 @author Jozo, 16-06-30 18:06:19
 
 获取对方号码
 */
- (NSString *)getRemoteAddress {
    if (self.currentCall == nil) {
        return nil;
    }
    const LinphoneAddress *address = linphone_call_get_remote_address(self.currentCall);
    
    char *uri = linphone_address_as_string_uri_only(address);
    NSString *addressStr = [NSString stringWithUTF8String:uri];
    NSString *normalizedSipAddress = [[addressStr
                                       componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@" "];
    LinphoneAddress *addr = linphone_core_interpret_url(LC, [addressStr UTF8String]);
    
    if (addr != NULL) {
        linphone_address_clean(addr);
        char *tmp = linphone_address_as_string(addr);
        normalizedSipAddress = [NSString stringWithUTF8String:tmp];
        ms_free(tmp);
        //linphone_address_destroy(addr);
        linphone_address_unref(addr);
    }
    
//    char *name = linphone_address_get_username(address);
//    NSString *addressStr = [NSString stringWithUTF8String:name];
   
    return addressStr;
}


/**
 @author Jozo, 16-06-30 18:06:19
 
 获取对方昵称
 */
- (NSString *)getRemoteDisplayName {
    if (self.currentCall == nil) {
        return nil;
    }
    const LinphoneAddress *address = linphone_core_get_current_call_remote_address(LC);
//    LinphoneAddress *parsed = linphone_core_get_primary_contact_parsed(LC);
    
    const char *uri = linphone_address_get_display_name(address);
    if (uri) {
        return [NSString stringWithUTF8String:uri];
    }
    return @"";
}


/**
 @author Jozo, 16-07-04 09:07:50
 
 获取通话参数
 */
- (UCSCallParams *)getCallParams {
    if (!self.currentCall) {
        return nil;
    }
    return (UCSCallParams *)linphone_call_get_current_params(self.currentCall);
}


/**
 启用视频
 */
- (void)setVideoEnable:(BOOL)enabled
{
    if (!linphone_core_video_display_enabled(LC)) {
        NSLog(@"视频功能没有启用");
        return;
    }
    
    LinphoneCall *call = linphone_core_get_current_call(LC);
    if (call) {
        LinphoneCallAppData *callAppData = (__bridge LinphoneCallAppData *)linphone_call_get_user_pointer(call);
        callAppData->videoRequested =
        TRUE; /* will be used later to notify user if video was not activated because of the linphone core*/
        LinphoneCallParams *call_params = linphone_core_create_call_params(LC,call);
        linphone_call_params_enable_video(call_params, enabled);
        //linphone_core_update_call(LC, call, call_params);
        linphone_call_update(call, call_params);
        linphone_call_enable_camera(call, YES);
        //linphone_call_params_destroy(call_params);
        linphone_call_params_unref(call_params);
    } else {
        NSLog(@"Cannot toggle video button, because no current call");
    }
}

+ (void)sendTextWithRoom:(LinphoneChatRoom *)room message:(NSString *)text
{
    if (!room || !text) {
        NSLog(@"发送信息失败, %@ %@",room,text);
        return;
    }
    LinphoneChatMessage *msg = linphone_chat_room_create_message(room, text.UTF8String);
    linphone_chat_room_send_chat_message(room, linphone_chat_message_ref(msg));
}

+ (NSString *)TextMessageForChat:(LinphoneChatMessage *)message
{
    const char *url = linphone_chat_message_get_external_body_url(message);
    const LinphoneContent *last_content = linphone_chat_message_get_file_transfer_information(message);
    if (last_content) {
        const char *encoding = linphone_content_get_encoding(last_content);
        NSLog(@"encoding = %s",encoding);
    }
    // Last message was a file transfer (image) so display a picture...
    if (url || last_content) {
        return @"🗻";
    } else {
        const char *text = linphone_chat_message_get_text(message) ?: "";
        return [NSString stringWithUTF8String:text] ?: [NSString stringWithCString:text encoding:NSASCIIStringEncoding]
        ?: NSLocalizedString(@"(invalid string)", nil);
    }
}

+ (NSString *)ContactDateForChat:(LinphoneChatMessage *)message
{
    const LinphoneAddress *address = linphone_chat_message_get_from_address(message) ? linphone_chat_message_get_from_address(message) : linphone_chat_room_get_peer_address(linphone_chat_message_get_chat_room(message));
    return [NSString stringWithFormat:@"%@ - %@", [LinphoneUtils timeToString:linphone_chat_message_get_time(message) withFormat:LinphoneDateChatBubble], [LinphoneManager displayNameForAddress:address]];
}


/**
 @author Jozo, 16-07-01 15:07:19
 
  将int转为标准格式的NSString时间
 */
+ (NSString *)durationToString:(int)duration
{
    NSMutableString *result = [[NSMutableString alloc] init];
    if (duration / 3600 > 0) {
        [result appendString:[NSString stringWithFormat:@"%02i:", duration / 3600]];
        duration = duration % 3600;
    }
    return [result stringByAppendingString:[NSString stringWithFormat:@"%02i:%02i", (duration / 60), (duration % 60)]];
}


- (BOOL)checkPhoneNumInput:(NSString *)mobileNum
{
    if (mobileNum.length == 14)
    {
        return YES;
    }
    /**
     * 手机号码:
     * 13[0-9], 14[5,7], 15[0, 1, 2, 3, 5, 6, 7, 8, 9], 17[6, 7, 8], 18[0-9], 170[0-9]
     * 移动号段: 134,135,136,137,138,139,150,151,152,157,158,159,182,183,184,187,188,147,178,1705
     * 联通号段: 130,131,132,155,156,185,186,145,176,1709
     * 电信号段: 133,153,180,181,189,177,1700
     */
    NSString *MOBILE = @"^1((3[0-9]|4[57]|5[0-35-9]|7[0678]|8[0-9])\\d{8}$)";
    /**
     * 中国移动：China Mobile
     * 134,135,136,137,138,139,150,151,152,157,158,159,182,183,184,187,188,147,178,1705
     */
    NSString *CM = @"(^1(3[4-9]|4[7]|5[0-27-9]|7[8]|8[2-478])\\d{8}$)|(^1705\\d{7}$)";
    /**
     * 中国联通：China Unicom
     * 130,131,132,155,156,185,186,145,176,1709
     */
    NSString *CU = @"(^1(3[0-2]|4[5]|5[56]|7[6]|8[56])\\d{8}$)|(^1709\\d{7}$)";
    /**
     * 中国电信：China Telecom
     * 133,153,180,181,189,177,1700
     */
    NSString *CT = @"(^1(33|53|77|8[019])\\d{8}$)|(^1700\\d{7}$)";
    /**
    * 大陆地区固话及小灵通
    * 区号：010,020,021,022,023,024,025,027,028,029
    * 号码：七位或八位
    */
    NSString *PHS = @"(^0(10|2[0-5789]|\\d{3})\\d{7,8}$)";
    
    NSPredicate *regextestmobile = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", MOBILE];
    NSPredicate *regextestcm = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CM];
    NSPredicate *regextestcu = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CU];
    NSPredicate *regextestct = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", CT];
    NSPredicate *regextestphs = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", PHS];
    
    BOOL isMobile = [regextestmobile evaluateWithObject:mobileNum];
    BOOL isCm = [regextestcm evaluateWithObject:mobileNum];
    BOOL isCu = [regextestcu evaluateWithObject:mobileNum];
    BOOL isCt = [regextestct evaluateWithObject:mobileNum];
    BOOL isPhs = [regextestphs evaluateWithObject:mobileNum];
    if (isMobile || isCm || isCu || isCt || isPhs)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}


//+ (LinphoneAddress *)normalizeSipOrPhoneAddress:(NSString *)value {
//    if (!value) {
//        return NULL;
//    }
//    
//    LinphoneProxyConfig *cfg = linphone_core_get_default_proxy_config(LC);
//    LinphoneAddress *addr = linphone_proxy_config_normalize_sip_uri(cfg, value.UTF8String);
//    
//    // since user wants to escape plus, we assume it expects to have phone numbers by default
//    if (addr && cfg && linphone_proxy_config_get_dial_escape_plus(cfg)) {
//        char *phone = linphone_proxy_config_normalize_phone_number(cfg, value.UTF8String);
//        if (phone) {
//            linphone_address_set_username(addr, phone);
//            ms_free(phone);
//        }
//    }
//
//    return addr;
//}


@end
