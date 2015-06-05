//
//  JSZNetworkRecording.h
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JSZNetworkRecording : NSObject

@property (nonatomic) NSData *data;
@property (nonatomic) NSURLResponse *response;
@property (nonatomic) NSURLRequest *request;

+ (instancetype)recordingWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data;

@end
