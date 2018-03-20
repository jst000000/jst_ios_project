//
//  ocAudioFileModel.m
//  VoiceMixer
//
//  Created by jst on 2017/7/28.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import "ocAudioFileModel.h"

@implementation ocAudioFileModel

-(instancetype)init
{
    if (self = [super init]) {
        self.numFrames = 0;
        self.seekFrameNum = 0;
        
    }
    
    return self;
}

-(void)fileOpen:(CFURLRef)url
{
    ExtAudioFileOpenURL(url, &_audioFileRef);
}
-(void)close
{
    self.numFrames = 0;
    self.seekFrameNum = 0;
    if (_audioFileRef){
        ExtAudioFileDispose(_audioFileRef);
    }

}
@end
