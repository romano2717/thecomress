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
@end

@implementation ReportMissingQRViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    myDatabase = [Database sharedMyDbManager];
    
    self.title = @"Report missing QR Code";
    
    _qrCodeLabel.text = [NSString stringWithFormat:@"QR Code: %@",[_scannedQrCodeDict valueForKey:@"scanValue"]];
    
    [self generateData];
    
    self.lastVisibleView = _proceedBtn;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    Blocks *blocks = [[Blocks alloc] init];
    
    _blocksArray = [[NSMutableArray alloc] init];
    NSArray *theBlocks = [blocks fetchBlocksWithBlockId:nil];
    
    
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
    [self getAllQrCodesForBlockId:[[_selectedBlock valueForKeyPath:@"CustomObject.block_id"] intValue]];
}

@end
