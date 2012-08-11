//
//  JS2ObjC.m
//  JS2ObjC
//
//  Created by tarunon on 12/06/11.
//  Copyright (c) 2012年 Nobuo Saito. All rights reserved.
//

#import "JS2ObjC.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>

void swizz_js2objc(Class klass, SEL sel1, SEL sel2);

NSMutableSet *swizzedDelegateClassName;
NSMutableDictionary *jsFunctions;
NSString *jsFunction;
JS2ObjC *standardJS2ObjC;
BOOL webViewSwizzed;

@interface JS2ObjC()<UIWebViewDelegate>
- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request;
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;
@end

@interface JCURLProtocol : NSURLProtocol<NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    NSMutableData *_data;
    NSURLConnection *_connection;
    BOOL ishtml;
}

@end

@implementation JCURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"] || [request.URL.scheme isEqualToString:@"file"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    [NSURLProtocol unregisterClass:[JCURLProtocol class]];
    if ([[NSThread currentThread].name hasPrefix:@"WebCore"]) {
        _data = [NSMutableData data];
        _connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
    } else {
        [NSURLConnection sendAsynchronousRequest:self.request queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            if (error) {
                [self.client URLProtocol:self didFailWithError:error];
            } else {
                [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:self.request.cachePolicy];
                [self.client URLProtocol:self didLoadData:data];
                [self.client URLProtocolDidFinishLoading:self];
            }
        }];
    }
}

- (void)stopLoading
{
    [_connection cancel];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:self.request.cachePolicy];
    if (!([response.MIMEType hasPrefix:@"text"] || [response.MIMEType hasPrefix:@"application"])) {
        _data = nil;
    } else if ([response.MIMEType isEqualToString:@"text/html"]) {
        ishtml = YES;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_data) {
        [_data appendData:data];
    } else {
        [self.client URLProtocol:self didLoadData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_data.length) {
        [self.client URLProtocol:self didLoadData:(NSData *)^{
            if (ishtml) {
                NSString *source = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
                if (!source.length) {
                    return (NSData *)_data;
                }
                NSInteger loc = [source rangeOfString:@"<HTML"].location;
                if (loc == NSNotFound) {
                    loc = [source rangeOfString:@"<html"].location;
                }
                if (loc != NSNotFound) {
                    loc += [[source substringFromIndex:loc] rangeOfString:@">"].location + 1;
                    source = [NSString stringWithFormat:@"%@<script type=\"text/javascript\">%@js2objc.lastId=%i;</script>%@", [source substringToIndex:loc], jsFunction, self.request.hash, [source substringFromIndex:loc]];
                }
                return [source dataUsingEncoding:NSUTF8StringEncoding];
            } else {
                return (NSData *)_data;
            }
        }()];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    _data = nil;
    if ([cachedResponse.response.MIMEType isEqualToString:@"text/html"]) {
        cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:cachedResponse.response data:(NSData *)^{
            NSString *source = [[NSString alloc] initWithData:cachedResponse.data encoding:NSUTF8StringEncoding];
            if (!source.length) {
                return cachedResponse.data;
            }
            NSInteger loc = [source rangeOfString:@"<HTML"].location;
            if (loc == NSNotFound) {
                loc = [source rangeOfString:@"<html"].location;
            }
            if (loc != NSNotFound) {
                loc += [[source substringFromIndex:loc] rangeOfString:@">"].location + 1;
                source = [NSString stringWithFormat:@"%@<script type=\"text/javascript\">%@js2objc.lastId=%i;</script>%@", [source substringToIndex:loc], jsFunction, self.request.hash, [source substringFromIndex:loc]];
            }
            return [source dataUsingEncoding:NSUTF8StringEncoding];
        }()];
    }
    [self.client URLProtocol:self cachedResponseIsValid:cachedResponse];
    return cachedResponse;
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response) {
        [NSURLProtocol registerClass:[JCURLProtocol class]];
        [self.client URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
        return nil;
    } else {
        return request;
    }
}

@end

static BOOL webViewShouldStartLoadWithRequestIMP(id self,SEL _cmd,id webView, id request, UIWebViewNavigationType navigationType)
{
    if (![standardJS2ObjC webView:webView js2objcRequest:request]) {
        if ((BOOL)objc_msgSend(self, sel_getUid("webView_js2objc:shouldStartLoadWithRequest:navigationType:"), webView, request, navigationType)) {
            [NSURLProtocol registerClass:[JCURLProtocol class]];
            return YES;
        }
    }
    return NO;
}

@implementation UIWebView(JS2ObjC)

- (id)init_JS2ObjC
{
    self = [self init_JS2ObjC];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (id)initWithCoder_JS2ObjC:(NSCoder *)coder
{
    self = [self initWithCoder_JS2ObjC:coder];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (id)initWithFrame_JS2ObjC:(CGRect)frame
{
    self = [self initWithFrame_JS2ObjC:frame];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (void)setDelegate_JS2ObjC:(id<UIWebViewDelegate>)delegate
{
    if (!delegate) {
        [self setDelegate_JS2ObjC:standardJS2ObjC];
    } else {
        [standardJS2ObjC swizzUIWebViewDelegateMethodes:delegate];
        [self setDelegate_JS2ObjC:delegate];
    }
}

@end

@implementation JS2ObjC

- (id)init
{
    if ((self = [super init])) {
        swizzedDelegateClassName = [NSMutableSet set];
        jsFunctions = [NSMutableDictionary dictionary];
        standardJS2ObjC = self;
        if (!webViewSwizzed) {
            webViewSwizzed = YES;
            Class klass = [UIWebView class];
            swizz_js2objc(klass, @selector(init), @selector(init_JS2ObjC));
            swizz_js2objc(klass, @selector(initWithCoder:), @selector(initWithCoder_JS2ObjC:));
            swizz_js2objc(klass, @selector(initWithFrame:), @selector(initWithFrame_JS2ObjC:));
            swizz_js2objc(klass, @selector(setDelegate:), @selector(setDelegate_JS2ObjC:));
        }
        [self updateJSFunction];
    }
    return self;
}

+ (JS2ObjC *)standardJS2ObjC
{
    if (!standardJS2ObjC) {
        standardJS2ObjC = [[JS2ObjC alloc] init];
    }
    return standardJS2ObjC;
}

- (void)initializedWebView:(UIWebView *)webView
{
    if (!webView.delegate) {
        webView.delegate = self;
    }
    [webView stringByEvaluatingJavaScriptFromString:jsFunction];
}

- (void)swizzUIWebViewDelegateMethodes:(id)delegate
{
    Class klass = [delegate class];
    if (![swizzedDelegateClassName containsObject:klass]) {
        [swizzedDelegateClassName addObject:klass];
        SEL sel = sel_registerName("webView_js2objc:shouldStartLoadWithRequest:navigationType:");
        class_addMethod([delegate class], sel, (IMP)webViewShouldStartLoadWithRequestIMP, "@@:@@");
        swizz_js2objc(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), sel);
    }
}

- (void)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name
{
    __weak id _target = target;
    [self addJSFunctionName:name usingBlock:^NSString *(NSArray *arguments, UIWebView *webView) {
        if (strcmp([_target methodSignatureForSelector:sel].methodReturnType, "@")) {
            objc_msgSend(_target, sel, arguments, webView);
            return @"";
        } else {
            return (NSString *)objc_msgSend(_target, sel, arguments, webView);
        }
    }];
}

- (void)addJSFunctionName:(NSString *)name usingBlock:(NSString *(^)(NSArray *, UIWebView *))block
{
    [jsFunctions setObject:block forKey:name];
    [self updateJSFunction];
}

- (void)removeJSFunctionName:(NSString *)name
{
    [jsFunctions removeObjectForKey:name];
    [self updateJSFunction];
}

- (void)removeAllJSFunctions
{
    [jsFunctions removeAllObjects];
    [self updateJSFunction];
}

- (void)updateJSFunction
{
    jsFunction = (NSString *)^{
        NSMutableString *_return = [NSMutableString stringWithString:@"var js2objc={returnValue:'',lastId:0,perform:[function(method,args){var u='JS2ObjC://'+method+'?';for(var i=0;i<args.length;i++){u=u+js2objc.perform[1](args[i])+'&';}u=u.substr(0,u.length-1);var t=document.createElement('A');t.setAttribute('href',u);var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);var _return=js2objc.returnValue;delete js2objc.returnValue;return _return;}, function(arg){if(typeof(arg)=='function'){this.push(arg);return encodeURIComponent('function(){return js2objc.perform['+(this.length-1)+'].apply(this,arguments);}');}else{return encodeURIComponent(arg);}}]};"];
        [[jsFunctions.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
            [_return appendFormat:@"%@=function(){js2objc.self=this;return js2objc.perform[0]('%@',Array.prototype.slice.apply(arguments));};", key, key];
        }];
        return _return;
    }();
}

- (void(^)(void))createFunction:(NSString *)jsFunction withWebView:(UIWebView *)webView
{
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func();},false);return id;})('js2objc'+(++js2objc.lastId),%@)", jsFunction]];
    __weak UIWebView *_webView = webView;
    return ^(){
        [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id){var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);})('%@');", identifier]];
    };
}

- (void(^)(NSString *))createFunctionHasArgument:(NSString *)jsFunction withWebView:(UIWebView *)webView
{
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func(js2objc.argValue);},false);return id;})('js2objc'+(++js2objc.lastId),%@)", jsFunction]];
    __weak UIWebView *_webView = webView;
    return ^(NSString *arg){
        [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id, arg){js2objc.argValue=arg;var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);delete js2objc.argValue;})('%@', '%@');", identifier, arg]];
    };
}

- (void (^)(NSArray *))createFunctionHasArguments:(NSString *)jsFunction numberOfArguments:(NSUInteger)number withWebView:(UIWebView *)webView
{
    NSMutableString *args = [NSMutableString stringWithString:@"js2objc.argValue0"];
    for (NSUInteger i = 1; i < number; i++) {
        [args appendFormat:@", js2objc.argValue%i", i];
    }
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func(%@);},false);return id;})('js2objc'+(++js2objc.lastId),%@)", args, jsFunction]];
    __weak UIWebView *_webView = webView;
    return ^(NSArray *args){
        NSMutableString *aargs = [NSMutableString string];
        for (NSUInteger i = 0; i < number; i++) {
            [aargs appendFormat:@", arg%i", i];
        }
        NSMutableString *fargs = [NSMutableString string];
        for (NSUInteger i = 0; i < number; i++) {
            [fargs appendFormat:@"js2objc.argValue%i=arg%i;", i, i];
        }
        NSMutableString *dargs = [NSMutableString string];
        for (NSUInteger i = 0; i < number; i++) {
            [dargs appendFormat:@"delete js2objc.argValue%i;", i];
        }
        [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id%@){%@var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);%@})('%@', '%@');", aargs, fargs, dargs, identifier, [args componentsJoinedByString:@"', '"]]];
    };
}

- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request
{
    if ([[request.URL.scheme uppercaseString] isEqualToString:@"JS2OBJC"]) {
        NSString *jsfunc = request.URL.host;
        NSMutableArray *_args = [NSMutableArray array];
        [[request.URL.query componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString *arg, NSUInteger idx, BOOL *stop) {
            [_args addObject:[arg stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }];
        id _return = ((NSString *(^)(NSArray *arguments, UIWebView *webView))[jsFunctions objectForKey:jsfunc])(_args, webView);
        [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.returnValue='%@';", _return ? _return : @""]];
        return YES;
    }
    return NO;
}

@end

static BOOL dummy_js2objc(){return YES;}

void swizz_js2objc(Class klass, SEL sel1, SEL sel2)
{
    Method method1 = class_getInstanceMethod(klass, sel1);
    Method method2 = class_getInstanceMethod(klass, sel2);
    if (method1 && method2) {
        if(class_addMethod(klass, sel1, method_getImplementation(method2), method_getTypeEncoding(method2))) {
            class_replaceMethod(klass, sel2, method_getImplementation(method1), method_getTypeEncoding(method1));
        } else {
            method_exchangeImplementations(method1, method2);
        }
    } else if (method1) {
        class_addMethod(klass, sel2, method_getImplementation(method1), method_getTypeEncoding(method1));
        class_replaceMethod(klass, sel1, (IMP)dummy_js2objc, "@");
    } else {
        class_addMethod(klass, sel1, method_getImplementation(method2), method_getTypeEncoding(method2));
        class_replaceMethod(klass, sel2, (IMP)dummy_js2objc, "@");
    }
}
