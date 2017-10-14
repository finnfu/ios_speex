#import "EYAudio.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define MIN_SIZE_PER_FRAME 1920   //ÿ�����Ĵ�С,���ڻ�Ҫ��Ϊ960,���忴�����������Ϣ
#define QUEUE_BUFFER_SIZE  3      //����������
#define SAMPLE_RATE        16000  //����Ƶ��

@interface EYAudio(){
    AudioQueueRef audioQueue;                                 //��Ƶ���Ŷ���
    AudioStreamBasicDescription _audioDescription;
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //��Ƶ����
    BOOL audioQueueBufferUsed[QUEUE_BUFFER_SIZE];             //�ж���Ƶ�����Ƿ���ʹ��
    NSLock *sysnLock;
    NSMutableData *tempData;
    OSStatus osState;
}
@end

@implementation EYAudio

#pragma mark - ��ǰ����AVAudioSessionCategoryMultiRoute ���ź�¼��
+ (void)initialize
{
    NSError *error = nil;
    //ֻ��Ҫ����:AVAudioSessionCategoryPlayback
    //ֻ��Ҫ¼��:AVAudioSessionCategoryRecord
    //��Ҫ"���ź�¼��"ͬʱ���� ��������Ϊ:AVAudioSessionCategoryMultiRoute ������AVAudioSessionCategoryPlayAndRecord(�����������ʹ)
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:&error];
    if (!ret) {
        NSLog(@"������������ʧ��");
        return;
    }
    //����audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"����ʧ��");
        return;
    }
}

- (void)resetPlay
{
    if (audioQueue != nil) {
        AudioQueueReset(audioQueue);
    }
}

- (void)stop
{
    if (audioQueue != nil) {
        AudioQueueStop(audioQueue,true);
    }

    audioQueue = nil;
    sysnLock = nil;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        sysnLock = [[NSLock alloc]init];

        //������Ƶ���� �������Ϣ��Ҫ�ʺ�̨
        _audioDescription.mSampleRate = SAMPLE_RATE;
        _audioDescription.mFormatID = kAudioFormatLinearPCM;
        _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        //1������
        _audioDescription.mChannelsPerFrame = 1;
        //ÿһ��packetһ������,ÿ�����ݰ��µ���������ÿ�����ݰ������ж�����
        _audioDescription.mFramesPerPacket = 1;
        //ÿ��������16bit���� ����ÿ������ռ��λ��
        _audioDescription.mBitsPerChannel = 16;
        _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
        //ÿ�����ݰ���bytes������ÿ���bytes��*ÿ�����ݰ�������
        _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;

        // ʹ��player���ڲ��̲߳��� �½����
        AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, 0, 0, &audioQueue);

        // ��������
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);

        // ��ʼ����Ҫ�Ļ�����
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            audioQueueBufferUsed[i] = false;
            osState = AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
        }

        osState = AudioQueueStart(audioQueue, NULL);
        if (osState != noErr) {
            NSLog(@"AudioQueueStart Error");
        }
    }
    return self;
}

// ��������
-(void)playWithData:(NSData *)data
{
    [sysnLock lock];

    tempData = [NSMutableData new];
    [tempData appendData: data];
    NSUInteger len = tempData.length;
    Byte *bytes = (Byte*)malloc(len);
    [tempData getBytes:bytes length: len];

    int i = 0;
    while (true) {
        if (!audioQueueBufferUsed[i]) {
            audioQueueBufferUsed[i] = true;
            break;
        }else {
            i++;
            if (i >= QUEUE_BUFFER_SIZE) {
                i = 0;
            }
        }
    }

    audioQueueBuffers[i] -> mAudioDataByteSize =  (unsigned int)len;
    // ��bytes��ͷ��ַ��ʼ��len�ֽڸ�mAudioData,���i��������
    memcpy(audioQueueBuffers[i] -> mAudioData, bytes, len);

    // �ͷŶ���
    free(bytes);

    //����i���������ŵ�������,ʣ�µĶ�����ϵͳ��
    AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);

    [sysnLock unlock];
}

// ************************** �ص� **********************************
// �ص�������buffer״̬��Ϊδʹ��
static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {

    EYAudio* audio = (__bridge EYAudio*)inUserData;

    [audio resetBufferState:audioQueueRef and:audioQueueBufferRef];
}

- (void)resetBufferState:(AudioQueueRef)audioQueueRef and:(AudioQueueBufferRef)audioQueueBufferRef {
    // ��ֹ��������audioqueue������������,Ϊ�˰�ȫ����һ��
    if (tempData.length == 0) {
        audioQueueBufferRef->mAudioDataByteSize = 1;
        Byte* byte = audioQueueBufferRef->mAudioData;
        byte = 0;
        AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef, 0, NULL);
    }

    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        // �����buffer��Ϊδʹ��
        if (audioQueueBufferRef == audioQueueBuffers[i]) {
            audioQueueBufferUsed[i] = false;
        }
    }
}

@end