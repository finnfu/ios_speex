//
//  XYRecorder.m
//  XYRealTimeRecord
//
//  Created by zxy on 2017/3/17.
//  Copyright © 2017年 zxy. All rights reserved.
//

#import "XYRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import "PCMDataPlayer.h"

#define INPUT_BUS 1
#define OUTPUT_BUS 0

#define CALLBACK_DURATION 0.002
#define TOTAL_COUNT 10/CALLBACK_DURATION


AudioUnit audioUnit;
AudioBufferList *buffList;
NSString *mfileRes;
NSString *mfileEnc;
NSString *mfileDec;
NSMutableData *resAllData;
NSMutableData *encAllData;
NSMutableData *decAllData;
NSMutableData *tenData;
int count;
SpeexCodec *codec;

PCMDataPlayer* player;

AVAudioSession *audioSession;

@implementation XYRecorder

#pragma mark - init

- (instancetype)init {
    self = [super init];
    if (self) {
        AudioUnitInitialize(audioUnit);
        [self initRemoteIO];
    }

    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if (![fileManager fileExistsAtPath:PATH_OF_AUDIO]) {
        [fileManager createDirectoryAtPath:PATH_OF_AUDIO withIntermediateDirectories:YES attributes:nil error:nil];
    }
    mfileRes = [PATH_OF_AUDIO stringByAppendingPathComponent:@"res_audio.pcm"];
    mfileEnc = [PATH_OF_AUDIO stringByAppendingPathComponent:@"enc_audio.pcm"];
    mfileDec = [PATH_OF_AUDIO stringByAppendingPathComponent:@"dec_audio.pcm"];
    resAllData = [NSMutableData dataWithCapacity:20];
    encAllData = [NSMutableData dataWithCapacity:20];
    decAllData = [NSMutableData dataWithCapacity:20];
    
    tenData = [NSMutableData dataWithCapacity:20];
    
    
    count = 0;
    //初始化
    codec = [[SpeexCodec alloc] init];
    [codec open:4];
    
    
    
    //自定义音频播放器的初始化
    if (player != nil) {
        [player stop];
        player = nil;
    }
    player = [[PCMDataPlayer alloc] init];
    
    
    return self;
}

- (void)initRemoteIO {
    [self initAudioSession];
    
    [self initBuffer];
    
    [self initAudioComponent];
    
    [self initFormat];
    
    [self initAudioProperty];
    
    [self initRecordeCallback];
    
//    [self initPlayCallback];
}

- (void)initAudioSession {
    NSError *error;
    audioSession = [AVAudioSession sharedInstance];
    //扬声器
//    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    
    //听筒
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    
    [audioSession setPreferredSampleRate:16000 error:&error];
    [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    [audioSession setPreferredIOBufferDuration:CALLBACK_DURATION error:&error];
    [audioSession setActive:YES error:&error];
}

- (void)initBuffer {
    UInt32 flag = 0;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    
    buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = 640;
    buffList->mBuffers[0].mData = (short *)malloc(640);
}

- (void)initAudioComponent {
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
}

- (void)initFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 16000;//
    audioFormat.mFormatID = kAudioFormatLinearPCM;//
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;//
    
    audioFormat.mBitsPerChannel = 16;//
    audioFormat.mChannelsPerFrame = 1;//
    audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
    
    
    
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
}

- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));
}

- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
}

- (void)initAudioProperty {
    UInt32 flag = 1;
    
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &flag,
                         sizeof(flag));

}

#pragma mark - callback function

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    
    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, buffList);
    short *data = (short *)buffList->mBuffers[0].mData;
    NSMutableData *resData = [NSMutableData dataWithCapacity:20];
    int resDataBytesLenght = buffList->mBuffers[0].mDataByteSize;
    [resData appendBytes:data length:resDataBytesLenght];
    NSLog(@"buffer size: %d",resDataBytesLenght);
    
    //原数据写入文件
    count++;
    NSLog(@"count : %d",count);
    if(count < TOTAL_COUNT){
        [resAllData appendData:resData];
    }else if(count == TOTAL_COUNT){
        [resAllData writeToFile:mfileRes atomically:YES];
        NSLog(@"resAllData write to file");
    }
    if(count % 10 == 0){
        [tenData appendData:resData];
        const void *bytes1 =  [tenData bytes];
//        [player play:bytes1 length:640]; //播放采集的原始pcm数据
        short input_frame[320];
        memcpy(input_frame, bytes1, 640);
        //压缩
        NSData *speexData = [codec encode:input_frame length:320];
        int encodeLength = (int)[speexData length];
        //压缩后的数据写入文件
        if(count < TOTAL_COUNT){
            [encAllData appendData:speexData];
        }else if(count == TOTAL_COUNT){
            [encAllData writeToFile:mfileEnc atomically:YES];
            NSLog(@"encAllData write to file");
        }
        //解压缩
        const Byte *bytes = [speexData bytes];
        unsigned char charData[encodeLength];
        memcpy(charData,bytes,encodeLength);
        NSData *decodeData = [codec decode:charData length:encodeLength];
        
        bytes1 =  [decodeData bytes];
        [player play:bytes1 length:640];//播放解压缩后的pcm数据
        
        //解压缩后的数据写入文件
        if(count < TOTAL_COUNT){
            [decAllData appendData:decodeData];
        }else if(count == TOTAL_COUNT){
            [decAllData writeToFile:mfileDec atomically:YES];
            NSLog(@"decAllData write to file");
        }
        
        //清空
        [tenData replaceBytesInRange:NSMakeRange(0, 640) withBytes:NULL length:0];
    }else{
        [tenData appendData:resData];
    }

    return noErr;
}





static OSStatus PlayCallback(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData) {
    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    return noErr;
}

#pragma mark - public methods

- (void)startRecorder {
    AudioOutputUnitStart(audioUnit);
}

- (void)stopRecorder {
    AudioOutputUnitStop(audioUnit);
}


@end
