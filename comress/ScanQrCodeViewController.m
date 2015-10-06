//
//  ScanQrCodeViewController.m
//  comress
//
//  Created by Diffy Romano on 23/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "ScanQrCodeViewController.h"

@interface ScanQrCodeViewController ()

@property (nonatomic, weak) IBOutlet UITableView *qrCodeTableView;
@property (nonatomic, strong) NSArray *qrCodeListArray;

@end

@implementation ScanQrCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"select block_no, street_name from blocks where block_id = ?",_blockId];
        
        while ([rs next]) {
            self.title = [NSString stringWithFormat:@"%@ %@",[rs stringForColumn:@"block_no"],[rs stringForColumn:@"street_name"]];
        }
    }];
    
    
    _qrCodeTableView.rowHeight = 108.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getQrCodesForBlock) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self getQrCodesForBlock];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)getQrCodesForBlock
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    NSDictionary *params = @{@"blkId":_blockId};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_download_all_qr_code_for_block] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        _qrCodeListArray = [responseObject objectForKey:@"RelatedQRCodeList"];
        
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        [self saveQrCode];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_qrCodeTableView reloadData];
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
    }];
}


- (void)saveQrCode
{
    for (NSDictionary *dict in _qrCodeListArray) {
        [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
            
            NSNumber *blk_id = [NSNumber numberWithInt:[[dict valueForKey:@"BlockId"] intValue]];
            NSNumber *scanChkListBlkId = [NSNumber numberWithInt:[[dict valueForKey:@"ScanChkListBlkId"] intValue]];
            NSString *area = [dict valueForKey:@"Area"];
            NSString *qrCode = [dict valueForKey:@"QRCode"];
            NSDate *LastScannedTime = [myDatabase createNSDateWithWcfDateString:[dict valueForKey:@"LastScannedTime"]];
            NSDate *PrintedTime = [myDatabase createNSDateWithWcfDateString:[dict valueForKey:@"PrintedTime"]];
            NSDate *ReportTime = [myDatabase createNSDateWithWcfDateString:[dict valueForKey:@"ReportTime"]];
            
            FMResultSet *rs = [db executeQuery:@"select * from rt_qr_code where blk_id = ? and scanChkListBlkId = ? and area = ? and qrCode = ?",blk_id,scanChkListBlkId,area,qrCode];
            
            if([rs next] == NO)
            {
                BOOL ins = [db executeUpdate:@"insert into rt_qr_code(blk_id,scanChkListBlkId,area,qrCode,last_scanned_time,last_report_time,printed_time) values (?,?,?,?,?,?,?)",blk_id,scanChkListBlkId,area,qrCode,LastScannedTime,ReportTime,PrintedTime];
                
                if(!ins)
                {
                    *rollback = YES;
                    return;
                }
            }
            else
            {
                BOOL ups = [db executeUpdate:@"update rt_qr_code set blk_id = ? ,scanChkListBlkId = ? ,area = ? ,qrCode = ? ,last_scanned_time = ? ,last_report_time = ? ,printed_time = ? where blk_id = ? and scanChkListBlkId = ? and area = ? and qrCode = ? ",blk_id,scanChkListBlkId,area,qrCode,LastScannedTime,ReportTime,PrintedTime,blk_id,scanChkListBlkId,area,qrCode];
                
                if(!ups)
                {
                    *rollback = YES;
                    return;
                }
            }
            
        }];
    }
    
    //get the locally stored qr codes
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        FMResultSet *rs = [db executeQuery:@"select * from rt_qr_code where blk_id = ?",_blockId];
        
        NSMutableArray *rows = [[NSMutableArray alloc] init];
        
        while ([rs next]) {
            NSNumber *blk_id = [NSNumber numberWithInt:[rs intForColumn:@"blk_id"]];
            NSNumber *scanChkListBlkId = [NSNumber numberWithInt:[rs intForColumn:@"scanChkListBlkId"]];
            NSString *area = [rs stringForColumn:@"area"];
            NSString *qrCode = [rs stringForColumn:@"area"];
            NSString *LastScannedTime = [myDatabase createWcfDateWithNsDate:[rs dateForColumn:@"last_scanned_time"]];
            NSString *PrintedTime = [myDatabase createWcfDateWithNsDate:[rs dateForColumn:@"printed_time"]];
            NSString *ReportTime = [myDatabase createWcfDateWithNsDate:[rs dateForColumn:@"last_report_time"]];
            
            [rows addObject:@{@"Area":area,@"BlockId":blk_id,@"LastScannedTime":LastScannedTime,@"PrintedTime":PrintedTime,@"QRCode":qrCode,@"ReportTime":ReportTime,@"ScanChkListBlkId":scanChkListBlkId}];
        }
        
        _qrCodeListArray = rows;
        
    }];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if([segue.identifier isEqualToString:@"push_qr_code_scanning"])
    {
        QRCodeScanningViewController *qrCodeScanning = [segue destinationViewController];
        qrCodeScanning.scheduleDetailDict = _scheduleDetailDict;
        qrCodeScanning.scanQrCodeInsideJobList = YES;
    }
    else if ([segue.identifier isEqualToString:@"modal_report_missing_qr_code"])
    {
        QRCodeListViewController *qrCodeListVc = [segue destinationViewController];
        qrCodeListVc.blockId = sender;
    }
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _qrCodeListArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cell";
    
    ScanQrCodeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    NSDictionary *dict = [_qrCodeListArray objectAtIndex:indexPath.row];

    [cell initCellWithResultSet:dict];
    
    return cell;
}

- (IBAction)scanQrCode:(id)sender
{
    [self performSegueWithIdentifier:@"push_qr_code_scanning" sender:nil];
}


- (IBAction)reportMissingQrCode:(id)sender
{
    [self performSegueWithIdentifier:@"modal_report_missing_qr_code" sender:_blockId];
}


@end
