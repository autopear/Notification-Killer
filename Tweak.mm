#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import <libactivator/libactivator.h>

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

@interface SBNotificationsViewController : SBBulletinObserverViewController
@end

@interface SBNotificationCenterLayoutViewController : UIViewController {
    SBNotificationsViewController *_notificationsViewController;
    //SBModeViewController *_modeViewController;
}
@end

@interface SBNotificationCenterViewController {
    SBBulletinObserverViewController* _allModeViewController; //iOS 7 & 8
    SBNotificationCenterLayoutViewController *_layoutViewController; //iOS 9
}
-(void)hostWillDismiss;
@end

@interface SBNotificationCenterController
@property(readonly, retain, nonatomic) SBNotificationCenterViewController* viewController;
+(id)sharedInstance;
-(void)clearAllNotifications; //New
-(void)clearAllNotificationsInternal; //New
@end

@interface SBIcon
-(void)setBadge:(id)value;
-(id)badgeNumberOrString;
@end

@interface SBIconModel
-(SBIcon *)applicationIconForDisplayIdentifier:(NSString *)identifier; //iOS 7
-(SBIcon *)applicationIconForBundleIdentifier:(NSString *)bundleIdentifier; //iOS 8 & 9
@end

@interface SBIconViewMap
+(SBIconViewMap *)homescreenMap; //Deprecated in 9.3
-(SBIconModel *)iconModel;
@end

@interface SBIconController : UIViewController
+(id)sharedInstance;
-(SBIconViewMap *)homescreenIconViewMap; //New in 9.3
@end

@interface NotificationKillerAlert : NSObject <UIAlertViewDelegate>
-(void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

static BOOL tweakEnabled = YES;
static NSArray *whiteList = nil;
static BOOL removeBadge = YES;
static BOOL needConfirm = YES;
static SBIconModel *iconModel = nil;
static SBNotificationCenterController *notiCenter =  nil;
static NotificationKillerAlert *alertDelegate = nil;
static NSString *tweakName = nil, *tweakDesc = nil, *alertMessage = nil, *alertOK = nil, *alertCancel = nil;
static UIAlertView *alertView = nil;

static void LoadPreferences() {
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:PreferencesFilePath];

    tweakEnabled = [dict objectForKey:@"enabled"] ? [[dict objectForKey:@"enabled"] boolValue] : YES;
    removeBadge = [dict objectForKey:@"badge"] ? [[dict objectForKey:@"badge"] boolValue] : YES;
    needConfirm = [dict objectForKey:@"confirm"] ? [[dict objectForKey:@"confirm"] boolValue] : YES;

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

@implementation NotificationKillerAlert

-(void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alert == alertView) {
        [alertView dismissWithClickedButtonIndex:[alertView cancelButtonIndex] animated:YES];
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            if (!notiCenter)
                notiCenter = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
            if (notiCenter)
                [notiCenter clearAllNotifications];
        }
        [alertView release];
        alertView = nil;
    }
}

@end

%hook SBNotificationCenterController

%new
-(void)clearAllNotifications {
    SBBulletinObserverViewController *allCtrl = nil;
    if (kCFCoreFoundationVersionNumber < 1240.10) //iOS 7 & 8
        allCtrl = (SBBulletinObserverViewController *)CHIvar(self.viewController, _allModeViewController, SBBulletinObserverViewController *);
    else { //iOS 9
        SBNotificationCenterLayoutViewController *sbnclvc = (SBNotificationCenterLayoutViewController *)CHIvar(self.viewController, _layoutViewController, SBNotificationCenterLayoutViewController *);
        allCtrl = (SBBulletinObserverViewController *)CHIvar(sbnclvc, _notificationsViewController, SBBulletinObserverViewController *);
    }

    NSMutableArray *_visibleSectionIDs = CHIvar(allCtrl, _visibleSectionIDs, NSMutableArray *);
    NSArray *allSections = [NSArray arrayWithArray:_visibleSectionIDs];
    for (NSString *identifier in allSections) {
        if (whiteList && [whiteList containsObject:identifier])
            continue;

        id sectionInfo = [allCtrl sectionWithIdentifier:identifier];
        if (sectionInfo)
            [allCtrl clearSection:sectionInfo];

        if (removeBadge) {
            if (!iconModel) {
                if ([%c(SBIconViewMap) respondsToSelector:@selector(homescreenMap)])
                    iconModel = (SBIconModel *)[(SBIconViewMap *)[%c(SBIconViewMap) homescreenMap] iconModel];
                else {
                    SBIconController *iconCtrl = [%c(SBIconController) sharedInstance];
                    if ([iconCtrl respondsToSelector:@selector(homescreenIconViewMap)])
                        iconModel = (SBIconModel *)[(SBIconViewMap *)[iconCtrl homescreenIconViewMap] iconModel];
                }
            }
            if (iconModel) {
                SBIcon *appIcon = nil;
                if (kCFCoreFoundationVersionNumber < 1140.10) //iOS 7
                    appIcon = [iconModel applicationIconForDisplayIdentifier:identifier];
                else //iOS 8 & 9
                    appIcon = [iconModel applicationIconForBundleIdentifier:identifier];

                if (appIcon && [appIcon badgeNumberOrString])
                    [appIcon setBadge:nil];
            }
        }
    }
}

%new
-(void)clearAllNotificationsInternal {
    SBBulletinObserverViewController *allCtrl = nil;
    if (kCFCoreFoundationVersionNumber < 1240.10) //iOS 7 & 8
        allCtrl = (SBBulletinObserverViewController *)CHIvar(self.viewController, _allModeViewController, SBBulletinObserverViewController *);
    else { //iOS 9
        SBNotificationCenterLayoutViewController *sbnclvc = (SBNotificationCenterLayoutViewController *)CHIvar(self.viewController, _layoutViewController, SBNotificationCenterLayoutViewController *);
        allCtrl = (SBBulletinObserverViewController *)CHIvar(sbnclvc, _notificationsViewController, SBBulletinObserverViewController *);
    }

    NSMutableArray *_visibleSectionIDs = CHIvar(allCtrl, _visibleSectionIDs, NSMutableArray *);
    if (_visibleSectionIDs && [_visibleSectionIDs count] > 0) {
        if (needConfirm) {
            if (alertView) {
                [alertView dismissWithClickedButtonIndex:[alertView cancelButtonIndex] animated:YES];
                [alertView release];
            }
            alertView = [[UIAlertView alloc] initWithTitle:tweakName
                                                   message:alertMessage
                                                  delegate:alertDelegate
                                         cancelButtonTitle:alertCancel
                                         otherButtonTitles:alertOK, nil];
            [alertView show];
        } else
            [self clearAllNotifications];
    }
}

%end

%hook SBModeControlManager

-(void)insertSegmentWithTitle:(id)title atIndex:(unsigned)index animated:(BOOL)animated {
    %orig(title, index, animated);
    UIView *control = [self _segmentedControlForUse:index];
    if (control) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleNKLongPress:)];
        [control addGestureRecognizer:longPress];
        [longPress release];
    }
}

%new
-(void)handleNKLongPress:(UIGestureRecognizer *)sender {
    if (tweakEnabled && sender.state == UIGestureRecognizerStateBegan) {
        if (!notiCenter)
            notiCenter = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
            if (notiCenter)
                [notiCenter clearAllNotificationsInternal];
    }
}

%end

%hook SBNotificationCenterViewController

-(void)hostWillDismiss {
    if (alertView) {
        [alertView dismissWithClickedButtonIndex:[alertView cancelButtonIndex] animated:YES];
        [alertView release];
        alertView = nil;
    }

    %orig;
}

%end

@interface NotificationKillerListener : NSObject <LAListener> {
    UIImage *_icon;
}
@end

@implementation NotificationKillerListener

- (id)init {
    if ((self = [super init])) {
    }
    return self;
}

-(void)dealloc {
    [_icon release];
    [super dealloc];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    if (!notiCenter)
        notiCenter = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
    if (notiCenter)
        [notiCenter clearAllNotificationsInternal];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    return tweakName;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    return tweakDesc;
}

- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale {
    if (!_icon) {
        if (scale == 3.0f)
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller@3x.png"];
        else if (scale == 2.0f)
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller@2x.png"];
        else
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller.png"];
    }
    return _icon;
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale {
    if (!_icon) {
        if (scale == 3.0f)
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller@3x.png"];
        else if (scale == 2.0f)
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller@2x.png"];
        else
            _icon = [[UIImage alloc] initWithContentsOfFile:@"/Library/PreferenceBundles/NKPrefs.bundle/NotificationKiller.png"];
    }
    return _icon;
}

@end

%ctor {
    @autoreleasepool {
        NSBundle *localizedBundle = [[NSBundle alloc] initWithPath:@"/Library/PreferenceBundles/NKPrefs.bundle"];

        tweakName = [NSLocalizedStringFromTableInBundle(@"Notification Killer", @"NotificationKiller", localizedBundle, @"Notification Killer") retain];
        tweakDesc = [NSLocalizedStringFromTableInBundle(@"Clear all notifications!", @"NotificationKiller", localizedBundle, @"Clear all notifications!") retain];
        alertMessage = [NSLocalizedStringFromTableInBundle(@"Would you like to clear all notifications?", @"NotificationKiller", localizedBundle, @"Would you like to clear all notifications?") retain];
        alertCancel = [NSLocalizedStringFromTableInBundle(@"Cancel", @"NotificationKiller", localizedBundle, @"Cancel") retain];
        alertOK = [NSLocalizedStringFromTableInBundle(@"OK", @"NotificationKiller", localizedBundle, @"OK") retain];

        [localizedBundle release];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

        LoadPreferences();

        alertDelegate = [[NotificationKillerAlert alloc] init];

        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Activator.dylib"]) {
            NotificationKillerListener *listener = [[NotificationKillerListener alloc] init];
            [[LAActivator sharedInstance] registerListener:listener forName:@"com.autopear.notificationkiller"];
        }
    }
}
