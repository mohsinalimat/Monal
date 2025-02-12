
//
//  MLMainWindow.m
//  Monal
//
//  Created by Anurodh Pokharel on 6/28/15.
//  Copyright (c) 2015 Monal.im. All rights reserved.
//

#import "MLMainWindow.h"
#import "AppDelegate.h"
#import "DataLayer.h"
#import "MLConstants.h"
#import "MLImageManager.h"
#import "MLXMPPManager.h"
#import "MLContactDetails.h"
#import "MLCallScreen.h"

@interface MLMainWindow ()

@property (nonatomic, strong) NSDictionary *contactInfo;

@end

@implementation MLMainWindow

- (void)windowDidLoad {
    [super windowDidLoad];
    __weak AppDelegate *appDelegate = (AppDelegate *) [NSApplication sharedApplication].delegate;
    appDelegate.mainWindowController= self;
    self.window.frameAutosaveName =@"MonalMainWindow";
    self.window.titleVisibility=NSWindowTitleHidden;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleNewMessage:) name:kMonalNewMessageNotice object:nil];
    [nc addObserver:self selector:@selector(handleConnect:) name:kMLHasConnectedNotice object:nil];
    [nc addObserver:self selector:@selector(showConnectionStatus:) name:kXMPPError object:nil];
    
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate= self;
    
    
}

-(void) updateCurrentContact:(NSDictionary *) contact;
{
    self.contactInfo= contact;
    NSString *fullName= (NSString *) [self.contactInfo objectForKey:kFullName];
    NSNumber *muc=[self.contactInfo objectForKey:@"Muc"];
    
    if(muc.boolValue ==YES)
    {
        self.contactNameField.stringValue =(NSString *) [self.contactInfo objectForKey:@"muc_subject"];
    }
    
    else if(fullName.length>0){
        self.contactNameField.stringValue= [self.contactInfo objectForKey:kFullName];
    } else  {
        if([self.contactInfo objectForKey:kContactName]){
            self.contactNameField.stringValue= [self.contactInfo objectForKey:kContactName];
        }
    }
    
    BOOL encrypt = [(NSNumber *)[contact objectForKey:@"encrypt"] boolValue];
    if(!encrypt) {
        self.lock.image = [NSImage imageNamed:@"745-unlocked"];
    }
    else {
        self.lock.image = [NSImage imageNamed:@"744-locked-selected"];
    }
}

#pragma mark - segue
- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"ContactDetails"]) {
        MLContactDetails *details = (MLContactDetails *)[segue destinationController];
        details.contact=self.contactInfo;
    }
    if([segue.identifier isEqualToString:@"CallContact"]) {
        [[MLXMPPManager sharedInstance] callContact:self.contactInfo];
        MLCallScreen *call = (MLCallScreen *)[segue destinationController];
        call.contact=self.contactInfo;
        
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if([identifier isEqualToString:@"ContactDetails"]) {
        if(!self.contactInfo)
        {
            return  NO;
        }
        else {
            return YES;
        }
    } else {
        return YES;
    }
}




#pragma mark - notifications
-(void) handleConnect:(NSNotification *)notification
{
    if(self.window.isKeyWindow) {
         [[MLXMPPManager sharedInstance] setClientsActive]; 
    }
    else  {
        NSString* nameToShow=[notification.object objectForKey:@"AccountName"];
        NSUserNotification *alert =[[NSUserNotification alloc] init];
        NSString* messageString =[NSString stringWithFormat:@"Account %@ has connected.", nameToShow];
        alert.informativeText =messageString;
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:alert];
    }
    
}

-(void) showConnectionStatus:(NSNotification *) notification
{
    NSArray *payload= notification.object;
    
    NSString *message = payload[1]; // this is just the way i set it up a dic might better
   // NSError *error =payload[2];
    xmpp *xmppAccount= payload.firstObject;
    
    NSString *accountName = [NSString stringWithFormat:@"%@@%@", xmppAccount.username, xmppAccount.domain];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserNotification *alert =[[NSUserNotification alloc] init];
        alert.title= accountName;
        alert.informativeText =message;
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:alert];
    });
    
    
    
}

-(void) handleNewMessage:(NSNotification *)notification;
{
    NSNumber *showAlert =[notification.userInfo objectForKey:@"showAlert"];
    NSUserNotification *alert =[[NSUserNotification alloc] init];
    NSString* acctString =[NSString stringWithFormat:@"%ld", (long)[[notification.userInfo objectForKey:@"accountNo"] integerValue]];
    
    [[DataLayer sharedInstance] isMutedJid:[notification.userInfo objectForKey:@"from"] withCompletion:^(BOOL muted) {
        if(!muted){
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL showNotification = showAlert.boolValue;
                NSString* nameToShow=[notification.userInfo objectForKey:@"from"];
                if(self.window.occlusionState & NSWindowOcclusionStateVisible) {
                    if(self.window.isKeyWindow) {
                        if([nameToShow isEqualToString:[self.contactInfo objectForKey:kContactName]])
                        {
                            showNotification= NO;
                        }
                    }
                }
                
                if([[notification.userInfo objectForKey:@"messageType"] isEqualToString:kMessageTypeStatus])
                {
                    showNotification=NO;
                }
                
                
                if (showNotification) {
                    
                    NSString* fullName = [notification.userInfo objectForKey:@"actuallyfrom"];
                    
                    if([[notification.userInfo objectForKey:@"actuallyfrom"] isEqualToString:[notification.userInfo objectForKey:@"from"]]) {
                        fullName=[[DataLayer sharedInstance] fullName:[notification.userInfo objectForKey:@"from"] forAccount:acctString];
                        
                    }
                    if([fullName length]>0) nameToShow=fullName;
                    
                    alert.title= nameToShow;
                    if([[[NSUserDefaults standardUserDefaults] objectForKey:@"MessagePreview"] boolValue]) {
                        alert.informativeText=[notification.userInfo objectForKey:@"messageText"];
                    } else  {
                        alert.informativeText=@"Open app to see message";
                    }
                    
                    if([[[NSUserDefaults standardUserDefaults] objectForKey:@"Sound"] boolValue])
                    {
                        alert.soundName= NSUserNotificationDefaultSoundName;
                    }
                    
                    [[MLImageManager sharedInstance] getIconForContact:[notification.userInfo objectForKey:@"from"] andAccount:[notification.userInfo objectForKey:@"accountNo"] withCompletion:^(NSImage *alertImage) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            alert.contentImage= alertImage;
                            alert.hasReplyButton=YES;
                            alert.userInfo= notification.userInfo;
                            [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:alert];
                        });
                        
                        
                    }];
                    
                }
            
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[DataLayer sharedInstance] countUnreadMessagesWithCompletion:^(NSNumber * result) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([result integerValue]>0) {
                        [[[NSApplication sharedApplication] dockTile] setBadgeLabel:[NSString stringWithFormat:@"%@", result]];
                        if(!muted) {
                            [[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
                        }
                    }
                });
                
            }];
        });
        
        
    }];

    

}

#pragma mark - UI Actions
-(IBAction)showContactsTab:(id)sender
{
    [self.contactsViewController toggleContactsTab];
}

-(IBAction)showActiveChatTab:(id)sender;
{
     [self.contactsViewController toggleActiveChatTab];
}

-(IBAction)showContactDetails:(id)sender
{
    [self performSegueWithIdentifier:@"ContactDetails" sender:self];
}

-(IBAction)showAddContactSheet:(id)sender
{
    [self performSegueWithIdentifier:@"AddContact" sender:self];
}


#pragma mark - notificaiton delegate

- (void)userNotificationCenter:(NSUserNotificationCenter * )center didActivateNotification:(NSUserNotification *  )notification
{
    if(notification.activationType==NSUserNotificationActivationTypeReplied)
    {
        if(notification.response.string.length>0) {
            
            NSString *replyingAccount = [notification.userInfo objectForKey:@"to"];
            
            NSString *messageID =[[NSUUID UUID] UUIDString];
            
            BOOL encryptChat =[[DataLayer sharedInstance] shouldEncryptForJid:[notification.userInfo objectForKey:@"from"] andAccountNo:[notification.userInfo objectForKey:@"accountNo"]];
            
            [[DataLayer sharedInstance] addMessageHistoryFrom:replyingAccount to:[notification.userInfo objectForKey:@"from"] forAccount:[notification.userInfo objectForKey:@"accountNo"] withMessage:notification.response.string actuallyFrom:replyingAccount withId:messageID encrypted:encryptChat withCompletion:^(BOOL success, NSString *messageType) {
                
            }];
            
            [[MLXMPPManager sharedInstance] sendMessage:notification.response.string toContact:[notification.userInfo objectForKey:@"from"] fromAccount:[notification.userInfo objectForKey:@"accountNo"] isEncrypted:encryptChat isMUC:NO isUpload:NO messageId:messageID  withCompletionHandler:^(BOOL success, NSString *messageId) {
                
            }];
            
            [[DataLayer sharedInstance] markAsReadBuddy:[notification.userInfo objectForKey:@"from"] forAccount:[notification.userInfo objectForKey:@"accountNo"]];
        }
        
    }
    else  {
        [[MLXMPPManager sharedInstance].contactVC toggleActiveChatTab];
        [[MLXMPPManager sharedInstance].contactVC showConversationForContact:notification.userInfo];
        [self showWindow:self];
    }
}


#pragma mark - Window delegate
- (void)windowDidChangeOcclusionState:(NSNotification *)notification
{
    if ([[notification object] occlusionState]  &  NSWindowOcclusionStateVisible) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMonalWindowVisible object:nil];
        // visible
        if(self.window.isKeyWindow)
        {
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
        }
       
    } else {
        // occluded
    
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [[MLXMPPManager sharedInstance] setClientsInactive];
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
     [[MLXMPPManager sharedInstance] setClientsActive];
}

#pragma mark - quick look controller

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    panel.delegate = self.chatViewController;
    panel.dataSource = self.chatViewController;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    
}


@end
