//
//  JSZNetworkRecording.m
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import "JSZNetworkRecording.h"

@implementation JSZNetworkRecording

- (instancetype)initWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data {
    self = [super init];
    if (self) {
        _request = request;
        _response = response;
        _data = data;
    }
    return self;
}

+ (instancetype)recordingWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data {
    return [[self alloc] initWithRequest:request response:response data:data];
}

@end
