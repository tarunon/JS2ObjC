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

NSMutableDictionary *jsFunctions;
NSString *jsFunction;
JS2ObjC *standardJS2ObjC;
BOOL webViewSwizzed;

@interface JS2ObjC()<UIWebViewDelegate>
- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request;
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;
@end

@interface JCURLProtocol : NSURLProtocol

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

static NSString *cast2JS (id object)
{
    return object ? [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object options:NSJSONReadingAllowFragments error:nil] encoding:NSUTF8StringEncoding] : @"";
}

static id cast2ObjC (NSString *jscode)
{
    return jscode ? [NSJSONSerialization JSONObjectWithData:[[jscode stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil] : nil;
}

static BOOL webViewShouldStartLoadWithRequestIMP(id self, SEL _cmd, id webView, id request, UIWebViewNavigationType navigationType)
{
    if (![standardJS2ObjC webView:webView js2objcRequest:request]) {
        if ((BOOL)objc_msgSend(self, @selector(webView_JS2ObjC:shouldStartLoadWithRequest:navigationType:), webView, request, navigationType)) {
            return YES;
        }
    }
    return NO;
}

static void webViewDidFinishLoadIMP(id self, SEL _cmd, id webView)
{
    if ([[[webView stringByEvaluatingJavaScriptFromString:@"(window.js2objc==undefined)"] uppercaseString] isEqualToString:@"TRUE"]) {
        [webView stringByEvaluatingJavaScriptFromString:jsFunction];
    }
    objc_msgSend(self, @selector(webViewDidFinishLoad_JS2ObjC:), webView);
}

@implementation JCURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [request.URL.lastPathComponent isEqualToString:@"js2objc.js"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    [self.client URLProtocol:self didReceiveResponse:[[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"text/javascript" expectedContentLength:-1 textEncodingName:@"utf-8"] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[jsFunction dataUsingEncoding:NSUTF8StringEncoding]];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

@end

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
        [NSURLProtocol registerClass:[JCURLProtocol class]];
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
    SEL sel = @selector(webView_JS2ObjC:shouldStartLoadWithRequest:navigationType:);
    if (![delegate respondsToSelector:sel]) {
        class_addMethod([delegate class], sel, (IMP)webViewShouldStartLoadWithRequestIMP, "@@:@@");
        swizz_js2objc(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), sel);
        sel = @selector(webViewDidFinishLoad_JS2ObjC:);
        class_addMethod([delegate class], sel, (IMP)webViewDidFinishLoadIMP, "@@:@@");
        swizz_js2objc(klass, @selector(webViewDidFinishLoad:), sel);
    }
}

- (void)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name
{
    __weak id _target = target;
    [self addJSFunctionName:name usingBlock:^id (NSArray *arguments, UIWebView *webView) {
        if (strcmp([_target methodSignatureForSelector:sel].methodReturnType, "@")) {
            objc_msgSend(_target, sel, arguments, webView);
            return @"";
        } else {
            return objc_msgSend(_target, sel, arguments, webView);
        }
    }];
}

- (void)addJSFunctionName:(NSString *)name usingBlock:(id (^)(NSArray *, UIWebView *))block
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
        NSMutableString *_return = [NSMutableString stringWithString:@"var js2objc={perform:[function(method,args){var u='JS2ObjC://'+method+'/'+js2objc.identifier+'?';for(var i=0;i<args.length;i++){u=u+encodeURIComponent(js2objc.perform[1](args[i]))+'&';}u=u.substr(0,u.length-1);var t=document.createElement('A');t.href=u;var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);delete js2objc.self;return self._return;}, function(arg){if(typeof(arg)=='function'){this.push(arg);return '\"js2objc.perform['+(this.length-1)+']\"';}else if(arg instanceof Array){if(arg.length){var r='';arg.forEach(function(i){r+=js2objc.perform[1](i)+',';});return '['+r.substr(0,r.length-1)+']';}else{return '[]';}}else if(arg instanceof Object){if(Object.keys(arg).length){var r='';Object.keys(arg).forEach(function(i){r+=js2objc.perform[1](i)+':'+js2objc.perform[1](arg[i])+',';});return '{'+r.substr(0,r.length-1)+'}';}else{return '{}';}}else{return '\"'+arg+'\"';}},function(){var s='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';var r='';for(var i=0;i<10;i++){r+=s[Math.floor(Math.random()*s.length)];}return r;}]};js2objc.identifier=js2objc.perform[2]();"];
        [[jsFunctions.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
            [_return appendFormat:@"%@=function(){js2objc.self=this;return js2objc.perform[0]('%@',Array.prototype.slice.apply(arguments));};", key, key];
        }];
        return _return;
    }();
}

- (void)setJSPropertyForKey:(NSString *)key value:(id)value withWebView:(UIWebView *)webView
{
    [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.self.%@=%@", key, cast2JS(value)]];
}

- (id (^)(NSArray *))createFunction:(NSString *)function withWebView:(id)webView
{
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier;"];
    __weak UIWebView *_webView = webView;
    return ^id (NSArray *args) {
        NSMutableString *arg = [NSMutableString string];
        if ([args isKindOfClass:[NSArray class]]) {
            if (args.count) {
                [args enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [arg appendFormat:@"%@,", cast2JS(obj)];
                }];
                [arg deleteCharactersInRange:NSMakeRange(arg.length - 1, 1)];
            }
        } else {
            arg = [NSMutableString stringWithString:cast2JS(args)];
        }
        return cast2ObjC([_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(js2objc.identifier=='%@'){encodeURIComponent(js2objc.perform[1](%@(%@)));}", identifier, function, arg]]);
    };
}

- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request
{
    if ([[request.URL.scheme uppercaseString] isEqualToString:@"JS2OBJC"]) {
        if ([[webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier"] isEqualToString:request.URL.lastPathComponent]) {
            NSString *jsfunc = request.URL.host;
            NSMutableArray *_args = [NSMutableArray array];
            [[request.URL.query componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString *arg, NSUInteger idx, BOOL *stop) {
                [_args addObject:cast2ObjC(arg)];
            }];
            id _return = ((NSString *(^)(NSArray *arguments, UIWebView *webView))[jsFunctions objectForKey:jsfunc])(_args, webView);
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.self._return=%@;", cast2JS(_return)]];
        }
        return YES;
    }
    return NO;
}

@end
