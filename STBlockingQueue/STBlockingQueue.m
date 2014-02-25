//
//  STBlockingQueue.m
//  STBlockingQueue
//
//  Created by saiten on 2014/02/25.
//  Copyright (c) 2014年 saiten. All rights reserved.
//

#import "STBlockingQueue.h"
#import <TPCircularBuffer.h>
#import <pthread.h>

int32_t const RDKBlockingQueueDefaultCapacity = 4096;

@implementation STBlockingQueue {
    pthread_mutex_t _mutex;
    pthread_cond_t  _condition;
    TPCircularBuffer _circularBuffer;
}

- (id)initWithCapacity:(int32_t)capacity
{
    self = [super init];
    if(self) {
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_condition, NULL);
        
        _discontinuity = NO;
        
        _capacity = capacity;
        if(!TPCircularBufferInit(&_circularBuffer, capacity)) {
            return nil;
        }
    }
    return self;
}

+ (instancetype)blockingQueueWithCapacity:(int32_t)capacity
{
    return [[STBlockingQueue alloc] initWithCapacity:capacity];
}

- (void)close
{
    if(_closed) {
        return;
    }
    
    pthread_mutex_lock(&_mutex);
    _closed = YES;
    pthread_cond_signal(&_condition);
    pthread_mutex_unlock(&_mutex);
}

- (int32_t)pushWithBytes:(const int8_t *)buffer size:(int32_t)size
{
    return [self pushWithBytes:buffer size:size discontinuity:NO];
}

- (int32_t)popWithBytes:(int8_t *)buffer size:(int32_t)size
{
    BOOL discontinuity;
    return [self popWithBytes:buffer size:size discontinuity:&discontinuity];
}

- (int32_t)pushWithBytes:(const int8_t *)buffer size:(int32_t)size discontinuity:(BOOL)discontinuity
{
    if(size > _capacity) {
        return -1;
    }
    if(_closed) {
        return 0;
    }
    
    BOOL first = YES;
    int32_t availableSize;
    int8_t *head;
    
    pthread_mutex_lock(&_mutex);
    
    do {
        if(!first) {
            pthread_cond_wait(&_condition, &_mutex);
        } else {
            first = NO;
        }
        head = TPCircularBufferHead(&_circularBuffer, &availableSize);
    } while(size > availableSize && !_closed);
    
    int32_t writableSize = MIN(size, availableSize);
    memcpy(head, buffer, writableSize);
    TPCircularBufferProduce(&_circularBuffer, writableSize);
    
    _discontinuity = discontinuity;
    
    pthread_cond_signal(&_condition);
    pthread_mutex_unlock(&_mutex);
    
    if(discontinuity) {
        pthread_mutex_lock(&_mutex);
        while(_discontinuity) {
            pthread_cond_wait(&_condition, &_mutex);
        }
        pthread_mutex_unlock(&_mutex);
    }
    
    return writableSize;
}

- (int32_t)popWithBytes:(int8_t *)buffer size:(int32_t)size discontinuity:(BOOL *)discontinuity
{
    if(size > _capacity) {
        return -1;
    }
    
    BOOL first = YES;
    int32_t availableSize;
    int8_t *tail;
    
    pthread_mutex_lock(&_mutex);
    
    do {
        if(!first) {
            pthread_cond_wait(&_condition, &_mutex);
        } else {
            first = NO;
        }
        tail = TPCircularBufferTail(&_circularBuffer, &availableSize);
    } while(size > availableSize && !_closed && !_discontinuity);
    
    int32_t readableSize = MIN(size, availableSize);
    memcpy(buffer, tail, readableSize);
    TPCircularBufferConsume(&_circularBuffer, readableSize);
    
    if(_discontinuity && availableSize > readableSize) {
        *discontinuity = NO;
    } else {
        *discontinuity = _discontinuity;
        _discontinuity = NO;
        pthread_cond_signal(&_condition);
    }
    
    pthread_mutex_unlock(&_mutex);
    
    return readableSize;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_condition);
    TPCircularBufferCleanup(&_circularBuffer);
}

@end
