#import <Foundation/Foundation.h>

@interface EYAudio : NSObject

// ���ŵ�����������
- (void)playWithData:(NSData *)data;

// �������ų��������ʱ���������һ��
- (void)resetPlay;

// ֹͣ����
- (void)stop;

@end