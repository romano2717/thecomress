//
//  ScheduleActionsViewController.m
//  comress
//
//  Created by Diffy Romano on 16/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "ScheduleActionsViewController.h"

@interface ScheduleActionsViewController ()<UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *actionsTableView;

@property (nonatomic, strong) NSArray *actionsArray;
@property (nonatomic, strong) NSMutableArray *disabledRowsArray;

@end

@implementation ScheduleActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _actionsArray = [NSArray arrayWithObjects:@"Start",@"Perform Checklist",@"Complete",@"Cancel", nil];
    
    _disabledRowsArray = [[NSMutableArray alloc] init];
    
    int status = [[_scheduleDict valueForKeyPath:@"SUPSchedule.Status"] intValue];
    
    if(status == 2)//started
        [_disabledRowsArray addObject:[NSNumber numberWithInt:0]];
    
    if(status == 1)//new
    {
        [_disabledRowsArray addObject:[NSNumber numberWithInt:1]];
        [_disabledRowsArray addObject:[NSNumber numberWithInt:2]];
    }
    
    if(status == 3)//complete
    {
        [_disabledRowsArray addObject:[NSNumber numberWithInt:0]];
        [_disabledRowsArray addObject:[NSNumber numberWithInt:1]];
        [_disabledRowsArray addObject:[NSNumber numberWithInt:2]];
    }
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
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return _actionsArray.count;
}


 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
     static NSString *cellIdentifier = @"cell";
     
     UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
     
     if(cell == nil)
     {
         cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
     }
     
     //config cell
     
     cell.backgroundColor = [UIColor whiteColor];
     cell.textLabel.textColor = [UIColor blackColor];
     cell.userInteractionEnabled = YES;
     
     if([_disabledRowsArray containsObject:[NSNumber numberWithInteger:indexPath.row]])
     {
         cell.backgroundColor = [UIColor grayColor];
         cell.textLabel.textColor = [UIColor whiteColor];
         cell.userInteractionEnabled = NO;
     }
     
     //display text
     cell.textLabel.text = [_actionsArray objectAtIndex:indexPath.row];

     return cell;
 }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"setScheduleAction" object:nil userInfo:@{@"action":[_actionsArray objectAtIndex:indexPath.row]}];
}

@end
