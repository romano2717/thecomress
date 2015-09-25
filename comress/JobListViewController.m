//
//  JobListViewController.m
//  comress
//
//  Created by Diffy Romano on 4/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "JobListViewController.h"

@interface JobListViewController ()<UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *jobListTableView;
@property (nonatomic, strong) NSArray *jobList;
@property (nonatomic, strong) NSDictionary *SchedulesContainer;
@end

@implementation JobListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didScanQrCodeForJobList:) name:@"didScanQrCodeForJobList" object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self getJobList];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)didScanQrCodeForJobList:(NSNotification *)notif
{
//    {
//        location = "<+1.38922977,+103.84968376> +/- 65.00m (speed -1.00 mps / course -1.00) @ 23/9/15, 4:17:44 PM Singapore Standard Time";
//        scanValue = "980_HLC_SCAN_GEN 100652";
//        scheduleDict =     {
//            IsUnlock = 1;
//            Noti = "";
//            ScheduledDate = 1442937600;
//            TotalJob = 1;
//            "blk_id" = 980;
//            blockDesc = "BLK31 Holland Close";
//            "block_id" = 980;
//            "user_id" = bv1;
//        };
//    }
    
    NSDictionary *dict = [notif userInfo];
    
    //check if this qr code is present in rt_qr_code, if so, get the resultset then save it to rt_scanned_qr_code, else display error msg
    
    NSNumber *blockId = [NSNumber numberWithInt:[[dict valueForKeyPath:@"scheduleDict.blk_id"] intValue]];
    NSString *qrCode = [dict valueForKey:@"scanValue"];
    
    __block NSDictionary *qrCodeDict;
    
    __block BOOL qrCodeFound = NO;
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"select * from rt_qr_code where blk_id = ? and qrCode = ?",blockId,qrCode];
        
        while([rs next])
        {
            qrCodeFound = YES;
            qrCodeDict = [rs resultDictionary];
        }

    }];
    
    if(qrCodeFound == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"COMRESS" message:@"Invalid QR Code" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    else
    {
        [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
            NSNumber *scanChkListBlkId = [NSNumber numberWithInt:[[qrCodeDict valueForKey:@"scanChkListBlkId"] intValue]];
            
            BOOL ins = [db executeUpdate:@"insert into rt_scanned_qr_code(block_id,scanChkListBlkId) values (?,?)",blockId,scanChkListBlkId];
            
            if(!ins)
            {
                *rollback = YES;
                return;
            }
        }];
    }
    
    RoutineSynchronize *routineSync = [RoutineSynchronize sharedRoutineSyncManager];
    [routineSync uploadScannedQrCodeFromSelf:NO];
}

- (void)reloadJobListTable
{
    [_jobListTableView reloadData];
    
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    
    self.title = [_SchedulesContainer valueForKey:@"BlockName"];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if([segue.identifier isEqualToString:@"push_schedule_detail"])
    {
        NSIndexPath *indexPath = sender;
        
        SchedDetailViewController *skedDetail = [segue destinationViewController];
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[_jobList objectAtIndex:indexPath.row]];
        [dict setObject:[_scheduleDetailDict valueForKey:@"blockDesc"] forKey:@"blockDesc"];
        
        skedDetail.jobDetailDict = dict;
    }
    
    else if ([segue.identifier isEqualToString:@"push_scan_qr_code"])
    {
        ScanQrCodeViewController *scanQr = [segue destinationViewController];
        scanQr.scheduleDetailDict = _scheduleDetailDict;
        scanQr.blockId = sender;
    }
    
}


- (void)getJobList
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    NSNumber *blockId = [NSNumber numberWithInt:[[_scheduleDetailDict valueForKey:@"blk_id"] intValue]];
    NSDate *scheduleDate = [NSDate dateWithTimeIntervalSince1970:[[_scheduleDetailDict valueForKey:@"ScheduledDate"] doubleValue]];
    NSString *scheduleDateString = [myDatabase createWcfDateWithNsDate:scheduleDate];
    
    NSDictionary *params = @{@"blkId":blockId,@"scheduleDate":scheduleDateString};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_get_job_list_for_block] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        _SchedulesContainer = [responseObject objectForKey:@"SchedulesContainer"];
        
        _jobList = [_SchedulesContainer objectForKey:@"ScheduleList"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadJobListTable];
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return _jobList.count;
}


 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
     static NSString *cellIdentifier = @"cell";
     
     JobListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
     
     NSDictionary *dict = [_jobList objectAtIndex:indexPath.row];
     
     [cell initCellWithResultSet:dict];
 
     return cell;
 }

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueWithIdentifier:@"push_schedule_detail" sender:indexPath];
}

- (IBAction)QrList:(id)sender
{
    NSNumber *blockId = [NSNumber numberWithInt:[[_scheduleDetailDict valueForKey:@"blk_id"] intValue]];
    
    [self performSegueWithIdentifier:@"push_scan_qr_code" sender:blockId];
}

@end
