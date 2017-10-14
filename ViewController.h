//
//  ViewController.h
//  XYRealTimeRecord
//
//  Created by zxy on 2017/3/17.
//  Copyright © 2017年 zxy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PCMDataPlayer.h"

#define EVERY_READ_LENGTH 1024 //每次从PCM文件读取的长度

@interface ViewController : UIViewController
{
    PCMDataPlayer* player;
    FILE* pcmFile;
    void* pcmDataBuffer; //pcm读数据的缓冲区
    NSTimer* sendDataTimer;
}

@end

