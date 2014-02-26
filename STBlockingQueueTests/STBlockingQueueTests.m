//
//  STBlockingQueueTests.m
//  STBlockingQueueTests
//
//  Created by saiten on 2014/02/25.
//

#import <XCTest/XCTest.h>
#import <XCTestAsync.h>
#import "STBlockingQueue.h"

@interface STBlockingQueueTests : XCTestCase

@end

@implementation STBlockingQueueTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCapacity
{
    {
        STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
        XCTAssert(STBlockingQueueDefaultCapacity <= blockingQueue.capacity, @"should be more than DefaultCapacity");
    }
    {
        STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueueWithCapacity:4];
        XCTAssert(3 < blockingQueue.capacity, @"should be more than 3");
    }
}

- (void)testReadableSize
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    XCTAssertEqual(0, blockingQueue.readableSize, @"should be equal 0");
    
    NSData *data = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
    [blockingQueue pushWithBytes:data.bytes size:data.length];
    
    XCTAssertEqual((int32_t)data.length, blockingQueue.readableSize, @"should be equal pushed bytes");
    
    int8_t buf[16];
    int readSize = [blockingQueue popWithBytes:buf size:data.length];
    
    XCTAssert(data.length == readSize, @"");
    XCTAssertEqual(0, blockingQueue.readableSize, @"should be equal 0");
}

- (void)testWritableSize
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    XCTAssertEqual(blockingQueue.capacity, blockingQueue.writableSize, @"should be equal capacity");
    
    NSData *data = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
    [blockingQueue pushWithBytes:data.bytes size:data.length];
    
    XCTAssertEqual((int32_t)(blockingQueue.capacity - data.length), blockingQueue.writableSize, @"");
    
    int8_t buf[16];
    int readSize = [blockingQueue popWithBytes:buf size:data.length];
    XCTAssert(data.length == readSize, @"");
    XCTAssertEqual(blockingQueue.capacity, blockingQueue.writableSize, @"should be equal 0");
}

- (void)testProducerConsumerAsync
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    
    // producer
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int writtenSize;
        NSData *data1 = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
        NSData *data2 = [@"poyopoyo" dataUsingEncoding:NSASCIIStringEncoding];
        
        writtenSize = [blockingQueue pushWithBytes:data1.bytes size:data1.length];
        XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
        
        sleep(1);
        
        writtenSize = [blockingQueue pushWithBytes:data2.bytes size:data2.length];
        XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
    });

    // consumer
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int8_t buf[16];
        int readSize = [blockingQueue popWithBytes:buf size:16];
        
        XCTAssertEqual(16, readSize, @"should read 16 bytes");

        NSString *str = [[NSString alloc] initWithBytes:buf length:16 encoding:NSASCIIStringEncoding];
        XCTAssertEqualObjects(@"hogehogepoyopoyo", str, @"");
        
        XCTAssertEqual(0, blockingQueue.readableSize, @"");
        XCAsyncSuccess();
    });
}

- (void)testPushOverCapacityAsync
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    int32_t bufferSize = blockingQueue.capacity * 2;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int8_t *dataBuf = (int8_t*)malloc(bufferSize);
        memset(dataBuf, 0, bufferSize);
        
        int writtenSize = [blockingQueue pushWithBytes:dataBuf size:bufferSize];
        
        XCTAssertEqual(bufferSize, writtenSize, @"written bufferSize bytes");
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int8_t buf[blockingQueue.capacity];
        int readSize;
        
        sleep(1);
        
        readSize = [blockingQueue popWithBytes:buf size:blockingQueue.capacity];
        XCTAssertEqual(blockingQueue.capacity, readSize, @"");

        sleep(1);
        
        readSize = [blockingQueue popWithBytes:buf size:blockingQueue.capacity];
        XCTAssertEqual(blockingQueue.capacity, readSize, @"");

        XCTAssertEqual(0, blockingQueue.readableSize, @"");
        XCAsyncSuccess();
    });
}

- (void)testPopOverCapacityAsync
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    int32_t bufferSize = blockingQueue.capacity * 2;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int8_t *dataBuf = (int8_t*)malloc(blockingQueue.capacity);
        memset(dataBuf, 0, blockingQueue.capacity);
        int writtenSize;

        writtenSize = [blockingQueue pushWithBytes:dataBuf size:blockingQueue.capacity];
        XCTAssertEqual(blockingQueue.capacity, writtenSize, @"");
        XCTAssertEqual(0, blockingQueue.writableSize, @"");
        
        sleep(1);
        
        writtenSize = [blockingQueue pushWithBytes:dataBuf size:blockingQueue.capacity];
        XCTAssertEqual(blockingQueue.capacity, writtenSize, @"");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int8_t buf[bufferSize];
        
        int readSize = [blockingQueue popWithBytes:buf size:bufferSize];
        XCTAssertEqual(bufferSize, readSize, @"");
        XCTAssertEqual(0, blockingQueue.readableSize, @"");
        XCAsyncSuccess();
    });
}

- (void)testDiscontinuityAsync
{
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int writtenSize;
        NSData *data1 = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
        NSData *data2 = [@"poyopoyo" dataUsingEncoding:NSASCIIStringEncoding];
        NSData *data3 = [@"parapara" dataUsingEncoding:NSASCIIStringEncoding];
        
        writtenSize = [blockingQueue pushWithBytes:data1.bytes size:data1.length discontinuity:NO];
        XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
        
        writtenSize = [blockingQueue pushWithBytes:data2.bytes size:data2.length discontinuity:YES];
        XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
        
        writtenSize = [blockingQueue pushWithBytes:data3.bytes size:data2.length discontinuity:NO];
        XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        
        int8_t buf[24];
        BOOL discontinuity;
        int readSize;
        
        readSize = [blockingQueue popWithBytes:buf size:24 discontinuity:&discontinuity];
        XCTAssertEqual(16, readSize, @"");
        XCTAssert(discontinuity, @"");
        
        NSString *str = [[NSString alloc] initWithBytes:buf length:readSize encoding:NSASCIIStringEncoding];
        XCTAssertEqualObjects(@"hogehogepoyopoyo", str, @"");
        
        readSize = [blockingQueue popWithBytes:buf size:8 discontinuity:&discontinuity];
        XCTAssertEqual(8, readSize, @"");
        XCTAssertFalse(discontinuity, @"");
        
        str = [[NSString alloc] initWithBytes:buf length:readSize encoding:NSASCIIStringEncoding];
        XCTAssertEqualObjects(@"parapara", str, @"");
        
        XCAsyncSuccess();
    });
}

- (void)testCancelAsync
{
    // cancel when wait for reading
    {
        STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
            
            int writtenSize = [blockingQueue pushWithBytes:data.bytes size:data.length];

            XCTAssertFalse(blockingQueue.cancelled, @"");
            XCTAssertEqual(8, writtenSize, @"should write 8 bytes");
        });

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            int8_t buf[16];
            int readSize = [blockingQueue popWithBytes:buf size:16];

            XCTAssert(blockingQueue.cancelled, @"");
            XCTAssertEqual(8, readSize, @"should read 8 bytes");
        });
    
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [blockingQueue cancel];
        });
    }
    // cancel when wait for writing
    {
        STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
        int32_t bufferSize = blockingQueue.capacity * 2;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            int8_t *dataBuf = (int8_t*)malloc(bufferSize);
            memset(dataBuf, 0, bufferSize);
            
            int writtenSize = [blockingQueue pushWithBytes:dataBuf size:bufferSize];
            
            XCTAssert(blockingQueue.cancelled, @"");
            XCTAssertEqual(blockingQueue.capacity + 8, writtenSize, @"written capacity bytes");
            
            XCAsyncSuccess();
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            int8_t buf[8];
            
            int readSize = [blockingQueue popWithBytes:buf size:8];
            XCTAssertFalse(blockingQueue.cancelled, @"");
            XCTAssertEqual(8, readSize, @"should read capacity bytes");
        });
        
        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [blockingQueue cancel];
            XCTAssert(blockingQueue.cancelled, @"");
        });
    }
}

@end
