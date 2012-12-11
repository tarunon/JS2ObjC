//
//  JS2ObjC.h
//
//  Created by tarunon on 12/06/11.
//
//  Copyright (c) 2012 Nobuo Saito. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documenåtation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

//  I'm sure the behavior in iOS5.x and Xcode 4.4 later.
//  Initialize an instance using 'standardJS2ObjC',
//  and connect JavaScript's function and Objective-C's function.
//  You must do before create an instance of UIWebView.
//  The Objective-C's functions return value must be NSString.
//  The Objective-C's functions argument are one NSArray including NSString(s)
//  that JavaScript's functions argument(s), and webview that called JavaScript's function.
//  You can create blocks object from JavaScript's function string.
//  If you use JS2ObjC's functions in HTML,
//  you should write "<script type="text/javascript" src="js2objc.js"></script>".

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface JSClass : NSObject

- (JSClass *)addTarget:(id)target action:(SEL)sel withJSFunctionName:(NSString *)name;
- (JSClass *)addJSFunctionName:(NSString *)name usingBlock:(id(^)(NSArray *arguments, UIWebView *webView))block;
- (void)removeJSFunctionName:(NSString *)name;

@end

@interface JS2ObjC : JSClass

@property (nonatomic) NSString *anyScript;

+ (JS2ObjC *)standardJS2ObjC;
- (void)removeJSFunction:(JSClass *)function;

@end

@interface UIWebView(JS2ObjC)

- (void)setJSProperty:(id)value forKey:(NSString *)key;
- (id)jsPropertyForKey:(NSString *)key;
- (id)jsSelfObject;
// There are able to used in JSClass's target action or block method(s).

@end

@interface JSFunction : JSClass

- (id)initWithFunctionName:(NSString *)name withWebView:(UIWebView *)webView;
- (id)runWithArguments:(NSArray *)arguments;
- (void)makeNewValue:(NSString *)value withArguments:(NSArray *)arguments;
// Run the function with arguments.

@end
