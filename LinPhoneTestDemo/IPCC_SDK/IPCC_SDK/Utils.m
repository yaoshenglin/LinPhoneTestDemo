/* Utils.m
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
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */   
#define FILE_SIZE 17
#define DOMAIN_SIZE 3

#import <asl.h>
#import "Utils.h"

@implementation LinphoneLogger

+ (NSString *)cacheDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    // cache directory must be created if not existing
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cachePath
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&error]) {
            LOGE(@"Could not create cache directory: %@", error);
        }
    }
    return cachePath;
}

+ (void)log:(OrtpLogLevel)severity file:(const char *)file line:(int)line format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    const char *utf8str = [str cStringUsingEncoding:NSString.defaultCStringEncoding];
    const char *filename = strchr(file, '/') ? strrchr(file, '/') + 1 : file;
    NSString *value = [NSString stringWithFormat:@"(%*s:%-4d) %s", FILE_SIZE, filename + MAX((int)strlen(filename) - FILE_SIZE, 0), line, utf8str];
    //ortp_log(severity, "(%*s:%-4d) %s", FILE_SIZE, filename + MAX((int)strlen(filename) - FILE_SIZE, 0), line, utf8str);
    va_end(args);
    
    NSLog(@"%@",value);
    //    if(severity == ORTP_DEBUG) {
    //        LOGD(str);
    //    } else  if(severity == ORTP_MESSAGE) {
    //        LOGI(str);
    //    } else if(severity == ORTP_WARNING) {
    //        LOGW(str);
    //    } else if(severity == ORTP_ERROR) {
    //        LOGE(str);
    //    } else if(severity == ORTP_FATAL) {
    //        LOGF(str);
    //    }
}

+ (void)enableLogs:(OrtpLogLevel)level {
    BOOL enabled = (level >= ORTP_DEBUG && level < ORTP_ERROR);
    static BOOL stderrInUse = NO;
    if (!stderrInUse) {
        asl_add_log_file(NULL, STDERR_FILENO);
        stderrInUse = YES;
    }
    linphone_core_set_log_collection_path([self cacheDirectory].UTF8String);
    linphone_core_set_log_handler(linphone_iphone_log_handler);
    linphone_core_enable_log_collection(enabled);
    if (level == 0) {
        linphone_core_set_log_level(ORTP_FATAL);
        ortp_set_log_level("ios", ORTP_FATAL);
        NSLog(@"I/%s/Disabling all logs", ORTP_LOG_DOMAIN);
    } else {
        NSLog(@"I/%s/Enabling %s logs", ORTP_LOG_DOMAIN, (enabled ? "all" : "application only"));
        linphone_core_set_log_level(level);
        ortp_set_log_level("ios", level == ORTP_DEBUG ? ORTP_DEBUG : ORTP_MESSAGE);
    }
}

#pragma mark - Logs Functions callbacks

void linphone_iphone_log_handler(const char *domain, OrtpLogLevel lev, const char *fmt, va_list args) {
    NSString *format = [[NSString alloc] initWithUTF8String:fmt];
    NSString *formatedString = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *lvl;
    
    if (!domain)
        domain = "lib";
    // since \r are interpreted like \n, avoid double new lines when logging network packets (belle-sip)
    // output format is like: I/ios/some logs. We truncate domain to **exactly** DOMAIN_SIZE characters to have
    // fixed-length aligned logs
    switch (lev) {
        case ORTP_FATAL:
            lvl = @"Fatal";
            break;
        case ORTP_ERROR:
            lvl = @"Error";
            break;
        case ORTP_WARNING:
            lvl = @"Warning";
            break;
        case ORTP_MESSAGE:
            lvl = @"Message";
            break;
        case ORTP_DEBUG:
            lvl = @"Debug";
            break;
        case ORTP_TRACE:
            lvl = @"Trace";
            break;
        case ORTP_LOGLEV_END:
            return;
        default:
            break;
    }
    if ([formatedString containsString:@"\n"]) {
        NSArray *myWords = [[formatedString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]
                            componentsSeparatedByString:@"\n"];
        for (int i = 0; i < myWords.count; i++) {
            NSString *tab = i > 0 ? @"\t" : @"";
            if (((NSString *)myWords[i]).length > 0) {
                NSLog(@"[%@] %@%@", lvl, tab, (NSString *)myWords[i]);
            }
        }
    } else {
        NSLog(@"[%@] %@", lvl, [formatedString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]);
    }
}

@end

@implementation LinphoneUtils

+ (NSString *)timeToString:(time_t)time withFormat:(LinphoneDateFormat)format
{
    NSString *formatstr;
    NSDate *todayDate = [[NSDate alloc] init];
    NSDate *messageDate = (time == 0) ? todayDate : [NSDate dateWithTimeIntervalSince1970:time];
    NSDateComponents *todayComponents =
    [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                    fromDate:todayDate];
    NSDateComponents *dateComponents =
    [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                    fromDate:messageDate];
    BOOL sameYear = (todayComponents.year == dateComponents.year);
    BOOL sameMonth = (sameYear && (todayComponents.month == dateComponents.month));
    BOOL sameDay = (sameMonth && (todayComponents.day == dateComponents.day));
    
    switch (format) {
        case LinphoneDateHistoryList:
            if (sameYear) {
                formatstr = NSLocalizedString(@"EEE dd MMMM",
                                              @"Date formatting in History List, for current year (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr = NSLocalizedString(@"EEE dd MMMM yyyy",
                                              @"Date formatting in History List, for previous years (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
        case LinphoneDateHistoryDetails:
            formatstr = NSLocalizedString(@"EEE dd MMM 'at' HH'h'mm", @"Date formatting in History Details (also see "
                                          @"http://cybersam.com/ios-dev/"
                                          @"quick-guide-to-ios-dateformatting)");
            break;
        case LinphoneDateChatList:
            if (sameDay) {
                formatstr = NSLocalizedString(
                                              @"HH:mm", @"Date formatting in Chat List and Conversation bubbles, for current day (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr =
                NSLocalizedString(@"MM/dd", @"Date formatting in Chat List, for all but current day (also see "
                                  @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
        case LinphoneDateChatBubble:
            if (sameDay) {
                formatstr = NSLocalizedString(
                                              @"HH:mm", @"Date formatting in Chat List and Conversation bubbles, for current day (also see "
                                              @"http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            } else {
                formatstr = NSLocalizedString(@"MM/dd - HH:mm",
                                              @"Date formatting in Conversation bubbles, for all but current day (also "
                                              @"see http://cybersam.com/ios-dev/quick-guide-to-ios-dateformatting)");
            }
            break;
    }
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:formatstr];
    return [dateFormatter stringFromDate:messageDate];
}

+ (BOOL)findAndResignFirstResponder:(UIView*)view {
    if (view.isFirstResponder) {
        [view resignFirstResponder];
        return YES;
    }
    for (UIView *subView in view.subviews) {
        if ([LinphoneUtils findAndResignFirstResponder:subView])
            return YES;
    }
    return NO;
}

+ (void)adjustFontSize:(UIView*)view mult:(float)mult{
    if([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel*)view;
        UIFont *font = [label font];
        [label setFont:[UIFont fontWithName:font.fontName size:font.pointSize * mult]];
    } else if([view isKindOfClass:[UITextField class]]) {
        UITextField *label = (UITextField*)view;
        UIFont *font = [label font];
        [label setFont:[UIFont fontWithName:font.fontName size:font.pointSize * mult]];
    } else if([view isKindOfClass:[UIButton class]]) {
        UIButton* button = (UIButton*)view;
        UIFont* font = button.titleLabel.font;
        [button.titleLabel setFont:[UIFont fontWithName:font.fontName size:font.pointSize*mult]];
    } else {
        for(UIView *subView in [view subviews]) {
            [LinphoneUtils adjustFontSize:subView mult:mult];
        }
    }
}

+ (void)buttonFixStates:(UIButton*)button {
    // Set selected+over title: IB lack !
    [button setTitle:[button titleForState:UIControlStateSelected]
                 forState:(UIControlStateHighlighted | UIControlStateSelected)];
    
    // Set selected+over titleColor: IB lack !
    [button setTitleColor:[button titleColorForState:UIControlStateHighlighted]
                      forState:(UIControlStateHighlighted | UIControlStateSelected)];
    
    // Set selected+disabled title: IB lack !
    [button setTitle:[button titleForState:UIControlStateSelected]
                 forState:(UIControlStateDisabled | UIControlStateSelected)];
    
    // Set selected+disabled titleColor: IB lack !
    [button setTitleColor:[button titleColorForState:UIControlStateDisabled]
                      forState:(UIControlStateDisabled | UIControlStateSelected)];
}

+ (void)buttonFixStatesForTabs:(UIButton*)button {
    // Set selected+over title: IB lack !
    [button setTitle:[button titleForState:UIControlStateSelected]
            forState:(UIControlStateHighlighted | UIControlStateSelected)];
    
    // Set selected+over titleColor: IB lack !
    [button setTitleColor:[button titleColorForState:UIControlStateSelected]
                 forState:(UIControlStateHighlighted | UIControlStateSelected)];
    
    // Set selected+disabled title: IB lack !
    [button setTitle:[button titleForState:UIControlStateSelected]
            forState:(UIControlStateDisabled | UIControlStateSelected)];
    
    // Set selected+disabled titleColor: IB lack !
    [button setTitleColor:[button titleColorForState:UIControlStateDisabled]
                 forState:(UIControlStateDisabled | UIControlStateSelected)];
}

+ (void)buttonMultiViewAddAttributes:(NSMutableDictionary*)attributes button:(UIButton*)button {
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateNormal] key:@"title-normal"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateHighlighted] key:@"title-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateDisabled] key:@"title-disabled"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateSelected] key:@"title-selected"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateDisabled | UIControlStateHighlighted] key:@"title-disabled-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateSelected | UIControlStateHighlighted] key:@"title-selected-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleForState:UIControlStateSelected | UIControlStateDisabled] key:@"title-selected-disabled"];
    
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateNormal] key:@"title-color-normal"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateHighlighted] key:@"title-color-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateDisabled] key:@"title-color-disabled"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateSelected] key:@"title-color-selected"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateDisabled | UIControlStateHighlighted] key:@"title-color-disabled-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateSelected | UIControlStateHighlighted] key:@"title-color-selected-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button titleColorForState:UIControlStateSelected | UIControlStateDisabled] key:@"title-color-selected-disabled"];
    
	[LinphoneUtils addDictEntry:attributes item:NSStringFromUIEdgeInsets([button titleEdgeInsets]) key:@"title-edge"];
	[LinphoneUtils addDictEntry:attributes item:NSStringFromUIEdgeInsets([button contentEdgeInsets]) key:@"content-edge"];
	[LinphoneUtils addDictEntry:attributes item:NSStringFromUIEdgeInsets([button imageEdgeInsets]) key:@"image-edge"];
	
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateNormal] key:@"image-normal"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateHighlighted] key:@"image-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateDisabled] key:@"image-disabled"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateSelected] key:@"image-selected"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateDisabled | UIControlStateHighlighted] key:@"image-disabled-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateSelected | UIControlStateHighlighted] key:@"image-selected-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button imageForState:UIControlStateSelected | UIControlStateDisabled] key:@"image-selected-disabled"];
    
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateNormal] key:@"background-normal"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateHighlighted] key:@"background-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateDisabled] key:@"background-disabled"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateSelected] key:@"background-selected"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateDisabled | UIControlStateHighlighted] key:@"background-disabled-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateSelected | UIControlStateHighlighted] key:@"background-selected-highlighted"];
    [LinphoneUtils addDictEntry:attributes item:[button backgroundImageForState:UIControlStateSelected | UIControlStateDisabled] key:@"background-selected-disabled"];
}

+ (void)buttonMultiViewApplyAttributes:(NSDictionary*)attributes button:(UIButton*)button {
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-normal"] forState:UIControlStateNormal];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-highlighted"] forState:UIControlStateHighlighted];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-disabled"] forState:UIControlStateDisabled];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-selected"] forState:UIControlStateSelected];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-disabled-highlighted"] forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-selected-highlighted"] forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setTitle:[LinphoneUtils getDictEntry:attributes key:@"title-selected-disabled"] forState:UIControlStateSelected | UIControlStateDisabled];
    
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-normal"] forState:UIControlStateNormal];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-highlighted"] forState:UIControlStateHighlighted];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-disabled"] forState:UIControlStateDisabled];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-selected"] forState:UIControlStateSelected];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-disabled-highlighted"] forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-selected-highlighted"] forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setTitleColor:[LinphoneUtils getDictEntry:attributes key:@"title-color-selected-disabled"] forState:UIControlStateSelected | UIControlStateDisabled];
    
	[button setTitleEdgeInsets:UIEdgeInsetsFromString([LinphoneUtils getDictEntry:attributes key:@"title-edge"])];
	[button setContentEdgeInsets:UIEdgeInsetsFromString([LinphoneUtils getDictEntry:attributes key:@"content-edge"])];
	[button setImageEdgeInsets:UIEdgeInsetsFromString([LinphoneUtils getDictEntry:attributes key:@"image-edge"])];

    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-normal"] forState:UIControlStateNormal];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-highlighted"] forState:UIControlStateHighlighted];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-disabled"] forState:UIControlStateDisabled];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-selected"] forState:UIControlStateSelected];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-disabled-highlighted"] forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-selected-highlighted"] forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setImage:[LinphoneUtils getDictEntry:attributes key:@"image-selected-disabled"] forState:UIControlStateSelected | UIControlStateDisabled];
    
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-normal"] forState:UIControlStateNormal];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-highlighted"] forState:UIControlStateHighlighted];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-disabled"] forState:UIControlStateDisabled];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-selected"] forState:UIControlStateSelected];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-disabled-highlighted"] forState:UIControlStateDisabled | UIControlStateHighlighted];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-selected-highlighted"] forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setBackgroundImage:[LinphoneUtils getDictEntry:attributes key:@"background-selected-disabled"] forState:UIControlStateSelected | UIControlStateDisabled];
}


+ (void)addDictEntry:(NSMutableDictionary*)dict item:(id)item key:(id)key {
    if(item != nil && key != nil) {
        [dict setObject:item forKey:key];
    }
}

+ (id)getDictEntry:(NSDictionary*)dict key:(id)key {
    if(key != nil) {
        return [dict objectForKey:key];
    }
    return nil;
}

@end

@implementation NSNumber (HumanReadableSize)

- (NSString*)toHumanReadableSize {
    float floatSize = [self floatValue];
	if (floatSize < 1023)
		return([NSString stringWithFormat:@"%1.0f bytes",floatSize]);
	floatSize = floatSize / 1024;
	if (floatSize < 1023)
		return([NSString stringWithFormat:@"%1.1f KB",floatSize]);
	floatSize = floatSize / 1024;
	if (floatSize < 1023)
		return([NSString stringWithFormat:@"%1.1f MB",floatSize]);
	floatSize = floatSize / 1024;
    
	return([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

@end

void Linphone_log(NSString* format, ...){
    LOGV(ORTP_MESSAGE, format);
}

void Linphone_dbg(NSString* format, ...){
    LOGV(ORTP_DEBUG, format);
}

void Linphone_warn(NSString* format, ...){
    LOGV(ORTP_WARNING, format);
}

void Linphone_err(NSString* format, ...){
    LOGV(ORTP_ERROR, format);
}

void Linphone_fatal(NSString* format, ...){
    LOGV(ORTP_FATAL, format);
}
