//
//  MLOptOutSettings.m
//  Monal-OSX
//
//  Created by Anurodh Pokharel on 1/31/19.
//  Copyright © 2019 Monal.im. All rights reserved.
//

#import "MLOptOutSettings.h"

@interface MLOptOutSettings ()

@end

@implementation MLOptOutSettings

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

-(void) viewDidAppear {
    [super viewDidAppear];
    self.crashlytics.state = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CrashlyticsOptOut"] boolValue];
    
}

-(void) viewWillDisappear
{
    [[NSUserDefaults standardUserDefaults] setBool:self.crashlytics.state  forKey: @"CrashlyticsOptOut"];

}


#pragma mark - preferences delegate

- (NSString *)identifier
{
    return self.title;
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"1040-checkmark"];
}

- (NSString *)toolbarItemLabel
{
    return @"Opt Out";
}


@end
