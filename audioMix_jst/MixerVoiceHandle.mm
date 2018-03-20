//
//  MixerVoiceHandle.m
//  VoiceMixer
//
//  Created by jst on 2017/6/30.
//  Copyright © 2017年 jst. All rights reserved.
//

#import "MixerVoiceHandle.h"
#import "ocAudioFileModel.h"
//#import "CAComponentDescription.h"
//输出音频的采样率(也是session设置的采样率)，
const double kGraphSampleRate = 44100.0;
//每次回调提供多长时间的数据,结合采样率 0.005 = x*1/44100, x = 220.5, 因为回调函数中的inNumberFrames是2的幂，所以x应该是256
const double kSessionBufDuration    = 0.005;

void CheckError(OSStatus error,const char *operaton){
    if (error==noErr) {
        return;
    }
    char errorString[20]={};
    *(UInt32 *)(errorString+1)=CFSwapInt32HostToBig(error);
    if (isprint(errorString[1])&&isprint(errorString[2])&&isprint(errorString[3])&&isprint(errorString[4])) {
        errorString[0]=errorString[5]='\'';
        errorString[6]='\0';
    }else{
        sprintf(errorString, "%d",(int)error);
    }
    fprintf(stderr, "Error:%s (%s)\n",operaton,errorString);
    exit(1);
}



@interface MixerVoiceHandle ()
{
    FILE* outFile;
    
    int audioLength;
    
    long long seekFrameNum;
}
@property (nonatomic,strong) NSArray *sourceArr;

@property (nonatomic,strong) NSMutableArray* audioRefArr;

@property (nonatomic,strong) NSMutableArray<ocAudioFileModel*>* audioArr;

@end


@implementation MixerVoiceHandle{
    
    AUGraph        _mGraph;
    AudioUnit      _mMixer;
    AudioUnit      _mOutput;
    dispatch_queue_t _mQueue;//串行队列,初始化和初始设置音量等操作放到这个队列中，因为加载文件需要比较久，所以都放到了子线程中
    AudioStreamBasicDescription _asbd;
    ExtAudioFileRef _fileFP;
    CFURLRef                    fileURL;
    
    AUNode _mixNode;
    BOOL isRecord;
    
}
-(instancetype)initWithSourceArr:(NSArray *)sourceArr{
    self = [super init];
    if (self) {
        self.isPlaying = NO;
        self.sourceArr = sourceArr;
        self.audioRefArr = [NSMutableArray array];
        self.audioArr = [NSMutableArray array];
        _mQueue = dispatch_queue_create("serial queue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_mQueue, ^{
            [self setRecording:NO];
            [self loadFileIntoMemory];
            [self configGraph];
        });
    }
    return self;
}

-(void)setRecording:(BOOL)isrecord
{
    isRecord = isrecord;
}
-(void)initFileRef
{
    
    AudioStreamBasicDescription audioDescription;
    memset(&audioDescription, 0, sizeof(audioDescription));
    audioDescription.mFormatID         = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 2;
    audioDescription.mBytesPerPacket   = sizeof(SInt16)*2;
    audioDescription.mFramesPerPacket  = 1;
    audioDescription.mBytesPerFrame    = sizeof(SInt16)*2;
    audioDescription.mBitsPerChannel   = 8 * sizeof(SInt16);
    audioDescription.mSampleRate       = 44100.0;
    
    AudioStreamBasicDescription outputDescription;
    memset(&outputDescription, 0, sizeof(outputDescription));
    outputDescription.mFormatID         = kAudioFormatMPEG4AAC;
    outputDescription.mChannelsPerFrame = 2;
    outputDescription.mSampleRate       = 44100.0;
    fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)[self GetFilePathByfileName:@"audiii.aac"], kCFURLPOSIXPathStyle, false);
    UInt32 propSize = sizeof(audioDescription);
    
    OSStatus status;
    status =  ExtAudioFileCreateWithURL(self->fileURL,
                                        kAudioFileAAC_ADTSType,
                                        &outputDescription,
                                        NULL,
                                        kAudioFileFlags_EraseFile,
                                        &_fileFP);
    status = ExtAudioFileSetProperty(_fileFP,
                                     kExtAudioFileProperty_ClientDataFormat,
                                     propSize,
                                     &audioDescription);
    
}

- (void)initForFilePath {
    //    NSString *path = [self GetFilePathByfileName:@"mixAudio.wav"];
    //    NSLog(@"%@", path);
    //    self->outFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

-(void)loadFileIntoMemory{
    
    
    for (int i = 0; i < self.sourceArr.count; i++) {
        NSLog(@"read Audio file : %@",self.sourceArr[i]);
        CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self.sourceArr[i], kCFURLPOSIXPathStyle, false);
        ocAudioFileModel* fileModel = [ocAudioFileModel new];
        [self.audioArr addObject:fileModel];
        
        //open the audio file
        
        [fileModel fileOpen:url];
        AudioStreamBasicDescription fileFormat;
        UInt32 propSize = sizeof(fileFormat);
        
        //read the file data format , it represents the file's actual data format.
        CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileDataFormat,
                                           &propSize, &fileFormat),
                   "read audio data format from file");
        
        double rateRatio = kGraphSampleRate/fileFormat.mSampleRate;
        
        UInt32 channel = 1;
        AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                       sampleRate:kGraphSampleRate
                                                                         channels:channel
                                                                      interleaved:NO];
        
        propSize = sizeof(AudioStreamBasicDescription);
        CheckError(ExtAudioFileSetProperty(fileModel.audioFileRef, kExtAudioFileProperty_ClientDataFormat,
                                           propSize, clientFormat.streamDescription),
                   "cant set the file output format");
        //get the file's length in sample frames
        UInt64 numFrames = 0;
        propSize = sizeof(numFrames);
        CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileLengthFrames,
                                           &propSize, &numFrames),
                   "cant get the fileLengthFrames");
        
        numFrames = numFrames * rateRatio;
        
        fileModel.numFrames = (UInt32)numFrames;
        fileModel.channel = channel;
        fileModel.desc = *(clientFormat.streamDescription);
        fileModel.seekFrameNum = 0;
        fileModel.url = self.sourceArr[i];
    }
}

-(void)configGraph{
    
    CheckError(NewAUGraph(&_mGraph), "cant new a graph");
    
    
    
    AUNode outputNode;
    
    AudioComponentDescription mixerACD;
    mixerACD.componentType      = kAudioUnitType_Mixer;
    mixerACD.componentSubType   = kAudioUnitSubType_MultiChannelMixer;
    mixerACD.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerACD.componentFlags = 0;
    mixerACD.componentFlagsMask = 0;
    
    AudioComponentDescription outputACD;
    outputACD.componentType      = kAudioUnitType_Output;
    outputACD.componentSubType   = kAudioUnitSubType_RemoteIO;
    outputACD.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputACD.componentFlags = 0;
    outputACD.componentFlagsMask = 0;
    
    CheckError(AUGraphAddNode(_mGraph, &mixerACD,
                              &_mixNode),
               "cant add node");
    CheckError(AUGraphAddNode(_mGraph, &outputACD,
                              &outputNode),
               "cant add node");
    
    CheckError(AUGraphConnectNodeInput(_mGraph, _mixNode, 0, outputNode, 0),
               "connect mixer Node to output node error");
    
    CheckError(AUGraphOpen(_mGraph), "cant open the graph");
    
    CheckError(AUGraphNodeInfo(_mGraph, _mixNode,
                               NULL, &_mMixer),
               "generate mixer unit error");
    CheckError(AUGraphNodeInfo(_mGraph, outputNode, NULL, &_mOutput),
               "generate remote I/O unit error");
    
    UInt32 numberOfMixBus = (UInt32)self.sourceArr.count;
    
    CheckError(AudioUnitSetProperty(_mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                                    &numberOfMixBus, sizeof(numberOfMixBus)),
               "set mix elements error");
    
    UInt32 maximumFramesPerSlice = 4096;
    CheckError( AudioUnitSetProperty (_mMixer,
                                      kAudioUnitProperty_MaximumFramesPerSlice,
                                      kAudioUnitScope_Global,
                                      0,
                                      &maximumFramesPerSlice,
                                      sizeof (maximumFramesPerSlice)
                                      ), "cant set kAudioUnitProperty_MaximumFramesPerSlice");
    
    
    for (int i = 0; i < numberOfMixBus ; i++) {
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = (__bridge void*)(self);
        
        AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &rcbs, sizeof(rcbs));
        
        
        AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                       sampleRate:kGraphSampleRate
                                                                         channels:1
                                                                      interleaved:NO];
        CheckError(AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input, i,
                                        clientFormat.streamDescription, sizeof(AudioStreamBasicDescription)),
                   "cant set the input scope format on bus[i]");
        
    }
    
    CheckError(AUGraphInitialize(_mGraph), "cant initial graph");
    
    
}

-(void)stopAUGraph{
    Boolean isRunning = false;
    OSStatus result = AUGraphIsRunning(_mGraph, &isRunning);
    if (result) { printf("AUGraphIsRunning result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
    if (!_mGraph) {
        return;
    }
    if (isRunning) {
        result = AUGraphStop(_mGraph);
        if (result) { printf("AUGraphStop result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
        self.isPlaying = NO;
    }
}
-(void)startAUGraph{
    printf("PLAY\n");
    OSStatus result = AUGraphStart(_mGraph);
    if (result) { printf("AUGraphStart result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    self.isPlaying = YES;
}
-(void)enableInput:(NSInteger)busIndex isOn:(BOOL)isOn{
    dispatch_async(_mQueue, ^{
        AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Enable,
                              kAudioUnitScope_Input, (int)busIndex,
                              (AudioUnitParameterValue)isOn, 0) ;
    });
    
}
-(void)setInputVolumeWithBus:(NSInteger)busIndex value:(CGFloat)value{
    dispatch_async(_mQueue, ^{
        AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Volume,
                              kAudioUnitScope_Input, (int)busIndex,
                              (AudioUnitParameterValue)value, 0) ;
    });
}
-(void)setOutputVolume:(AudioUnitParameterValue)value{
    dispatch_async(_mQueue, ^{
        AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Volume,
                              kAudioUnitScope_Output, 0, value, 0);
    });
}
static OSStatus renderInput(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber, UInt32 inNumberFrames,
                            AudioBufferList *ioData)
{
    MixerVoiceHandle* weakSelf = (__bridge MixerVoiceHandle*)inRefCon;
    
    
    ExtAudioFileRef fp =  (weakSelf.audioArr[inBusNumber]).audioFileRef;
    UInt32 sample = (weakSelf.audioArr[inBusNumber]).seekFrameNum;      // frame number to start from
    UInt32 bufSamples = (weakSelf.audioArr[inBusNumber]).numFrames;  // total number of frames in the sound buffer
    UInt32 channel = (weakSelf.audioArr[inBusNumber]).channel;
    AudioBufferList *bufList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer)*(channel-1));
    
    AudioBuffer emptyBuffer = {0};
    for (int arrayIndex = 0; arrayIndex < channel; arrayIndex++) {
        bufList->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufList->mNumberBuffers = channel;
    
    bufList->mBuffers[0].mNumberChannels = 1;
    bufList->mBuffers[0].mData = (UInt16 *)calloc(inNumberFrames, sizeof(UInt16));
    bufList->mBuffers[0].mDataByteSize = (UInt16)inNumberFrames*sizeof(UInt16);
    
    if (2 == channel) {
        bufList->mBuffers[1].mNumberChannels = 1;
        bufList->mBuffers[1].mDataByteSize = (UInt16)inNumberFrames*sizeof(UInt16);
        bufList->mBuffers[1].mData = (UInt16 *)calloc(inNumberFrames, sizeof(UInt16));
    }
    
    if (sample + inNumberFrames <= bufSamples) {
        UInt32 numPacketToRead = (UInt32) inNumberFrames;
        
        ExtAudioFileSeek(fp, sample);
        ExtAudioFileRead(fp, &numPacketToRead,bufList);
        
        ioData->mNumberBuffers = 1;
        memcpy(ioData->mBuffers[0].mData, bufList -> mBuffers[0].mData, numPacketToRead*4);
        //        if (sndbuf[inBusNumber].channelCount == 2) {
        //            ioData->mNumberBuffers = 1;
        //            memcpy(ioData->mBuffers[1].mData, bufList -> mBuffers[1].mData, numPacketToRead*4);
        //        }
        free(bufList -> mBuffers[0].mData);
        bufList -> mBuffers[0].mData = NULL;
        if (bufList -> mBuffers[1].mData && channel == 2) {
            free(bufList -> mBuffers[1].mData);
            bufList -> mBuffers[1].mData = NULL;
        }
        free(bufList);
        bufList = NULL;
        sample = sample + inNumberFrames;
        
    }
    else
    {
        UInt32 numPacketToRead = (UInt32) inNumberFrames;
        ExtAudioFileSeek(fp, 0);
        ExtAudioFileRead(fp, &numPacketToRead,bufList);
        ioData->mNumberBuffers = 1;
        memcpy(ioData->mBuffers[0].mData, bufList -> mBuffers[0].mData, numPacketToRead*4);
        //        if (sndbuf[inBusNumber].channelCount == 2) {
        //            ioData->mNumberBuffers = 1;
        //            memcpy(ioData->mBuffers[1].mData, bufList -> mBuffers[1].mData, numPacketToRead*4);
        //        }
        free(bufList -> mBuffers[0].mData);
        bufList -> mBuffers[0].mData = NULL;
        if (bufList -> mBuffers[1].mData && channel == 2) {
            free(bufList -> mBuffers[1].mData);
            bufList -> mBuffers[1].mData = NULL;
        }
        free(bufList);
        bufList = NULL;
        
        if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(musicFinished:)] && !weakSelf.audioArr[inBusNumber].isOver) {
            weakSelf.audioArr[inBusNumber].isOver = YES;
            [weakSelf.delegate musicFinished:inBusNumber];
        }
        return -1;
        //        sample = inNumberFrames;
    }
    
    (weakSelf.audioArr[inBusNumber]).seekFrameNum = sample; // keep track of where we are in the source data buffer
    return noErr;
}

-(void)close
{
    @synchronized (self) {
        if (!self.isPlaying) {
            return;
        }
        [self stopAUGraph];
        NSLog(@"_mGraph close");
        
        if (_mGraph) {
            AUGraphUninitialize(_mGraph);
            AUGraphClose(_mGraph);
            DisposeAUGraph(_mGraph);
            _mGraph = nil;
        }
        
        for(int i = 0;i<self.audioArr.count;i++)
        {
            ocAudioFileModel* fileModel = _audioArr[i];
            [fileModel close];
        }
        [self.audioArr removeAllObjects];
    }
}

-(void)addMixRender:(NSString*)url
{
    [self addModel:url];
    AURenderCallbackStruct rcbs;
    rcbs.inputProc = &renderInput;
    rcbs.inputProcRefCon = (__bridge void*)(self);
    
    AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, (UInt32)self.audioArr.count - 1, &rcbs, sizeof(rcbs));
    
    
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:1
                                                                  interleaved:NO];
    CheckError(AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, (UInt32)self.audioArr.count -1,
                                    clientFormat.streamDescription, sizeof(AudioStreamBasicDescription)),
               "cant set the input scope format on bus[i]");
    
}

-(void)removeMixRenderBusNum:(UInt32)busNum
{
    AudioUnitConnection connection = {0};
    connection.sourceAudioUnit = NULL;
    connection.sourceOutputNumber = 0;
    connection.destInputNumber = (UInt32)_audioArr.count-1;
    AudioUnitSetProperty(_mMixer, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &connection, sizeof(connection));
    [self removeModel:busNum];
}

-(void)removeModel:(int)busNum
{
    ocAudioFileModel* fileModel = _audioArr[busNum];
    [fileModel close];
    [_audioArr removeObjectAtIndex:busNum];
}

-(void)addModel:(NSString*)urlstr
{
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)urlstr, kCFURLPOSIXPathStyle, false);
    ocAudioFileModel* fileModel = [ocAudioFileModel new];
    [self.audioArr addObject:fileModel];
    
    //open the audio file
    
    [fileModel fileOpen:url];
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(fileFormat);
    
    //read the file data format , it represents the file's actual data format.
    CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileDataFormat,
                                       &propSize, &fileFormat),
               "read audio data format from file");
    
    double rateRatio = kGraphSampleRate/fileFormat.mSampleRate;
    
    UInt32 channel = 1;
    //        if (fileFormat.mChannelsPerFrame == 2) {
    //            channel = 2;
    //        }
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:channel
                                                                  interleaved:NO];
    
    propSize = sizeof(AudioStreamBasicDescription);
    CheckError(ExtAudioFileSetProperty(fileModel.audioFileRef, kExtAudioFileProperty_ClientDataFormat,
                                       propSize, clientFormat.streamDescription),
               "cant set the file output format");
    //get the file's length in sample frames
    UInt64 numFrames = 0;
    propSize = sizeof(numFrames);
    CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileLengthFrames,
                                       &propSize, &numFrames),
               "cant get the fileLengthFrames");
    
    numFrames = numFrames * rateRatio;
    
    fileModel.numFrames = (UInt32)numFrames;
    fileModel.channel = channel;
    fileModel.desc = *(clientFormat.streamDescription);
    fileModel.seekFrameNum = 0;
    fileModel.url = urlstr;
}

-(void)seekInBusNum:(int)num Value:(float)vlaue
{
    ocAudioFileModel* model = _audioArr[num];
    int sample = model.numFrames*vlaue;
    model.seekFrameNum = sample;
}

-(void)resetAudioSeek
{
    for (ocAudioFileModel* model in _audioArr) {
        model.seekFrameNum = 0;
    }
}

-(void)resetAudioFile:(NSString *)urlstr inbus:(int)bus
{
    ocAudioFileModel* fileModel = _audioArr[bus];
    [fileModel close];
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)urlstr, kCFURLPOSIXPathStyle, false);
    //open the audio file
    
    [fileModel fileOpen:url];
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(fileFormat);
    
    //read the file data format , it represents the file's actual data format.
    CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileDataFormat,
                                       &propSize, &fileFormat),
               "read audio data format from file");
    
    double rateRatio = kGraphSampleRate/fileFormat.mSampleRate;
    
    UInt32 channel = 1;
    //        if (fileFormat.mChannelsPerFrame == 2) {
    //            channel = 2;
    //        }
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:channel
                                                                  interleaved:NO];
    
    propSize = sizeof(AudioStreamBasicDescription);
    CheckError(ExtAudioFileSetProperty(fileModel.audioFileRef, kExtAudioFileProperty_ClientDataFormat,
                                       propSize, clientFormat.streamDescription),
               "cant set the file output format");
    //get the file's length in sample frames
    UInt64 numFrames = 0;
    propSize = sizeof(numFrames);
    CheckError(ExtAudioFileGetProperty(fileModel.audioFileRef, kExtAudioFileProperty_FileLengthFrames,
                                       &propSize, &numFrames),
               "cant get the fileLengthFrames");
    
    numFrames = numFrames * rateRatio;
    
    fileModel.numFrames = (UInt32)numFrames;
    fileModel.channel = channel;
    fileModel.desc = *(clientFormat.streamDescription);
    fileModel.seekFrameNum = 0;
    fileModel.url = urlstr;
    
}
@end
