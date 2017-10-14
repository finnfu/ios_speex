//
//  ViewController.m
//  XYRealTimeRecord
//
//  Created by zxy on 2017/3/17.
//  Copyright © 2017年 zxy. All rights reserved.
//

#import "ViewController.h"
#import "XYRecorder.h"

@interface ViewController ()
{

    NSString *mfileDec;
    NSMutableData *decAllData;
}
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (nonatomic, strong) XYRecorder *recorder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _recorder = [[XYRecorder alloc] init];
    self.stopButton.enabled = FALSE;
    
//    [self initPlayer];
//    [self startPlay];
    
//    [self decodePCMData];

}

-(void)initPlayer{
    if (player != nil) {
        [player stop];
        player = nil;
    }
    player = [[PCMDataPlayer alloc] init];
    NSLog(@"PlayerViewController PCMDataPlayer init...");
}

-(void)startPlay{
    if (sendDataTimer) {
        [sendDataTimer invalidate];
        sendDataTimer = nil;
    }else {
        
        // res_audio enc_audio dec_audio
        
        
        NSString* filepath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"dec_audio.pcm"];
        NSLog(@"PlayerViewController filepath = %@", filepath);
        NSFileManager* manager = [NSFileManager defaultManager];
        NSLog(@"PlayerViewController file exist = %d", [manager fileExistsAtPath:filepath]);
        NSLog(@"PlayerViewController file size = %lld", [[manager attributesOfItemAtPath:filepath error:nil] fileSize]);
        pcmFile = fopen([filepath UTF8String], "r");
        if (pcmFile) {
            fseek(pcmFile, 0, SEEK_SET);
            pcmDataBuffer = malloc(EVERY_READ_LENGTH);
            NSLog(@"PlayerViewController PCM文件打开成功...");
        }else {
            NSLog(@"PlayerViewController PCM文件打开错误...");
            return;
        }
    }
    sendDataTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 40.0)target:self selector:@selector(readNextPCMData:) userInfo:nil repeats:YES];
}


- (void)readNextPCMData:(NSTimer*)timer
{
    if (pcmFile != NULL && pcmDataBuffer != NULL) {
        int readLength = (int)fread(pcmDataBuffer, 1, EVERY_READ_LENGTH, pcmFile); //读取PCM文件
        if (readLength > 0) {
            [player play:pcmDataBuffer length:readLength];
        }else {
            if (sendDataTimer) {
                [sendDataTimer invalidate];
            }
            sendDataTimer = nil;
            
            if (player) {
                [player stop];
            }
            
            if (pcmFile) {
                fclose(pcmFile);
            }
            pcmFile = NULL;
            
            if (pcmDataBuffer) {
                free(pcmDataBuffer);
            }
            pcmDataBuffer = NULL;
        }
    }
}


-(void)decodePCMData{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if (![fileManager fileExistsAtPath:PATH_OF_AUDIO]) {
        [fileManager createDirectoryAtPath:PATH_OF_AUDIO withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    mfileDec = [PATH_OF_AUDIO stringByAppendingPathComponent:@"dec_encode.pcm"];
    decAllData = [NSMutableData dataWithCapacity:20];
    
    
    SpeexCodec *codec;
    codec = [[SpeexCodec alloc] init];
    [codec open:4];
    
    NSString* filepath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"encode.pcm"];
    NSLog(@"PlayerViewController filepath = %@", filepath);
    NSFileManager* manager = [NSFileManager defaultManager];
    NSLog(@"PlayerViewController file exist = %d", [manager fileExistsAtPath:filepath]);
    NSLog(@"PlayerViewController file size = %lld", [[manager attributesOfItemAtPath:filepath error:nil] fileSize]);
    pcmFile = fopen([filepath UTF8String], "r");
    if (pcmFile) {
        fseek(pcmFile, 0, SEEK_SET);
        pcmDataBuffer = malloc(EVERY_READ_LENGTH);
        NSLog(@"PlayerViewController PCM文件打开成功...");
    }else {
        NSLog(@"PlayerViewController PCM文件打开错误...");
        return;
    }
    
    while (pcmFile != NULL && pcmDataBuffer != NULL) {
        int readLength = (int)fread(pcmDataBuffer, 1, 70, pcmFile); //读取PCM文件
        if (readLength > 0) {
            unsigned char charData[70];
            memcpy(charData,pcmDataBuffer,70);
            NSData *decodeData = [codec decode:charData length:70];
            [decAllData appendData:decodeData];
        }else {
            [decAllData writeToFile:mfileDec atomically:YES];
            NSLog(@"write file");
        }
    }
}



- (IBAction)startRecord:(id)sender {
    [_recorder startRecorder];
    
    self.startButton.enabled = FALSE;
    self.stopButton.enabled = TRUE;
}

- (IBAction)stopRecorder:(id)sender {
    [_recorder stopRecorder];
    
    self.startButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
}

@end
