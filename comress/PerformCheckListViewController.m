//
//  PerformCheckListViewController.m
//  comress
//
//  Created by Diffy Romano on 16/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "PerformCheckListViewController.h"

@interface PerformCheckListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) IBOutlet STCollapseTableView *checkListTableView;
@property (nonatomic, weak) IBOutlet UIButton *checkAllBtn;

@property (nonatomic, strong) NSArray *checkListArray;
@property (nonatomic, strong) NSArray *checkAreaArray;

@property (nonatomic, strong) NSMutableArray *checkedCheckListArray;
@property (nonatomic, strong) NSMutableArray *checkedCheckListAllSectionArray;


@property (nonatomic) BOOL checkListWasModified;

@end

@implementation PerformCheckListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    routineSync = [RoutineSynchronize sharedRoutineSyncManager];
    
    _checkedCheckListArray = [[NSMutableArray alloc] init];
    _checkedCheckListAllSectionArray = [[NSMutableArray alloc] init];
    
    _checkListArray = [_scheduleDict objectForKey:@"CheckListArray"];
    _checkAreaArray = [[NSOrderedSet orderedSetWithArray:[_checkListArray valueForKey:@"CheckArea"]] array];
    
    //don't include blank checkArea
    NSMutableArray *checkAreaTemp = [[NSMutableArray alloc] init];
    for (NSString *string in _checkAreaArray) {
        if(string.length > 1)
            [checkAreaTemp addObject:string];
    }
    _checkAreaArray = checkAreaTemp;
    
    if(_checkAreaArray.count > 0)
    {
        NSMutableArray *groupedCheckList = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < _checkAreaArray.count; i++) {
            NSString *checkArea = [_checkAreaArray objectAtIndex:i];
            
            NSMutableArray *row = [[NSMutableArray alloc] init];
            
            for (NSDictionary *dict in _checkListArray) {
                NSString *theCheckArea = [dict valueForKey:@"CheckArea"];
                
                if([checkArea isEqualToString:theCheckArea])
                {
                    [row addObject:dict];
                }
            }
            
            [groupedCheckList addObject:row];
        }
        
        _checkListArray = groupedCheckList;
    }
    
    [_checkListTableView setExclusiveSections:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didTapSectionNotification:) name:@"didTapSectionNotification" object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_checkListTableView openSection:0 animated:NO];
    
    
    //pre select/add selected checklist/checkarea
    if(_checkAreaArray.count > 0)
    {
        for (int i = 0; i < _checkListArray.count; i++) {
            
            BOOL checkedAllUnderSection = YES;
            
            NSArray *arr = [_checkListArray objectAtIndex:i];
            
            for (NSDictionary *dict in arr) {
                BOOL isChecked = [[dict valueForKey:@"IsCheck"] boolValue];
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                
                if(isChecked == NO)
                {
                    checkedAllUnderSection = NO;
                    continue;
                }
                else
                {
                    if([_checkedCheckListArray containsObject:checkListId] == NO)
                        [_checkedCheckListArray addObject:checkListId];
                }
                
            }
            
            if(checkedAllUnderSection == YES)
            {
                if([_checkedCheckListAllSectionArray containsObject:[NSNumber numberWithInt:i]] == NO)
                    [_checkedCheckListAllSectionArray addObject:[NSNumber numberWithInt:i]];
            }
            
        }
        
        if(_checkAreaArray.count == _checkedCheckListAllSectionArray.count)
            _checkAllBtn.selected = YES;
    }
    else
    {
        for (NSDictionary *dict in _checkListArray) {
            BOOL isChecked = [[dict valueForKey:@"IsCheck"] boolValue];
            NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
            
            if(isChecked == YES)
            {
                if([_checkedCheckListArray containsObject:checkListId] == NO)
                    [_checkedCheckListArray addObject:checkListId];
            }
            
        }

        if(_checkedCheckListArray.count == _checkListArray.count)
            _checkAllBtn.selected = YES;
    }
    
    [_checkListTableView reloadData];
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

- (void)didTapSectionNotification:(NSNotification *)notif
{
    _checkListWasModified = YES;
    
    NSDictionary *dict = [notif userInfo];
    
    NSNumber *section = [dict objectForKey:@"section"];
    NSNumber *tapAtXArea = [dict objectForKey:@"tapAtXArea"];
    
    if([tapAtXArea intValue] <= 25)
    {
        
        if([_checkedCheckListAllSectionArray containsObject:section] == NO)
        {
            [_checkedCheckListAllSectionArray addObject:section];
            
            NSArray *checLst = [_checkListArray objectAtIndex:[section integerValue]];
            
            for (NSDictionary *dict in checLst) {
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                
                [_checkedCheckListArray addObject:checkListId];
            }
        }
        
        else
        {
            [_checkedCheckListAllSectionArray removeObject:section];
            
            NSArray *checLst = [_checkListArray objectAtIndex:[section integerValue]];
            
            for (NSDictionary *dict in checLst) {
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                
                [_checkedCheckListArray removeObject:checkListId];
            }
        }
        
        [_checkListTableView openSection:[section integerValue] animated:YES];
        
        
        if(_checkAreaArray.count > 0)
        {
            if(_checkedCheckListAllSectionArray.count == _checkAreaArray.count)
                [self checkAll:self];
            else
                _checkAllBtn.selected = NO;
        }
        else
        {
            if(_checkListArray.count == _checkedCheckListArray.count)
                [self checkAll:self];
            else
                _checkAllBtn.selected = NO;
        }
    }
    
    [_checkListTableView reloadData];
}

#pragma mark - Table view data source


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if(_checkAreaArray.count > 0)
        return 42.0f;
    return 0.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    // Return the number of sections.
    if(_checkAreaArray.count > 0)
        return _checkAreaArray.count;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    // Return the number of rows in the section.
    if(_checkAreaArray.count == 0)
        return _checkListArray.count;
    return [[_checkListArray objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_checkAreaArray objectAtIndex:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIImage *checkedImage = [UIImage imageNamed:@"check"];
    
    if([_checkedCheckListAllSectionArray containsObject:[NSNumber numberWithInteger:section]])
        checkedImage = [UIImage imageNamed:@"checked"];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    
    btn.frame = CGRectMake(0, 0, self.view.frame.size.width, 42.0f);
    [btn setTitle:[NSString stringWithFormat:@" %@",[_checkAreaArray objectAtIndex:section]] forState:UIControlStateNormal];
    [btn setImage:checkedImage forState:UIControlStateNormal];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.backgroundColor = [UIColor lightGrayColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    btn.tag = section;
    [btn.layer setBorderWidth:0.5f];
    [btn.layer setBorderColor:[UIColor whiteColor].CGColor];
    
    return btn;
}

 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
     static NSString *cellIdentifier = @"cell";
     
     CheckListCustomCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
     
     NSArray *theCheckListArray;

     if(_checkAreaArray.count > 0)
         theCheckListArray = [[_checkListArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
     else
         theCheckListArray = [_checkListArray objectAtIndex:indexPath.row];
     
     NSDictionary *dict = @{@"checkListArray":theCheckListArray,@"checked":_checkedCheckListArray,@"wasModified":[NSNumber numberWithBool:_checkListWasModified]};

     [cell initCellWithResultSet:dict];
     
     return cell;
 }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    if(_checkAreaArray.count == 0)
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateCheckList" object:nil userInfo:@{@"checkeCheckList":_checkedCheckListArray}];
//    else
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateCheckList" object:nil userInfo:@{@"checkeCheckList":[[_checkedCheckListArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]}];
}

- (IBAction)cancel:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateCheckList" object:nil userInfo:nil];
}

- (IBAction)save:(id)sender
{
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        BOOL up = NO;
        NSNumber *scheduleId = [NSNumber numberWithInt:[[_scheduleDict valueForKeyPath:@"SUPSchedule.ScheduleId"] intValue]];
        
        if(_checkAreaArray.count > 0)
        {
            for (NSArray *arr in _checkListArray) {
                for (NSDictionary *dict in arr) {
                    NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                    
                    NSNumber *toggle = [NSNumber numberWithBool:NO];
                    
                    if([_checkedCheckListArray containsObject:checkListId])
                        toggle = [NSNumber numberWithBool:YES];
                    DDLogVerbose(@"_checkedCheckListArray %@",_checkedCheckListArray);
                    db.traceExecution = YES;
                    up = [db executeUpdate:@"update rt_checklist set is_checked = ? where checklist_id = ? and schedule_id = ?",toggle,checkListId,scheduleId];
                    db.traceExecution = NO;
                    DDLogVerbose(@"row affected %d",[db changes]);
                    
                }
            }
        }
        
        else
        {
            for (NSDictionary *dict in _checkListArray) {
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                
                NSNumber *toggle = [NSNumber numberWithBool:NO];
                
                if([_checkedCheckListArray containsObject:checkListId])
                    toggle = [NSNumber numberWithBool:YES];
                
                DDLogVerbose(@"save _checkedCheckListArray %@",_checkedCheckListArray);
                db.traceExecution = NO;
                up = [db executeUpdate:@"update rt_checklist set is_checked = ? where checklist_id = ? and schedule_id = ?",toggle,checkListId,scheduleId];
                db.traceExecution = NO;
                FMResultSet *rs = [db executeQuery:@"select * from rt_checklist where checklist_id = ? and schedule_id = ?",checkListId,scheduleId];
                [rs next];
                DDLogVerbose(@"after update %@",[rs resultDictionary]);
            }
        }

        if(up == YES)
        {
            NSNumber *needToSync = [NSNumber numberWithInt:2];
            
            BOOL up2 = [db executeUpdate:@"update rt_schedule_detail set checklist_sync_flag = ? where schedule_id",needToSync,scheduleId];
            
            if(!up2)
            {
                *rollback = YES;
                return;
            }
        }
    }];
    
    [AGPushNoteView showWithNotificationMessage:@"Checklist Updated!"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateCheckList" object:nil userInfo:@{@"checkeCheckList":_checkedCheckListArray}];
}
 

- (IBAction)checkAll:(id)sender
{
    _checkListWasModified = YES;
    
    _checkAllBtn.selected = !_checkAllBtn.selected;
    
    
    [_checkedCheckListAllSectionArray removeAllObjects];
    [_checkedCheckListArray removeAllObjects];
    
    if(_checkAllBtn.selected == YES)
    {
        //check all!
        for (int i = 0; i < _checkAreaArray.count; i++) {
            [_checkedCheckListAllSectionArray addObject:[NSNumber numberWithInt:i]];
        }
        
        if(_checkAreaArray.count > 0)
        {
            for (int i = 0; i < _checkListArray.count; i++) {
                NSArray *arr = [_checkListArray objectAtIndex:i];
                
                for (NSDictionary *dict in arr) {
                    NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                    
                    [_checkedCheckListArray addObject:checkListId];
                }
            }
        }
        else
        {
            for (NSDictionary *dict in _checkListArray) {
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];
                
                [_checkedCheckListArray addObject:checkListId];
            }
        }
    }
    
    
    [_checkListTableView reloadData];
}

- (IBAction)toggleCheckList:(id)sender
{
    _checkListWasModified = YES;

    UIButton *btn = sender;
    
    btn.selected = !btn.selected;
    
    NSIndexPath *indexPath = [_checkListTableView indexPathForCell:(UITableViewCell *)btn.superview.superview];
    
    NSNumber *checkListId;
    
    if(_checkAreaArray.count > 0)
        checkListId = [[[_checkListArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] valueForKey:@"CheckListId"];
    else
        checkListId = [[_checkListArray objectAtIndex:indexPath.row] valueForKey:@"CheckListId"];
    
    [_checkedCheckListArray removeObject:checkListId];

    if(btn.selected && [_checkedCheckListArray containsObject:checkListId] == NO)
        [_checkedCheckListArray addObject:checkListId];
    
    if(_checkAreaArray.count > 0)
    {
        [_checkedCheckListAllSectionArray removeAllObjects];
        
        for (int i = 0; i < _checkListArray.count; i++) {
            
            BOOL checkedAllUnderSection = YES;
            
            NSArray *arr = [_checkListArray objectAtIndex:i];
            
            for (NSDictionary *dict in arr) {
                NSNumber *checkListId = [NSNumber numberWithInt:[[dict valueForKey:@"CheckListId"] intValue]];

                if([_checkedCheckListArray containsObject:checkListId] == NO)
                {
                    checkedAllUnderSection = NO;
                    break;
                }
            }
            
            if(checkedAllUnderSection == YES)
                [_checkedCheckListAllSectionArray addObject:[NSNumber numberWithInt:i]];
        }
        
        if(_checkedCheckListAllSectionArray.count == _checkAreaArray.count)
            [self checkAll:sender];
        else
            _checkAllBtn.selected = NO;
    }
    
    else
    {
        if(_checkListArray.count == _checkedCheckListArray.count)
            [self checkAll:sender];
        else
            _checkAllBtn.selected = NO;
    }
    
    DDLogVerbose(@"selected %@",_checkedCheckListArray);
    
    [_checkListTableView reloadData];
}


@end
