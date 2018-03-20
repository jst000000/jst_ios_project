//
//  ocAudioFileManger.h
//  VoiceMixer
//
//  Created by jst on 2017/6/27.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface ocAudioFileManger : NSObject
-(id)initWith:(int)channel samplerates:(int)rates isFloat:(int)type;
-(void)createFileWithUrlStr:(NSString*)str outDesc:(AudioStreamBasicDescription)desc;
-(void)writeFileWithBufferList:(AudioBufferList*)iodata;
@end
