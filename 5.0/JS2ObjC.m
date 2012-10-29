//
//  JS2ObjC.m
//  JS2ObjC
//
//  Created by tarunon on 12/06/11.
//  Copyright (c) 2012年 Nobuo Saito. All rights reserved.
//

#import "JS2ObjC.h"
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>

NSMutableDictionary *jsFunctions;
NSString *jsFunction;
JS2ObjC *standardJS2ObjC;
BOOL webViewSwizzed;

@interface JS2ObjC()<UIWebViewDelegate>
@property(nonatomic) UIWebView *currentWebView;
- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request;
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;
@end

@interface JSURLProtocol : NSURLProtocol

@end

static BOOL dummy_js2objc(){return YES;}

static void swizz_js2objc(Class klass, SEL sel1, SEL sel2)
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

static id cast2ObjCInternal (id object)
{
    if ([object isKindOfClass:[NSArray class]]) {
        [object enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [object replaceObjectAtIndex:idx withObject:cast2ObjCInternal(obj)];
        }];
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        [[object copy] enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id key, id obj, BOOL *stop) {
            [object setObject:cast2ObjCInternal(obj) forKey:key];
        }];
    } else {
        if ([object hasPrefix:@"js2objc.perform["] && [object hasSuffix:@"]"]) {
            object = [[JSFunction alloc] initWithFunctionString:object withWebView:[JS2ObjC standardJS2ObjC].currentWebView];
        }
    }
    return object;
}

static id cast2ObjC (NSString *jscode)
{
    return jscode ? cast2ObjCInternal([NSJSONSerialization JSONObjectWithData:[[jscode stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:nil]) : nil;
}

static BOOL webViewShouldStartLoadWithRequestIMP(id self, SEL _cmd, id webView, id request, UIWebViewNavigationType navigationType)
{
    if (![standardJS2ObjC webView:webView js2objcRequest:request]) {
        return (BOOL)objc_msgSend(self, @selector(webView_JS2ObjC:shouldStartLoadWithRequest:navigationType:), webView, request, navigationType);
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

@implementation JSURLProtocol

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
        [NSURLProtocol registerClass:[JSURLProtocol class]];
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
        Method method = class_getInstanceMethod([delegate class], @selector(webView:shouldStartLoadWithRequest:navigationType:));
        class_addMethod([delegate class], sel, (IMP)webViewShouldStartLoadWithRequestIMP, method_getTypeEncoding(method));
        swizz_js2objc(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), sel);
        sel = @selector(webViewDidFinishLoad_JS2ObjC:);
        method = class_getInstanceMethod([delegate class], @selector(webViewDidFinishLoad:));
        class_addMethod([delegate class], sel, (IMP)webViewDidFinishLoadIMP, method_getTypeEncoding(method));
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

- (void)setAnyScript:(NSString *)anyScript
{
    _anyScript = anyScript;
    [self updateJSFunction];
}

- (void)updateJSFunction
{
    jsFunction = (NSString *)^{
        NSMutableString *_return = [NSMutableString stringWithString:@"var js2objc={perform:[function(method,args){var u='JS2ObjC://'+method+'/'+js2objc.identifier+'?';for(var i=0;i<args.length;i++){u=u+encodeURIComponent(js2objc.perform[1](args[i]))+'&';}u=u.substr(0,u.length-1);var t=document.createElement('A');t.href=u;var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);delete js2objc.self;return self._return;}, function(arg){if(typeof(arg)=='function'){this.push(arg);return '\"js2objc.perform['+(this.length-1)+']\"';}else if(arg instanceof Array){if(arg.length){var r='';arg.forEach(function(i){r+=js2objc.perform[1](i)+',';});return '['+r.substr(0,r.length-1)+']';}else{return '[]';}}else if(arg instanceof Object){if(Object.keys(arg).length){var r='';Object.keys(arg).forEach(function(i){r+=js2objc.perform[1](i)+':'+js2objc.perform[1](arg[i])+',';});return '{'+r.substr(0,r.length-1)+'}';}else{return '{}';}}else{return '\"'+arg+'\"';}},function(){var s='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';var r='';for(var i=0;i<10;i++){r+=s[Math.floor(Math.random()*s.length)];}return r;}]};js2objc.identifier=js2objc.perform[2]();"];
        [[jsFunctions.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
            [_return appendFormat:@"%@=function(){js2objc.self=this;return js2objc.perform[0]('%@',Array.prototype.slice.apply(arguments));};", key, key];
        }];
        if (_anyScript.length) {
            [_return appendString:_anyScript];
        }
        return _return;
    }();
}

- (void)setJSPropertyForKey:(NSString *)key value:(id)value
{
    [_currentWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.self.%@=%@", key, cast2JS(value)]];
}

- (id (^)(NSArray *))createFunction:(NSString *)function withWebView:(id)webView
{
    JSFunction *func = [[JSFunction alloc] initWithFunctionString:function withWebView:webView];
    return ^id (NSArray *args) {
        return [func runWithArguments:args];
    };
}

- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request
{
    if ([request.URL.scheme.uppercaseString isEqualToString:@"JS2OBJC"]) {
        if ([[webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier"] isEqualToString:request.URL.lastPathComponent]) {
            NSString *jsfunc = request.URL.host;
            _currentWebView = webView;
            NSMutableArray *_args = [NSMutableArray array];
            [[request.URL.query componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString *arg, NSUInteger idx, BOOL *stop) {
                [_args addObject:cast2ObjC(arg)];
            }];
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.self._return=%@;", cast2JS(((NSString *(^)(NSArray *arguments, UIWebView *webView))[jsFunctions objectForKey:jsfunc])(_args, webView))]];
            _currentWebView = nil;
        }
        return YES;
    }
    return NO;
}

@end

@interface JSFunction(){
    NSString *_function, *_identifier;
    __weak UIWebView *_webView;
}
@end

@implementation JSFunction

- (NSUInteger)length
{
    return [_function length];
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return [_function characterAtIndex:index];
}

- (BOOL)isEqualToString:(NSString *)aString
{
    return NO;
}

- (id)initWithFunctionString:(NSString *)function withWebView:(UIWebView *)webView
{
    if ((self = [self init])) {
        _function = function;
        _webView = webView;
        _identifier = [_webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier;"];
    }
    return self;
}

- (id)runWithArguments:(NSArray *)arguments
{
    if (!_function || !_webView) {
        NSLog(@"JSFunction warning!! : function or webview be nil");
    }
    NSMutableString *arg = [NSMutableString string];
    if ([arguments isKindOfClass:[NSArray class]]) {
        if (arguments.count) {
            [arguments enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [arg appendFormat:@"%@,", cast2JS(obj)];
            }];
            [arg deleteCharactersInRange:NSMakeRange(arg.length - 1, 1)];
        }
    } else {
        arg = [NSMutableString stringWithString:cast2JS(arguments)];
    }
    [JS2ObjC standardJS2ObjC].currentWebView = _webView;
    id _return = cast2ObjC([_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(js2objc.identifier=='%@'){encodeURIComponent(js2objc.perform[1](%@(%@)));}", _identifier, _function, arg]]);
    [JS2ObjC standardJS2ObjC].currentWebView = nil;
    return _return;
}

@end