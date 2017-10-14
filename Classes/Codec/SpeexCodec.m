//
//  SpeexCodec.m
//  OggSpeex
//
//  Created by Jiang Chuncheng on 11/26/12.
//  Copyright (c) 2012 Sense Force. All rights reserved.
//

#import "SpeexCodec.h"

@implementation SpeexCodec
- (id)init {
    if (self = [super init]) {
        codecOpenedTimes = 0;
    }
    return self;
}

/*
 quality value 1 ~ 10
 */
- (void)open:(int)quality {
    if ((quality < 1) || (quality > 10)) {
        return;
    }
    if (codecOpenedTimes++ != 0) {
        return;
    }
    else {
        //初始化SpeexBits
        speex_bits_init(&encodeSpeexBits);
        speex_bits_init(&decodeSpeexBits);
        
        //设置为宽带 16k
        
        
        
        encodeState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_WB));
        decodeState = speex_decoder_init(speex_lib_get_mode(SPEEX_MODEID_WB));

        //设置压缩质量
        int tmp = quality;
        speex_encoder_ctl(encodeState, SPEEX_SET_QUALITY, &tmp);

        //设置知觉增强
        tmp = 1;
        speex_encoder_ctl(encodeState, SPEEX_SET_ENH, &tmp);
        
        //设置编码器的可用CPU资源
        tmp = 3;
        speex_encoder_ctl(encodeState, SPEEX_SET_COMPLEXITY, &tmp);
        
        tmp = 0;
        speex_encoder_ctl(encodeState, SPEEX_SET_VBR, &tmp);
        
        tmp=3;
        speex_encoder_ctl(encodeState, SPEEX_SET_HIGH_MODE, &tmp);
        
        tmp=6;
        speex_encoder_ctl(encodeState, SPEEX_SET_LOW_MODE, &tmp);
        
        
        speex_encoder_ctl(encodeState, SPEEX_GET_FRAME_SIZE, &encodeFrameSize);
        speex_decoder_ctl(decodeState, SPEEX_GET_FRAME_SIZE, &decodeFrameSize);
        
        SpeexPreprocessState *preprocess_state = speex_preprocess_state_init(32, 16000);
        int denoise = 1;
        int noiseSuppress = -25;
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_DENOISE, &denoise);// 降噪
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_NOISE_SUPPRESS, &noiseSuppress);// 噪音
        
        int agc = 1;
        int level = 24000;
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_AGC, &agc);// 增益
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_AGC_LEVEL,&level);// 增益后的值
        
        int vad = 1;
        int vadProbStart = 80;
        int vadProbContinue = 65;
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_VAD, &vad); //静音检测
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_PROB_START , &vadProbStart);
        speex_preprocess_ctl(preprocess_state, SPEEX_PREPROCESS_SET_PROB_CONTINUE, &vadProbContinue);
    }
}

- (NSData *)encode:(short *)pcmBuffer length:(int)lengthOfShorts {
    if (codecOpenedTimes == 0 || encodeState == nil || encodeState == NULL) {
        return nil;
    }
    NSMutableData *ecodedData = [NSMutableData dataWithCapacity:20];
    char cbits[lengthOfShorts*2];
    int nbBytes;
    speex_bits_reset(&encodeSpeexBits);
    speex_encode_int(encodeState, pcmBuffer, &encodeSpeexBits);
    nbBytes = speex_bits_write(&encodeSpeexBits, cbits, lengthOfShorts*2);
    [ecodedData appendBytes:cbits length:nbBytes];
    return ecodedData;
    
    
}

- (NSData*)decode:(unsigned char *)encodedBytes length:(int)lengthOfBytes{
	if ( ! codecOpenedTimes)
		return 0;
    short decodedBuffer[1024];
    NSMutableData *decodedData = [NSMutableData dataWithCapacity:20];
    char cbits[1024];
    memcpy(cbits, encodedBytes, lengthOfBytes);
    speex_bits_reset(&decodeSpeexBits);
    speex_bits_read_from(&decodeSpeexBits, cbits, lengthOfBytes);
    speex_decode_int(decodeState, &decodeSpeexBits, decodedBuffer);
    [decodedData appendBytes:decodedBuffer length:640];
	return decodedData;
}

- (void)close {
    if (--codecOpenedTimes != 0) {
		return;
    }
    
    speex_bits_destroy(&encodeSpeexBits);
    speex_encoder_destroy(encodeState);
}

- (void)dealloc {
    [self close];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

@end
