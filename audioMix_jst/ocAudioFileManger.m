//
//  ocAudioFileManger.m
//  VoiceMixer
//
//  Created by jst on 2017/6/27.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import "ocAudioFileManger.h"

@interface ocAudioFileManger()
{
    ExtAudioFileRef _audioFp;
    @private
    int _channel;
    int _samplerates;

    int _type;
    AudioStreamBasicDescription _outputDesc;
}
@end
@implementation ocAudioFileManger

-(id)initWith:(int)channel samplerates:(int)rates isFloat:(int)type
{
    if (self = [super init]) {
        _channel = channel;
        _samplerates = rates;
        _type = type;
    }
    
    return self;
}

-(void)createFileWithUrlStr:(NSString *)str outDesc:(AudioStreamBasicDescription)desc
{
    
    int outputType = 0;
    AudioStreamBasicDescription audioDescription;
    memset(&audioDescription, 0, sizeof(audioDescription));
    audioDescription.mFormatID         = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = _channel;
    //if you input pcm is folat please change the size
    audioDescription.mBytesPerPacket   = sizeof(SInt16)*2;
    audioDescription.mFramesPerPacket  = 1;
    audioDescription.mBytesPerFrame    = sizeof(SInt16)*2;
    audioDescription.mBitsPerChannel   = 8 * sizeof(SInt16);
    audioDescription.mSampleRate       = _samplerates;
    if (desc.mBitsPerChannel != 0) {
        _outputDesc = desc;
        outputType = desc.mFormatID;
    }
    else
    {
        memset(&_outputDesc, 0, sizeof(_outputDesc));
        if ([[str pathExtension] isEqualToString:@"wav"]||[[str pathExtension] isEqualToString:@"mp3"]) {
            _outputDesc = audioDescription;
            outputType = kAudioFormatLinearPCM;
        }
        else if ([[str pathExtension] isEqualToString:@"aac"]||[[str pathExtension] isEqualToString:@"m4a"])
        {
            int type =[[str pathExtension] isEqualToString:@"aac"]?kAudioFileAAC_ADTSType:kAudioFileM4AType;
            _outputDesc.mFormatID = type;
            _outputDesc.mChannelsPerFrame = _channel;
            _outputDesc.mSampleRate = _samplerates;
            outputType = type;
        }
    }
    UInt32 propSize = sizeof(audioDescription);
    NSURL *url = [NSURL fileURLWithPath:str];
    OSStatus status;
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)url, outputType, &_outputDesc, NULL, kAudioFileFlags_EraseFile, &_audioFp);
    if (status != noErr) {
        printf("error: create file failed\n");
        ExtAudioFileDispose(_audioFp);
    }
    status = ExtAudioFileSetProperty(_audioFp, kExtAudioFileProperty_ClientDataFormat, propSize, &audioDescription);
    if (status != noErr) {
        printf("error:no match output fromat\n");
    }
}

-(void)writeFileWithBufferList:(AudioBufferList *)iodata inMunberFrames:(int)frames
{
    OSStatus status = noErr;
    status = ExtAudioFileWriteAsync(_audioFp, frames, iodata);
    if (status != noErr) NSLog(@"E:AEAudioFileWriterAddAudio %d", status);
}
@end
