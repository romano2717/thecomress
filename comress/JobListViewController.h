//
//  JobListViewController.h
//  comress
//
//  Created by Diffy Romano on 4/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppWideImports.h"
#import "Database.h"
#import "JobListTableViewCell.h"
#import "MBProgressHUD.h"
#import "SchedDetailViewController.h"
#import "ScanQrCodeViewController.h"
#import "RoutineSynchronize.h"
#import "RoofAccessInfoViewController.h"
#import "QRCodeScanningViewController.h"
#import "MZFormSheetController.h"
#import "MZCustomTransition.h"
#import "MZFormSheetSegue.h"
#import "JobListActionsViewController.h"

@interface JobListViewController : UIViewController
{
    Database *myDatabase;
    ImageOptions *imgOpts;
}

@property (nonatomic, strong)NSDictionary *scheduleDetailDict;

@end
