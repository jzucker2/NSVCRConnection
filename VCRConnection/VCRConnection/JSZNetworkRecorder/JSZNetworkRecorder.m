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

@interface JSZCustomClient: NSObject  <NSURLProtocolClient>
@property (nonatomic, weak) id<NSURLProtocolClient>originalClient;
@property (nonatomic, weak) NSURLSession *session;
+ (instancetype)customClientWithClient:(id<NSURLProtocolClient>)client;
@end

@implementation JSZCustomClient

- (instancetype)initWithClient:(id<NSURLProtocolClient>)client {
    self = [super init];
    if (self) {
        _originalClient = client;
    }
    return self;
}

+ (instancetype)customClientWithClient:(id<NSURLProtocolClient>)client {
    return [[self alloc] initWithClient:client];
}

- (void)URLProtocol:(NSURLProtocol *)protocol didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.originalClient URLProtocol:protocol didCancelAuthenticationChallenge:challenge];
}

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.originalClient URLProtocol:protocol didReceiveAuthenticationChallenge:challenge];
}

- (void)URLProtocol:(NSURLProtocol *)protocol wasRedirectedToRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    [self.originalClient URLProtocol:protocol wasRedirectedToRequest:request redirectResponse:redirectResponse];
}

- (void)URLProtocol:(NSURLProtocol *)protocol cachedResponseIsValid:(NSCachedURLResponse *)cachedResponse {
    [self.originalClient URLProtocol:protocol cachedResponseIsValid:cachedResponse];
}

- (void)URLProtocol:(NSURLProtocol *)protocol didFailWithError:(NSError *)error {
    [self.originalClient URLProtocol:protocol didFailWithError:error];
}

- (void)URLProtocol:(NSURLProtocol *)protocol didLoadData:(NSData *)data {
    [self.originalClient URLProtocol:protocol didLoadData:data];
}

- (void)URLProtocol:(NSURLProtocol *)protocol didReceiveResponse:(NSURLResponse *)response cacheStoragePolicy:(NSURLCacheStoragePolicy)policy {
    [self.originalClient URLProtocol:protocol didReceiveResponse:response cacheStoragePolicy:policy];
}

- (void)URLProtocolDidFinishLoading:(NSURLProtocol *)protocol {
    [self.originalClient URLProtocolDidFinishLoading:protocol];
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Protocol Class

@interface JSZNetworkRecorderProtocol() <NSURLConnectionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(assign) BOOL stopped;
@property(strong) JSZRecordingDescriptor *recording;
@property(strong) id<NSURLProtocolClient>originalClient;
@property(nonatomic) NSURLConnection *connection;
//@property(assign) CFRunLoopRef clientRunLoop;
//- (void)executeOnClientRunLoopAfterDelay:(NSTimeInterval)delayInSeconds block:(dispatch_block_t)block;
@end

@implementation JSZNetworkRecorderProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![JSZNetworkRecorder.sharedInstance firstRecordingPassingTestForRequest:request]) {
        return NO;
    }
    if ([NSURLProtocol propertyForKey:@"myKey" inRequest:request]) {
        return NO;
    }
    return YES;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)response client:(id<NSURLProtocolClient>)client
{
    // Make super sure that we never use a cached response.
    JSZNetworkRecorderProtocol *proto = [super initWithRequest:request cachedResponse:nil client:[JSZCustomClient customClientWithClient:client]];
    proto.recording = [JSZNetworkRecorder.sharedInstance firstRecordingPassingTestForRequest:request];
    return proto;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (NSCachedURLResponse *)cachedResponse
{
    return nil;
}

- (void)startLoading
{
//    self.clientRunLoop = CFRunLoopGetCurrent();
    NSURLRequest* request = self.request;
    id<NSURLProtocolClient> client = self.client;
    
    if (!self.recording)
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"It seems like the recording has been removed BEFORE the response had time to be sent.",
                                  NSLocalizedFailureReasonErrorKey,
                                  @"For more info, see https://github.com/AliSoftware/OHHTTPStubs/wiki/OHHTTPStubs-and-asynchronous-tests",
                                  NSLocalizedRecoverySuggestionErrorKey,
                                  request.URL, // Stop right here if request.URL is nil
                                  NSURLErrorFailingURLErrorKey,
                                  nil];
        NSError* error = [NSError errorWithDomain:@"OHHTTPStubs" code:500 userInfo:userInfo];
        [client URLProtocol:self didFailWithError:error];
        return;
    }
    
    if (JSZNetworkRecorder.sharedInstance.onRecordingActivationBlock)
    {
        JSZNetworkRecorder.sharedInstance.onRecordingActivationBlock(request, self.recording);
    }
    NSLog(@"self.task: %@", self.task);
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [[self class] setProperty:@(YES) forKey:@"myKey" inRequest:mutableRequest];
//    self.connection = [NSURLConnection connectionWithRequest:mutableRequest delegate:self];
    
    
    
    
//
//    if (responseStub.error == nil)
//    {
//        NSHTTPURLResponse* urlResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL
//                                                                     statusCode:responseStub.statusCode
//                                                                    HTTPVersion:@"HTTP/1.1"
//                                                                   headerFields:responseStub.httpHeaders];
//        
//        // Cookies handling
//        if (request.HTTPShouldHandleCookies && request.URL)
//        {
//            NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:responseStub.httpHeaders forURL:request.URL];
//            if (cookies)
//            {
//                [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookies:cookies forURL:request.URL mainDocumentURL:request.mainDocumentURL];
//            }
//        }
//        
//        
//        NSString* redirectLocation = (responseStub.httpHeaders)[@"Location"];
//        NSURL* redirectLocationURL;
//        if (redirectLocation)
//        {
//            redirectLocationURL = [NSURL URLWithString:redirectLocation];
//        }
//        else
//        {
//            redirectLocationURL = nil;
//        }
//        if (((responseStub.statusCode > 300) && (responseStub.statusCode < 400)) && redirectLocationURL)
//        {
//            NSURLRequest* redirectRequest = [NSURLRequest requestWithURL:redirectLocationURL];
//            [self executeOnClientRunLoopAfterDelay:responseStub.requestTime block:^{
//                if (!self.stopped)
//                {
//                    [client URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:urlResponse];
//                }
//            }];
//        }
//        else
//        {
//            [self executeOnClientRunLoopAfterDelay:responseStub.requestTime block:^{
//                if (!self.stopped)
//                {
//                    [client URLProtocol:self didReceiveResponse:urlResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed];
//                    if(responseStub.inputStream.streamStatus == NSStreamStatusNotOpen)
//                    {
//                        [responseStub.inputStream open];
//                    }
//                    [self streamDataForClient:client
//                             withStubResponse:responseStub
//                                   completion:^(NSError * error)
//                     {
//                         [responseStub.inputStream close];
//                         if (error==nil)
//                         {
//                             [client URLProtocolDidFinishLoading:self];
//                         }
//                         else
//                         {
//                             [client URLProtocol:self didFailWithError:responseStub.error];
//                         }
//                     }];
//                }
//            }];
//        }
//    } else {
//        // Send the canned error
//        [self executeOnClientRunLoopAfterDelay:responseStub.responseTime block:^{
//            if (!self.stopped)
//            {
//                [client URLProtocol:self didFailWithError:responseStub.error];
//            }
//        }];
//    }
}

- (void)stopLoading
{
    self.stopped = YES;
    [self.connection cancel];
    self.connection = nil;
    [super stopLoading];
//    NSURLRequest* request = self.request;
//    id<NSURLProtocolClient> client = self.client;
//    
//    if (!self.recording)
//    {
//        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  @"It seems like the recording has been removed BEFORE the response had time to be sent.",
//                                  NSLocalizedFailureReasonErrorKey,
//                                  @"For more info, see https://github.com/AliSoftware/OHHTTPStubs/wiki/OHHTTPStubs-and-asynchronous-tests",
//                                  NSLocalizedRecoverySuggestionErrorKey,
//                                  request.URL, // Stop right here if request.URL is nil
//                                  NSURLErrorFailingURLErrorKey,
//                                  nil];
//        NSError* error = [NSError errorWithDomain:@"OHHTTPStubs" code:500 userInfo:userInfo];
//        [client URLProtocol:self didFailWithError:error];
//        return;
//    }
//    
//    if (JSZNetworkRecorder.sharedInstance.onRecordingActivationBlock)
//    {
//        JSZNetworkRecorder.sharedInstance.onRecordingActivationBlock(request, self.recording);
//    }
}

//typedef struct {
//    NSTimeInterval slotTime;
//    double chunkSizePerSlot;
//    double cumulativeChunkSize;
//} OHHTTPStubsStreamTimingInfo;
//
//- (void)streamDataForClient:(id<NSURLProtocolClient>)client
//           withStubResponse:(OHHTTPStubsResponse*)stubResponse
//                 completion:(void(^)(NSError * error))completion
//{
//    if ((stubResponse.dataSize>0) && stubResponse.inputStream.hasBytesAvailable && (!self.stopped))
//    {
//        // Compute timing data once and for all for this stub
//        
//        OHHTTPStubsStreamTimingInfo timingInfo = {
//            .slotTime = kSlotTime, // Must be >0. We will send a chunk of data from the stream each 'slotTime' seconds
//            .cumulativeChunkSize = 0
//        };
//        
//        if(stubResponse.responseTime < 0)
//        {
//            // Bytes send each 'slotTime' seconds = Speed in KB/s * 1000 * slotTime in seconds
//            timingInfo.chunkSizePerSlot = (fabs(stubResponse.responseTime) * 1000) * timingInfo.slotTime;
//        }
//        else if (stubResponse.responseTime < kSlotTime) // includes case when responseTime == 0
//        {
//            // We want to send the whole data quicker than the slotTime, so send it all in one chunk.
//            timingInfo.chunkSizePerSlot = stubResponse.dataSize;
//            timingInfo.slotTime = stubResponse.responseTime;
//        }
//        else
//        {
//            // Bytes send each 'slotTime' seconds = (Whole size in bytes / response time) * slotTime = speed in bps * slotTime in seconds
//            timingInfo.chunkSizePerSlot = ((stubResponse.dataSize/stubResponse.responseTime) * timingInfo.slotTime);
//        }
//        
//        [self streamDataForClient:client
//                       fromStream:stubResponse.inputStream
//                       timingInfo:timingInfo
//                       completion:completion];
//    }
//    else
//    {
//        if (completion)
//        {
//            completion(nil);
//        }
//    }
//}
//
//- (void) streamDataForClient:(id<NSURLProtocolClient>)client
//                  fromStream:(NSInputStream*)inputStream
//                  timingInfo:(OHHTTPStubsStreamTimingInfo)timingInfo
//                  completion:(void(^)(NSError * error))completion
//{
//    NSParameterAssert(timingInfo.chunkSizePerSlot > 0);
//    
//    if (inputStream.hasBytesAvailable && (!self.stopped))
//    {
//        // This is needed in case we computed a non-integer chunkSizePerSlot, to avoid cumulative errors
//        double cumulativeChunkSizeAfterRead = timingInfo.cumulativeChunkSize + timingInfo.chunkSizePerSlot;
//        NSUInteger chunkSizeToRead = floor(cumulativeChunkSizeAfterRead) - floor(timingInfo.cumulativeChunkSize);
//        timingInfo.cumulativeChunkSize = cumulativeChunkSizeAfterRead;
//        
//        if (chunkSizeToRead == 0)
//        {
//            // Nothing to read at this pass, but probably later
//            [self executeOnClientRunLoopAfterDelay:timingInfo.slotTime block:^{
//                [self streamDataForClient:client fromStream:inputStream
//                               timingInfo:timingInfo completion:completion];
//            }];
//        } else {
//            uint8_t* buffer = (uint8_t*)malloc(sizeof(uint8_t)*chunkSizeToRead);
//            NSInteger bytesRead = [inputStream read:buffer maxLength:chunkSizeToRead];
//            if (bytesRead > 0)
//            {
//                NSData * data = [NSData dataWithBytes:buffer length:bytesRead];
//                // Wait for 'slotTime' seconds before sending the chunk.
//                // If bytesRead < chunkSizePerSlot (because we are near the EOF), adjust slotTime proportionally to the bytes remaining
//                [self executeOnClientRunLoopAfterDelay:((double)bytesRead / (double)chunkSizeToRead) * timingInfo.slotTime block:^{
//                    [client URLProtocol:self didLoadData:data];
//                    [self streamDataForClient:client fromStream:inputStream
//                                   timingInfo:timingInfo completion:completion];
//                }];
//            }
//            else
//            {
//                if (completion)
//                {
//                    // Note: We may also arrive here with no error if we were just at the end of the stream (EOF)
//                    // In that case, hasBytesAvailable did return YES (because at the limit of OEF) but nothing were read (because EOF)
//                    // But then in that case inputStream.streamError will be nil so that's cool, we won't return an error anyway
//                    completion(inputStream.streamError);
//                }
//            }
//            free(buffer);
//        }
//    }
//    else
//    {
//        if (completion)
//        {
//            completion(nil);
//        }
//    }
//}

/////////////////////////////////////////////
// Delayed execution utility methods
/////////////////////////////////////////////

//- (void)executeOnClientRunLoopAfterDelay:(NSTimeInterval)delayInSeconds block:(dispatch_block_t)block
//{
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        CFRunLoopPerformBlock(self.clientRunLoop, kCFRunLoopDefaultMode, block);
//        CFRunLoopWakeUp(self.clientRunLoop);
//    });
//}

//#pragma mark - 
//
//- (void)
//
#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
//    self.recording.headerFields = response.allHeaderFields;
//    self.recording.statusCode = response.statusCode;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
//    if (self.recording.data) {
//        NSMutableData *currentData = [NSMutableData dataWithData:self.recording.data];
//        [currentData appendData:data];
//        self.recording.data = currentData;
//    } else {
//        self.recording.data = data;
//    }
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
//    self.recording.error = error;
//    [[[VCRCassetteManager defaultManager] currentCassette] addRecording:self.recording];
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//    [[[VCRCassetteManager defaultManager] currentCassette] addRecording:self.recording];
    [self.client URLProtocolDidFinishLoading:self];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* The task has received a request specific authentication challenge.
 * If this delegate is not implemented, the session specific authentication challenge
 * will *NOT* be called and the behavior will be the same as using the default handling
 * disposition.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Sent if a task requires a new, unopened body stream.  This may be
 * necessary when authentication has failed for any request that
 * involves a body stream.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - NSURLSessionDataDelegate

/* The task has received a response and no further messages will be
 * received until the completion block is called. The disposition
 * allows you to cancel a request or to turn a data task into a
 * download task. This delegate message is optional - if you do not
 * implement it, you can get the response as a property of the task.
 *
 * This method will not be called for background upload tasks (which cannot be converted to download tasks).
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Notification that a data task has become a download task.  No
 * future messages will be sent to the data task.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

/* Invoke the completion routine with a valid NSCachedURLResponse to
 * allow the resulting data to be cached, or pass nil to prevent
 * caching. Note that there is no guarantee that caching will be
 * attempted for a given resource, and you should not rely on this
 * message to receive the resource data.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end




