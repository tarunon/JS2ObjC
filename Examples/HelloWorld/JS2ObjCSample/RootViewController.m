#import "RootViewController.h"

#import "JS2ObjC.h"

@implementation RootViewController

- (id)init
{
    self = [super init];
    if (self) {
        JS2ObjC* js2objc = [JS2ObjC standardJS2ObjC];
        [js2objc addTarget:self action:@selector(helloWorld) withJSFunctionName:@"helloWorld"];
        [js2objc addTarget:self action:@selector(searchHello:webView:) withJSFunctionName:@"sayHello"];
        [js2objc addTarget:self action:@selector(arrayDictSample:) withJSFunctionName:@"arrayDictSample"];
        [js2objc addTarget:self action:@selector(functionSample:) withJSFunctionName:@"functionSample"];
    }
    return self;
}

- (void)loadView
{
    UIWebView* webView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    NSURL* url = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"server/index.html"];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    webView.delegate = self;
    self.view = webView;
}

- (void)helloWorld
{
    NSLog(@"Hello World");
}

- (id)searchHello:(NSArray *)arguments webView:(UIWebView *)webView
{
    if (arguments.count) {
        if ([arguments.lastObject rangeOfString:@"Hello"].location != NSNotFound) {
            return @"Hello :)";
        }
    }
    return @"Say Hello :(";
}

- (void)arrayDictSample:(NSArray *)arguments
{
    NSArray *ary = [arguments objectAtIndex:0];
    NSDictionary *dict = [arguments objectAtIndex:1];
    NSLog(@"%@", ary);
    NSLog(@"%@", dict);
}

- (void)functionSample:(NSArray *)arguments
{
    JSFunction *function = arguments.lastObject;
    [function runWithArguments:@[@"You can use Javascript function from Objective-C"]];
}

@end
