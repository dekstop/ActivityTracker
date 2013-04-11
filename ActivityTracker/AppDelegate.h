//
//  AppDelegate.h
//  ActivityTracker
//
//  Created by mongo on 10/04/2013.
//  Copyright (c) 2013 martind. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate, NSTokenFieldDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    
    BOOL doRemind;
    NSTimeInterval reminderIntervalInSeconds;
    IBOutlet NSMenuItem *dontRemindMenuItem;
    IBOutlet NSMenuItem *remindPeriod1MenuItem;
    IBOutlet NSMenuItem *remindPeriod2MenuItem;
    IBOutlet NSMenuItem *remindPeriod3MenuItem;
    IBOutlet NSMenuItem *remindPeriod4MenuItem;
    IBOutlet NSMenuItem *launchOnStartupMenuItem;
}

@property BOOL doRemind;
- (IBAction)selectDontRemind:(id)pId;
- (IBAction)selectRemindPeriod1:(id)pId;
- (IBAction)selectRemindPeriod2:(id)pId;
- (IBAction)selectRemindPeriod3:(id)pId;
- (IBAction)selectRemindPeriod4:(id)pId;
- (IBAction)toggleLaunchOnStartup:(id)pId;
- (IBAction)trackNow:(id)pId;
- (IBAction)openLog:(id)pId;
- (IBAction)about:(id)pId;
- (IBAction)quit:(id)pId;

@end
