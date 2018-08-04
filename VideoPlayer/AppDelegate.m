//
//  AppDelegate.m
//  VideoPlayer
//
//  Created by Kelian on 04/08/2018.
//  Copyright © 2018 OSXHackers. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "AppDelegate.h"

#define TIME_WIDTH  350

#define TMPDIR      @"/tmp/"
#define PKEY        @"-path="
#define UKEY        @"-url="

@implementation AppDelegate

struct kvo {
    AVPlayer *player;
    CMTime duration;
    NSTextField *durText;
    NSMutableArray *holders;
};

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    struct kvo *ctx = (struct kvo*)context;
    if (object != ctx->player || ![keyPath isEqualToString:@"status"] || ctx->player.status != AVPlayerItemStatusReadyToPlay)
        return;
    [ctx->player play];
    [[[NSThread alloc] initWithBlock:^(void)
      {
          for (Float64 duration = CMTimeGetSeconds(ctx->duration); duration >= 0; duration--)
          {
              dispatch_async(dispatch_get_main_queue(), ^(void)
                             {
                                 [ctx->durText setStringValue:[NSString stringWithFormat:@"Temps restant: %lds", (long)duration]];
                             });
              sleep(1);
          }
          dispatch_async(dispatch_get_main_queue(), ^(void)
                         {
                             for (int i = 0; i < ctx->holders.count; i++)
                                 [ctx->holders[i] close];
                             free(ctx);
                         });
          [[NSApplication sharedApplication] terminate:nil];
          [NSThread exit]; // Will never run
      }] start];
}

- (void)playVideoWithURL:(NSURL*)url
{
    // Declarations
    NSArray *screens = [NSScreen screens];
    struct kvo *ctx = (struct kvo*)malloc(sizeof(struct kvo));

    // Setting context
    ctx->holders = [NSMutableArray new];
    ctx->durText = [[NSTextField alloc] initWithFrame:NSMakeRect([screens[0] frame].size.width - TIME_WIDTH - 50, [screens[0] frame].size.height - 75, TIME_WIDTH, 35)];
    [ctx->durText setEditable:NO];
    [ctx->durText setAlignment:NSTextAlignmentCenter];
    [ctx->durText setFont:[NSFont systemFontOfSize:25 weight:NSFontWeightBold]];
    ctx->duration = CMTimeMake(0, 0);
    //ctx->player = [[AVPlayer alloc] initWithURL:url];
    ctx->player = [AVPlayer playerWithURL:url];

    // Creating windows
    for (int i = 0; i < screens.count; i++)
    {
        NSRect currScreenFrame = [screens[i] frame];
        NSWindow *holder = [[NSWindow alloc] initWithContentRect:currScreenFrame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        [holder setLevel:kCGMaximumWindowLevel];
        [holder setBackgroundColor:[NSColor blackColor]];
        [holder setCollectionBehavior:NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorCanJoinAllSpaces];
        [ctx->holders addObject:holder];
        ctx->duration = [ctx->player.currentItem.asset duration];
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:ctx->player];
        [playerLayer setFrame:[holder contentView].bounds];
        [[holder contentView] setWantsLayer:YES];
        [[holder contentView].layer addSublayer:playerLayer];
        if (i == 0)
            [[holder contentView] addSubview:ctx->durText];
        [holder makeKeyAndOrderFront:nil];
    }

    // Registering ready event for ctx player
    [ctx->player addObserver:self forKeyPath:@"status" options:0 context:(void*)ctx];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSArray *av = [[NSProcessInfo processInfo] arguments];
    NSString *path = nil, *url = nil;

    for (int idx = 0; idx < av.count; ++idx)
    {
        if ([av[idx] hasPrefix:PKEY])
        {
            path = [av[idx] substringFromIndex:PKEY.length];
            break;
        }
        if ([av[idx] hasPrefix:UKEY])
        {
            url = [av[idx] substringFromIndex:UKEY.length];
            break;
        }
    }
    if ((!path || [path isEqualToString:@""] || ![[NSFileManager defaultManager] fileExistsAtPath:path]) && !url)
    {
        fputs("No such file. Use -path=/path/to/file\n", stderr);
        [[NSApplication sharedApplication] terminate:nil];
    }
    [self playVideoWithURL:(path) ? [NSURL fileURLWithPath:path] : [NSURL URLWithString:url]];
}

@end
