//
//  XYRecorder.h
//  XYRealTimeRecord
//
//  Created by zxy on 2017/3/17.
//  Copyright © 2017年 zxy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpeexCodec.h"

#define PATH_OF_DOCUMENT    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define PATH_OF_AUDIO   [PATH_OF_DOCUMENT stringByAppendingPathComponent:@"audio"]

@interface XYRecorder : NSObject



- (void)startRecorder;
- (void)stopRecorder;

@end
