//
//  MarsHub.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/9.
//

#import <MarsGate/MarsGate.h>

#import "DIMConstants.h"

#import "MarsHub.h"

@interface MarsSocket : NIOSocketChannel <SGStarDelegate>

@property(nonatomic, strong) MGMars *mars;

@property(nonatomic, strong) id<NIOSocketAddress> remoteAddress;

@property(nonatomic, strong) NSMutableArray<NSData *> *caches;  // received data

@property(nonatomic, readonly) NSUInteger available;

@end

@implementation MarsSocket

- (instancetype)init {
    if (self = [super init]) {
        self.mars = nil;
        self.remoteAddress = nil;
        self.caches = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSUInteger)available {
    @synchronized (self) {
        if ([self.caches count] > 0) {
            NSData *first = [self.caches firstObject];
            return [first length];
        }
    }
    return 0;
}

- (void)setMars:(MGMars *)mars {
    MGMars *old = _mars;
    if (old) {
        NSLog(@"%@ terminating: %@", self, old);
        [old terminate];
    }
    _mars = mars;
}

#pragma mark NIOAbstractInterruptibleChannel

- (BOOL)isOpen {
    return self.mars;
}

- (BOOL)isAlive {
    return [self isOpen] && ([self isConnected] || [self isBound]);
}

- (void)close {
    NSLog(@"closing channel");
    self.mars = nil;
}

#pragma mark NIOSelectableChannel

- (nullable NIOSelectableChannel *)configureBlocking:(BOOL)blocking {
    NSLog(@"blocking: %d", blocking);
    return self;
}

- (BOOL)isBlocking {
    //NSAssert(false, @"override me!");
    return NO;
}

#pragma mark NIOSocketChannel

- (BOOL)isBound {
    //NSAssert(false, @"override me!");
    // TODO: bound flag
    return [self.mars status] >= SGStarStatus_Init;
}

- (BOOL)isConnected {
    return [self.mars status] == SGStarStatus_Connected;
}

- (nullable id<NIONetworkChannel>)bindLocalAddress:(id<NIOSocketAddress>)local
                                            throws:(NIOException **)error {
    NSLog(@"bind local: %@", local);
    return self;
}

- (nullable id<NIONetworkChannel>)connectRemoteAddress:(id<NIOSocketAddress>)remote
                                                throws:(NIOException **)error {
    NSLog(@"%@, create Mars to connect remote: %@", self, remote);
    MGMars *mars = [[MGMars alloc] initWithMessageHandler:self];
    [mars launchWithOptions:[self launchOptions:remote]];
    self.mars = mars;
    self.remoteAddress = remote;
    return self;
}

- (nullable id<NIOByteChannel>)disconnect {
    NSLog(@"disconnecting channel");
    self.mars = nil;
    return self;
}

- (NSDictionary *)launchOptions:(id<NIOSocketAddress>)remoteAddress {
    return @{
        @"LongLinkAddress": @"dim.chat",
        @"LongLinkPort": @(remoteAddress.port),
        @"ShortLinkPort": @(remoteAddress.port),
        @"NewDNS": @{
            @"dim.chat": @[
                remoteAddress.host,
            ],
        }
    };
}

- (nullable id<NIOSocketAddress>)receiveWithBuffer:(NIOByteBuffer *)dst
                                            throws:(NIOException **)error {
    NSData *pack = nil;
    @synchronized (self) {
        if ([_caches count] > 0) {
            pack = [_caches firstObject];
            [_caches removeObjectAtIndex:0];
        }
    }
    if (pack) {
        NSLog(@"---- receiveWithBuffer: %lu byte(s), remote: %@", [pack length], _remoteAddress);
        [dst putData:pack];
        return _remoteAddress;
    }
    return nil;
}

- (NSInteger)sendWithBuffer:(NIOByteBuffer *)src
              remoteAddress:(id<NIOSocketAddress>)remote
                     throws:(NIOException **)error {
    // flip to read data
    [src flip];
    NSInteger len = src.remaining;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:len];
    [src getData:data];
    // send data
    NSLog(@"---- sendWithBuffer: %lu byte(s) => %@", [data length], remote);
    [self.mars send:data handler:self];
    return data.length;;
}


// Override
- (NSInteger)readWithBuffer:(NIOByteBuffer *)dst throws:(NIOException **)error {
    NSData *pack = nil;
    @synchronized (self) {
        if ([_caches count] > 0) {
            pack = [_caches firstObject];
            [_caches removeObjectAtIndex:0];
        }
    }
    if (pack) {
        NSLog(@"---- readWithBuffer: %lu byte(s)", [pack length]);
        [dst putData:pack];
    }
    return [pack length];
}

// Override
- (NSInteger)writeWithBuffer:(NIOByteBuffer *)src throws:(NIOException **)error {
    // flip to read data
    [src flip];
    NSInteger len = src.remaining;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:len];
    [src getData:data];
    // send data
    NSLog(@"---- writeWithBuffer: %lu byte(s)", [data length]);
    [self.mars send:data handler:self];
    return data.length;;
}

// Override
- (id<NIOSocketAddress>)remoteAddress {
    return _remoteAddress;
}

// Override
- (id<NIOSocketAddress>)localAddress {
    NSLog(@"local address");
    return nil;
}

#pragma mark SGStarDelegate

- (NSInteger)star:(id<SGStar>)star onReceive:(NSData *)responseData {
    NSUInteger len = [responseData length];
    if (len <= 4) {
        // TODO: respond 'PONG' when received 'PING'
        NSLog(@"star: onReceive: [%@]", MKMUTF8Decode(responseData));
        return 0;
    } else {
        NSLog(@"star: onReceive: %lu byte(s)", len);
    }
    @synchronized (self) {
        [_caches addObject:responseData];
    }
    return 0;
}

- (void)star:(id<SGStar>)star onConnectionStatusChanged:(SGStarStatus)status {
    NSLog(@"star: onConnectionStatusChanged: %d", status);
    if (status == SGStarStatus_Error) {
        NSLog(@"connection error, closing...");
        [self disconnect];
    }
}

- (void)star:(id<SGStar>)star onFinishSend:(NSData *)requestData
   withError:(NSError *)error {
    NSUInteger len = [requestData length];
    if (len == 4) {
        NSLog(@"star: onFinishSend: [%@], error: %@", MKMUTF8Decode(requestData), error);
    } else {
        NSLog(@"star: onFinishSend: %lu byte(s), error: %@", len, error);
    }
}

@end

static inline MarsSocket *create_socket(id<NIOSocketAddress> remote,
                                        id<NIOSocketAddress> local) {
    MarsSocket *sock = [[MarsSocket alloc] init];
    if (local) {
        [sock bindLocalAddress:local throws:nil];
    }
    [sock connectRemoteAddress:remote throws:nil];
    return sock;
}

#pragma mark Channel

@interface MarsChannel : STStreamChannel

@end

@implementation MarsChannel

// Override
- (BOOL)isOpen {
    return [self.socketChannel isOpen];
}

@end

#pragma mark -

@interface MarsHub ()

@property(atomic, weak) MarsChannel *channel;

@end

@implementation MarsHub

- (instancetype)initWithConnectionDelegate:(id<STConnectionDelegate>)delegate {
    if (self = [super initWithConnectionDelegate:delegate]) {
        self.channel = nil;
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(onSessionStateChanged:)
                   name:kNotificationName_ServerStateChanged object:nil];
    }
    return self;
}

- (void)onSessionStateChanged:(NSNotification *)notification {
    NSString *name = [notification name];
    NSDictionary *info = notification.userInfo;
    if ([name isEqualToString:kNotificationName_ServerStateChanged]) {
        NSNumber *state = [info objectForKey:@"stateIndex"];
        NSUInteger index = [state unsignedIntegerValue];
        if (index == DIMSessionStateOrderError) {
            NSLog(@">>> Network error!");
            MarsChannel *sock = self.channel;
            if (sock) {
                NSLog(@"mars isOpen: %d", [sock isOpen]);
                id<NIOSocketAddress> remote = [sock remoteAddress];
                id<NIOSocketAddress> local = [sock localAddress];
                id<STConnection> conn = [self connectionWithRemoteAddress:remote
                                                             localAddress:local];
                if ([conn isOpen]) {
                    NSLog(@"closing connection: %@", conn);
                    [conn close];
                }
                if ([sock isOpen]) {
                    NSLog(@"closing mars: %@", sock);
                    [sock close];
                }
                self.channel = nil;
            }
        }
    }
}

// Override
- (NSUInteger)availableInChannel:(id<STChannel>)channel {
    NIOSocketChannel *sock = [(STStreamChannel *)channel socketChannel];
    return [(MarsSocket *)sock available];
}

// Override
- (id<STChannel>)createChannelWithSocketChannel:(NIOSocketChannel *)sock
                                  remoteAddress:(id<NIOSocketAddress>)remote
                                   localAddress:(nullable id<NIOSocketAddress>)local {
    return [[MarsChannel alloc] initWithSocket:sock
                                 remoteAddress:remote
                                  localAddress:local];
}

// Override
- (id<STChannel>)createSocketChannelForRemoteAddress:(id<NIOSocketAddress>)remote
                                        localAddress:(id<NIOSocketAddress>)local {
    MarsChannel *channel;
    @synchronized (self) {
        channel = self.channel;
        if ([channel isOpen]) {
            if ([channel.remoteAddress isEqual:remote]) {
                NSLog(@"reuse channel: %@ => %@", remote, channel);
                return channel;
            }
            // TODO: only one channel?
            NSLog(@"close channel: %@", channel);
            [channel close];
        }
        NSLog(@"create socket: %@, %@", remote, local);
        MarsSocket *sock = create_socket(remote, local);
        if (!local) {
            local = [sock localAddress];
        }
        NSLog(@"create channel: %@, %@", remote, local);
        channel = [self createChannelWithSocketChannel:sock
                                         remoteAddress:remote
                                          localAddress:local];
        self.channel = channel;
    }
    return channel;
}

@end
