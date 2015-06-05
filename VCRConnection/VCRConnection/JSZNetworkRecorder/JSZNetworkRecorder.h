//
//  JSZNetworkRecorder.h
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import <Foundation/Foundation.h>

// typedef returnType (^TypeName)(parameterTypes);
typedef BOOL (^JSZNetworkRecorderTestBlock)(NSURLRequest *request);
typedef NSString *(^JSZNetworkRecorderRecordingBlock)(NSURLRequest *request, NSData *data, NSURLResponse *response, NSError *error);

@protocol JSZRecordingDescriptor

@property (nonatomic, strong) NSString *name;

@end

@interface JSZNetworkRecorder : NSObject

+ (id<JSZRecordingDescriptor>)recordingRequestsPassingTest:(JSZNetworkRecorderTestBlock)testBlock withRecordingResponse:(JSZNetworkRecorderRecordingBlock)recordingBlock;

+ (void)setEnabled:(BOOL)enabled;

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)
+ (void)setEnabled:(BOOL)enabled forSessionConfiguration:(NSURLSessionConfiguration *)sessionConfig;
#endif

+(NSArray*)allRecordings;

+(void)onRecordingActivation:( void(^)(NSURLRequest* request, id<JSZRecordingDescriptor> recording) )block;

@end
