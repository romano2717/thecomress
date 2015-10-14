//
//  ReportMissingQRViewController.m
//  comress
//
//  Created by Diffy Romano on 18/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import "ReportMissingQRViewController.h"

@interface ReportMissingQRViewController ()

@property (nonatomic, weak) IBOutlet UILabel *qrCodeLabel;
@property (nonatomic, weak) IBOutlet MPGTextField *areaTextFieldSelect;
@property (nonatomic, weak) IBOutlet UIButton *proceedBtn;

@property (nonatomic, strong) NSMutableArray *blocksArray;

@property (nonatomic, strong) NSDictionary *selectedBlock;

@property (nonatomic, assign) BOOL willDisappear;
@end

@implementation ReportMissingQRViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    self.title = @"Report missing QR Code";
    
    _qrCodeLabel.text = [NSString stringWithFormat:@"QR Code: %@",[_scannedQrCodeDict valueForKey:@"scanValue"]];
    
    _blocksArray = [[NSMutableArray alloc] init];
    
    [self generateData];
    
    self.lastVisibleView = _proceedBtn;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    _willDisappear = YES;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if([segue.identifier isEqualToString:@"modal_qr_code_list"])
    {
        QRCodeListViewController *qrCodeList = [segue destinationViewController];
        qrCodeList.blockId = sender;
    }
}

- (void)generateData
{
    NSDate *now = [NSDate date];
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    NSDate *nowDate = [[[NSCalendar currentCalendar] dateFromComponents:comps] dateByAddingTimeInterval:24*00*00];
    
    NSNumber *scheduleDateEpoch = [NSNumber numberWithDouble:[nowDate timeIntervalSince1970]];
    NSString *userId = [NSString stringWithFormat:@"%@",[myDatabase.userDictionary valueForKey:@"user_id"]];
    
    NSMutableArray *theBlocks = [[NSMutableArray alloc] init];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        db.traceExecution = YES;
        FMResultSet *rs = [db executeQuery:@"select * from blocks where block_id in (select distinct blk_id from rt_blk_schedule where schedule_date = ? and user_id = ?)",scheduleDateEpoch,userId];
        
        while ([rs next]) {
            [theBlocks addObject:[rs resultDictionary]];
        }
        db.traceExecution = NO;
    }];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [theBlocks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *postal_code = [NSString stringWithFormat:@"%@ - %@ - %@",[obj valueForKey:@"postal_code"],[obj valueForKey:@"street_name"],[obj valueForKey:@"block_no"]];
            NSString *block_no = [obj valueForKey:@"block_no"];

            [_blocksArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:postal_code,@"DisplayText",obj,@"CustomObject",block_no,@"DisplaySubText", nil]];
        }];
        
    });
}

#pragma mark MPGTextField Delegate Methods

- (NSArray *)dataForPopoverInTextField:(MPGTextField *)textField
{
    return self.blocksArray;
}

- (BOOL)textFieldShouldSelect:(MPGTextField *)textField
{
    return YES;
}

- (void)textField:(MPGTextField *)textField didEndEditingWithSelection:(NSDictionary *)result
{
    if(_willDisappear == YES)
        return;
    
    if([[result valueForKey:@"CustomObject"] isKindOfClass:[NSDictionary class]] == NO) //user typed some shit!
        return;
    
    DDLogVerbose(@"%@",result);
    
    _selectedBlock = result;
    
    [self getAllQrCodesForBlockId:[[result valueForKeyPath:@"CustomObject.block_id"] intValue]];
    
}

- (void)getAllQrCodesForBlockId:(int)blockId
{
    [self performSegueWithIdentifier:@"modal_qr_code_list" sender:[NSNumber numberWithInt:blockId]];
}

- (IBAction)proceed:(id)sender
{
    if([[_selectedBlock valueForKeyPath:@"CustomObject.block_id"] intValue] > 0)
    {
        [self getAllQrCodesForBlockId:[[_selectedBlock valueForKeyPath:@"CustomObject.block_id"] intValue]];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"COMRESS" message:@"Please select a block" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    
}

@end
