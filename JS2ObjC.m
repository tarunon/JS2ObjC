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

JS2ObjC *standardJS2ObjC;
UIWebView *currentWebView;
NSMutableDictionary *jsFunctions;
NSMutableSet *tempJSFunctions;
NSString *jsFunction;

@interface JS2ObjC()<UIWebViewDelegate>

- (void)updateJSFunction;
- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request;
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;

@end

@interface JSURLProtocol : NSURLProtocol

@end

@interface JSFunction() {
    NSString *_identifier;
    NSMutableDictionary *_jsFunctions;
    __weak UIWebView *_webView;
}

- (id)jsFunctionBlockWithName:(NSString *)name;

@end

@interface JSClass() {
@protected
    NSString *_class;
}
- (id)initWithClassName:(NSString *)name;
- (NSString *)className;
- (NSString *)childClassName:(NSString *)function;

@end

#pragma mark implementation static c

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

static NSString *implementCode (NSString *name)
{
    return [NSString stringWithFormat:@"%@=function(){js2objc.currents.push(this);var res= js2objc.perform('%@',Array.prototype.slice.apply(arguments));js2objc.currents.pop();delete js2objc.res;return res;};", name, name];
}

static NSString *cast2JS (id object)
{
    NSMutableString *_return = [NSMutableString string];
    if ([object isKindOfClass:[NSArray class]]) {
        [_return appendString:@"["];
        [object enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [_return appendFormat:@"%@,", cast2JS(obj)];
        }];
        if (_return.length > 1) {
            [_return replaceCharactersInRange:NSMakeRange(_return.length - 1, 1) withString:@"]"];
        } else {
            [_return appendString:@"]"];
        }
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        [_return appendString:@"{"];
        [object enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [_return appendFormat:@"%@,", cast2JS(obj)];
        }];
        if (_return.length > 1) {
            [_return replaceCharactersInRange:NSMakeRange(_return.length - 1, 1) withString:@"}"];
        } else {
            [_return appendString:@"}"];
        }
    } else if ([object isKindOfClass:[JSClass class]]) {
        [_return appendString:[object className]];
    } else if (object) {
        [_return appendFormat:@"\"%@\"", object];
    } else {
        [_return appendString:@"undefined"];
    }
    return _return;
}

static id castFunctionString (id object)
{
    if ([object isKindOfClass:[NSArray class]]) {
        [object enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [object replaceObjectAtIndex:idx withObject:castFunctionString(obj)];
        }];
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        [[object copy] enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id key, id obj, BOOL *stop) {
            [object setObject:castFunctionString(obj) forKey:key];
        }];
    } else if ([object isKindOfClass:[NSString class]]) {
        if ([object hasPrefix:@"js2objc.functions["] && [object hasSuffix:@"]"]) {
            object = [[JSFunction alloc] initWithFunctionName:object withWebView:currentWebView];
        }
    }
    return object;
}

static id cast2ObjC (NSString *jscode)
{
    return jscode ? castFunctionString([NSJSONSerialization JSONObjectWithData:[jscode dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:nil]) : nil;
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
    if ([[webView stringByEvaluatingJavaScriptFromString:@"(window.js2objc==undefined)"].lowercaseString isEqualToString:@"true"]) {
        [webView stringByEvaluatingJavaScriptFromString:jsFunction];
    }
    objc_msgSend(self, @selector(webViewDidFinishLoad_JS2ObjC:), webView);
}

#pragma mark implementation Objective-C

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

- (void)setJSProperty:(id)value forKey:(NSString *)key
{
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.currents[js2objc.currents.length-1].%@=%@", key, cast2JS(value)]];
}

- (id)jsPropertyForKey:(NSString *)key
{
    return cast2ObjC([self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.json(js2objc.currents[js2objc.currents.length-1].%@)", key]]);
}

- (id)jsSelfObject
{
    return cast2ObjC([self stringByEvaluatingJavaScriptFromString:@"js2objc.json(js2objc.currents[js2objc.currents.length-1])"]);
}

@end

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

@implementation JSClass

- (id)initWithClassName:(NSString *)name
{
    if ((self = [super init])) {
        _class = name;
    }
    return self;
}

- (NSString *)className
{
    return _class;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: 0x%X; function = \"%@\">", NSStringFromClass([self class]), (int)self, _class];
}

- (NSString *)childClassName:(NSString *)name
{
    return _class ? [NSString stringWithFormat:@"%@.prototype.%@", _class, name] : name;
}

- (JSClass *)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name
{
    __weak id _target = target;
    return [self addJSFunctionName:name usingBlock:^id (NSArray *arguments, UIWebView *webView) {
        if (strcmp([_target methodSignatureForSelector:sel].methodReturnType, "@")) {
            objc_msgSend(_target, sel, arguments, webView);
            return @"";
        } else {
            return objc_msgSend(_target, sel, arguments, webView);
        }
    }];
}

- (JSClass *)addJSFunctionName:(NSString *)name usingBlock:(id (^)(NSArray *, UIWebView *))block
{
    name = [self childClassName:name];
    [jsFunctions setObject:block  forKey:name];
    [[JS2ObjC standardJS2ObjC] updateJSFunction];
    return [[JSClass alloc] initWithClassName:name];
}

- (void)removeJSFunctionName:(NSString *)name
{
    name = [self childClassName:name];
    NSMutableArray *remover = [NSMutableArray arrayWithObject:name];
    name = [name stringByAppendingString:@".prototype."];
    [jsFunctions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key hasPrefix:name]) {
            [remover addObject:key];
        }
    }];
    [jsFunctions removeObjectsForKeys:remover];
    [[JS2ObjC standardJS2ObjC] updateJSFunction];
}

@end

@implementation JS2ObjC

+ (id)alloc
{
    return standardJS2ObjC ? standardJS2ObjC : [super alloc];
}

- (id)init
{
    if (!standardJS2ObjC && (self = [super init])) {
        jsFunctions = [NSMutableDictionary dictionary];
        tempJSFunctions = [NSMutableSet set];
        [NSURLProtocol registerClass:[JSURLProtocol class]];
        Class klass = [UIWebView class];
        swizz_js2objc(klass, @selector(init), @selector(init_JS2ObjC));
        swizz_js2objc(klass, @selector(initWithCoder:), @selector(initWithCoder_JS2ObjC:));
        swizz_js2objc(klass, @selector(initWithFrame:), @selector(initWithFrame_JS2ObjC:));
        swizz_js2objc(klass, @selector(setDelegate:), @selector(setDelegate_JS2ObjC:));
        [self updateJSFunction];
        standardJS2ObjC = self;
    }
    return self;
}

+ (JS2ObjC *)standardJS2ObjC
{
    return [[JS2ObjC alloc] init];
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

- (void)removeJSFunction:(JSClass *)function
{
    NSString *name = function.className;
    if (name) {
        NSMutableArray *remover = [NSMutableArray arrayWithObject:name];
        name = [name stringByAppendingString:@".prototype."];
        [jsFunctions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key hasPrefix:name]) {
                [remover addObject:key];
            }
        }];
        [jsFunctions removeObjectsForKeys:remover];
    } else {
        [jsFunctions removeAllObjects];
    }
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
        NSMutableString *_return = [NSMutableString stringWithString:@"var js2objc={currents:[],functions:[],usedidxs:[],perform:function(method,args){var u='JS2ObjC://'+method+'/'+js2objc.identifier+'?'+encodeURIComponent(js2objc.json(args));var t=document.createElement('A');t.href=u;var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);return js2objc.res;},json:function(arg){if(typeof(arg)=='function'){if(js2objc.usedidxs.length){var j=js2objc.usedidxs.pop();js2objc.functions[j]=arg;return '\"js2objc.functions['+j+']\"';}else{js2objc.functions.push(arg);return '\"js2objc.functions['+(js2objc.functions.length-1)+']\"';}}else if(arg instanceof Array){if(arg.length){var r='';arg.forEach(function(i){r+=js2objc.json(i)+',';});return '['+r.substr(0,r.length-1)+']';}else{return '[]';}}else if(arg instanceof Object){if(Object.keys(arg).length){var r='';Object.keys(arg).forEach(function(i){r+=js2objc.json(i)+':'+js2objc.json(arg[i])+',';});return '{'+r.substr(0,r.length-1)+'}';}}else if((''+arg).indexOf('object')==1){return '{}';}else{return '\"'+arg+'\"';}},rand:function(l){var s='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';var r='';for(var i=0;i<l;i++){r+=s[Math.floor(Math.random()*s.length)];}return r;}};js2objc.identifier=js2objc.rand(10);"];
        [[jsFunctions.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            [_return appendString:implementCode(key)];
        }];
        if (_anyScript.length) {
            [_return appendString:_anyScript];
        }
        return _return;
    }();
}

- (BOOL)webView:(UIWebView *)webView js2objcRequest:(NSURLRequest *)request
{
    if ([request.URL.scheme.lowercaseString isEqualToString:@"js2objc"]) {
        if ([[webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier"] isEqualToString:request.URL.lastPathComponent]) {
            NSString *jsfunc = request.URL.host;
            currentWebView = webView;
            __block id(^blk)(NSArray *arguments, UIWebView *webView) = [jsFunctions objectForKey:jsfunc];
            if (!blk) {
                [tempJSFunctions enumerateObjectsUsingBlock:^(JSFunction *func, BOOL *stop) {
                    if ((blk = [func jsFunctionBlockWithName:jsfunc])) {
                        *stop = YES;
                    }
                }];
            }
            if (blk) {
                [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"js2objc.res=%@;", cast2JS(blk(cast2ObjC([request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]), webView))]];
            }
            currentWebView = nil;
        }
        return YES;
    }
    return NO;
}

@end

@implementation JSFunction

- (id)initWithFunctionName:(NSString *)name withWebView:(UIWebView *)webView
{
    if ((self = [super initWithClassName:name])) {
        _webView = webView;
        _identifier = [_webView stringByEvaluatingJavaScriptFromString:@"js2objc.identifier;"];
    }
    return self;
}

- (void)dealloc
{
    if (_webView && [_class hasPrefix:@"js2objc.functions["] && [_class hasSuffix:@"]"]) {
        NSArray *functionComponents = [_class componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[]"]];
        [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(js2objc.identifier=='%@'){js2objc.usedidxs.push(%@);}", _identifier,  [functionComponents objectAtIndex:functionComponents.count - 2]]];
    }
}

- (id)jsFunctionBlockWithName:(NSString *)name
{
    if ([_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(js2objc.identifier=='%@')", _identifier]].boolValue) {
        return [_jsFunctions objectForKey:name];
    } else {
        [tempJSFunctions removeObject:self];
        _jsFunctions = nil;
        return nil;
    }
}

- (JSFunction *)addJSFunctionName:(NSString *)name usingBlock:(id (^)(NSArray *, UIWebView *))block
{
    name = [NSString stringWithFormat:@"%@.prototype.%@", _class, name];
    [tempJSFunctions addObject:self];
    if (!_jsFunctions) {
        _jsFunctions = [NSMutableDictionary dictionary];
    }
    [_jsFunctions setObject:block forKey:name];
    [_webView stringByEvaluatingJavaScriptFromString:implementCode(name)];
    return [[JSFunction alloc] initWithClassName:name];
}

- (NSString *)argString:(NSArray *)arguments;
{
    currentWebView = _webView;
    NSMutableString *res = [NSMutableString stringWithString:arguments ? cast2JS(arguments) : @"[]"];
    [res deleteCharactersInRange:NSMakeRange(res.length - 1, 1)];
    [res deleteCharactersInRange:NSMakeRange(0, 1)];
    currentWebView = nil;
    return res;
}

- (id)runWithArguments:(NSArray *)arguments
{
    if (!_webView) {
        NSLog(@"JSFunction warning!! : webview is nil.");
    }
    [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setTimeout(function(){if(js2objc.identifier=='%@'){js2objc.ret = js2objc.json(%@(%@));}else{js2objc.ret = 0;}},0);", _identifier, _class, [self argString:arguments]]];
    NSString *ret;
    do {
        ret = [_webView stringByEvaluatingJavaScriptFromString:@"js2objc.ret;"];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    } while (!ret);
    [_webView stringByEvaluatingJavaScriptFromString:@"delete js2objc.ret;"];
    return cast2ObjC(ret);
}

- (void)makeNewValue:(NSString *)value withArguments:(NSArray *)arguments
{
    if (!_webView) {
        NSLog(@"JSFunction warning!! : webview is nil.");
    }
    [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setTimeout(function(){var %@;if(js2objc.identifier=='%@'){%@=new %@(%@);}},0);", value, _identifier, value, _class, [self argString:arguments]]];
}

@end
