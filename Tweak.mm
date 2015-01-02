#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>

#define PreferencesName "com.autopear.notificationkiller"
#define PreferencesChangedNotification "com.autopear.notificationkiller.preferenceschanged"
#define PreferencesFilePath @"/var/mobile/Library/Preferences/com.autopear.notificationkiller.plist"

@interface SBModeControlManager
@property(readonly, assign, nonatomic) NSArray* views;
-(void)insertSegmentWithTitle:(id)title atIndex:(unsigned)index animated:(BOOL)animated;
-(id)_segmentedControlForUse:(int)use;
@end

@interface SBBulletinObserverViewController {
    NSMutableArray* _visibleSectionIDs;
}
-(id)sectionWithIdentifier:(NSString *)identifier;
-(void)clearSection:(id)section;
@end

@interface SBNotificationCenterViewController {
    SBBulletinObserverViewController* _allModeViewController;
}
@end

@interface SBNotificationCenterController
@property(readonly, retain, nonatomic) SBNotificationCenterViewController* viewController;
+(id)sharedInstance;
@end

@interface SBIcon
-(void)setBadge:(id)value;
-(id)badgeNumberOrString;
@end

@interface SBIconModel
-(SBIcon *)applicationIconForDisplayIdentifier:(NSString *)identifier; //iOS 7
-(SBIcon *)applicationIconForBundleIdentifier:(NSString *)bundleIdentifier; //iOS 8
@end

@interface SBIconViewMap
+(SBIconViewMap *)homescreenMap;
-(SBIconModel *)iconModel;
@end

@interface NotificationKillerAlert : NSObject <UIAlertViewDelegate>
-(void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

static BOOL tweakEnabled = YES;
static NSArray *whiteList = nil;
static BOOL removeBadge = YES;
static BOOL needConfirm = YES;
static SBBulletinObserverViewController *ncAllConrtoller = nil;
static SBIconModel *iconModel = nil;
static NotificationKillerAlert *alertDelegate = nil;
static NSString *alertTitle = nil, *alertMessage = nil, *alertOK = nil, *alertCancel = nil;

static BOOL readPreferenceBOOL(NSString *key, BOOL defaultValue) {
    return !CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR(PreferencesName)) ? defaultValue : [(id)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR(PreferencesName))) boolValue];
}

static void LoadPreferences() {
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:PreferencesFilePath];

    if (kCFCoreFoundationVersionNumber >= 1140.10) {
        CFPreferencesAppSynchronize(CFSTR(PreferencesName));
        tweakEnabled = readPreferenceBOOL(@"enabled", YES);
        removeBadge = readPreferenceBOOL(@"badge", YES);
        needConfirm = readPreferenceBOOL(@"confirm", YES);
    } else {
        tweakEnabled = [dict objectForKey:@"enabled"] ? [[dict objectForKey:@"enabled"] boolValue] : YES;
        removeBadge = [dict objectForKey:@"badge"] ? [[dict objectForKey:@"removeBadge"] boolValue] : YES;
        needConfirm = [dict objectForKey:@"confirm"] ? [[dict objectForKey:@"confirm"] boolValue] : YES;
    }

    NSMutableArray *list = [NSMutableArray array];
    for (NSString *key in [dict allKeys]) {
        if ([key hasPrefix:@"NK-"] && [[dict objectForKey:key] boolValue])
            [list addObject:[key substringFromIndex:3]];
    }
    if (whiteList)
        [whiteList release];

    whiteList = [list retain];

    [dict release];
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LoadPreferences();
}

static void clearAllSections() {
    if (!ncAllConrtoller)
        return;

    NSMutableArray *_visibleSectionIDs = CHIvar(ncAllConrtoller, _visibleSectionIDs, NSMutableArray *);
    NSArray *allSections = [NSArray arrayWithArray:_visibleSectionIDs];
    for (NSString *identifier in allSections) {
        if (whiteList && [whiteList containsObject:identifier])
            continue;

        id sectionInfo = [ncAllConrtoller sectionWithIdentifier:identifier];
        if (sectionInfo)
            [ncAllConrtoller clearSection:sectionInfo];

        if (removeBadge) {
            if (!iconModel)
                iconModel = (SBIconModel *)[(SBIconViewMap *)[%c(SBIconViewMap) homescreenMap] iconModel];
            if (iconModel) {
                SBIcon *appIcon = nil;
                if (kCFCoreFoundationVersionNumber < 1140.10)
                    appIcon = [iconModel applicationIconForDisplayIdentifier:identifier];
                else
                    appIcon = [iconModel applicationIconForBundleIdentifier:identifier];

                if (appIcon && [appIcon badgeNumberOrString])
                    [appIcon setBadge:nil];
            }
        }
    }
}

@implementation NotificationKillerAlert

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [alertView dismissAnimated:YES];
    [alertView release];
    if (buttonIndex == 1)
        clearAllSections();
}

@end

%hook SBModeControlManager

-(void)insertSegmentWithTitle:(id)title atIndex:(unsigned)index animated:(BOOL)animated {
    %orig(title, index, animated);
    UIView *control = [self _segmentedControlForUse:index];
    if (control) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [control addGestureRecognizer:longPress];
        [longPress release];
    }
}

%new
-(void)handleLongPress:(UIGestureRecognizer *)sender {
    if (tweakEnabled && sender.state == UIGestureRecognizerStateEnded) {
        if (!ncAllConrtoller) {
            SBNotificationCenterController *nc = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
            SBNotificationCenterViewController *ncvc = nc.viewController;
            ncAllConrtoller = (SBBulletinObserverViewController *)CHIvar(ncvc, _allModeViewController, SBBulletinObserverViewController *);
        }
        if (ncAllConrtoller) {
            NSMutableArray *_visibleSectionIDs = CHIvar(ncAllConrtoller, _visibleSectionIDs, NSMutableArray *);
            if (_visibleSectionIDs && [_visibleSectionIDs count] > 0) {
                if (needConfirm) {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle
                                                                        message:alertMessage
                                                                       delegate:alertDelegate
                                                              cancelButtonTitle:alertCancel
                                                              otherButtonTitles:alertOK, nil];
                    [alertView show];
                } else
                    clearAllSections();
            }
        }
    }
}

%end

%ctor {
    @autoreleasepool {
        NSBundle *localizedBundle = [[NSBundle alloc] initWithPath:@"/Library/PreferenceLoader/Preferences/NotificationKiller"];

        alertTitle = [NSLocalizedStringFromTableInBundle(@"Notification Killer", @"NotificationKiller", localizedBundle, @"Notification Killer") retain];
        alertMessage = [NSLocalizedStringFromTableInBundle(@"Would you like to clear all notifications?", @"NotificationKiller", localizedBundle, @"Would you like to clear all notifications?") retain];
        alertCancel = [NSLocalizedStringFromTableInBundle(@"Cancel", @"NotificationKiller", localizedBundle, @"Cancel") retain];
        alertOK = [NSLocalizedStringFromTableInBundle(@"OK", @"NotificationKiller", localizedBundle, @"OK") retain];

        [localizedBundle release];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

        LoadPreferences();

        alertDelegate = [[NotificationKillerAlert alloc] init];
    }
}
