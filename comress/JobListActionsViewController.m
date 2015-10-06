//
//  JobListActionsViewController.m
//  comress
//
//  Created by Diffy Romano on 30/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "JobListActionsViewController.h"

@interface JobListActionsViewController ()
@property (nonatomic, weak) IBOutlet UITableView *actionsTableView;
@property (nonatomic, strong) NSMutableArray *menuList;
@end

@implementation JobListActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _menuList = [[NSMutableArray alloc] init];
    
    [_menuList addObject:@"Scan/Report Missing QR Code"];
    [_menuList addObject:@"Check Roof Access"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _menuList.count;
}


 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
     static NSString *cellIdentifier = @"cell";
     
     UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
     
     if(cell == nil)
     {
         cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
     }
     
     //config cell

     cell.textLabel.text = [_menuList objectAtIndex:indexPath.row];
     
     return cell;
 }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row == 0)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didTapScanReportQRCode" object:nil];
    }
    else if (indexPath.row == 1)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"didTapRoofAccess" object:nil];
    }
}



@end
