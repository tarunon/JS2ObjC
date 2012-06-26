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
NSMutableDictionary *jsFunctions;
JS2ObjC *standardJS2ObjC;
BOOL webViewSwizzed;

@interface JS2ObjC()<UIWebViewDelegate>
- (void)initializedWebView:(UIWebView *)webView;
- (void)swizzUIWebViewDelegateMethodes:(id)delegate;
@end

@implementation NSObject(JS2ObjC)

- (void)webViewDidFinishLoad_ConJS:(UIWebView *)webView
{
    [standardJS2ObjC webViewDidFinishLoad:webView];
    [self webViewDidFinishLoad_ConJS:webView];
}

- (BOOL)webView_ConJS:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([standardJS2ObjC webView:webView shouldStartLoadWithRequest:request navigationType:navigationType]) {
        return [self webView_ConJS:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    return NO;
}

@end

@implementation UIWebView(JS2ObjC)

- (id)init_ConJS
{
    self = [self init_ConJS];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (id)initWithCoder_ConJS:(NSCoder *)coder
{
    self = [self initWithCoder_ConJS:coder];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (id)initWithFrame_ConJS:(CGRect)frame
{
    self = [self initWithFrame_ConJS:frame];
    if (self) {
        [standardJS2ObjC initializedWebView:self];
    }
    return self;
}

- (void)setDelegate_ConJS:(id<UIWebViewDelegate>)delegate
{
    [standardJS2ObjC swizzUIWebViewDelegateMethodes:delegate];
    [self setDelegate_ConJS:delegate];
}

@end

@implementation JS2ObjC

- (id)init
{
    if ((self = [super init])) {
        swizzedDelegateClassName = [NSMutableSet setWithObject:[self class]];
        jsFunctions = [NSMutableDictionary dictionary];
        standardJS2ObjC = self;
        if (!webViewSwizzed) {
            webViewSwizzed = YES;
            swizz([UIWebView class], @selector(init), @selector(init_ConJS));
            swizz([UIWebView class], @selector(initWithCoder:), @selector(initWithCoder_ConJS:));
            swizz([UIWebView class], @selector(initWithFrame:), @selector(initWithFrame_ConJS:));
            swizz([UIWebView class], @selector(setDelegate:), @selector(setDelegate_ConJS:));
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
        swizz(klass, @selector(webViewDidFinishLoad:), @selector(webViewDidFinishLoad_ConJS:));
        swizz(klass, @selector(webView:shouldStartLoadWithRequest:navigationType:), @selector(webView_ConJS:shouldStartLoadWithRequest:navigationType:));
    }
}

- (void)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name
{
    NSArray *array = [NSArray arrayWithObjects:target, [NSString stringWithFormat:@"%s", sel_getName(sel)], nil];
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

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    for (NSString *key in jsFunctions.allKeys) {
        [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"function %@(){var u='JS2ObjC://%@';for(var i=0;i<arguments.length;i++){u=u+'\t'+encodeURIComponent(arguments[i]);}var t=document.createElement('A');t.setAttribute('href',u);var e=document.createEvent('MouseEvent');e.initMouseEvent('click');t.dispatchEvent(e);return JS2ObjC_Return;}", key, key]];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqualToString:@"JS2ObjC"]) {
        NSArray *operationCodes = [[request.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\t"];
        NSString *jsfunc = [[operationCodes objectAtIndex:0] substringFromIndex:10];
        id target = [[jsFunctions objectForKey:jsfunc] objectAtIndex:0];
        SEL sel = sel_getUid([[[jsFunctions objectForKey:jsfunc] objectAtIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]);
        id _return;
        if ([target respondsToSelector:sel]) {
            id _args;
            if (operationCodes.count > 1) {
                _args = [operationCodes subarrayWithRange:NSMakeRange(1, operationCodes.count - 1)];
            }
            if ([[NSString stringWithFormat:@"%s", [target methodSignatureForSelector:sel].methodReturnType] isEqualToString:@"@"]) {
                if (_args) {
                    _return = objc_msgSend(target, sel, _args);
                } else {
                    _return = objc_msgSend(target, sel);
                }
            } else {
                if (_args) {
                    objc_msgSend(target, sel, _args);
                } else {
                    objc_msgSend(target, sel);
                }
            }
        }
        if (_return) {
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JS2ObjC_Return='%@';", _return]];
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
