#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>

#define PreferencesChangedNotification "com.autopear.notificationkiller.preferenceschanged"
#define PreferencesFilePath @"/var/mobile/Library/Preferences/com.autopear.notificationkiller.plist"

@interface NKPrefsListController: PSListController
- (void)donate;
- (void)followWeibo;
- (void)followTwitter;
@end

@implementation NKPrefsListController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"NotificationKiller" target:self] retain];

        for (PSSpecifier *spec in _specifiers) {
            if ([[spec propertyForKey:@"id"] isEqualToString:@"ABOUT"]) {
                NSDate *today = [NSDate date];
                NSDateFormatter *currentFormatter = [[NSDateFormatter alloc] init];
                [currentFormatter setDateFormat:@"yyyy"];
                NSString *year = [currentFormatter stringFromDate:today];
                [spec setProperty:[NSString stringWithFormat:@"Copyright © 2015-%@ Merlin Mao", year] forKey:@"footerText"];
                [currentFormatter release];
                break;
            }
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Activator.dylib"])
            [self removeSpecifierID:@"ACTIVATOR"];
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PreferencesFilePath];
    if ([dict objectForKey:[specifier propertyForKey:@"key"]])
        return [dict objectForKey:[specifier propertyForKey:@"key"]];
    else
        return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PreferencesFilePath]];
    [defaults setObject:value forKey:[specifier propertyForKey:@"key"]];
    [defaults writeToFile:PreferencesFilePath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(PreferencesChangedNotification), NULL, NULL, YES);
}

- (void)donate {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=mqz0708%40gmail%2ecom&lc=US&item_name=autopear%27s%20tweaks&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted"]];
}

- (void)followTwitter {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/Aut0pear"]];
}

- (void)followWeibo {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://weibo.com/autopear"]];
}

@end
