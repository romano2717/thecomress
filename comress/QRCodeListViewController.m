//
//  QRCodeListViewController.m
//  comress
//
//  Created by Diffy Romano on 22/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "QRCodeListViewController.h"

@interface QRCodeListViewController ()

@property (nonatomic, weak) IBOutlet UITableView *qrCodeTableView;
@property (nonatomic, weak) IBOutlet UINavigationBar *navigationBar;
@property (nonatomic, weak) IBOutlet UIButton *OkButton;

@property (nonatomic, strong) NSArray *qrCodeListArray;
@property (nonatomic, strong) NSMutableArray *selectedQrCodeIndexPathsArray;
@end

@implementation QRCodeListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:@"select block_no, street_name from blocks where block_id = ?",_blockId];
        
        while ([rs next]) {
            _navigationBar.topItem.title = [NSString stringWithFormat:@"%@ %@",[rs stringForColumn:@"block_no"],[rs stringForColumn:@"street_name"]];
        }
    }];
    
    
    _selectedQrCodeIndexPathsArray = [[NSMutableArray alloc] init];
    
    [_OkButton setTitle:@"Proceed" forState:UIControlStateNormal];

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
            NSString *qrCode = [rs stringForColumn:@"qrCode"];
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
     
     QrCodeListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
     
     NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[_qrCodeListArray objectAtIndex:indexPath.row]];
     [dict setObject:indexPath forKey:@"indexPath"];
     [dict setObject:_selectedQrCodeIndexPathsArray forKey:@"selectedQrCodeIndexPathsArray"];
     
     [cell initCellWithResultSet:dict];
     
     return cell;
 }

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (IBAction)selectQrCodeToReport:(id)sender
{
    UIButton *btn = (UIButton *)sender;
    
    NSNumber *tag = [NSNumber numberWithInteger:btn.tag];
    
    btn.selected = !btn.selected;
    
    if(btn.selected && [_selectedQrCodeIndexPathsArray containsObject:tag] == NO)
        [_selectedQrCodeIndexPathsArray addObject:tag];
    else
        [_selectedQrCodeIndexPathsArray removeObject:tag];
    
    [_qrCodeTableView reloadData];
}

- (IBAction)reportMissingQrCode:(id)sender
{
    for (NSNumber *row in _selectedQrCodeIndexPathsArray) {
        
        NSDictionary *qrCodeToReport = [_qrCodeListArray objectAtIndex:[row intValue]];
        
        NSNumber *blk_id = [NSNumber numberWithInt:[[qrCodeToReport valueForKey:@"BlockId"] intValue]];
        NSNumber *scanChkListBlkId = [NSNumber numberWithInt:[[qrCodeToReport valueForKey:@"ScanChkListBlkId"] intValue]];
        NSString *area = [qrCodeToReport valueForKey:@"Area"];
        NSString *qrCode = [qrCodeToReport valueForKey:@"QRCode"];
        NSDate *ReportTime = [NSDate date];
        
        [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
            db.traceExecution = YES;
            BOOL up = [db executeUpdate:@"update rt_qr_code set last_report_time = ? where blk_id = ? and scanChkListBlkId = ? and area = ? and qrCode = ?",ReportTime,blk_id,scanChkListBlkId,area,qrCode];
            db.traceExecution = NO;
            
            if(!up)
            {
                *rollback = YES;
                return;
            }
            
            //save to rt_miss_qr_code
            BOOL ins = [db executeUpdate:@"insert into rt_miss_qr_code(block_id, scanChkListBlkId) values (?,?)",blk_id,scanChkListBlkId];
            
            if(!ins)
            {
                *rollback = YES;
                return;
            }
        }];
    }
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    RoutineSynchronize *sync = [RoutineSynchronize sharedRoutineSyncManager];
    
    [sync uploadMissingQrCodeFromSelf:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        
        [AGPushNoteView showWithNotificationMessage:@"Missing QR Code reported!"];
        
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
