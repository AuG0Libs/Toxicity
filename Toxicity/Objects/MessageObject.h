//
//  MessageObject.h
//  Toxicity
//
//  Created by James Linnell on 8/15/13.
//  Copyright (c) 2013 JamesTech. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    MessageLocation_Me,
    MessageLocation_Them
} MessageOrigin;

@interface MessageObject : NSObject
{
    
}

@property (nonatomic, strong) NSString          *message;
@property (nonatomic, assign) MessageOrigin     origin;
@property (nonatomic, assign) BOOL              didFailToSend;
@property (nonatomic, assign) BOOL              isGroupMessage;
@property (nonatomic, assign) BOOL              isActionMessage;
@property (nonatomic, strong) NSString          *recipientKey;
@property (nonatomic, strong) NSString          *senderKey;

@end
