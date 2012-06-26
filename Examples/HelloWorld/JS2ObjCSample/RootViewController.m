#import "RootViewController.h"

#import "JS2ObjC.h"

@implementation RootViewController

- (id)init
{
    self = [super init];
    if (self) {
        JS2ObjC* js2objc = [JS2ObjC standardJS2ObjC];
        [js2objc addTarget:self action:@selector(helloWorld) withJSFunctionName:@"helloWorld"];
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

@end
