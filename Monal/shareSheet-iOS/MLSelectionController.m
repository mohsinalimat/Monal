//
//  MLSelectionController.m
//  Monal
//
//  Created by Anurodh Pokharel on 10/26/18.
//  Copyright © 2018 Monal.im. All rights reserved.
//

#import "MLSelectionController.h"

@interface MLSelectionController ()

@end

@implementation MLSelectionController

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.options.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"option" forIndexPath:indexPath];
   NSDictionary *row = self.options[indexPath.row];
    
    if([row objectForKey:@"buddy_name"]) {
        cell.textLabel.text = [row objectForKey:@"full_name"];
        if([[self.selection objectForKey:@"buddy_name"] isEqualToString: [row objectForKey:@"buddy_name"]]) {
            cell.accessoryType=UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType= UITableViewCellAccessoryNone;
        }
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"%@@%@",[row objectForKey:@"username"],[row objectForKey:@"domain"]];
        if([[self.selection objectForKey:@"account_id"] integerValue]==[[row objectForKey:@"account_id"] integerValue]) {
            cell.accessoryType=UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType= UITableViewCellAccessoryNone;
        }
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selection= self.options[indexPath.row];
    [tableView reloadData];
    if(self.completion) {
        self.completion(self.selection);
    }
}


@end
