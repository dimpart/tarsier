//
//  SharedSession.m
//  Runner
//
//  Created by Albert Moky on 2023/5/19.
//

#import "DIMChannelManager.h"
#import "DIMSessionChannel.h"

#import "MarsHub.h"

#import "SharedSession.h"

@implementation SharedSession

// Override
- (STStreamHub *)createHubForRemoteAddress:(id<NIOSocketAddress>)remote
                             socketChannel:(NIOSocketChannel *)sock
                                  delegate:(id<STConnectionDelegate>)gate {
    return [[MarsHub alloc] initWithConnectionDelegate:gate];
}

@end

@implementation SharedSession (Process)

- (NSArray<NSData *> *)processData:(NSData *)pack
                        fromRemote:(id<NIOSocketAddress>)source {
    NSLog(@"pack length: %lu", pack.length);
    DIMChannelManager *man = [DIMChannelManager sharedInstance];
    DIMSessionChannel *channel = [man sessionChannel];
    [channel onReceivedData:pack from:source];
    return @[];
}

@end
