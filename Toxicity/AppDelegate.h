//
//  AppDelegate.h
//  Toxicity
//
//  Created by James Linnell on 8/4/13.
//  Copyright (c) 2013 JamesTech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Singleton.h"
#import "ZBarReaderView.h"

#include "tox.h"
#include "Messenger.h"

//for the resolve_addr()
#include <netdb.h>

#include <unistd.h>
#define c_sleep(x) usleep(1000*x)


@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>
{
    
    //used for tox
    int             on;
    
//    NSThread        *toxMainThread;
//    dispatch_queue_t    toxMainThread;
    BOOL                toxMainThreadShouldEnd;
    NSArray             *dhtNodes;
    int                 lastAttemptedConnect;
    uint8_t             *toxWaitData;
    uint16_t            toxWaitBufferSize;
}

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) dispatch_queue_t toxMainThread;
//@property (nonatomic, assign) BOOL toxMainThreadShouldEnd;

unsigned char * hex_string_to_bin(char hex_string[]);
- (void)toxCoreLoop;

- (void)connectToDHTWithIP:(DHTNodeObject *)theDHTInfo;
- (void)userNickChanged;
- (void)userStatusChanged;
- (void)userStatusTypeChanged;
- (void)addFriend:(NSString *)theirKey;
- (BOOL)sendMessage:(MessageObject *)theMessage;
- (void)acceptFriendRequests:(NSArray *)theKeysToAccept;
- (void)acceptGroupInvites:(NSArray *)theKeysToAccept;
- (int)deleteFriend:(NSString*)friendKey;
- (int)deleteGroupchat:(int)theGroupNumber;

- (void)configureNavigationControllerDesign:(UINavigationController *)navController;

@end
