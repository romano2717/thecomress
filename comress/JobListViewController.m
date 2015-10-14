//
//  JobListViewController.m
//  comress
//
//  Created by Diffy Romano on 4/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "JobListViewController.h"

@interface JobListViewController ()<UITableViewDataSource, UITableViewDelegate, MZFormSheetBackgroundWindowDelegate>

@property (nonatomic, weak) IBOutlet UITableView *jobListTableView;

@property (nonatomic, strong) NSArray *jobList;
@property (nonatomic, strong) NSDictionary *SchedulesContainer;
@property (nonatomic, strong) UIImagePickerController *imagePicker;

@end

@implementation JobListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didScanQrCodeForJobList:) name:@"didScanQrCodeForJobList" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didTapScanReportQRCode:) name:@"didTapScanReportQRCode" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didTapRoofAccess:) name:@"didTapRoofAccess" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didScanQRCodeForRoofAccessCheck:) name:@"didScanQRCodeForRoofAccessCheck" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getJobList) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
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

-(void)didScanQRCodeForRoofAccessCheck:(NSNotification *)notif
{
    NSDictionary *dict = [notif userInfo];
    
    NSDictionary *params = @{@"blkId":[NSNumber numberWithInt:[[_scheduleDetailDict valueForKey:@"blk_id"] intValue]],@"qrcode":[dict valueForKey:@"scanValue"]};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_check_roof_qr_code] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        int RoofCheckSNO = [[responseObject valueForKey:@"RoofCheckSNO"] intValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(RoofCheckSNO == 0)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"COMRESS" message:@"Invalid QR Code" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
                
                [alert show];
            }
            else
            {
                [self performSegueWithIdentifier:@"push_roof_info" sender:[NSNumber numberWithInt:RoofCheckSNO]];
            }
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"COMRESS" message:@"Request error. Please try again" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
        
        [alert show];
    }];
}

-(void)didTapScanReportQRCode:(NSNotification *)notif
{
    [self mz_dismissFormSheetControllerAnimated:YES completionHandler:^(MZFormSheetController *formSheetController) {
        [self QrList:self];
    }];
}

-(void)didTapRoofAccess:(NSNotification *)notif
{
    [self mz_dismissFormSheetControllerAnimated:YES completionHandler:^(MZFormSheetController *formSheetController) {
        [self performSegueWithIdentifier:@"push_qr_code_scanning_roof_access" sender:self];
    }];
}

- (void)didScanQrCodeForJobList:(NSNotification *)notif
{
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
    else if ([segue.identifier isEqualToString:@"push_roof_info"])
    {
        RoofAccessInfoViewController *roofAccess = [segue destinationViewController];
        roofAccess.scheduleDict = _scheduleDetailDict;
        roofAccess.roofSNo = sender;
    }
    else if ([segue.identifier isEqualToString:@"push_qr_code_scanning_roof_access"])
    {
        QRCodeScanningViewController *qrCodeScanning = [segue destinationViewController];
        qrCodeScanning.scheduleDetailDict = _scheduleDetailDict;
        qrCodeScanning.scanQrCodeForRoofCheckAccess = YES;
    }
}


- (void)getJobList
{
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
    
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
            
            [self.navigationItem.rightBarButtonItem setEnabled:YES];
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
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

- (IBAction)jobListActions:(id)sender
{
    JobListActionsViewController *jobListAction = [self.storyboard instantiateViewControllerWithIdentifier:@"JobListActionsViewController"];
    
    MZFormSheetController *formSheet = [[MZFormSheetController alloc] initWithViewController:jobListAction];
    
    formSheet.presentedFormSheetSize = CGSizeMake(300, 180);
    formSheet.shadowRadius = 2.0;
    formSheet.shadowOpacity = 0.3;
    formSheet.shouldDismissOnBackgroundViewTap = YES;
    formSheet.shouldCenterVertically = YES;
    formSheet.movementWhenKeyboardAppears = MZFormSheetWhenKeyboardAppearsCenterVertically;
    
    // If you want to animate status bar use this code
    formSheet.didTapOnBackgroundViewCompletionHandler = ^(CGPoint location) {
        
    };
    
    formSheet.willPresentCompletionHandler = ^(UIViewController *presentedFSViewController) {
        DDLogVerbose(@"will present");
    };
    formSheet.transitionStyle = MZFormSheetTransitionStyleCustom;
    
    [MZFormSheetController sharedBackgroundWindow].formSheetBackgroundWindowDelegate = self;
    
    [self mz_presentFormSheetController:formSheet animated:YES completionHandler:^(MZFormSheetController *formSheetController) {
        DDLogVerbose(@"did present");
    }];
    
    formSheet.willDismissCompletionHandler = ^(UIViewController *presentedFSViewController) {
        DDLogVerbose(@"will dismiss");
    };
}

@end
