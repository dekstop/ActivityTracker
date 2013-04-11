//
//  AppDelegate.m
//  ActivityTracker
//
//  Created by mongo on 10/04/2013.
//  Copyright (c) 2013 martind. All rights reserved.
//

#import "AppDelegate.h"

#import <Carbon/Carbon.h>

@implementation AppDelegate

@synthesize doRemind;
NSAttributedString *menuTitleActive = nil;
NSAttributedString *menuTitleInactive = nil;

NSMutableSet *allActivities = nil;
NSArray *previousActivity = nil;

NSString *logFilePath;
NSDateFormatter *dateFormatter;
NSFileHandle *logFile;

- (id)init {
    if (self = [super init]) {
        allActivities = [[NSMutableSet alloc] init];
        previousActivity = [[NSArray alloc] init];
        
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
        logFilePath = [NSString stringWithFormat:@"%@/Library/Logs/ActivityTracker.log", NSHomeDirectory()];
        logFile = OpenUserLog(logFilePath);
        
        menuTitleActive = [[NSMutableAttributedString alloc] initWithString:@"A" attributes:@{NSForegroundColorAttributeName:[NSColor blackColor], NSFontAttributeName:[NSFont systemFontOfSize:14.0]}];
        menuTitleInactive = [[NSMutableAttributedString alloc] initWithString:@"A" attributes:@{NSForegroundColorAttributeName:[NSColor darkGrayColor], NSFontAttributeName:[NSFont systemFontOfSize:14.0]}];
    }
    return self;
}

- (IBAction)selectDontRemind:(id)pId
{
    doRemind = NO;
    [self updateMenuDisplay];
    [self updateAppSettings];
}

- (IBAction)selectRemindPeriod1:(id)pId
{
    [self _setReminderInterval:30*60];
}

- (IBAction)selectRemindPeriod2:(id)pId
{
    [self _setReminderInterval:60*60];
}

- (IBAction)selectRemindPeriod3:(id)pId
{
    [self _setReminderInterval:90*60];
}

- (IBAction)selectRemindPeriod4:(id)pId
{
    [self _setReminderInterval:120*60];
}

- (void)_setReminderInterval:(int)seconds
{
    doRemind = YES;
    if (reminderIntervalInSeconds > seconds) {
        // Reschedule the next reminder if we're now on a shorter interval
        [self scheduleReminderNotificationAfter:seconds];
    }
    reminderIntervalInSeconds = seconds;
    [self updateMenuDisplay];
    [self updateAppSettings];
}

- (void)updateMenuDisplay
{
    [statusItem setAttributedTitle:(doRemind ? menuTitleActive : menuTitleInactive)];
    [dontRemindMenuItem setState:(doRemind ? NSOffState : NSOnState)];
    [remindPeriod1MenuItem setState:(doRemind && reminderIntervalInSeconds==(30*60) ? NSOnState : NSOffState)];
    [remindPeriod2MenuItem setState:(doRemind && reminderIntervalInSeconds==(60*60) ? NSOnState : NSOffState)];
    [remindPeriod3MenuItem setState:(doRemind && reminderIntervalInSeconds==(90*60) ? NSOnState : NSOffState)];
    [remindPeriod4MenuItem setState:(doRemind && reminderIntervalInSeconds==(120*60) ? NSOnState : NSOffState)];
}

- (IBAction)trackNow:(id)pId
{
    [self doTrackCurrentActivity];
}

- (IBAction)openLog:(id)pId
{
    [[NSWorkspace sharedWorkspace] openFile:logFilePath];
}

- (IBAction)toggleLaunchOnStartup:(id)pId
{
    if ([self isLoginItem]) {
        [self removeAsLoginItem];
        [launchOnStartupMenuItem setState:NSOffState];
    } else {
        [self addAsLoginItem];
        [launchOnStartupMenuItem setState:NSOnState];
    }
}

- (IBAction)about:(id)pId
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/dekstop/ActivityTracker"]];
}

- (IBAction)quit:(id)pId
{
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // App preferences
    [self registerDefaultAppSettings];
    doRemind = [[NSUserDefaults standardUserDefaults] boolForKey:@"doRemind"];
    reminderIntervalInSeconds = [[NSUserDefaults standardUserDefaults] integerForKey:@"reminderIntervalInSeconds"];
    NSLog(@"Reminder interval: %f", reminderIntervalInSeconds);
    [allActivities addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"allActivities"]];
    previousActivity = [[NSUserDefaults standardUserDefaults] arrayForKey:@"previousActivity"];
    [self updateAppSettings];

    [launchOnStartupMenuItem setState:([self isLoginItem] ? NSOnState : NSOffState)];
    
    // Status bar / tray icon
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    [self updateMenuDisplay];
    
    // Register global keyboard shortcut -- may require assistive device access.
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event){
        NSUInteger modifierKeyMask = NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSFunctionKeyMask;
        NSUInteger modifierFlags = [event modifierFlags] & modifierKeyMask;
        unsigned short keyCode = [event keyCode];
        if (modifierFlags == NSCommandKeyMask && keyCode == kVK_ISO_Section) {
            [self doTrackCurrentActivity];
        }
    }];
    
    // Notifications
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    [self scheduleReminderNotificationAfter:reminderIntervalInSeconds]; // Schedule the first reminder

    // Lose focus
    [self loseApplicationFocus]; // For some reason this gets ignored.
}

- (void)registerDefaultAppSettings
{
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"YES", @"doRemind",
                                 [NSNumber numberWithInt:(30*60)], @"reminderIntervalInSeconds",
                                 [[NSArray alloc] init], @"allActivities",
                                 [[NSArray alloc] init], @"previousActivity",
                                 nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

- (void)updateAppSettings
{
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings setBool:doRemind forKey:@"doRemind"];
    [settings setInteger:reminderIntervalInSeconds forKey:@"reminderIntervalInSeconds"];
    [settings setObject:[allActivities allObjects] forKey:@"allActivities"];
    [settings setObject:previousActivity forKey:@"previousActivity"];
}

- (void)syncAppSettings
{
    [self updateAppSettings];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self syncAppSettings];
    CloseLog();
}

// Give up application focus to make global event monitor work (for keyboard shortcuts)
- (void)loseApplicationFocus
{
//    [[NSApplication sharedApplication] deactivate];
    [[NSApplication sharedApplication] hide:nil];
    [[NSApplication sharedApplication] unhideWithoutActivation];
}

/**
 *
 * Editing controls.
 *
 **/

- (void)doTrackCurrentActivity
{
    NSArray *activity = [self askForCurrentActivityWithDefault:previousActivity];
    if (activity!=nil) {
        Log(@"%@", [activity componentsJoinedByString:@", "]);
        previousActivity = activity;
        [self syncAppSettings]; // Write history to disk
    }
    [self scheduleReminderNotificationAfter:reminderIntervalInSeconds]; // Schedule the next reminder
}

- (NSArray*)askForCurrentActivityWithDefault:(NSArray*)defaultValue
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"What are you currently doing?"
                                     defaultButton:@"Track"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@"Use short comma-separated tags to describe activities, your location, your mood, or anything else that relates to your current context. These tags are logged in a file so you can refer to them later."];
    
    NSTokenField *input = [[NSTokenField alloc] initWithFrame:NSMakeRect(0, 0, 400, 72)];
    [input setObjectValue:defaultValue];
    [input setDelegate:self];

    [NSApp activateIgnoringOtherApps:YES];
    [alert setAccessoryView:input];
    [input setTarget:alert];
    
    NSInteger button = [alert runModal];
    [self loseApplicationFocus];

    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        [allActivities addObjectsFromArray:[input objectValue]]; // Update autocomplete history
        return [input objectValue];
    } else {
        return nil;
    }
}

// NSTokenFieldDelegate: autocomplete
- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex
{
//    *selectedIndex = -1; // don't pre-select any option
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", substring];
    NSMutableSet *matchingActivities = [allActivities mutableCopy]; // Load autocomplete history
    [matchingActivities filterUsingPredicate:predicate];
    return [matchingActivities allObjects];
}

/**
 *
 * Tools: user notifications.
 *
 */

- (void)scheduleReminderNotificationAfter:(NSInteger)seconds
{
    [self removeAllScheduledNotifications]; // Only one scheduled notification at a time

    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:@"ActivityTracker"];
    [notification setInformativeText:[NSString stringWithFormat:@"What are you currently doing?"]];
    [notification setHasActionButton:TRUE];
    [notification setActionButtonTitle:@"Track"];

    NSDate *deliveryDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    NSLog(@"Next reminder: %@", deliveryDate);
    [notification setDeliveryDate:deliveryDate];

    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
}

// NSUserNotificationCenterDelegate
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    [self doTrackCurrentActivity];
}

- (void)removeAllScheduledNotifications
{
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *notification in [center scheduledNotifications]) {
        [center removeScheduledNotification:notification];
    }
}

// NSUserNotificationCenterDelegate
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

/**
 *
 * Tools: logging.
 *
 **/

NSFileHandle *OpenUserLog(NSString *logFilePath)
{
    NSFileHandle *logFile;
    NSFileManager * mFileManager = [NSFileManager defaultManager];
    if([mFileManager fileExistsAtPath:logFilePath] == NO) {
        [mFileManager createFileAtPath:logFilePath contents:nil attributes:nil];
    }
    logFile = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    [logFile seekToEndOfFile];
    return logFile;
}

void Log(NSString* format, ...)
{
    // Build string
    va_list argList;
    va_start(argList, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end(argList);
    
    // Console
    //    NSLog(@"%@", formattedMessage);
    
    // File logging
    NSString *logMessage = [NSString stringWithFormat:@"%@ %@\n",
                            [dateFormatter stringFromDate:[NSDate date]],
                            formattedMessage];
    [logFile writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [logFile synchronizeFile];
}

void CloseLog()
{
    [logFile closeFile];
}

/**
 *
 * Tools: add/remove login item.
 * Based on https://gist.github.com/boyvanamstel/1409312 (MIT license)
 *
 **/

- (BOOL)isLoginItem {
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);
    
    return isInList;
}

- (void)addAsLoginItem {
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    
    // Add the app to the LoginItems list.
    CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
    if (itemRef) CFRelease(itemRef);
}

- (void)removeAsLoginItem {
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    
    // Remove the app from the LoginItems list.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    LSSharedFileListItemRemove(loginItemsRef,itemRef);
    //    if (itemRef != nil) CFRelease(itemRef);
}

- (LSSharedFileListItemRef)itemRefInLoginItems {
    LSSharedFileListItemRef itemRef = nil;
    
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
	if (loginItems) {
		UInt32 seedValue;
		//Retrieve the list of Login Items and cast them to
		// a NSArray so that it will be easier to iterate.
		NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for(int i = 0; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)[loginItemsArray
                                                                                        objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(currentItemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(__bridge NSURL*)url path];
				if ([urlPath compare:appPath] == NSOrderedSame){
                    itemRef = currentItemRef;
				}
			}
		}
        CFRelease(loginItems);
	}
    return itemRef;
}

@end
