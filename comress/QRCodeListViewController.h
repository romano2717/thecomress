//
//  QRCodeListViewController.h
//  comress
//
//  Created by Diffy Romano on 22/9/15.
//  Copyright © 2015 Combuilder. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppWideImports.h"
#import "Database.h"
#import "MBProgressHUD.h"
#import "QrCodeListTableViewCell.h"
#import "RoutineSynchronize.h"
#import "AGPushNoteView.h"

@interface QRCodeListViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
{
    Database *myDatabase;
}

@property (nonatomic, strong) NSNumber *blockId;
@end
