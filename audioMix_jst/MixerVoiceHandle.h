//
//  MixerVoiceHandle.h
//  VoiceMixer
//
//  Created by jst on 2017/6/30.
//  Copyright © 2017年 jst. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVAudioFormat.h>

#define handleError(error)  if(error){ NSLog(@"%@",error); exit(1);}

extern const double kGraphSampleRate;
extern const double kSessionBufDuration;

void CheckError(OSStatus error,const char *operaton);

@protocol mixMusicsFinishedCallBackDelegate <NSObject>

-(void)musicFinished:(int)idx;

@end

@interface MixerVoiceHandle : NSObject

@property (nonatomic,assign) BOOL isPlaying;

@property (nonatomic,weak)id<mixMusicsFinishedCallBackDelegate> delegate;

-(instancetype)initWithSourceArr:(NSArray *)sourceArr;
-(void)stopAUGraph;
-(void)startAUGraph;

/*
 voice Volume(isOn) control
 */
-(void)enableInput:(NSInteger)busIndex isOn:(BOOL)isOn;
-(void)setInputVolumeWithBus:(NSInteger)busIndex value:(CGFloat)value;
-(void)setOutputVolume:(AudioUnitParameterValue)value;

-(void)setRecording:(BOOL)isrecord;
//delete audio
-(void)removeMixRenderBusNum:(UInt32)busNum;
//add audio
-(void)addMixRender:(NSString*)url;

/*
 seek to frame vlaue :0~1
 */
-(void)seekInBusNum:(int)num Value:(float)vlaue;

//reset all audio seek to zero
-(void)resetAudioSeek;

//replace the audio with new audio path
-(void)resetAudioFile:(NSString*)urlstr inbus:(int)bus;

- (void)close;
@end
