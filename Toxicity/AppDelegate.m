//
//  AppDelegate.m
//  Toxicity
//
//  Created by James Linnell on 8/4/13.
//  Copyright (c) 2013 JamesTech. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize toxMainThread;

#pragma mark - Application Delegation Methods

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    
    [self setupTox];
    
    
    // force view class to load so it may be referenced directly from NIB
    [ZBarReaderView class];
    
    
    [self configureNavigationControllerDesign:(UINavigationController *)self.window.rootViewController];
    
    // Tox thread
    self.toxMainThread = dispatch_queue_create("com.Jman.Toxicity", DISPATCH_QUEUE_SERIAL);
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    

    [self killToxThread];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if ([[Singleton sharedSingleton] toxCoreInstance] == NULL) {
        [self setupTox];
    }
    [self startToxThread];
    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    
    [self killToxThread];
    tox_kill([[Singleton sharedSingleton] toxCoreInstance]);
    [[Singleton sharedSingleton] setToxCoreInstance:NULL];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    NSLog(@"URL: %@", url);
    
    if ([Singleton friendPublicKeyIsValid:url.host]) {
        [self addFriend:url.host];
    }
    
    return YES;
}

- (void)setupToxNew
{
    //user defaults is the easy way to save info between app launches. dont have to read a file manually, etc. basically a plist
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    //start messenger here for LAN discorvery without pesky dht. required for tox core
    Tox *tempTox = tox_new(0);
    if (tempTox) {
        [[Singleton sharedSingleton] setToxCoreInstance:tempTox];
    }
    
    //callbacks
    tox_callback_friend_request(       [[Singleton sharedSingleton] toxCoreInstance], print_request,                NULL);
    tox_callback_group_invite(         [[Singleton sharedSingleton] toxCoreInstance], print_groupinvite,            NULL);
    tox_callback_friend_message(       [[Singleton sharedSingleton] toxCoreInstance], print_message,                NULL);
    tox_callback_friend_action(        [[Singleton sharedSingleton] toxCoreInstance], print_action,                 NULL);
    tox_callback_group_message(        [[Singleton sharedSingleton] toxCoreInstance], print_groupmessage,           NULL);
    tox_callback_name_change(          [[Singleton sharedSingleton] toxCoreInstance], print_nickchange,             NULL);
    tox_callback_status_message(       [[Singleton sharedSingleton] toxCoreInstance], print_statuschange,           NULL);
    tox_callback_connection_status(    [[Singleton sharedSingleton] toxCoreInstance], print_connectionstatuschange, NULL);
    tox_callback_user_status(          [[Singleton sharedSingleton] toxCoreInstance], print_userstatuschange,       NULL);
    tox_callback_group_namelist_change([[Singleton sharedSingleton] toxCoreInstance], print_groupnamelistchange,    NULL);
    
    //load public/private key. key is held in NSData bytes in the user defaults
    if ([prefs objectForKey:@"tox_data"] == nil) {
        NSLog(@"loading new key");
        //load a new key
        int size = tox_size([[Singleton sharedSingleton] toxCoreInstance]);
        uint8_t *data = malloc(size);
        tox_save([[Singleton sharedSingleton] toxCoreInstance], data);
        
        //save to userdefaults
        NSData *theKey = [NSData dataWithBytes:data length:size];
        [prefs setObject:theKey forKey:@"tox_data"];
        [prefs synchronize];
        
        free(data);
    } else {
        NSLog(@"using already made key");
        //key already made, laod it from memory
        NSData *theKey = [prefs objectForKey:@"tox_data"];
        
        int size = tox_size([[Singleton sharedSingleton] toxCoreInstance]);
        uint8_t *data = (uint8_t *)[theKey bytes];
        
        tox_load([[Singleton sharedSingleton] toxCoreInstance], data, size);
    }
    
    // Name
    uint8_t nameUTF8[TOX_MAX_NAME_LENGTH];
    tox_get_self_name([[Singleton sharedSingleton] toxCoreInstance], nameUTF8, TOX_MAX_NAME_LENGTH);
    [[Singleton sharedSingleton] setUserNick:[NSString stringWithUTF8String:(const char *)nameUTF8]];
    
    // Status
    uint8_t statusNoteUTF8[TOX_MAX_STATUSMESSAGE_LENGTH];
    tox_get_self_status_message([[Singleton sharedSingleton] toxCoreInstance], statusNoteUTF8, TOX_MAX_STATUSMESSAGE_LENGTH);
    [[Singleton sharedSingleton] setUserStatusMessage:[NSString stringWithUTF8String:(const char *)nameUTF8]];
    
    // Friends
    uint32_t friendCount = tox_count_friendlist([[Singleton sharedSingleton] toxCoreInstance]);
    for (int i = 0; i < friendCount; i++) {
        FriendObject *tempFriend = [[FriendObject alloc] init];
        
        uint8_t theirID[TOX_CLIENT_ID_SIZE];
        tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], i, theirID);
        [tempFriend setPublicKey:[NSString stringWithUTF8String:(const char *)theirID]];
        
        uint8_t theirName[TOX_MAX_NAME_LENGTH];
        tox_get_name([[Singleton sharedSingleton] toxCoreInstance], i, theirName);
        [tempFriend setNickname:[NSString stringWithUTF8String:(const char *)theirName]];
        
        uint8_t theirStatus[TOX_MAX_STATUSMESSAGE_LENGTH];
        tox_get_status_message([[Singleton sharedSingleton] toxCoreInstance], i, theirStatus, TOX_MAX_STATUSMESSAGE_LENGTH);
        [tempFriend setStatusMessage:[NSString stringWithUTF8String:(const char *)theirStatus]];
        
        [tempFriend setStatusType:ToxFriendUserStatus_None];
        [tempFriend setConnectionType:ToxFriendConnectionStatus_None];
        
        [[[Singleton sharedSingleton] mainFriendList] insertObject:tempFriend atIndex:i];
        [[[Singleton sharedSingleton] mainFriendMessages] insertObject:[NSMutableArray array] atIndex:i];
    }

    
    //Miscellaneous
    
    //print our our client id/address
    char convertedKey[(TOX_FRIEND_ADDRESS_SIZE * 2) + 1];
    int pos = 0;
    uint8_t ourAddress1[TOX_FRIEND_ADDRESS_SIZE];
    tox_get_address([[Singleton sharedSingleton] toxCoreInstance], ourAddress1);
    for (int i = 0; i < TOX_FRIEND_ADDRESS_SIZE; ++i, pos += 2) {
        sprintf(&convertedKey[pos] ,"%02X", ourAddress1[i] & 0xff);
    }
    NSLog(@"Our Address: %s", convertedKey);
    NSLog(@"Our id: %@", [[NSString stringWithUTF8String:convertedKey] substringToIndex:63]);
}

- (void)setupTox
{
    //user defaults is the easy way to save info between app launches. dont have to read a file manually, etc. basically a plist
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    //start messenger here for LAN discorvery without pesky dht. required for tox core
    Tox *tempTox = tox_new(0);
    if (tempTox) {
        [[Singleton sharedSingleton] setToxCoreInstance:tempTox];
    }
    
    //callbacks
    tox_callback_friend_request(       [[Singleton sharedSingleton] toxCoreInstance], print_request,                NULL);
    tox_callback_group_invite(         [[Singleton sharedSingleton] toxCoreInstance], print_groupinvite,            NULL);
    tox_callback_friend_message(       [[Singleton sharedSingleton] toxCoreInstance], print_message,                NULL);
    tox_callback_friend_action(        [[Singleton sharedSingleton] toxCoreInstance], print_action,                 NULL);
    tox_callback_group_message(        [[Singleton sharedSingleton] toxCoreInstance], print_groupmessage,           NULL);
    tox_callback_name_change(          [[Singleton sharedSingleton] toxCoreInstance], print_nickchange,             NULL);
    tox_callback_status_message(       [[Singleton sharedSingleton] toxCoreInstance], print_statuschange,           NULL);
    tox_callback_connection_status(    [[Singleton sharedSingleton] toxCoreInstance], print_connectionstatuschange, NULL);
    tox_callback_user_status(          [[Singleton sharedSingleton] toxCoreInstance], print_userstatuschange,       NULL);
    tox_callback_group_namelist_change([[Singleton sharedSingleton] toxCoreInstance], print_groupnamelistchange,    NULL);
    
    /***** Start Loading from NSUserDefaults *****/
    /***** Load:
     Public/Private Key Data - NSData with bytes
     Our Username/nick and Status Message - NSString for both
     Friend List - NSArray of Archived instances of FriendObject
     Saved DHT Nodes - NSArray of Archived instances of DHTNodeObject
     *****/
    
    
    //load public/private key. key is held in NSData bytes in the user defaults
    if ([prefs objectForKey:@"self_key"] == nil) {
        NSLog(@"loading new key");
        //load a new key
        int size = tox_size([[Singleton sharedSingleton] toxCoreInstance]);
        uint8_t *data = malloc(size);
        tox_save([[Singleton sharedSingleton] toxCoreInstance], data);
        
        //save to userdefaults
        NSData *theKey = [NSData dataWithBytes:data length:size];
        [prefs setObject:theKey forKey:@"self_key"];
        [prefs synchronize];
        
        free(data);
    } else {
        NSLog(@"using already made key");
        //key already made, laod it from memory
        NSData *theKey = [prefs objectForKey:@"self_key"];
        
        int size = tox_size([[Singleton sharedSingleton] toxCoreInstance]);
        uint8_t *data = (uint8_t *)[theKey bytes];
        
        tox_load([[Singleton sharedSingleton] toxCoreInstance], data, size);
    }
    
    //load nick and statusmsg
    if ([prefs objectForKey:@"self_nick"] != nil) {
        [[Singleton sharedSingleton] setUserNick:[prefs objectForKey:@"self_nick"]];
        tox_set_name([[Singleton sharedSingleton] toxCoreInstance], (uint8_t *)[[[Singleton sharedSingleton] userNick] UTF8String], strlen([[[Singleton sharedSingleton] userNick] UTF8String]) + 1);
    }
    if ([prefs objectForKey:@"self_status_message"] != nil) {
        [[Singleton sharedSingleton] setUserStatusMessage:[prefs objectForKey:@"self_status_message"]];
        tox_set_status_message([[Singleton sharedSingleton] toxCoreInstance], (uint8_t *)[[[Singleton sharedSingleton] userStatusMessage] UTF8String], strlen([[[Singleton sharedSingleton] userStatusMessage] UTF8String]) + 1);
    }
    
    //loads friend list
    if ([prefs objectForKey:@"friend_list"] == nil) {
        
    } else {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        for (NSData *data in [prefs objectForKey:@"friend_list"]) {
            FriendObject *tempFriend = (FriendObject *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
            [array addObject:tempFriend];
            
            unsigned char *idToAdd = hex_string_to_bin((char *)[tempFriend.publicKey UTF8String]);
            int num = tox_add_friend_norequest([[Singleton sharedSingleton] toxCoreInstance], idToAdd);
            if (num >= 0) {
                [[[Singleton sharedSingleton] mainFriendMessages] insertObject:[NSArray array] atIndex:num];
                [[[Singleton sharedSingleton] mainFriendList] insertObject:tempFriend atIndex:num];
            }
            free(idToAdd);
        }
    }
    
    //loads any save dht nodes
    if ([prefs objectForKey:@"dht_node_list"] == nil) {
        //no list exists, make a new array, add a placeholder so I don't have to add one manually
        DHTNodeObject *tempDHT = [[DHTNodeObject alloc] init];
        tempDHT.dhtName = @"stal-premade";
        tempDHT.dhtIP = @"198.46.136.167";
        tempDHT.dhtPort = @"33445";
        tempDHT.dhtKey = @"728925473812C7AAC482BE7250BCCAD0B8CB9F737BF3D42ABD34459C1768F854";
        [[Singleton sharedSingleton] setDhtNodeList:(NSMutableArray *)@[tempDHT]];
    } else {
        //theere's a list, loop through them and add to singleton
        NSMutableArray *array = [[NSMutableArray alloc] init];
        for (NSData *data in [prefs objectForKey:@"dht_node_list"]) {
            DHTNodeObject *tempDHT = (DHTNodeObject *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
            [array addObject:tempDHT];
        }
        [[Singleton sharedSingleton] setDhtNodeList:array];
    }
    
    //loads any pending friend requests
    if ([prefs objectForKey:@"pending_requests_list"] == nil) {
        
    } else {
        [[Singleton sharedSingleton] setPendingFriendRequests:(NSMutableDictionary *)[prefs objectForKey:@"pending_requests_list"]];
    }
    
    /***** End NSUserDefault Loading *****/
    
    
    //Miscellaneous
    
    //print our our client id/address
    char convertedKey[(TOX_FRIEND_ADDRESS_SIZE * 2) + 1];
    int pos = 0;
    uint8_t ourAddress1[TOX_FRIEND_ADDRESS_SIZE];
    tox_get_address([[Singleton sharedSingleton] toxCoreInstance], ourAddress1);
    for (int i = 0; i < TOX_FRIEND_ADDRESS_SIZE; ++i, pos += 2) {
        sprintf(&convertedKey[pos] ,"%02X", ourAddress1[i] & 0xff);
    }
    NSLog(@"Our Address: %s", convertedKey);
    NSLog(@"Our id: %@", [[NSString stringWithUTF8String:convertedKey] substringToIndex:63]);
}

#pragma mark - End Application Delegation

#pragma mark - Tox related Methods

- (void)connectToDHTWithIP:(DHTNodeObject *)theDHTInfo {
    NSLog(@"Connecting to %@ %@ %@", [theDHTInfo dhtIP], [theDHTInfo dhtPort], [theDHTInfo dhtKey]);
    const char *dht_ip = [[theDHTInfo dhtIP] UTF8String];
    const char *dht_port = [[theDHTInfo dhtPort] UTF8String];
    const char *dht_key = [[theDHTInfo dhtKey] UTF8String];
    
    
    //used from toxic source, this tells tox core to make a connection into the dht network    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        unsigned char *binary_string = hex_string_to_bin((char *)dht_key);
        tox_bootstrap_from_address([[Singleton sharedSingleton] toxCoreInstance],
                                   dht_ip,
                                   TOX_ENABLE_IPV6_DEFAULT,
                                   htons(atoi(dht_port)),
                                   binary_string); //actual connection
        free(binary_string);
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

}

- (void)userNickChanged {
    char *newNick = (char *)[[[Singleton sharedSingleton] userNick] UTF8String];
    
    //submit new nick to core
    dispatch_async(self.toxMainThread, ^{
        tox_set_name([[Singleton sharedSingleton] toxCoreInstance], (uint8_t *)newNick, strlen(newNick) + 1);
    });
    
    //save to user defaults
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:[[Singleton sharedSingleton] userNick] forKey:@"self_nick"];
    [prefs synchronize];
}

- (void)userStatusChanged {
    char *newStatus = (char *)[[[Singleton sharedSingleton] userStatusMessage] UTF8String];
    
    //submit new status to core
    dispatch_async(self.toxMainThread, ^{
        tox_set_status_message([[Singleton sharedSingleton] toxCoreInstance], (uint8_t *)newStatus, strlen(newStatus) + 1);
    });
    
    //save to user defaults
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:[[Singleton sharedSingleton] userStatusMessage] forKey:@"self_status_message"];
    [prefs synchronize];
}

- (void)userStatusTypeChanged {
    TOX_USERSTATUS statusType = TOX_USERSTATUS_INVALID;
    switch ([[Singleton sharedSingleton] userStatusType]) {
        case ToxFriendUserStatus_None:
            statusType = TOX_USERSTATUS_NONE;
            break;
            
        case ToxFriendUserStatus_Away:
            statusType = TOX_USERSTATUS_AWAY;
            break;
            
        case ToxFriendUserStatus_Busy:
            statusType = TOX_USERSTATUS_BUSY;
            break;
            
        default:
            statusType = TOX_USERSTATUS_INVALID;
            break;
    }
    dispatch_async(self.toxMainThread, ^{
        tox_set_user_status([[Singleton sharedSingleton] toxCoreInstance], statusType);
    });
}

- (BOOL)sendMessage:(MessageObject *)theMessage {
    //return type: TRUE = sent, FALSE = not sent, should error
    //send a message to a friend, called primarily from the caht window vc

    
    //organize our message data
    NSString *theirKey = theMessage.recipientKey;
    NSString *messageToSend = theMessage.message;
    BOOL isGroupMessage = theMessage.isGroupMessage;
    BOOL isActionMessage = theMessage.isActionMessage;
    NSInteger friendNum = -1;
    if (isGroupMessage) {
        for (int i = 0; i < [[[Singleton sharedSingleton] groupList] count]; i++) {
            GroupObject *tempGroup = [[[Singleton sharedSingleton] groupList] objectAtIndex:i];
            if ([theirKey isEqualToString:tempGroup.groupPulicKey]) {
                friendNum = i;
                break;
            }
        }
    } else {
        friendNum = friendNumForID(theirKey);
    }
    if (friendNum == -1) {
        //in case something data-wise messed up and the friend no longer exists, or the key got messed up
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Uh oh, something went wrong! The friend key you're trying to send a message to doesn't seem to be in your friend list. Try restarting the app and send a bug report!"
                                                           delegate:nil
                                                  cancelButtonTitle:@"Okay"
                                                  otherButtonTitles:nil];
        [alertView show];
        return FALSE;
    }
    
    NSLog(@"Sending Message: %@", theMessage);

    
    //here we have to check to see if a "/me " exists, but before we do that we have to make sure the length is 5 or more
    //dont want to get out of bounds error
    __block BOOL returnVar = TRUE;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        int num;
        char *utf8Message = (char *)[messageToSend UTF8String];
        
        if (isGroupMessage == NO) { //chat message
            if (isActionMessage) {
                char *utf8FormattedMessage = (char *)[[messageToSend substringFromIndex:2] UTF8String];
                num = tox_send_action([[Singleton sharedSingleton] toxCoreInstance], friendNum, (uint8_t *)utf8FormattedMessage, strlen(utf8FormattedMessage) + 1);
            } else {
                num = tox_send_message([[Singleton sharedSingleton] toxCoreInstance], friendNum, (uint8_t *)utf8Message, strlen(utf8Message) + 1);
            }
        } else { //group message
            num = tox_group_message_send([[Singleton sharedSingleton] toxCoreInstance], friendNum, (uint8_t *)utf8Message, strlen(utf8Message) + 1);
        }
        
        if (num == -1) {
            NSLog(@"Failed to put message in send queue!");
            returnVar =  FALSE;
        } else {
            returnVar =  TRUE;
        }
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW + (100000 * NSEC_PER_USEC));
    return returnVar;
}

- (void)addFriend:(NSString *)theirKey {
    //sends a request to the key
    
    uint8_t *binID = hex_string_to_bin((char *)[theirKey UTF8String]);
    __block int num = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        num = tox_add_friend([[Singleton sharedSingleton] toxCoreInstance], binID, (uint8_t *)"Toxicity for iOS", strlen("Toxicity for iOS") + 1);
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    free(binID);
    
    switch (num) {
        case TOX_FAERR_TOOLONG:            
        case TOX_FAERR_NOMESSAGE:
        case TOX_FAERR_OWNKEY:
        case TOX_FAERR_ALREADYSENT:
        case TOX_FAERR_UNKNOWN:
        case TOX_FAERR_BADCHECKSUM:
        case TOX_FAERR_SETNEWNOSPAM:
        case TOX_FAERR_NOMEM: {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unknown Error"
                                                                message:[NSString stringWithFormat:@"[Error Code: %d] There was an unknown error with adding that ID. Normally I try to prevent that, but something unfortunate happened.", num]
                                                               delegate:nil
                                                      cancelButtonTitle:@"Okay"
                                                      otherButtonTitles:nil];
            [alertView show];
            break;
        }
            
        default: //added friend successfully
        {
            //add friend to singleton array, for use throughout the app
            FriendObject *tempFriend = [[FriendObject alloc] init];
            [tempFriend setPublicKeyWithNoSpam:theirKey];
            [tempFriend setPublicKey:[theirKey substringToIndex:(TOX_CLIENT_ID_SIZE * 2)]];
            NSLog(@"new friend key: %@", [tempFriend publicKey]);
            [tempFriend setStatusMessage:@"Sending request..."];
            
            [[[Singleton sharedSingleton] mainFriendList] insertObject:tempFriend atIndex:num];
            [[[Singleton sharedSingleton] mainFriendMessages] insertObject:[NSArray array] atIndex:num];
            
            //save in user defaults
            [Singleton saveFriendListInUserDefaults];
                        
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendAdded" object:nil];
            break;
        }
    }
}

- (void)acceptFriendRequests:(NSArray *)theKeysToAccept {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{

        for (NSString *arrayKey in theKeysToAccept) {

            NSData *data = [[[[Singleton sharedSingleton] pendingFriendRequests] objectForKey:arrayKey] copy];

            uint8_t *key = (uint8_t *)[data bytes];
            
            int num = tox_add_friend_norequest([[Singleton sharedSingleton] toxCoreInstance], key);
            
            switch (num) {
                case -1: {
                    NSLog(@"Accepting request failed");
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unknown Error"
                                                                        message:[NSString stringWithFormat:@"[Error Code: %d] There was an unknown error with accepting that ID.", num]
                                                                       delegate:nil
                                                              cancelButtonTitle:@"Okay"
                                                              otherButtonTitles:nil];
                    [alertView show];
                    break;
                }
                    
                default: //added friend successfully
                {
                    //friend added through accept request
                    FriendObject *tempFriend = [[FriendObject alloc] init];
                    [tempFriend setPublicKey:[arrayKey substringToIndex:(TOX_CLIENT_ID_SIZE * 2)]];
                    NSLog(@"new friend key: %@", [tempFriend publicKey]);
                    [tempFriend setNickname:@""];
                    [tempFriend setStatusMessage:@"Accepted..."];
                    
                    [[[Singleton sharedSingleton] mainFriendList] insertObject:tempFriend atIndex:num];
                    [[[Singleton sharedSingleton] mainFriendMessages] insertObject:[NSArray array] atIndex:num];
                    
                    //save in user defaults
                    [Singleton saveFriendListInUserDefaults];
                    
                    //remove from the pending requests
                    [[[Singleton sharedSingleton] pendingFriendRequests] removeObjectForKey:arrayKey];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendAdded" object:nil];
                    
                    break;
                }
            }
        }
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:[[Singleton sharedSingleton] pendingFriendRequests] forKey:@"pending_requests_list"];
}

- (void)acceptGroupInvites:(NSArray *)theKeysToAccept {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        for (NSString *arrayKey in theKeysToAccept) {
            
            NSData *data = [[[[Singleton sharedSingleton] pendingGroupInvites] objectForKey:arrayKey] copy];
            NSNumber *friendNumOfGroupKey = [[[Singleton sharedSingleton] pendingGroupInviteFriendNumbers] objectForKey:arrayKey];
            
            uint8_t *key = (uint8_t *)[data bytes];
            int num = tox_join_groupchat([[Singleton sharedSingleton] toxCoreInstance], [friendNumOfGroupKey integerValue], key);

            switch (num) {
                case -1: {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"Accepting group invite failed");
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unknown Error"
                                                                            message:[NSString stringWithFormat:@"[Error Code: %d] There was an unkown error with accepting that Group", num]
                                                                           delegate:nil
                                                                  cancelButtonTitle:@"Okay"
                                                                  otherButtonTitles:nil];
                        [alertView show];
                    });
                    break;
                }
                    
                default: {
                    GroupObject *tempGroup = [[GroupObject alloc] init];
                    [tempGroup setGroupPulicKey:arrayKey];
                    [[[Singleton sharedSingleton] groupList] insertObject:tempGroup atIndex:num];
                    [[[Singleton sharedSingleton] groupMessages] insertObject:[NSArray array] atIndex:num];
                    
                    [Singleton saveGroupListInUserDefaults];
                    
                    [[[Singleton sharedSingleton] pendingGroupInvites] removeObjectForKey:arrayKey];
                    [[[Singleton sharedSingleton] pendingGroupInviteFriendNumbers] removeObjectForKey:arrayKey];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupAdded" object:nil];
                    
                    break;
                }
            }
        }
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
}

- (int)deleteFriend:(NSString*)friendKey {
    
    int friendNum = friendNumForID(friendKey);
    if (friendNum == -1) {
        return -1;
    }
    

    __block int num = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        num = tox_del_friend([[Singleton sharedSingleton] toxCoreInstance], friendNum);
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    //and return delfriend's number
    return num;
    
}

- (int)deleteGroupchat:(int)theGroupNumber {
    __block int num = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(self.toxMainThread, ^{
        num = tox_del_groupchat([[Singleton sharedSingleton] toxCoreInstance], theGroupNumber);
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return num;
}

#pragma mark - End Tox related Methods

#pragma mark - Tox Core Callback Functions

void print_request(uint8_t *public_key, uint8_t *data, uint16_t length, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"Friend Request! From:");
        
        for (int i=0; i<32; i++) {
            printf("%02X", public_key[i] & 0xff);
        }
        printf("\n");
        
        //convert the bin key to a char key. reverse of hex_string_to_bin. used in a lot of places
        //todo: make it a function
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", public_key[i] & 0xff);
        }
        
        //check to see if this person is already on our friends list
        BOOL alreadyAFriend = NO;
        for (FriendObject *tempFriend in [[Singleton sharedSingleton] mainFriendList]) {
            if ([tempFriend.publicKey isEqualToString:[NSString stringWithUTF8String:convertedKey]]) {
                NSLog(@"The friend request we got is one of a friend we already have: %@ %@", tempFriend.nickname, tempFriend.publicKey);
                alreadyAFriend = YES;
                break;
            }
        }
        
        //if they're not on our friends list then dont add a request, just auto accept
        if (alreadyAFriend == NO) {
            //we got a friend request, so we have to store it!
            //the pending dictionary has the object as nsdata bytes of the bin version of the publickey, and the dict key is the nsstring of said publickey
            [[[Singleton sharedSingleton] pendingFriendRequests] setObject:[NSData dataWithBytes:public_key length:TOX_CLIENT_ID_SIZE]
                                                                    forKey:[NSString stringWithUTF8String:convertedKey]];
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:[[Singleton sharedSingleton] pendingFriendRequests] forKey:@"pending_requests_list"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendRequestReceived" object:nil];
        } else {
            //no need to kill thread, this is synchronous
            AppDelegate *tempAppDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            dispatch_async(tempAppDelegate.toxMainThread, ^{
                tox_add_friend_norequest([[Singleton sharedSingleton] toxCoreInstance], public_key);
            });
        }
        
    });
}

void print_groupinvite(Tox *tox, int friendnumber, uint8_t *group_public_key, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", group_public_key[i] & 0xff);
        }
        NSString *theConvertedKey = [NSString stringWithUTF8String:convertedKey];
        NSLog(@"Group invite from friend [%d], group_public_key: %@", friendnumber, theConvertedKey);
        
        BOOL alreadyInThisGroup = NO;
        for (GroupObject *tempGroup in [[Singleton sharedSingleton] groupList]) {
            if ([theConvertedKey isEqualToString:[tempGroup groupPulicKey]]) {
                NSLog(@"The group we were invited to is one we're already in! %@", [tempGroup groupPulicKey]);
                alreadyInThisGroup = YES;
                break;
            }
        }
        
        if (alreadyInThisGroup == NO) {
            
            [[[Singleton sharedSingleton] pendingGroupInvites] setObject:[NSData dataWithBytes:group_public_key length:TOX_CLIENT_ID_SIZE]
                                                                  forKey:theConvertedKey];
            [[[Singleton sharedSingleton] pendingGroupInviteFriendNumbers] setObject:[NSNumber numberWithInt:friendnumber] forKey:theConvertedKey];
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:[[Singleton sharedSingleton] pendingGroupInvites] forKey:@"pending_invites_list"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupInviteReceived" object:nil];
            
        } else {
            AppDelegate *tempAppDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            dispatch_async(tempAppDelegate.toxMainThread, ^{
                tox_join_groupchat([[Singleton sharedSingleton] toxCoreInstance], friendnumber, group_public_key);
            });
        }
        
    });
}

void print_message(Tox *m, int friendnumber, uint8_t * string, uint16_t length, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"Message from [%d]: %s", friendnumber, string);
        
        
        MessageObject *theMessage = [[MessageObject alloc] init];
        [theMessage setMessage:[NSString stringWithUTF8String:(char *)string]];
        [theMessage setSenderName:[[Singleton sharedSingleton] userNick]];
        [theMessage setOrigin:MessageLocation_Them];
        [theMessage setDidFailToSend:NO];
        [theMessage setIsGroupMessage:NO];
        [theMessage setIsActionMessage:NO];
        [theMessage setSenderKey:[[[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber] publicKey]];
        
        
        //add to singleton
        //if the message coming through is not to the currently opened chat window, then uialertview it
        if (friendnumber != [[[Singleton sharedSingleton] currentlyOpenedFriendNumber] row] && [[[Singleton sharedSingleton] currentlyOpenedFriendNumber] section] != 1) {
            NSMutableArray *tempMessages = [[[[Singleton sharedSingleton] mainFriendMessages] objectAtIndex:friendnumber] mutableCopy];
            [tempMessages addObject:theMessage];
            
            [[Singleton sharedSingleton] mainFriendMessages][friendnumber] = [tempMessages copy];
            
            FriendObject *tempFriend = [[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber];
            UIAlertView *messageAlert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Message from: %@", tempFriend.nickname]
                                                                   message:[NSString stringWithUTF8String:(char *)string]
                                                                  delegate:nil
                                                         cancelButtonTitle:@"Okay"
                                                         otherButtonTitles:nil];
            [messageAlert show];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NewMessage" object:theMessage];
        }
    });
}

void print_action(Tox *m, int friendnumber, uint8_t * action, uint16_t length, void *userdata) {
    //todo: this
    print_message(m, friendnumber, action, length, userdata);
}

void print_groupmessage(Tox *tox, int groupnumber, int friendgroupnumber, uint8_t * message, uint16_t length, void *userdata) {
    NSLog(@"Group message received from group [%d], message: %s. Friend [%d]", groupnumber, message, friendgroupnumber);
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        uint8_t *theirNameC[TOX_MAX_NAME_LENGTH];
        tox_group_peername([[Singleton sharedSingleton] toxCoreInstance], groupnumber, friendgroupnumber, (uint8_t *)theirNameC);
        NSString *theirName = [NSString stringWithUTF8String:(const char *)theirNameC];
        NSString *theirMessage = [NSString stringWithUTF8String:(const char *)message];
        
        MessageObject *theMessage = [[MessageObject alloc] init];
        [theMessage setMessage:theirMessage];
        [theMessage setSenderName:theirName];
        if ([theirName isEqualToString:[[Singleton sharedSingleton] userNick]]) {
            [theMessage setOrigin:MessageLocation_Me];
        } else {
            [theMessage setOrigin:MessageLocation_Them];
        }
        [theMessage setDidFailToSend:NO];
        [theMessage setIsActionMessage:NO];
        [theMessage setIsGroupMessage:YES];
        [theMessage setSenderKey:[[[[Singleton sharedSingleton] groupList] objectAtIndex:groupnumber] groupPulicKey]];
        //add to singleton
        //if the message coming through is not to the currently opened chat window, then uialertview it
        if (groupnumber != [[[Singleton sharedSingleton] currentlyOpenedFriendNumber] row] && [[[Singleton sharedSingleton] currentlyOpenedFriendNumber] section] != 0) {
            NSMutableArray *tempMessages = [[[[Singleton sharedSingleton] groupMessages] objectAtIndex:groupnumber] mutableCopy];
            [tempMessages addObject:theMessage];

            [[Singleton sharedSingleton] groupMessages][groupnumber] = [tempMessages copy];
            
            UIAlertView *messageAlert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Message from Group #%d", groupnumber]
                                                                   message:theirMessage
                                                                  delegate:nil
                                                         cancelButtonTitle:@"Okay"
                                                         otherButtonTitles:nil];
            [messageAlert show];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NewMessage" object:theMessage];
        }
        
    });
}

void print_nickchange(Tox *m, int friendnumber, uint8_t * string, uint16_t length, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"Nick Change from [%d]: %s", friendnumber, string);
        
        uint8_t tempKey[TOX_CLIENT_ID_SIZE];
        tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], friendnumber, tempKey);
        
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", tempKey[i] & 0xff);
        }
        
        if ([Singleton friendNumber:friendnumber matchesKey:[NSString stringWithUTF8String:convertedKey]]) {
            
        } else {
            return;
        }
        
        
        FriendObject *tempFriend = [[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber];
        [tempFriend setNickname:[NSString stringWithUTF8String:(char *)string]];
        
        //save in user defaults
        [Singleton saveFriendListInUserDefaults];
        
        //for now
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendAdded" object:nil];
    });
}

void print_statuschange(Tox *m, int friendnumber,  uint8_t * string, uint16_t length, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"Status change from [%d]: %s", friendnumber, string);
        
        uint8_t tempKey[TOX_CLIENT_ID_SIZE];
        tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], friendnumber, tempKey);
        
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", tempKey[i] & 0xff);
        }
        
        if ([Singleton friendNumber:friendnumber matchesKey:[NSString stringWithUTF8String:convertedKey]]) {
            
        } else {
            return;
        }
        
        
        FriendObject *tempFriend = [[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber];
        [tempFriend setStatusMessage:[NSString stringWithUTF8String:(char *)string]];
        
        //save in user defaults
        [Singleton saveFriendListInUserDefaults];
        
        //for now
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendAdded" object:nil];
    });
}

void print_userstatuschange(Tox *m, int friendnumber, TOX_USERSTATUS kind, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        uint8_t tempKey[TOX_CLIENT_ID_SIZE];
        tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], friendnumber, tempKey);
        
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", tempKey[i] & 0xff);
        }
        
        if ([Singleton friendNumber:friendnumber matchesKey:[NSString stringWithUTF8String:convertedKey]]) {
            
        } else {
            return;
        }
        
        
        FriendObject *tempFriend = [[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber];
        switch (kind) {
            case TOX_USERSTATUS_AWAY:
            {
                [tempFriend setStatusType:ToxFriendUserStatus_Away];
                NSLog(@"User status change: away");
                break;
            }
                
            case TOX_USERSTATUS_BUSY:
            {
                [tempFriend setStatusType:ToxFriendUserStatus_Busy];
                NSLog(@"User status change: busy");
                break;
            }
                
            case TOX_USERSTATUS_INVALID:
            {
                [tempFriend setStatusType:ToxFriendUserStatus_None];
                NSLog(@"User status change: invalid");
                break;
            }
                
            case TOX_USERSTATUS_NONE:
            {
                [tempFriend setStatusType:ToxFriendUserStatus_None];
                NSLog(@"User status change: none");
                break;
            }
                
            default:
                break;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendUserStatusChanged" object:nil];
    });
}

void print_connectionstatuschange(Tox *m, int friendnumber, uint8_t status, void *userdata) {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"Friend Status Change: [%d]: %d", friendnumber, (int)status);

        uint8_t tempKey[TOX_CLIENT_ID_SIZE];
        tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], friendnumber, tempKey);
        
        char convertedKey[(TOX_CLIENT_ID_SIZE * 2) + 1];
        int pos = 0;
        for (int i = 0; i < TOX_CLIENT_ID_SIZE; ++i, pos += 2) {
            sprintf(&convertedKey[pos] ,"%02X", tempKey[i] & 0xff);
        }
        
        if ([Singleton friendNumber:friendnumber matchesKey:[NSString stringWithUTF8String:convertedKey]]) {
            
        } else {
            return;
        }
        
        FriendObject *tempFriend = [[[Singleton sharedSingleton] mainFriendList] objectAtIndex:friendnumber];
        switch (status) {
            case 0:
                tempFriend.connectionType = ToxFriendConnectionStatus_None;
                break;
                
            case 1:
                tempFriend.connectionType = ToxFriendConnectionStatus_Online;
                break;
                
            default:
                break;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FriendUserStatusChanged" object:nil];
    });
}

void print_groupnamelistchange(Tox *m, int groupnumber, int peernumber, uint8_t change, void *userdata) {
    /*void (^code_block)(void) = ^void(void) {
        NSLog(@"New names:");
        uint8_t groupPeerList[256][TOX_MAX_NAME_LENGTH];
        int groupPeerCount = tox_group_get_names([[Singleton sharedSingleton] toxCoreInstance], groupnumber, groupPeerList, 256);
        for (int i = 0; i < groupPeerCount; i++) {
            NSLog(@"\t%s", groupPeerList[i]);
        }
    };
    if ([NSThread isMainThread]) {
        code_block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), code_block);
    }*/
    switch (change) {
        case TOX_CHAT_CHANGE_PEER_ADD:
            NSLog(@"GroupChat[%d]: New Peer ([%d])", groupnumber, peernumber);
            break;
        case TOX_CHAT_CHANGE_PEER_NAME:
            NSLog(@"GroupChat[%d]: Peer[%d] -> ", groupnumber, peernumber);
            break;
        case TOX_CHAT_CHANGE_PEER_DEL:
            NSLog(@"GroupChat[%d]: Peer[%d] has left.", groupnumber, peernumber);
            break;
        default:
            break;
    }
}

#pragma mark - End Tox Core Callback Functions

#pragma mark - Thread methods

- (void)killToxThread {
    toxMainThreadShouldEnd = YES;
}

- (void)startToxThread {
    dhtNodes = @[
                 @{@"ip": @"192.254.75.98", @"port": @"33445", @"key": @"FE3914F4616E227F29B2103450D6B55A836AD4BD23F97144E2C4ABE8D504FE1B"},
                 @{@"ip": @"192.184.81.118", @"port": @"33445", @"key": @"5CD7EB176C19A2FD840406CD56177BB8E75587BB366F7BB3004B19E3EDC04143"},
                 @{@"ip": @"144.76.60.215", @"port": @"33445", @"key": @"DDCF277B8B45B0D357D78AA4E201766932DF6CDB7179FC7D5C9F3C2E8E705326"},
                 @{@"ip": @"193.107.16.73", @"port": @"33445", @"key": @"AE27E1E72ADA3DC423C60EEBACA241456174048BE76A283B41AD32D953182D49"},
                 @{@"ip": @"66.74.15.98", @"port": @"33445", @"key": @"20C797E098701A848B07D0384222416B0EFB60D08CECB925B860CAEAAB572067"}
                ];
    lastAttemptedConnect = time(0);
    srand(lastAttemptedConnect);
    
    toxWaitData = NULL;
    uint16_t rtmp = 0;
    tox_wait_prepare([[Singleton sharedSingleton] toxCoreInstance], NULL, &rtmp);
    toxWaitBufferSize = rtmp;
    toxWaitData = malloc(toxWaitBufferSize);

    
    toxMainThreadShouldEnd = NO;
    dispatch_async(self.toxMainThread, ^{
        [self toxCoreLoop];
    });
}

- (void)toxCoreLoop {
    
    //code to check if node connection has changed, if so notify the app
    if (on == 0 && tox_isconnected([[Singleton sharedSingleton] toxCoreInstance])) {
        NSLog(@"DHT Connected!");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DHTConnected" object:nil];
        });
        on = 1;
    }
    if (on == 1 && !tox_isconnected([[Singleton sharedSingleton] toxCoreInstance])) {
        NSLog(@"DHT Disconnected!");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DHTDisconnected" object:nil];
        });
        on = 0;
    }
    // If we haven't been connected for over two seconds, bootstrap to another node.
    if (on == 0 && lastAttemptedConnect < time(0)+2) {
        int num = rand() % [dhtNodes count];
        unsigned char *binary_string = hex_string_to_bin((char *)[dhtNodes[num][@"key"] UTF8String]);
        tox_bootstrap_from_address([[Singleton sharedSingleton] toxCoreInstance],
                                   [dhtNodes[num][@"ip"] UTF8String],
                                   TOX_ENABLE_IPV6_DEFAULT,
                                   htons(atoi([dhtNodes[num][@"port"] UTF8String])),
                                   binary_string); //actual connection
        free(binary_string);
    }
    
    
    // Call Wait Execute for up to a second
    if (toxWaitData && tox_wait_prepare([[Singleton sharedSingleton] toxCoreInstance], toxWaitData, &toxWaitBufferSize) == 1) {
        tox_wait_execute([[Singleton sharedSingleton] toxCoreInstance], toxWaitData, toxWaitBufferSize, 999);
        tox_wait_cleanup([[Singleton sharedSingleton] toxCoreInstance], toxWaitData, toxWaitBufferSize);
    }
    // Run tox_do
    int a = time(0);
    tox_do([[Singleton sharedSingleton] toxCoreInstance]);
    if (time(0) - a > 1) {
        NSLog(@"tox_do took more than %lu seconds!", time(0) - a);
    }

    // Keep going
    if (toxMainThreadShouldEnd == NO) {
        dispatch_time_t waitTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(33333 * NSEC_PER_USEC));
        dispatch_after(waitTime, toxMainThread, ^{
            [self toxCoreLoop];
        });
    }
    
    
    if (on) {
        //print when the number of connected clients changes
        static int lastCount = 0;
        Messenger *m = (Messenger *)[[Singleton sharedSingleton] toxCoreInstance];
        uint32_t i;
        uint64_t temp_time = time(0);
        uint16_t count = 0;
        for(i = 0; i < LCLIENT_LIST; ++i) {
            if (!(m->dht->close_clientlist[i].assoc4.timestamp + 70 <= temp_time) ||
                !(m->dht->close_clientlist[i].assoc6.timestamp + 70 <= temp_time))
                ++count;
            
        }
        if (count != lastCount) {
            NSLog(@"****Nodes connected: %d", count);
        }
        lastCount = count;
    }
}

#pragma mark - End Thread Methods

#pragma mark - Miscellaneous C Functions

unsigned char * hex_string_to_bin(char hex_string[])
{
    size_t len = strlen(hex_string);
    unsigned char *val = malloc(len);
    char *pos = hex_string;
    int i;
    for (i = 0; i < len; ++i, pos+=2)
        sscanf(pos,"%2hhX",&val[i]);
    
    return val;
}

/*
 * Gives the friend number corresponding to
 * the given Tox client ID (32bytes).
 * Returns -1 if not found.
 */
int friendNumForID(NSString *theKey) {
    //Convert key to uint8_t
    uint8_t *newKey = hex_string_to_bin((char *)[theKey UTF8String]);
    
    //Copy the friendlist (kinda) into a variable
    int friendList[256];
    int friendListCount = tox_get_friendlist([[Singleton sharedSingleton] toxCoreInstance], friendList, 256);
    
    //Loop through, check each key against the inputted key
    if (friendListCount > 0) {
        for (int i = 0; i < friendListCount; i++) {
            uint8_t tempKey[TOX_CLIENT_ID_SIZE];
            tox_get_client_id([[Singleton sharedSingleton] toxCoreInstance], i, tempKey);
            if (memcmp(newKey, tempKey, TOX_CLIENT_ID_SIZE) == 0) { // True
                free(newKey);
                return i;
            }
        }
    }
    free(newKey);
    return -1;
}

/*
 * Gives the group number corresponding to
 * the given Tox client ID (32 bytes).
 * Returns -1 of not found.
 */
//UNFINISHED
/*
int groupNumForID(NSString *theKey) {
    //Convert key to uint8_t
    uint8_t *newKey = hex_string_to_bin((char *)[theKey UTF8String]);
    
    //Copy the grouplist (kinda) into a variable
    int groupList[256];
    int groupListCount = tox_get_chatlist([[Singleton sharedSingleton] toxCoreInstance], groupList, 256);
    
    //Loop through, check each key against the inputted key
    if (groupListCount > 0) {
        for (int i = 0; i < groupListCount; i++) {
            uint8_t tempKey[TOX_CLIENT_ID_SIZE];
            
        }
    }
    
}*/

/*
 resolve_addr():
 address should represent IPv4 or a hostname with A record
 
 returns a data in network byte order that can be used to set IP.i or IP_Port.ip.i
 returns 0 on failure
 
 TODO: Fix ipv6 support
 */
uint32_t resolve_addr(const char *address)
{
    struct addrinfo *server = NULL;
    struct addrinfo  hints;
    int              rc;
    uint32_t         addr;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_INET;    // IPv4 only right now.
    hints.ai_socktype = SOCK_DGRAM; // type of socket Tox uses.
    
    rc = getaddrinfo(address, "echo", &hints, &server);
    
    // Lookup failed.
    if (rc != 0) {
        return 0;
    }
    
    // IPv4 records only..
    if (server->ai_family != AF_INET) {
        freeaddrinfo(server);
        return 0;
    }
    
    
    addr = ((struct sockaddr_in *)server->ai_addr)->sin_addr.s_addr;
    
    freeaddrinfo(server);
    return addr;
}

#pragma mark - End Miscellaneous C Functions

#pragma mark - Toxicity Visual Design Methods

- (void)configureNavigationControllerDesign:(UINavigationController *)navController {
    //first, non ios specific stuff:
    
    
    //ios specific stuff
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        // Load resources for iOS 6.1 or earlier
        navController.navigationBar.tintColor = [UIColor colorWithRed:0.3f green:0.37f blue:0.43f alpha:1];
        navController.toolbar.tintColor = [UIColor colorWithRed:0.3f green:0.37f blue:0.43f alpha:1];
    } else {
        // Load resources for iOS 7 or later
        navController.navigationBar.barTintColor = [UIColor colorWithRed:0.3f green:0.37f blue:0.43f alpha:1];
        navController.toolbar.barTintColor = [UIColor colorWithRed:0.3f green:0.37f blue:0.43f alpha:1];
        
        NSDictionary *titleColorsDict = [[NSDictionary alloc] initWithObjectsAndKeys:[UIColor whiteColor], UITextAttributeTextColor, nil];
        [[UIBarButtonItem appearance] setTitleTextAttributes:titleColorsDict forState:UIControlStateNormal];
        
        NSDictionary *pressedTitleColorsDict = [[NSDictionary alloc] initWithObjectsAndKeys:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0f], UITextAttributeTextColor, nil];
        [[UIBarButtonItem appearance] setTitleTextAttributes:pressedTitleColorsDict forState:UIControlStateHighlighted];
    }
}

#pragma mark - End Toxicity Visual Design Methods

@end
