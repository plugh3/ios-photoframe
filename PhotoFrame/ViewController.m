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

@property(strong, nonatomic) DBRestClient *restClient;
@property(strong, nonatomic) NSArray *photoPaths;
@property(strong, nonatomic) NSString *lastHash;
@property(nonatomic) BOOL working;

#define HISTORY_SIZE 5
@property(strong, nonatomic) NSMutableArray *photoHistory;
@property(strong, nonatomic) NSMutableArray *pathHistory;
@property(nonatomic) NSInteger historyIndex;

@end

@implementation ViewController

- (instancetype)init {
  self = [super init];
  NSLog(@"ViewController.init()");

  if (self) {
    self.photoHistory = [NSMutableArray arrayWithCapacity:HISTORY_SIZE];
    self.pathHistory = [NSMutableArray arrayWithCapacity:HISTORY_SIZE];
    self.historyIndex = -1;
  }

  return self;
}

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

  // swipe gesture
  UISwipeGestureRecognizer *leftSwipeRecognizer =
      [[UISwipeGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(handleLeftSwipeFrom:)];
  leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
  [self.view addGestureRecognizer:leftSwipeRecognizer];

  // disable sleep
  if ([self isPluggedIn]) {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
  } else {
    // TODO: timer if unplugged
  }
  // TODO: catch unplug event
  // TODO: catch background/foreground events in AppDelegate.m

  //  [self nextImage];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  //  NSLog(@"viewDidLayoutSubviews()");

  CGRect f = self.mainImageView.frame;
  NSLog(@"frame (%0.0f, %0.0f, %0.0f, %0.0f)", f.origin.x, f.origin.y,
        f.size.width, f.size.height);

  // dropbox init (credentials)
  // do not call from viewDidLoad (popup causes navctl error)
  if (![[DBSession sharedSession] isLinked]) {
    [[DBSession sharedSession] linkUserId:@"csserra@gmail.com"
                           fromController:self];
  }
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
#pragma mark UI delegates & targets

- (void)handleTapFrom:(UITapGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    NSLog(@"tap");
    [SystemSounds playFile:@"airdrop_invite.caf"];
    //[SystemSounds playID:SystemSoundIDVibrate];

    if (![[DBSession sharedSession] isLinked]) {
      [[DBSession sharedSession] linkUserId:@"csserra@gmail.com"
                             fromController:self];
      NSLog(@"DBlink created from user input");
    }

    if ([[DBSession sharedSession] isLinked]) {
      NSLog(@"linkDropboxSession");
    } else {
      NSLog(@"DBsession link failed");
    }

    self.restClient =
        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.restClient.delegate = self;
    NSLog(@"initDropboxRestClient");
  }
}

- (void)handleLeftSwipeFrom:(UISwipeGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    // swipeRecognizer.direction = bits set during config, NOT actual swipe
    // swipeRecognizer.touches = starting point of swipe
    NSLog(@"leftSwipe");
    [SystemSounds playID:SystemSoundIDMailSent];
  }
  [self nextImage];
}

// hide status bar
- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)nextImage {
  NSLog(@"nextImage()");
  UIImage *image = nil;

  NSString *photosRoot = @"/"; // folder-only-access
  [self.restClient loadMetadata:photosRoot withHash:self.lastHash];
}

#pragma mark -
#pragma mark DBRestClient.loadMetadata() delegates

- (void)restClient:(DBRestClient *)client
    loadedMetadata:(DBMetadata *)metadata {
  self.lastHash = metadata.hash;
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
  NSLog(@"metadata=%@", newPhotoPaths);

  [self loadRandomPhotoFromList:self.photoPaths];
}
- (BOOL)isOldPath:(NSString *)x {
  for (NSString *oldPath in self.pathHistory) {
    if ([oldPath isEqualToString:x])
      return YES;
  }
  return NO;
}
- (void)loadRandomPhotoFromList:(NSArray *)pathList {
  NSString *randomPath = nil;
  NSUInteger nFiles = pathList.count;
  do {
    int nRand = arc4random_uniform(nFiles);
    randomPath = pathList[nRand];
    NSLog(@"random file: #%i of %i", nRand, nFiles);
  } while ([self isOldPath:randomPath]);

  NSString *pathPrefix = @"/";
  NSString *filename = [randomPath substringFromIndex:(pathPrefix.length)];
  NSString *dstPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

  NSLog(@"fetching file \"%@\"", randomPath);
  [self.restClient loadFile:randomPath intoPath:dstPath];
}
- (void)restClient:(DBRestClient *)client
    metadataUnchangedAtPath:(NSString *)path {
  NSLog(@"restClient:metadataUnchangedAtPath()");
  [self loadRandomPhotoFromList:self.photoPaths];
}
- (void)restClient:(DBRestClient *)client
    loadMetadataFailedWithError:(NSError *)error {
  NSLog(@"restClient:loadMetadataFailedWithError: %@",
        [error localizedDescription]);
  [self setWorking:NO];
}

#pragma mark -
#pragma mark DBRestClient.loadFile() delegates

- (void)addPhotoToHistory:(NSString *)localPath {
}
- (void)restClient:(DBRestClient *)client
        loadedFile:(NSString *)destPath
       contentType:(NSString *)contentType
          metadata:(DBMetadata *)metadata {
  NSLog(@"loadedFile(): %@ isa %@", destPath, contentType);
  NSString *image = [UIImage imageWithContentsOfFile:destPath];
  // image = [[NSBundle mainBundle] pathForResource:@"galaga9" ofType:@"png"];
  [self setImage:image];

  // TODO: record new file
  [self addPhotoToHistory:destPath];
}
- (void)restClient:(DBRestClient *)client
      loadProgress:(CGFloat)progress
           forFile:(NSString *)destPath {
  // NSLog(@"loadProgress(): %@ at %5.1f%%", destPath, (100.0 * progress));
  // NOTE: this gets called very frequently during download
}
- (void)restClient:(DBRestClient *)client
    loadFileFailedWithError:(NSError *)error {
  NSLog(@"loadFileFailedWithError(): %@", [error userInfo]);
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
