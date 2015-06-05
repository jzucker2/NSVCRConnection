//
//  FirstViewController.m
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import "FirstViewController.h"
#import "JSZNetworkRecorder.h"

@interface FirstViewController ()
@property (nonatomic) NSURLSession *session;
@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    id<JSZRecordingDescriptor> descriptor = [JSZNetworkRecorder recordingRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withRecordingResponse:^JSZNetworkRecording *(NSURLRequest *request, NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"request: %@", request);
        NSLog(@"data: %@", data);
        NSLog(@"response: %@", response);
        NSLog(@"error: %@", error);
        
        JSZNetworkRecording *recording = [JSZNetworkRecording recordingWithRequest:request response:response data:data];
        return recording;
    }];
    descriptor.name = @"test";
    
    [JSZNetworkRecorder onRecordingActivation:^(NSURLRequest *request, id<JSZRecordingDescriptor> recording) {
        NSLog(@"request: %@", request);
        NSLog(@"recording: %@", recording);
    }];
    
    
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://pubsub.pubnub.com/publish/demo/demo/0/hello_world/0/%22Hello%20World%22"]];
    
    NSURLSessionDataTask *basicGetTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"data: %@", data);
        NSLog(@"response: %@", response);
        NSLog(@"error: %@", error);
    }];
    [basicGetTask resume];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
