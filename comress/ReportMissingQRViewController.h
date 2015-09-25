//
//  ReportMissingQRViewController.h
//  comress
//
//  Created by Diffy Romano on 18/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppWideImports.h"
#import "Database.h"
#import "Blocks.h"
#import "MPGTextField.h"
#import "VisibleFormViewController.h"
#import "MBProgressHUD.h"
#import "QRCodeListViewController.h"

@interface ReportMissingQRViewController : VisibleFormViewController<MPGTextFieldDelegate>
{
    Database *myDatabase;
}

@property (nonatomic, strong) NSDictionary *scannedQrCodeDict;
@end
