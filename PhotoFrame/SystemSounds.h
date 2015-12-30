//
//  SystemSounds.h
//  PhotoFrame
//
//  Created by Christopher Serra on 12/28/15.
//  Copyright © 2015 Christopher Serra. All rights reserved.
//

#import <AudioToolbox/AudioServices.h>

#define SystemSoundIDMailSent 1001
#define SystemSoundIDVibrate kSystemSoundID_Vibrate

@interface SystemSounds : NSObject {
  SystemSoundID soundID;
}

- (id)initWithSoundNamed:(NSString *)filename;
- (void)play;
+ (void)playFile:(NSString *)filename;
+ (void)playID:(SystemSoundID)soundID;

@end
