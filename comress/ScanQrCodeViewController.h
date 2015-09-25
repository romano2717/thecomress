//
//  ScanQrCodeViewController.h
//  comress
//
//  Created by Diffy Romano on 23/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppWideImports.h"
#import "Database.h"
#import "RoutineSynchronize.h"
#import "MBProgressHUD.h"
#import "ScanQrCodeTableViewCell.h"
#import "QRCodeScanningViewController.h"
#import "QRCodeListViewController.h"

@interface ScanQrCodeViewController : UIViewController
{
    Database *myDatabase;
}

@property (nonatomic, strong) NSNumber *blockId;
@property (nonatomic, strong) NSDictionary *scheduleDetailDict;


@end
