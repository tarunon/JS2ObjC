#import "AppDelegate.h"

#import "RootViewController.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [NSClassFromString(@"WebView") performSelector:@selector(_enableRemoteInspector)];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];  
    self.window.rootViewController = [[RootViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
