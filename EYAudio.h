#import <Foundation/Foundation.h>

@interface EYAudio : NSObject

// 播放的数据流数据
- (void)playWithData:(NSData *)data;

// 声音播放出现问题的时候可以重置一下
- (void)resetPlay;

// 停止播放
- (void)stop;

@end