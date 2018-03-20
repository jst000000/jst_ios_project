//
//  ViewController.h
//  audioMix_jst
//
//  Created by jst on 2017/6/19.
//  Copyright © 2017年 jst. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface ViewController : UIViewController
{
    MPMoviePlayerController *moviePlayer;
}
@property (weak, nonatomic) IBOutlet UIView *vwMoviePlayer;
@property (weak, nonatomic) IBOutlet UILabel *label;


@end

