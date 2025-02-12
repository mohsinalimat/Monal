//
//  MLGroupChatTableViewController.m
//  Monal
//
//  Created by Anurodh Pokharel on 3/25/18.
//  Copyright © 2018 Monal.im. All rights reserved.
//

#import "MLGroupChatTableViewController.h"
#import "MLXMPPManager.h"
#import "DataLayer.h"
#import "xmpp.h"
#import "MLEditGroupViewController.h"

@interface MLGroupChatTableViewController ()

@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) NSDictionary *toEdit; 


@end

@implementation MLGroupChatTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    self.splitViewController.preferredDisplayMode=UISplitViewControllerDisplayModeAllVisible;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) refresh
{
    self.favorites = [[NSMutableArray alloc] init];
    for(NSDictionary *row in [MLXMPPManager sharedInstance].connectedXMPP)
    {
        xmpp *account = [row objectForKey:kXmppAccount];
        [[DataLayer sharedInstance] mucFavoritesForAccount:account.accountNo withCompletion:^(NSMutableArray *results) {
            [self.favorites addObjectsFromArray:results];
            dispatch_async(dispatch_get_main_queue(),^(){
                [self.tableView reloadData];
            });
            
        }];
    }
}

-(void) viewWillAppear:(BOOL)animated
{
    [self refresh];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Favorite Group Chats (MUC). Tap to join. ";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.favorites.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ListItem" forIndexPath:indexPath];
    
    NSDictionary *dic = self.favorites[indexPath.row];
    
    NSMutableString *cellText = [NSMutableString stringWithFormat:@"%@ on %@", [dic objectForKey:@"nick"], [dic objectForKey:@"room"]];
    
    NSNumber *autoJoin = [dic objectForKey:@"autojoin"];
    
    if(autoJoin.boolValue)
    {
        cell.detailTextLabel.text= @"(autojoin)";
    }
    else  {
        cell.detailTextLabel.text= @"";
    }
    
    cell.textLabel.text = cellText;
    cell.accessoryType=UITableViewCellAccessoryDetailButton;
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
       NSDictionary *dic = self.favorites[indexPath.row];
    
    NSNumber *account=[dic objectForKey:@"account_id"];
    [[MLXMPPManager sharedInstance] joinRoom:[dic objectForKey:@"room"] withNick:[dic objectForKey:@"nick"]  andPassword:@"" forAccounId:account.integerValue ];
    [[DataLayer sharedInstance] addContact:[dic objectForKey:@"room"] forAccount:[NSString stringWithFormat:@"%@", account] fullname:@"" nickname:[dic objectForKey:@"nick"] withCompletion:^(BOOL success) {
        
        [[DataLayer sharedInstance] updateOwnNickName:[dic objectForKey:@"nick"] forMuc:[dic objectForKey:@"room"] forAccount:[NSString stringWithFormat:@"%@", account]];
        
    }];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}

-(void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
     NSDictionary *dic = self.favorites[indexPath.row];
    self.toEdit=dic;
    [self performSegueWithIdentifier:@"editGroup" sender:self];
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSDictionary *dic = self.favorites[indexPath.row];
        
        NSNumber *account=[dic objectForKey:@"account_id"];
  
        [[DataLayer sharedInstance] deleteMucFavorite:[dic objectForKey:@"mucid"] forAccountId:account.integerValue withCompletion:^(BOOL success) {

        }];
 
        [self.favorites removeObjectAtIndex:indexPath.row];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
        });
        
        
    }
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 
    if([segue.identifier isEqualToString:@"editGroup"])
    {
        UINavigationController *nav=segue.destinationViewController;
        MLEditGroupViewController *editor = (MLEditGroupViewController *)nav.topViewController;
        
        editor.groupData=self.toEdit;
        
    }
}


#pragma mark - empty data set

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"wind"];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"No groups yet";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"When you have some favorite groups, they will be here for you.";
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    if (@available(iOS 11.0, *)) {
          return [UIColor colorNamed:@"groups"];
      } else {
    return  [UIColor colorWithRed:255/255.0 green:250/255.0 blue:226/255.0 alpha:1];
      }
}

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    return self.favorites.count==0?YES:NO;
}

@end
