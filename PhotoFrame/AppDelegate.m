//
//  AppDelegate.m
//  PhotoFrame
//
//  Created by Christopher Serra on 12/26/15.
//  Copyright © 2015 Christopher Serra. All rights reserved.
//

#import "AppDelegate.h"
#import "SystemSounds.h"
#import <DropboxSDK/DropboxSDK.h>

@interface AppDelegate () <DBSessionDelegate, DBNetworkRequestDelegate>

@property(strong, nonatomic) NSString *relinkUserID;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  NSLog(@"application:didFinishLaunchingWithOptions");

  [self initDropboxSession];
  //[SystemSounds playFile:@"Sherwood_Forest.caf"];

  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state.
  // This can occur for certain types of temporary interruptions (such as an
  // incoming phone call or SMS message) or when the user quits the application
  // and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down
  // OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, invalidate
  // timers, and store enough application state information to restore your
  // application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called
  // instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the inactive state;
  // here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused (or not yet started) while the
  // application was inactive. If the application was previously in the
  // background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if
  // appropriate. See also applicationDidEnterBackground:.
}

#pragma mark Dropbox methods

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
  sourceApplication:(NSString *)source
         annotation:(id)annotation {
  NSLog(@"application:openURL:sourceApplication:annotation()");
  if ([[DBSession sharedSession] handleOpenURL:url]) {
    if ([[DBSession sharedSession] isLinked]) {
      NSLog(@"AOSA: app link successful");
      // At this point you can start making API calls
    } else {
      NSLog(@"AOSA: app link failed");
    }
    return YES;
  } else {
    NSLog(@"handleOpenURL() failed");
  }
  // Add whatever other url handling code your app requires here
  return NO;
}

- (void)initDropboxSession {
  NSLog(@"initDropboxSession()");

  NSString *appKey = @"t01r5m6twn30aoe";
  NSString *appSecret = @"tmsl2uqpyglbgms";
  NSString *root = kDBRootAppFolder; // Should be set to either kDBRootAppFolder

  //  NSString *errorMsg = nil;
  //  if ([appKey rangeOfCharacterFromSet:[[NSCharacterSet
  //  alphanumericCharacterSet]
  //                                          invertedSet]]
  //          .location != NSNotFound) {
  //    errorMsg =
  //        @"Make sure you set the app key correctly in
  //        DBRouletteAppDelegate.m";
  //  } else if ([appSecret rangeOfCharacterFromSet:[[NSCharacterSet
  //                                                    alphanumericCharacterSet]
  //                                                    invertedSet]]
  //                 .location != NSNotFound) {
  //    errorMsg = @"Make sure you set the app secret correctly in "
  //               @"DBRouletteAppDelegate.m";
  //  } else if ([root length] == 0) {
  //    errorMsg = @"Set your root to use either App Folder of full Dropbox";
  //  } else {
  //    NSString *plistPath =
  //        [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
  //    NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
  //    NSDictionary *loadedPlist =
  //        [NSPropertyListSerialization propertyListFromData:plistData
  //                                         mutabilityOption:0
  //                                                   format:NULL
  //                                         errorDescription:NULL];
  //    NSString *scheme = [[[[loadedPlist objectForKey:@"CFBundleURLTypes"]
  //        objectAtIndex:0] objectForKey:@"CFBundleURLSchemes"]
  //        objectAtIndex:0];
  //    if ([scheme isEqual:@"db-APP_KEY"]) {
  //      errorMsg = @"Set your URL scheme correctly in DBRoulette-Info.plist";
  //    }
  //  }

  DBSession *session =
      [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:root];
  session.delegate = self; // for reauth
  [DBSession setSharedSession:session];
  [DBRequest setNetworkRequestDelegate:self];

  //  if (errorMsg != nil) {
  //    [[[UIAlertView alloc] initWithTitle:@"Error Configuring Session"
  //                                message:errorMsg
  //                               delegate:nil
  //                      cancelButtonTitle:@"OK"
  //                      otherButtonTitles:nil] show];
  //  }
}

#pragma mark -
#pragma mark DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session
                                       userId:(NSString *)userId {
  NSLog(@"sessionDidReceiveAuthorizationFailure:userId()");
  self.relinkUserID = userId;
  [[[UIAlertView alloc] initWithTitle:@"Dropbox Session Ended"
                              message:@"Do you want to relink?"
                             delegate:self
                    cancelButtonTitle:@"Cancel"
                    otherButtonTitles:@"Relink", nil] show];
}

#pragma mark -
#pragma mark UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)index {
  NSLog(@">>> alertView:clickedButtonAtIndex()");
  UIViewController *rootViewController = self.window.rootViewController;
  // UIViewController *rootViewController = [[[UIApplication sharedApplication]
  // keyWindow] rootViewController];

  if (index != alertView.cancelButtonIndex) {
    [[DBSession sharedSession] linkUserId:self.relinkUserID
                           fromController:rootViewController];
  }
  self.relinkUserID = nil;
}

#pragma mark -
#pragma mark DBNetworkRequestDelegate methods

static int outstandingRequests;

- (void)networkRequestStarted {
  //  NSLog(@"networkRequestStarted()");
  outstandingRequests++;
  if (outstandingRequests == 1) {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  }
}

- (void)networkRequestStopped {
  //  NSLog(@"networkRequestStopped()");
  outstandingRequests--;
  if (outstandingRequests == 0) {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  }
}

@end
