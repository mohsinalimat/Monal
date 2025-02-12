//
//  MLEncryptedPayload.m
//  Monal
//
//  Created by Anurodh Pokharel on 4/19/19.
//  Copyright © 2019 Monal.im. All rights reserved.
//

#import "MLEncryptedPayload.h"

@interface MLEncryptedPayload ()
@property (nonatomic, strong) NSData* body;
@property (nonatomic, strong) NSData* key;
@property (nonatomic, strong) NSData* iv;
@end

@implementation MLEncryptedPayload

-(MLEncryptedPayload *) initWithBody:(NSData*) body key:(NSData *) key iv:(NSData *) iv
{
    self=[super init];
    self.body=body;
    self.key= key;
    self.iv= iv;
    return self;
}

@end
