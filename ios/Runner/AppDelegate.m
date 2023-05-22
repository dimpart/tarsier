
#import "SharedSession.h"

#import "GeneratedPluginRegistrant.h"

#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FlutterViewController* controller;
    controller = (FlutterViewController*)[self.window rootViewController];
    
    DIMChannelManager *manager = [DIMChannelManager sharedInstance];
    [manager initChannels:controller.binaryMessenger];
    
    DIMSessionController *sc = [DIMSessionController sharedInstance];
    sc.creator = ^DIMClientSession *(id<DIMSessionDBI> db, id<MKMStation>  server) {
        return [[SharedSession alloc] initWithDatabase:db station:server];
    };
    
    [DIMClientFacebook prepare];
    
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
