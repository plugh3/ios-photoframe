//
//  ViewController.m
//  PhotoFrame
//
//  Created by Christopher Serra on 12/26/15.
//  Copyright © 2015 Christopher Serra. All rights reserved.
//

#import "SystemSounds.h"
#import "ViewController.h"
#import <DropboxSDK/DropboxSDK.h>
#include <stdlib.h>
@import UIKit;

@interface ViewController () <DBRestClientDelegate>

@property(weak, nonatomic) IBOutlet UIImageView *mainImageView;
@property(weak, nonatomic) IBOutlet UIView *pauseView;

@property(strong, nonatomic) DBRestClient *restClient;
@property(strong, nonatomic) NSArray *photoPaths;
@property(strong, nonatomic) NSString *checksumLast;
@property(atomic) BOOL loadFilePending;
@property(strong) NSTimer *mainTimer;
@property(strong) NSThread *mainTimerThread;
@property(strong, nonatomic) NSDate *start;
@property(strong, nonatomic) NSString *photoBuffer;
@property(weak, nonatomic) IBOutlet UIProgressView *progressBar;

#define LOOP_TIME 45
#define DROPBOX_ROOT @"/"

#define HISTORY_SIZE 5
@property(strong, nonatomic) NSMutableArray *photoHistory;
@property(strong, nonatomic) NSMutableArray *pathHistory;
@property(nonatomic) NSInteger historyIndex;

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  //  NSLog(@"viewDidLoad()");

  // view.contentMode = UIViewContentModeScaleAspectFit;  // IB "Aspect Fit"

  // tap gesture
  UITapGestureRecognizer *tapRecognizer =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(handleTapFrom:)];
  [self.view addGestureRecognizer:tapRecognizer];

  // swipe gestures
  // need multiple recognizers to distinguish directions
  UISwipeGestureRecognizer *leftSwipeRecognizer =
      [[UISwipeGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(handleSwipeFrom:)];
  leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
  [self.view addGestureRecognizer:leftSwipeRecognizer];

  UISwipeGestureRecognizer *rightSwipeRecognizer =
      [[UISwipeGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(handleSwipeFrom:)];
  rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
  [self.view addGestureRecognizer:rightSwipeRecognizer];

  // disable sleep
  [UIApplication sharedApplication].idleTimerDisabled = YES;
  //  if ([self isPluggedIn]) {
  //  } else {
  //  }
  // TODO: timer if unplugged
  // TODO: catch unplug event
  // TODO: catch background/foreground events in AppDelegate.m

  // start time
  if (!self.start) {
    self.start = [NSDate date];
  }

  // splash screen
  NSString *imagePath =
      [[NSBundle mainBundle] pathForResource:@"invader-800" ofType:@"jpg"];
  UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
  [self setImage:image];
  self.pauseView.hidden = YES;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  //  NSLog(@"viewDidLayoutSubviews()");
  //  CGRect f = self.mainImageView.frame;
  //  NSLog(@"frame (%0.0f, %0.0f, %0.0f, %0.0f)", f.origin.x, f.origin.y,
  //        f.size.width, f.size.height);

  [self startMainLoop];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  //  NSLog(@"viewDidAppear()");
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  NSLog(@"didReceiveMemoryWarning()");
  // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark UI delegates

- (void)handleTapFrom:(UITapGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    NSLog(@"tap");
    //[SystemSounds playFile:@"airdrop_invite.caf"];
    //[SystemSounds playID:SystemSoundIDVibrate];

    if (self.mainTimer) {
      [self stopLoop];
    } else {
      [self startLoop:LOOP_TIME];
    }
  }
}

- (void)handleSwipeFrom:(UISwipeGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    if (sender.direction & UISwipeGestureRecognizerDirectionRight) {
      NSLog(@"rightSwipe");
    }
    if (sender.direction & UISwipeGestureRecognizerDirectionLeft) {
      NSLog(@"leftSwipe");
    }
    // swipeRecognizer.direction = bits set during config, NOT actual swipe
    // swipeRecognizer.touches = starting point of swipe
    //[SystemSounds playID:SystemSoundIDMailSent];

    self.progressBar.hidden = NO;
    [self.progressBar setProgress:0.0];
    [self nextImage];

    if (!self.mainTimer) {
      [self startLoop:LOOP_TIME];
    }
  }
}

// hide status bar
//- (BOOL)prefersStatusBarHidden {
//  return YES;
//}

#pragma mark -
#pragma mark helpers

static bool _first = YES;
- (void)startMainLoop {
  [self linkDropboxSession];
  [self initDropboxClient];
  if (_first) {
    _first = NO;
    NSLog(@">>> startMainLoop");
    [self startLoop:LOOP_TIME];
  }
}
- (void)startLoop:(NSTimeInterval)seconds {
  if (self.mainTimer == nil) {
    NSLog(@"startLoop()");
    [self nextImage]; // prime

    dispatch_async(dispatch_get_main_queue(), ^{
      self.mainTimer =
          [NSTimer scheduledTimerWithTimeInterval:seconds
                                           target:self
                                         selector:@selector(nextImageTimed:)
                                         userInfo:nil
                                          repeats:YES];
      self.mainTimer.tolerance = 5;
    });
    self.pauseView.hidden = YES;
  }
}
- (void)stopLoop {
  NSLog(@"stopLoop()");
  if (self.mainTimer) {
    NSTimer *timerRef = self.mainTimer;
    self.mainTimer = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      [timerRef invalidate];
    });
    self.pauseView.hidden = NO;
  }
}
- (void)nextImageTimed:(NSTimer *)timer {
  NSDate *now = [NSDate date];
  NSTimeInterval diff = [now timeIntervalSinceDate:self.start];
  NSLog(@"nextImageTimed() \t+%0.1fs", diff);

  [self nextImage];
}

// --nextImage() async method chain--
// nextImage()
// loadMetadata()
// ...
// loadedMetadata() [async]
// loadFile()
// ...
// loadedFile() [async]
// setImage()
- (void)nextImage {
  NSLog(@"nextImage()");

  if (self.loadFilePending) {
    //    NSLog(@">>> still waiting for previous loadFile()");
    return;
  }

  NSLog(@"loadMetadata()...");
  [self.restClient loadMetadata:DROPBOX_ROOT withHash:self.checksumLast];
}

// linkDropboxSession()
// do not call from viewDidLoad (bc popup causes navctl error)
- (void)linkDropboxSession {
  if (![[DBSession sharedSession] isLinked]) {
    [[DBSession sharedSession] linkUserId:@"csserra@gmail.com"
                           fromController:self];
    if ([[DBSession sharedSession] isLinked]) {
      NSLog(@"linkDropboxSession");
    } else {
      NSLog(@"linkDropboxSession failed");
    }
  }
}

- (void)initDropboxClient {
  if (self.restClient == nil) {
    self.restClient =
        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.restClient.delegate = self;
    NSLog(@"initDropboxRestClient");
  }
}

#pragma mark -
#pragma mark DBRestClient.loadMetadata() delegates

- (void)restClient:(DBRestClient *)client
    loadedMetadata:(DBMetadata *)metadata {
  self.checksumLast = metadata.hash;
  // directory listing
  NSArray *validExtensions =
      [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", nil];
  NSMutableArray *newPhotoPaths = [NSMutableArray new];
  for (DBMetadata *child in metadata.contents) {
    NSString *extension = [[child.path pathExtension] lowercaseString];
    // skips subdirectories
    if (!child.isDirectory &&
        [validExtensions indexOfObject:extension] != NSNotFound) {
      [newPhotoPaths addObject:child.path];
    }
  }
  self.photoPaths = [NSArray arrayWithArray:newPhotoPaths];
  NSLog(@"=>loadedMetadata() %lu files", (unsigned long)newPhotoPaths.count);

  [self loadRandomPhoto];
}
- (void)restClient:(DBRestClient *)client
    metadataUnchangedAtPath:(NSString *)path {
  NSLog(@"=>loadedMetadata() no changes");
  [self loadRandomPhoto];
}
- (void)restClient:(DBRestClient *)client
    loadMetadataFailedWithError:(NSError *)error {
  NSLog(@"restClient:loadMetadataFailedWithError: %@",
        [error localizedDescription]);
}

#pragma mark -
#pragma mark DBRestClient.loadFile() delegates

- (void)restClient:(DBRestClient *)client
        loadedFile:(NSString *)destPath
       contentType:(NSString *)contentType
          metadata:(DBMetadata *)metadata {
  NSArray *pathElems = [destPath componentsSeparatedByString:@"/"];
  NSString *filename = pathElems[pathElems.count - 1];
  NSLog(@"=>loadedFile() >%@<", filename);

  self.loadFilePending = NO;
  self.progressBar.hidden = YES;
  if (self.mainTimer == nil) {
    // if paused, buffer and do NOT update image
    self.photoBuffer = destPath;
  } else {
    [self setImage:[UIImage imageWithContentsOfFile:destPath]];
    [self addPhotoToHistory:destPath];
  }
}
- (void)restClient:(DBRestClient *)client
      loadProgress:(CGFloat)progress
           forFile:(NSString *)destPath {
  // NSLog(@"loadProgress(): %@ at %5.1f%%", destPath, (100.0 * progress));
  // NOTE: this gets called VERY frequently during download
  // TODO: connect to UIProgressView
  //  - (void)setProgress:(float)progress
  // animated:(BOOL)animated
  [self.progressBar setProgress:progress animated:YES];
}
- (void)restClient:(DBRestClient *)client
    loadFileFailedWithError:(NSError *)error {
  NSLog(@"loadFileFailedWithError(): %@", [error userInfo]);
  self.loadFilePending = NO;
}

// TODO: properties + synthesize + getters
//- (DBRestClient *)restClient {
//  NSLog(@"restClient()");
//  if (self.restClient == nil) {
//    self.restClient =
//        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
//    self.restClient.delegate = self;
//  }
//  return self.restClient;
//}
//

#pragma mark -
#pragma mark helper methods

- (void)setImage:(UIImage *)image {
  self.mainImageView.image = image;
}

- (void)addPhotoToHistory:(NSString *)localPath {
}

- (BOOL)isOldPath:(NSString *)x {
  for (NSString *oldPath in self.pathHistory) {
    if ([oldPath isEqualToString:x])
      return YES;
  }
  return NO;
}

- (void)loadRandomPhoto {
  if (self.photoBuffer) {
    [self setImage:[UIImage imageWithContentsOfFile:self.photoBuffer]];
    self.photoBuffer = nil;
  } else {
    NSArray *pathList = self.photoPaths;
    NSString *randomPath = nil;
    NSUInteger nFiles = pathList.count;
    do {
      int nRand = arc4random_uniform(nFiles);
      randomPath = pathList[nRand];
      NSLog(@"random file: #%i of %i", nRand, nFiles);
    } while ([self isOldPath:randomPath]);

    NSString *pathPrefix = DROPBOX_ROOT;
    NSString *filename = [randomPath substringFromIndex:(pathPrefix.length)];
    NSString *dstPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

    NSLog(@"loadFile()... >%@<", randomPath);
    self.loadFilePending = YES;
    [self.restClient loadFile:randomPath intoPath:dstPath];
  }
}

- (BOOL)isPluggedIn {
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  UIDeviceBatteryState batt = [[UIDevice currentDevice] batteryState];
  NSString *status = ((batt == UIDeviceBatteryStateCharging) ||
                      (batt == UIDeviceBatteryStateFull))
                         ? @"plugged in"
                         : @"unplugged";
  NSLog(@"device is %@", status);
  return (batt == UIDeviceBatteryStateCharging) ||
         (batt == UIDeviceBatteryStateFull);
}

@end

// fail: auto-auth via access token
// DropboxSDK (401) Access token not found.
//    [[DBSession sharedSession] unlinkAll];
//    if (![[DBSession sharedSession] isLinked]) {
//      NSString *accessToken =
//          @"UcHhdgJN27sAAAAAAAAIgpfoiT3A82-diaJSKC2z_Kz2zojiG1FwUo5r0JxnpTpG";
//      NSString *appSecret = @"tmsl2uqpyglbgms";
//      [[DBSession sharedSession] updateAccessToken:accessToken
//                                 accessTokenSecret:appSecret
//                                         forUserId:@"csserra@gmail.com"];
//      NSLog(@"DBlink created with access token");
//    }
