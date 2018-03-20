//
//  ViewController.m
//  audioMix_jst
//
//  Created by jst on 2017/6/19.
//  Copyright © 2017年 jst. All rights reserved.
//

#import "ViewController.h"
//#import "AudioFileMix.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property(nonatomic,strong)NSArray* sourceURLs;
@end

@implementation ViewController
@synthesize vwMoviePlayer;
@synthesize label;

- (void)viewDidLoad {
    // Do any additional setup after loading the view, typically from a nib.
    [super viewDidLoad];
    NSString* sound1_url = [[NSBundle mainBundle]pathForResource:@"fivesound.mp3" ofType:nil];
    NSString* sound2_url = [[NSBundle mainBundle]pathForResource:@"sound_voices.wav" ofType:nil];
    NSString* sound3_url = [[NSBundle mainBundle]pathForResource:@"DrumsMonoSTP.aif" ofType:nil];
    self.sourceURLs = @[sound1_url,sound2_url,sound3_url];
//    NSString* toStr = [self GetFilePathByfileName:@"mixaudo3.m4a"];
//    [AudioFileMix audioMixSourceURLs:array composeToURL:toStr completed:^(NSError *error) {
//        if (error) {
//            NSLog(@"mix failed error:%@",error);
//        }
//        else
//        {
//            NSLog(@"mix succeed");
//        }
//    }];
//    [self overlapVideos];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}
@end
