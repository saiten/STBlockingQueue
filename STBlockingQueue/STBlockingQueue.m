//
//  STBlockingQueue.m
//  STBlockingQueue
//
//  Created by saiten on 2014/02/25.
//

#import "STBlockingQueue.h"
#import <TPCircularBuffer.h>
#import <pthread.h>

int32_t const STBlockingQueueDefaultCapacity = 4096;

@implementation STBlockingQueue {
    pthread_mutex_t _mutex;
    pthread_cond_t  _condition;
    TPCircularBuffer _circularBuffer;
}

#pragma mark - lifecycle

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
        _capacity = _circularBuffer.length;
    }
    return self;
}

+ (instancetype)blockingQueue
{
    return [self blockingQueueWithCapacity:STBlockingQueueDefaultCapacity];
}

+ (instancetype)blockingQueueWithCapacity:(int32_t)capacity
{
    return [[STBlockingQueue alloc] initWithCapacity:capacity];
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_condition);
    TPCircularBufferCleanup(&_circularBuffer);
}


- (void)cancel
{
    if(_cancelled) {
        return;
    }
    
    pthread_mutex_lock(&_mutex);
    _cancelled = YES;
    pthread_cond_signal(&_condition);
    pthread_mutex_unlock(&_mutex);
}

- (int32_t)readableSize
{
    int32_t readableSize;
    TPCircularBufferTail(&_circularBuffer, &readableSize);
    return readableSize;
}

- (int32_t)writableSize
{
    int32_t writableSize;
    TPCircularBufferHead(&_circularBuffer, &writableSize);
    return writableSize;
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
    int writtenSize = 0;
    while(writtenSize < size && !_cancelled) {
        int32_t writableSize = MIN(size, _capacity);
        int32_t ret = [self _pushWithBytes:(buffer + writtenSize)
                                      size:writableSize
                             discontinuity:((writtenSize + writableSize) == size) && discontinuity];
        writtenSize += ret;
    }
    
    return writtenSize;
}

- (int32_t)popWithBytes:(int8_t *)buffer size:(int32_t)size discontinuity:(BOOL *)discontinuity
{
    int readSize = 0;
    while(readSize < size && !_cancelled) {
        int32_t readableSize = MIN(size, _capacity);
        int32_t ret = [self _popWithBytes:(buffer + readSize)
                                     size:readableSize
                            discontinuity:discontinuity];
        readSize += ret;
        
        if(*discontinuity) {
            break;
        }
    }
    return readSize;
}


- (int32_t)_pushWithBytes:(const int8_t *)buffer size:(int32_t)size discontinuity:(BOOL)discontinuity
{
    NSAssert(size <= _capacity, @"buffer overflow");
    
    if(_cancelled) {
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
    } while(size > availableSize && !_cancelled);
    
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

- (int32_t)_popWithBytes:(int8_t *)buffer size:(int32_t)size discontinuity:(BOOL *)discontinuity
{
    NSAssert(size <= _capacity, @"buffer overflow");
    
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
    } while(size > availableSize && !_cancelled && !_discontinuity);
    
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

@end
