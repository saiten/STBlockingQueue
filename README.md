
# STBlockingQueue 0.1.0 [![Build Status](https://travis-ci.org/saiten/STBlockingQueue.png?branch=master)](https://travis-ci.org/saiten/STBlockingQueue)

Simplified implementation for producer consumer pattern

## Requirements

- iOS5 and later
- ARC

## Usage

```objectivec
    STBlockingQueue *blockingQueue = [STBlockingQueue blockingQueue];
    
    // producer
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int writtenSize;
        NSData *data1 = [@"hogehoge" dataUsingEncoding:NSASCIIStringEncoding];
        NSData *data2 = [@"poyopoyo" dataUsingEncoding:NSASCIIStringEncoding];

        sleep(1);

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
```

## License

MIT

