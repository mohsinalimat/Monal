//
//  SworIMAppDelegate.m
//  SworIM
//
//  Created by Anurodh Pokharel on 11/16/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "MonalAppDelegate.h"

#import "CallViewController.h"

#import "MLNotificationManager.h"
#import "DataLayer.h"
#import "NXOAuth2AccountStore.h"
#import "MLPush.h"

@import Crashlytics;
@import Fabric;
#import <DropboxSDK/DropboxSDK.h>

//xmpp
#import "MLXMPPManager.h"
#import "UIColor+Theme.h"

@interface MonalAppDelegate ()

@property (nonatomic, strong)  UITabBarItem* activeTab;

@end

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation MonalAppDelegate


-(void) setUISettings
{
    UIColor *monalGreen = [UIColor monalGreen];
    UIColor *monaldarkGreen =[UIColor monaldarkGreen];
    [[UINavigationBar appearance] setTintColor:monalGreen];

    if (@available(iOS 11.0, *)) {
        [[UINavigationBar appearance] setPrefersLargeTitles:YES];
    }
    
    [[UITabBar appearance] setTintColor:monaldarkGreen];
}



#pragma mark -  APNS notificaion

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    
    NSString *token=[MLPush stringFromToken:deviceToken];
     [MLXMPPManager sharedInstance].hasAPNSToken=YES;
    DDLogInfo(@"APNS token string: %@", token);
    [[[MLPush alloc] init] postToPushServer:token];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DDLogError(@"push reg error %@", error);
    
}


#pragma mark - VOIP notification

-(void) voipRegistration
{
    DDLogInfo(@"registering for voip APNS...");
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    PKPushRegistry * voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
    voipRegistry.delegate = self;
    voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

// Handle updated APNS tokens
-(void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials: (PKPushCredentials *)credentials forType:(NSString *)type
{
    NSString *token=[MLPush stringFromToken:credentials.token];
     [MLXMPPManager sharedInstance].hasAPNSToken=YES;
    DDLogInfo(@"APNS voip token string: %@", token);
    [[[MLPush alloc] init] postToPushServer:token];
}

-(void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type
{
    DDLogInfo(@"didInvalidatePushTokenForType called (and ignored, TODO: disable push on server?)");
}

// Handle incoming pushes
-(void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    DDLogInfo(@"incoming voip push notfication: %@", [payload dictionaryPayload]);
    if([UIApplication sharedApplication].applicationState==UIApplicationStateActive) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
       __block UIBackgroundTaskIdentifier tempTask= [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^(void) {
           DDLogInfo(@"voip push wake expiring");
           [[UIApplication sharedApplication] endBackgroundTask:tempTask];
            tempTask=UIBackgroundTaskInvalid;
           [[MLXMPPManager sharedInstance] logoutAllKeepStreamWithCompletion:nil];
        }];
        
        [[MLXMPPManager sharedInstance] connectIfNecessary];
         DDLogInfo(@"voip push wake complete");
    });
}

#pragma mark - notification actions
-(void) showCallScreen:(NSNotification*) userInfo
{
//    dispatch_async(dispatch_get_main_queue(),
//                   ^{
//                       NSDictionary* contact=userInfo.object;
//                       CallViewController *callScreen= [[CallViewController alloc] initWithContact:contact];
//
//
//
//                       [self.tabBarController presentModalViewController:callNav animated:YES];
//                   });
}

-(void) updateUnread
{
    //make sure unread badge matches application badge
    
    [[DataLayer sharedInstance] countUnreadMessagesWithCompletion:^(NSNumber *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSInteger unread =0;
            if(result)
            {
                unread= [result integerValue];
            }
            
            if(unread>0)
            {
                self->_activeTab.badgeValue=[NSString stringWithFormat:@"%ld",(long)unread];
                [UIApplication sharedApplication].applicationIconBadgeNumber =unread;
            }
            else
            {
                self->_activeTab.badgeValue=nil;
                [UIApplication sharedApplication].applicationIconBadgeNumber =0;
            }
        });
    }];
    
}

#pragma mark - app life cycle

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
{
    completionHandler(UNNotificationPresentationOptionAlert);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
#ifdef  DEBUG
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    self.fileLogger = [[DDFileLogger alloc] init];
    self.fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    self.fileLogger.logFileManager.maximumNumberOfLogFiles = 5;
    self.fileLogger.maximumFileSize=1024 * 500;
    [DDLog addLogger:self.fileLogger];
#endif
    
    if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")){
        [UNUserNotificationCenter currentNotificationCenter].delegate=self;
    }
    
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateState:) name:kMLHasConnectedNotice object:nil];
    
    //ios8 register for local notifications and badges
    if([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)])
    {
        NSSet *categories;
        
        UIMutableUserNotificationAction *replyAction = [[UIMutableUserNotificationAction alloc] init];
        replyAction.activationMode = UIUserNotificationActivationModeBackground;
        replyAction.title = @"Reply";
        replyAction.identifier = @"ReplyButton";
        replyAction.destructive = NO;
        replyAction.authenticationRequired = NO;
        replyAction.behavior = UIUserNotificationActionBehaviorTextInput;
        
        UIMutableUserNotificationCategory *actionCategory = [[UIMutableUserNotificationCategory alloc] init];
        actionCategory.identifier = @"Reply";
        [actionCategory setActions:@[replyAction] forContext:UIUserNotificationActionContextDefault];
        
        UIMutableUserNotificationCategory *extensionCategory = [[UIMutableUserNotificationCategory alloc] init];
        extensionCategory.identifier = @"Extension";
             
        categories = [NSSet setWithObjects:actionCategory,extensionCategory,nil];
        
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound|UIUserNotificationTypeBadge categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    
    //register for voip push using pushkit
    if([UIApplication sharedApplication].applicationState!=UIApplicationStateBackground) {
          // if we are launched in the background, it was from a push. dont do this again.
//        if (@available(iOS 13.0, *)) {
//            //no more voip mode after ios 13
//            if(![[NSUserDefaults standardUserDefaults] boolForKey:@"HasUpgradedPushiOS13"]) {
//                MLPush *push = [[MLPush alloc] init];
//                [push unregisterPush];
//                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasUpgradedPushiOS13"];
//            }
//
//            [[UIApplication sharedApplication] registerForRemoteNotifications];
//           }
//           else {
                      [self voipRegistration];
   //        }
    }
    else  {
        [MLXMPPManager sharedInstance].pushNode = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushNode"];
        [MLXMPPManager sharedInstance].pushSecret=[[NSUserDefaults standardUserDefaults] objectForKey:@"pushSecret"];
        [MLXMPPManager sharedInstance].hasAPNSToken=YES;
           NSLog(@"push node %@", [MLXMPPManager sharedInstance].pushNode); 
    }
    
    [self setUISettings];
    
    [MLNotificationManager sharedInstance].window=self.window;
    
    // should any accounts connect?
    [[MLXMPPManager sharedInstance] connectIfNecessary];
    
    BOOL optout = [[NSUserDefaults standardUserDefaults] boolForKey:@"CrashlyticsOptOut"];
    if(!optout) {
        [Fabric with:@[[Crashlytics class]]];
    }
    
    //update logs if needed
    if(! [[NSUserDefaults standardUserDefaults] boolForKey:@"Logging"])
    {
        [[DataLayer sharedInstance] messageHistoryCleanAll];
    }
    
    //Dropbox
    DBSession *dbSession = [[DBSession alloc]
                            initWithAppKey:@"a134q2ecj1hqa59"
                            appSecret:@"vqsf5vt6guedlrs"
                            root:kDBRootAppFolder];
    [DBSession setSharedSession:dbSession];
    
    DDLogInfo(@"App started");
    return YES;
}

-(void) applicationDidBecomeActive:(UIApplication *)application
{
    //  [UIApplication sharedApplication].applicationIconBadgeNumber=0;
}

#pragma mark - handling urls

-(BOOL) openFile:(NSURL *) file {
    NSData *data = [NSData dataWithContentsOfURL:file];
    [[MLXMPPManager sharedInstance] parseMessageForData:data];
    return data?YES:NO;
}


- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
    if([url.scheme isEqualToString:@"file"])
    {
        return [self openFile:url];
    }
    if([url.scheme isEqualToString:@"xmpp"])
    {
        return YES;
    }
    if([url.scheme isEqualToString:@"com.googleusercontent.apps.472865344000-invcngpma1psmiek5imc1gb8u7mef8l9"])
    {
        [[NXOAuth2AccountStore sharedStore] handleRedirectURL:url];
        return YES;
    }
    else  {
        
        if ([[DBSession sharedSession] handleOpenURL:url]) {
            if ([[DBSession sharedSession] isLinked]) {
                DDLogVerbose(@"App linked successfully!");
                // At this point you can start making API calls
            }
            return YES;
        }
    }
    
    return NO;
}




#pragma mark  - user notifications
-(void) application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    DDLogVerbose(@"did register for local notifications");
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    DDLogVerbose(@"entering app with %@", notification);
    
    //iphone
    //make sure tab 0 for chat
    if([notification.userInfo objectForKey:@"from"]) {
        [self.tabBarController setSelectedIndex:0];
       [[MLXMPPManager sharedInstance].contactVC presentChatWithName:[notification.userInfo objectForKey:@"from"] account:[notification.userInfo objectForKey:@"accountNo"] ];
    }
}


-(void) application:(UIApplication *)application handleActionWithIdentifier:(nullable NSString *)identifier forLocalNotification:(nonnull UILocalNotification *)notification withResponseInfo:(nonnull NSDictionary *)responseInfo completionHandler:(nonnull void (^)())completionHandler
{
    if ([notification.category isEqualToString:@"Reply"]) {
        if ([identifier isEqualToString:@"ReplyButton"]) {
            NSString *message = responseInfo[UIUserNotificationActionResponseTypedTextKey];
            if (message.length > 0) {
                
                if([notification.userInfo objectForKey:@"from"]) {
                    
                    NSString *replyingAccount = [notification.userInfo objectForKey:@"to"];
                    
                    NSString *messageID =[[NSUUID UUID] UUIDString];
                    
                    BOOL encryptChat =[[DataLayer sharedInstance] shouldEncryptForJid:[notification.userInfo objectForKey:@"from"] andAccountNo:[notification.userInfo objectForKey:@"accountNo"]];
                    
                    [[DataLayer sharedInstance] addMessageHistoryFrom:replyingAccount to:[notification.userInfo objectForKey:@"from"] forAccount:[notification.userInfo objectForKey:@"accountNo"] withMessage:message actuallyFrom:replyingAccount withId:messageID encrypted:encryptChat withCompletion:^(BOOL success, NSString *messageType) {
                        
                    }];
                    
                    [[MLXMPPManager sharedInstance] sendMessage:message toContact:[notification.userInfo objectForKey:@"from"] fromAccount:[notification.userInfo objectForKey:@"accountNo"] isEncrypted:encryptChat isMUC:NO isUpload:NO messageId:messageID  withCompletionHandler:^(BOOL success, NSString *messageId) {
                        
                    }];
                    
                    [[DataLayer sharedInstance] markAsReadBuddy:[notification.userInfo objectForKey:@"from"] forAccount:[notification.userInfo objectForKey:@"accountNo"]];
                    [self updateUnread];
                    
                }
                
                
            }
        }
    }
    if(completionHandler) completionHandler();
}



#pragma mark - memory
-(void) applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[MLImageManager sharedInstance] purgeCache];
}

#pragma mark - backgrounding

-(void) updateState:(NSNotification *) notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateInactive || state == UIApplicationStateBackground) {
            [[MLXMPPManager sharedInstance] setClientsInactive];
        } else {
             [[MLXMPPManager sharedInstance] setClientsActive];
        }
    });
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    DDLogVerbose(@"Entering FG");
 
    [[MLXMPPManager sharedInstance] resetForeground];
    [[MLXMPPManager sharedInstance] setClientsActive];
    [[MLXMPPManager sharedInstance] sendMessageForConnectedAccounts];
}

-(void)applicationWillResignActive:(UIApplication *)application
{
     NSUserDefaults *groupDefaults= [[NSUserDefaults alloc] initWithSuiteName:@"group.monal"];
    [[DataLayer sharedInstance] activeContactsWithCompletion:^(NSMutableArray *cleanActive) {
        [groupDefaults setObject:cleanActive forKey:@"recipients"];
        [groupDefaults synchronize];
    }];
    
    [groupDefaults setObject:[[DataLayer sharedInstance] enabledAccountList] forKey:@"accounts"];
    [groupDefaults synchronize];
}

-(void) applicationDidEnterBackground:(UIApplication *)application
{
    UIApplicationState state = [application applicationState];
    if (state == UIApplicationStateInactive) {
        DDLogVerbose(@"Screen lock");
    } else if (state == UIApplicationStateBackground) {
        DDLogVerbose(@"Entering BG");
    }
    
    [self updateUnread];
    [[MLXMPPManager sharedInstance] setClientsInactive];

}

-(void)applicationWillTerminate:(UIApplication *)application
{
    [self updateUnread];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - splitview controller delegate
- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return NO;
}

@end

