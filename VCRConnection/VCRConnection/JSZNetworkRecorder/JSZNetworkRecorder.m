//
//  JSZNetworkRecorder.m
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import "JSZNetworkRecorder.h"

@interface JSZNetworkRecorderProtocol : NSURLProtocol

@end

@interface JSZNetworkRecorder ()
+ (instancetype)sharedInstance;
@property (atomic, copy) NSMutableArray *recordingDescriptors;
@property (atomic, copy) void (^onRecordingActivationBlock)(NSURLRequest *, id<JSZRecordingDescriptor>);

@end

@interface JSZRecordingDescriptor : NSObject <JSZRecordingDescriptor>
@property (atomic, copy) JSZNetworkRecorderTestBlock testBlock;
@property (atomic, copy) JSZNetworkRecorderRecordingBlock recordingBlock;

@end

@implementation JSZRecordingDescriptor

@synthesize name = _name;

+ (instancetype)recordingDescriptorWithTestBlock:(JSZNetworkRecorderTestBlock)testBlock recordingBlock:(JSZNetworkRecorderRecordingBlock)recordingBlock {
    JSZRecordingDescriptor *recording = [JSZRecordingDescriptor new];
    recording.testBlock = testBlock;
    recording.recordingBlock = recordingBlock;
    return recording;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p : %@>", self.class, self, self.name];
}

@end

@implementation JSZNetworkRecorder

+ (instancetype)sharedInstance {
    static JSZNetworkRecorder *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)initialize {
    if (self == [JSZNetworkRecorder class]) {
        [self setEnabled:YES];
    }
}

- (id)init {
    self = [super init];
    if (self) {
        _recordingDescriptors = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [self.class setEnabled:NO];
}

+(id<JSZRecordingDescriptor>)recordingRequestsPassingTest:(JSZNetworkRecorderTestBlock)testBlock withRecordingResponse:(JSZNetworkRecorderRecordingBlock)recordingBlock {
    JSZRecordingDescriptor *recording = [JSZRecordingDescriptor recordingDescriptorWithTestBlock:testBlock recordingBlock:recordingBlock];
    [JSZNetworkRecorder.sharedInstance addRecording:recording];
    return recording;
}

#pragma mark > Disabling & Re-Enabling stubs

+ (void)setEnabled:(BOOL)enable {
    static BOOL currentEnabledState = NO;
    if (enable && !currentEnabledState) {
//        [NSURLProtocol registerClass:OHHTTPStubsProtocol.class];
        [NSURLProtocol registerClass:[JSZNetworkRecorderProtocol class]];
    }
    else if (!enable && currentEnabledState) {
//        [NSURLProtocol unregisterClass:OHHTTPStubsProtocol.class];
        [NSURLProtocol registerClass:[JSZNetworkRecorderProtocol class]];
    }
    currentEnabledState = enable;
}

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)
+ (void)setEnabled:(BOOL)enable forSessionConfiguration:(NSURLSessionConfiguration*)sessionConfig {
    // Runtime check to make sure the API is available on this version
    if (   [sessionConfig respondsToSelector:@selector(protocolClasses)]
        && [sessionConfig respondsToSelector:@selector(setProtocolClasses:)]) {
        NSMutableArray * urlProtocolClasses = [NSMutableArray arrayWithArray:sessionConfig.protocolClasses];
        Class protoCls = [JSZNetworkRecorderProtocol class];
        if (enable && ![urlProtocolClasses containsObject:protoCls]) {
            [urlProtocolClasses insertObject:protoCls atIndex:0];
        }
        else if (!enable && [urlProtocolClasses containsObject:protoCls]) {
            [urlProtocolClasses removeObject:protoCls];
        }
        sessionConfig.protocolClasses = urlProtocolClasses;
    }
    else {
        NSLog(@"[OHHTTPStubs] %@ is only available when running on iOS7+/OSX9+. "
              @"Use conditions like 'if ([NSURLSessionConfiguration class])' to only call "
              @"this method if the user is running iOS7+/OSX9+.", NSStringFromSelector(_cmd));
    }
}
#endif

#pragma mark > Debug Methods

+ (NSArray*)allRecordings {
    return [JSZNetworkRecorder.sharedInstance recordingDescriptors];
}

+ (void)onRecordingActivation:(void (^)(NSURLRequest *, id<JSZRecordingDescriptor>))block {
    [JSZNetworkRecorder.sharedInstance setOnRecordingActivationBlock:block];
}

#pragma mark - Private instance methods

- (void)addRecording:(JSZRecordingDescriptor*)recordingDescriptor {
    @synchronized(_recordingDescriptors) {
        [_recordingDescriptors addObject:recordingDescriptor];
    }
}

- (BOOL)removeRecording:(id<JSZRecordingDescriptor>)recordingDescriptor {
    BOOL handlerFound = NO;
    @synchronized(_recordingDescriptors) {
        handlerFound = [_recordingDescriptors containsObject:recordingDescriptor];
        [_recordingDescriptors removeObject:recordingDescriptor];
    }
    return handlerFound;
}

- (void)removeAllStubs {
    @synchronized(_recordingDescriptors) {
        [_recordingDescriptors removeAllObjects];
    }
}

- (JSZRecordingDescriptor *)firstRecordingPassingTestForRequest:(NSURLRequest*)request {
    JSZRecordingDescriptor *foundRecording = nil;
    @synchronized(_recordingDescriptors) {
        for(JSZRecordingDescriptor *recording in _recordingDescriptors.reverseObjectEnumerator) {
            if (recording.testBlock(request)) {
                foundRecording = recording;
                break;
            }
        }
    }
    return foundRecording;
}





@end
