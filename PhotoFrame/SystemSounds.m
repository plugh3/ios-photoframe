//
//  SystemSounds.m
//  PhotoFrame
//
//  Created by Christopher Serra on 12/28/15.
//  Copyright © 2015 Christopher Serra. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SystemSounds.h"

@implementation SystemSounds

+ (void)playID:(SystemSoundID)soundID {
  //  NSLog(@"sound.playID %i", soundID);
  AudioServicesPlaySystemSound(soundID);
}

+ (void)playFile:(NSString *)filename {
  //  NSLog(@"sound.playFile \"%@\"", filename);
  SystemSounds *sound = [[SystemSounds alloc] initWithSoundNamed:filename];
  [sound play];
}

- (id)initWithSoundNamed:(NSString *)filename {
  if ((self = [super init])) {
    NSURL *fileURL =
        [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
    //    NSLog(@"url=%@", fileURL);
    if (fileURL != nil) {
      SystemSoundID theSoundID;
      OSStatus error = AudioServicesCreateSystemSoundID(
          (__bridge CFURLRef)fileURL, &theSoundID);
      if (error == kAudioServicesNoError) {
        soundID = theSoundID;
        //        NSLog(@"\nsound %u found", (unsigned int)soundID);
      } else {
        NSLog(@"\nsound \"%@\" sound not found", filename);
      }
    } else {
      NSLog(@"\nsound \"%@\" url not found", filename);
    }
  }
  return self;
}

- (void)play {
  //  NSLog(@"sound.play %i", soundID);
  AudioServicesPlaySystemSound(soundID);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   AudioServicesDisposeSystemSoundID(soundID);
                 });
}

@end