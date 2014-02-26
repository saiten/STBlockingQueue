//
//  STBlockingQueue.h
//  STBlockingQueue
//
//  Created by saiten on 2014/02/25.
//

#import <Foundation/Foundation.h>

extern int32_t const STBlockingQueueDefaultCapacity;

@interface STBlockingQueue : NSObject
@property (nonatomic, readonly) BOOL    closed;
@property (nonatomic, readonly) BOOL    discontinuity;
@property (nonatomic, readonly) int32_t capacity;
@property (nonatomic, readonly) int32_t readableSize;
@property (nonatomic, readonly) int32_t writableSize;

- (id)initWithCapacity:(int32_t)capacity;
+ (instancetype)blockingQueue;
+ (instancetype)blockingQueueWithCapacity:(int32_t)capacity;

- (int32_t)pushWithBytes:(const int8_t*)buffer size:(int32_t)size;
- (int32_t)pushWithBytes:(const int8_t*)buffer size:(int32_t)size discontinuity:(BOOL)discontinuity;

- (int32_t)popWithBytes:(int8_t*)buffer size:(int32_t)size;
- (int32_t)popWithBytes:(int8_t*)buffer size:(int32_t)size discontinuity:(BOOL*)discontinuity;

- (void)close;

@end
