//
//  ocAudioFileModel.h
//  VoiceMixer
//
//  Created by jst on 2017/7/28.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ocAudioFileModel : NSObject


//file desc
@property(nonatomic,assign)AudioStreamBasicDescription desc;

//num frames of file
@property(nonatomic,assign)UInt32 numFrames;

//the frame you want to seek ,default zero
@property(nonatomic,assign)UInt32 seekFrameNum;

//channel
@property(nonatomic,assign)UInt32 channel;


//file reader
@property(nonatomic,assign)ExtAudioFileRef audioFileRef;


//file url
@property(nonatomic,copy)NSString* url;

@property(nonatomic,assign)BOOL isOver;

-(void)close;

//open reader(initlize reader)
-(void)fileOpen:(CFURLRef)url;
@end
