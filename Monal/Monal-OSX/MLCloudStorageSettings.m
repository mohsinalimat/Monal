//
//  MLCloudStorageSettings.m
//  Monal
//
//  Created by Anurodh Pokharel on 2/25/16.
//  Copyright © 2016 Monal.im. All rights reserved.
//

#import "MLCloudStorageSettings.h"
#import <DropBoxOSX/DropBoxOSX.h>

@interface MLCloudStorageSettings ()

@end

@implementation MLCloudStorageSettings

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

-(void) viewWillAppear
{
    self.dropBox.state= [DBSession sharedSession].isLinked;
}



#pragma mark - preferences delegate

- (NSString *)identifier
{
    return self.title;
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"732-cloud-upload"];
}

- (NSString *)toolbarItemLabel
{
    return @"Cloud Storage";
}

@end
