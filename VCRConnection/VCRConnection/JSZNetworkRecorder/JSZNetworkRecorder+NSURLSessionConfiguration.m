//
//  JSZNetworkRecorder+NSURLSessionConfiguration.m
//  VCRConnection
//
//  Created by Jordan Zucker on 6/5/15.
//  Copyright (c) 2015 Jordan Zucker. All rights reserved.
//

#import <Foundation/Foundation.h>

#if defined(__IPHONE_7_0) || defined(__MAC_10_9)

#import <objc/runtime.h>
#import "JSZNetworkRecorder.h"


//////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  This helper is used to swizzle NSURLSessionConfiguration constructor methods
 *  defaultSessionConfiguration and ephemeralSessionConfiguration to insert the private
 *  OHHTTPStubsProtocol into their protocolClasses array so that OHHTTPStubs is automagically
 *  supported when you create a new NSURLSession based on one of there configurations.
 */

typedef NSURLSessionConfiguration*(*SessionConfigConstructor)(id,SEL);
static SessionConfigConstructor orig_defaultSessionConfiguration;
static SessionConfigConstructor orig_ephemeralSessionConfiguration;

static SessionConfigConstructor JSZNetworkRecorderSwizzle(SEL selector, SessionConfigConstructor newImpl)
{
    Class cls = NSURLSessionConfiguration.class;
    Class metaClass = object_getClass(cls);
    
    Method origMethod = class_getClassMethod(cls, selector);
    SessionConfigConstructor origImpl = (SessionConfigConstructor)method_getImplementation(origMethod);
    if (!class_addMethod(metaClass, selector, (IMP)newImpl, method_getTypeEncoding(origMethod)))
    {
        method_setImplementation(origMethod, (IMP)newImpl);
    }
    return origImpl;
}

static NSURLSessionConfiguration* JSZNetworkRecorder_defaultSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_defaultSessionConfiguration(self,_cmd); // call original method
    [JSZNetworkRecorder setEnabled:YES forSessionConfiguration:config]; //OHHTTPStubsAddProtocolClassToNSURLSessionConfiguration(config);
    return config;
}

static NSURLSessionConfiguration* JSZNetworkRecorder_ephemeralSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_ephemeralSessionConfiguration(self,_cmd); // call original method
    [JSZNetworkRecorder setEnabled:YES forSessionConfiguration:config]; //OHHTTPStubsAddProtocolClassToNSURLSessionConfiguration(config);
    return config;
}

@interface NSURLSessionConfiguration(OHHTTPStubsSupport) @end
@implementation NSURLSessionConfiguration(OHHTTPStubsSupport)
+(void)load
{
    orig_defaultSessionConfiguration = JSZNetworkRecorderSwizzle(@selector(defaultSessionConfiguration),
                                                          JSZNetworkRecorder_defaultSessionConfiguration);
    orig_ephemeralSessionConfiguration = JSZNetworkRecorderSwizzle(@selector(ephemeralSessionConfiguration),
                                                            JSZNetworkRecorder_ephemeralSessionConfiguration);
}
@end

#endif