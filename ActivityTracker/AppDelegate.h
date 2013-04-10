//
//  AppDelegate.h
//  ActivityTracker
//
//  Created by mongo on 10/04/2013.
//  Copyright (c) 2013 martind. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    
    BOOL isActive;
    NSTimeInterval reminderIntervalInSeconds;
    IBOutlet NSMenuItem *isActiveMenuItem;
    IBOutlet NSMenuItem *launchOnStartupMenuItem;
}

@property BOOL isActive;
- (IBAction)toggleIsActive:(id)pId;
- (IBAction)toggleLaunchOnStartup:(id)pId;
- (IBAction)trackNow:(id)pId;
- (IBAction)openLog:(id)pId;
- (IBAction)about:(id)pId;
- (IBAction)quit:(id)pId;

@end
