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

void swizz(Class klass, SEL sel1, SEL sel2);

NSMutableSet *swizzedDelegateClassName;
NSMutableDictionary *jsFunctions, *webViewLoadCounter;
JS2ObjC *standardJS2ObjC;
BOOL webViewSwizzed;

@interface JS2ObjC()<UIWebViewDelegate>
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;
@end

@implementation NSObject(JS2ObjC)

- (void)webViewDidFinishLoad_JS2ObjC:(UIWebView *)webView
{
    [standardJS2ObjC webViewDidFinishLoad:webView];
    [self webViewDidFinishLoad_JS2ObjC:webView];
}

- (BOOL)webView_JS2ObjC:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([standardJS2ObjC webView:webView shouldStartLoadWithRequest:request navigationType:navigationType]) {
        return [self webView_JS2ObjC:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    return NO;
}

- (BOOL)webView_JS2ObjC_OriginalMissing:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return [standardJS2ObjC webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

@end

@interface UIWebView(JS2ObjC)
@property (nonatomic) NSInteger pageLoadCount;

@end

@implementation UIWebView(JS2ObjC)
@dynamic pageLoadCount;

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
        [webViewLoadCounter removeObjectForKey:[NSNumber numberWithInteger:self.hash]];
        [self setDelegate_JS2ObjC:standardJS2ObjC];
    } else {
        [standardJS2ObjC swizzUIWebViewDelegateMethodes:delegate];
        [self setDelegate_JS2ObjC:delegate];
    }
}

- (NSInteger)pageLoadCount
{
    NSNumber *hash = [NSNumber numberWithInteger:self.hash];
    if ([webViewLoadCounter.allKeys containsObject:hash]) {
        return [[webViewLoadCounter objectForKey:hash] integerValue];
    } else {
        [webViewLoadCounter setObject:@0 forKey:hash];
        return 0;
    }
}

- (void)setPageLoadCount:(NSInteger)pageLoadCount
{
    NSNumber *hash = [NSNumber numberWithInteger:self.hash];
    [webViewLoadCounter setObject:[NSNumber numberWithInteger:pageLoadCount] forKey:hash];
}

@end

@implementation JS2ObjC

- (id)init
{
    if ((self = [super init])) {
        swizzedDelegateClassName = [NSMutableSet setWithObject:[self class]];
        jsFunctions = [NSMutableDictionary dictionary];
        webViewLoadCounter = [NSMutableDictionary dictionary];
        standardJS2ObjC = self;
        if (!webViewSwizzed) {
            webViewSwizzed = YES;
            Class klass = [UIWebView class];
            swizz(klass, @selector(init), @selector(init_JS2ObjC));
            swizz(klass, @selector(initWithCoder:), @selector(initWithCoder_JS2ObjC:));
            swizz(klass, @selector(initWithFrame:), @selector(initWithFrame_JS2ObjC:));
            swizz(klass, @selector(setDelegate:), @selector(setDelegate_JS2ObjC:));
        }
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
    webView.delegate = self;
    [self webViewDidFinishLoad:webView];
}

- (void)swizzUIWebViewDelegateMethodes:(id)delegate
{
    Class klass = [delegate class];
    if (![swizzedDelegateClassName containsObject:klass]) {
        [swizzedDelegateClassName addObject:klass];
        swizz(klass, @selector(webViewDidFinishLoad:), @selector(webViewDidFinishLoad_JS2ObjC:));
        if ([delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
            swizz(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), @selector(webView_JS2ObjC:shouldStartLoadWithRequest:navigationType:));
        } else {
            swizz(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), @selector(webView_JS2ObjC_OriginalMissing:shouldStartLoadWithRequest:navigationType:));
        }
    }
}

- (void)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name
{
    NSArray *array = @[ target, [NSString stringWithFormat:@"%s", sel_getName(sel)] ];
    [jsFunctions setObject:array forKey:name];
}

- (void)removeJSFunctionName:(NSString *)name
{
    [jsFunctions removeObjectForKey:name];
}

- (void)removeAllTargets
{
    [jsFunctions removeAllObjects];
}


- (void(^)(void))createFunction:(NSString *)jsFunction withWebView:(UIWebView *)webView
{
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func();},false);return id;})('js2objc'+(++js2objc.lastId),%@)", jsFunction]];
    NSInteger loadCount = webView.pageLoadCount;
    return ^(){
        if (webView.pageLoadCount == loadCount) {
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id){var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);})('%@');", identifier]];
        }
    };
}

- (void(^)(NSString *))createFunctionHasArgument:(NSString *)jsFunction withWebView:(UIWebView *)webView
{
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func(js2objc.argValue);},false);return id;})('js2objc'+(++js2objc.lastId),%@)", jsFunction]];
    NSInteger loadCount = webView.pageLoadCount;
    return ^(NSString *arg){
        if (webView.pageLoadCount == loadCount) {
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id, arg){js2objc.argValue=arg;var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);delete js2objc.argValue;})('%@', '%@');", identifier, arg]];
        }
    };
}

- (void (^)(NSArray *))createFunctionHasArguments:(NSString *)jsFunction numberOfArguments:(NSUInteger)number withWebView:(UIWebView *)webView
{
    NSMutableString *args = [NSMutableString stringWithString:@"js2objc.argValue0"];
    for (NSUInteger i = 1; i < number; i++) {
        [args appendFormat:@", js2objc.argValue%i", i];
    }
    NSString *identifier = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id,func){window.addEventListener(id,function(){func(%@);},false);return id;})('js2objc'+(++js2objc.lastId),%@)", args, jsFunction]];
    NSInteger loadCount = webView.pageLoadCount;
    return ^(NSArray *args){
        if (webView.pageLoadCount == loadCount) {
            NSMutableString *aargs = [NSMutableString stringWithString:@"arg0"];
            for (NSUInteger i = 1; i < number; i++) {
                [aargs appendFormat:@", arg%i", i];
            }
            NSMutableString *fargs = [NSMutableString stringWithString:@"js2objc.argValue0=arg0;"];
            for (NSUInteger i = 1; i < number; i++) {
                [fargs appendFormat:@"js2objc.argValue%i=arg%i;", i, i];
            }
            NSMutableString *dargs = [NSMutableString stringWithString:@"delete js2objc.argValue0;"];
            for (NSUInteger i = 1; i < number; i++) {
                [dargs appendFormat:@"delete js2objc.argValue%i;", i];
            }
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(id, %@){%@var e=document.createEvent('UIEvent');e.initUIEvent(id);window.dispatchEvent(e);%@})('%@', '%@');", aargs, fargs, identifier, [args componentsJoinedByString:@"', '"], dargs]];
        }
    };
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if ([[[webView stringByEvaluatingJavaScriptFromString:@"(window.js2objc == undefined)"] uppercaseString] isEqualToString:@"TRUE"]) {
        [webView stringByEvaluatingJavaScriptFromString:@"var js2objc={returnValue:'',lastId:0};"];
        webView.pageLoadCount++;
    }
    for (NSString *key in jsFunctions.allKeys) {
      if([[[webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(window.%@ == undefined)", key]] uppercaseString] isEqualToString:@"TRUE"]){
        [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@ = function(){var u='JS2ObjC://%@?';for(var i=0;i<arguments.length;i++){u=u+encodeURIComponent(arguments[i])+'&';}u=u.substr(0,u.length-1);var t=document.createElement('A');t.setAttribute('href',u);var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);var _return=js2objc.returnValue;delete js2objc.returnValue;return _return;}", key, key]];
      }
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[request.URL.scheme uppercaseString] isEqualToString:@"JS2OBJC"]) {
        NSString *jsfunc = request.URL.host;
        NSArray *operationCodes = [request.URL.query componentsSeparatedByString:@"&"];
        id target = [[jsFunctions objectForKey:jsfunc] objectAtIndex:0];
        SEL sel = sel_getUid([[[jsFunctions objectForKey:jsfunc] objectAtIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]);
        id _return;
        if ([target respondsToSelector:sel]) {
            NSMutableArray *_args = [NSMutableArray array];
            for (NSString *arg in operationCodes) {
                [_args addObject:[arg stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
            if ([[NSString stringWithFormat:@"%s", [target methodSignatureForSelector:sel].methodReturnType] isEqualToString:@"@"]) {
                if (_args) {
                    _return = objc_msgSend(target, sel, _args, webView);
                } else {
                    _return = objc_msgSend(target, sel, _args, webView);
                }
            } else {
                if (_args) {
                    objc_msgSend(target, sel, _args, webView);
                } else {
                    objc_msgSend(target, sel, _args, webView);
                }
            }
        }
        if (_return) {
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.returnValue='%@';", _return]];
        } else {
            [webView stringByEvaluatingJavaScriptFromString:@"js2objc.returnValue='';"];
        }
        return NO;
    }
    return YES;
}

@end

static id dummy(){return nil;}

void swizz(Class klass, SEL sel1, SEL sel2)
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
        class_replaceMethod(klass, sel1, (IMP)dummy, "@");
    } else {
        class_addMethod(klass, sel1, method_getImplementation(method2), method_getTypeEncoding(method2));
        class_replaceMethod(klass, sel2, (IMP)dummy, "@");
    }
}
