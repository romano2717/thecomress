//
//  RoutineSynchronize.m
//  comress
//
//  Created by Diffy Romano on 4/9/15.
//  Copyright (c) 2015 Combuilder. All rights reserved.
//

#import "RoutineSynchronize.h"

@implementation RoutineSynchronize

@synthesize isFinishedUploadingSchedule;

-(id)init {
    if (self = [super init]) {
        myDatabase = [Database sharedMyDbManager];
        isFinishedUploadingSchedule = YES;
    }
    return self;
}

+(id)sharedRoutineSyncManager {
    static RoutineSynchronize *sharedMySyncManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMySyncManager = [[self alloc] init];
    });
    return sharedMySyncManager;
}

- (void)startSync
{
    if(myDatabase.initializingComplete == NO)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startSync];
        });
        
        return;
    }
    else
        [self uploadUnlockBlockInfoFromSelf:YES];
}

- (void)stopSync
{

}

- (void)uploadUnlockBlockInfoFromSelf:(BOOL)fromSelf
{

    NSMutableArray *unlockList = [[NSMutableArray alloc] init];
    
    NSNumber *needToSync = [NSNumber numberWithInt:1];
    NSNumber *syncIsFinished = [NSNumber numberWithInt:2];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        FMResultSet *rs = [db executeQuery:@"select * from rt_blk_schedule where sync_flag = ?",needToSync];
        
        while ([rs next]) {
            NSNumber *BlockId = [NSNumber numberWithInt:[rs intForColumn:@"blk_id"]];
            NSString *UserId = [rs stringForColumn:@"user_id"];
            NSString *ScheduleDate = [myDatabase createWcfDateWithNsDate:[rs dateForColumn:@"schedule_date"]];
            NSString *Barcode = [rs stringForColumn:@"barcode"];
            NSNumber *Latitude = [NSNumber numberWithFloat:[rs doubleForColumn:@"latitude"]];
            NSNumber *Longitude = [NSNumber numberWithFloat:[rs doubleForColumn:@"longitude"]];
            
            [unlockList addObject:@{@"BlockId":BlockId,@"UserId":UserId,@"ScheduleDate":ScheduleDate,@"Barcode":Barcode,@"Latitude":Latitude,@"Longitude":Longitude}];
        }
    }];
    
    if(unlockList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleImageFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"unlockList":unlockList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_unlock_block_info] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckUnlockObj = [responseObject objectForKey:@"AckUnlockObj"];
        
        for (NSDictionary *dict in AckUnlockObj) {
            NSNumber *BlockId = [NSNumber numberWithInt:[[dict valueForKey:@"BlockId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSString *ScheduleDate = [dict valueForKey:@"ScheduleDate"];
            NSDate *ScheduleDateNsDate = [myDatabase createNSDateWithWcfDateString:ScheduleDate];
            NSNumber *ScheduleDateNsDateEpoch = [NSNumber numberWithDouble:[ScheduleDateNsDate timeIntervalSince1970]];
            NSString *UserId = [dict valueForKey:@"UserId"];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    BOOL up = [db executeUpdate:@"update rt_blk_schedule set sync_flag = ? where blk_id = ? and schedule_date = ? and user_id = ?",syncIsFinished, BlockId, ScheduleDateNsDateEpoch, UserId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                }];
            }
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleImageFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleImageFromSelf:fromSelf];
            });
        }
        
    }];
}

- (void)uploadScheduleImageFromSelf:(BOOL)fromSelf
{

    __block NSArray *scheduleImageList;
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        NSNumber *zero = [NSNumber numberWithInt:0];
        
        FMResultSet *rs = [db executeQuery:@"select * from rt_schedule_image where schedule_image_id = ? limit 0,1",zero];
        
        while ([rs next]) {
            NSNumber *CilentScheduleImageId = [NSNumber numberWithInt:[rs intForColumn:@"client_schedule_image_id"]];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *CheckListId = [NSNumber numberWithInt:[rs intForColumn:@"checklist_id"]];
            NSNumber *ImageType = [NSNumber numberWithInt:[rs intForColumn:@"image_type"]];
            NSString *Remark = [rs stringForColumn:@"remark"];
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsPath = [paths objectAtIndex:0];
            NSString *filePath = [documentsPath stringByAppendingPathComponent:[rs stringForColumn:@"image_name"]];
            
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            if([fileManager fileExistsAtPath:filePath] == NO) //file does not exist
                continue ;
            
            UIImage *image = [UIImage imageWithContentsOfFile:filePath];
            NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
            NSString *imageString = [imageData base64EncodedStringWithSeparateLines:NO];
            
            NSDictionary *dict = @{@"CilentScheduleImageId":CilentScheduleImageId,@"ScheduleId":ScheduleId,@"CheckListId":CheckListId,@"ImageType":ImageType,@"Remark":Remark,@"Image":imageString};
            
            scheduleImageList = [NSArray arrayWithObject:dict];
        }
    }];
    
    if(scheduleImageList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleUpdateFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"scheduleImageList":scheduleImageList};

    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_schedule_image] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckScheduleImageObj = [responseObject objectForKey:@"AckScheduleImageObj"];
        
        for (NSDictionary *dict in AckScheduleImageObj) {
            NSNumber *CilentScheduleImageId = [NSNumber numberWithInt:[[dict valueForKey:@"CilentScheduleImageId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSNumber *ScheduleImageId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleImageId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    BOOL ups = [db executeUpdate:@"update rt_schedule_image set schedule_image_id = ? where client_schedule_image_id = ?",ScheduleImageId,CilentScheduleImageId];
                    
                    if(!ups)
                    {
                        *rollback = YES;
                        return;
                    }
                    
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleUpdateFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScheduleUpdateFromSelf:fromSelf];
            });
        }
        
    }];
}


- (void)uploadScheduleUpdateFromSelf:(BOOL)fromSelf
{
 
    if(isFinishedUploadingSchedule == NO)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadCheckListUpdateFromSelf:fromSelf];
            });
        }
        return;
    }
        
    NSMutableArray *scheduleList = [[NSMutableArray alloc] init];
    NSNumber *needToSync = [NSNumber numberWithInt:2];
    NSNumber *syncFinished = [NSNumber numberWithInt:1];
    
    
    NSMutableArray *scheduleIdArray = [[NSMutableArray alloc] init];
    
    __block BOOL aCompletedScheduleWasFound = NO;
    __block NSNumber *completedScheduleId;
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
    
        FMResultSet *rs = [db executeQuery:@"select * from rt_schedule_detail where sync_flag = ?",needToSync];
        
        while ([rs next]) {
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *Status = [NSNumber numberWithInt:[rs intForColumn:@"status"]];
            NSString *Remarks = [rs stringForColumn:@"remarks"];
            
            /*
                check if the status == 3 //complete, bail out
            */
            
            if([Status intValue] == 3)
            {
                aCompletedScheduleWasFound = YES;
                completedScheduleId = ScheduleId;
            }
            
            else
            {
                [scheduleList addObject:@{@"ScheduleId":ScheduleId,@"Status":Status,@"Remarks":Remarks}];
                
                [scheduleIdArray addObject:ScheduleId];
            }
        }
    }];
    
    if(aCompletedScheduleWasFound == YES)
    {
        isFinishedUploadingSchedule = NO;
        
        [self uploadCheckListImagesWithScheduleId:completedScheduleId];
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadCheckListUpdateFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    if(scheduleList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadCheckListUpdateFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"scheduleList":scheduleList};
    
    
    isFinishedUploadingSchedule = NO;
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_update_sup_schedule] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        isFinishedUploadingSchedule = YES;
        
        NSArray *AckScheduleImageObj = [responseObject objectForKey:@"AckScheduleObj"];
        
        for (NSDictionary *dict in AckScheduleImageObj) {
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            BOOL IsSuccessful = [[dict valueForKey:@"IsSuccessful"] boolValue];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]] && IsSuccessful == YES)
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    //update schedule to finished sync
                    BOOL up = [db executeUpdate:@"update rt_schedule_detail set sync_flag = ? where schedule_id = ?",syncFinished,ScheduleId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadCheckListUpdateFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadCheckListUpdateFromSelf:fromSelf];
            });
        }
        
    }];
}


- (void)uploadCheckListUpdateFromSelf:(BOOL)fromSelf
{

    NSMutableArray *selectedCheckList = [[NSMutableArray alloc] init];
    
    NSNumber *needToSync = [NSNumber numberWithInt:2];
    NSNumber *syncFinished = [NSNumber numberWithInt:1];
    NSNumber *yesBool = [NSNumber numberWithBool:YES];
    
    NSMutableArray *scheduleIdArray = [[NSMutableArray alloc] init];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        //get the checklist to upload
        FMResultSet *rs = [db executeQuery:@"select * from rt_checklist c left join rt_schedule_detail sd on c.schedule_id =  sd.schedule_id where sd.checklist_sync_flag = ? ",needToSync,yesBool];
        
        while ([rs next]) {
            NSNumber *CheckListId = [NSNumber numberWithInt:[rs intForColumn:@"checklist_id"]];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *IsCheck = [NSNumber numberWithBool:[rs boolForColumn:@"is_checked"]];
            
            [selectedCheckList addObject:@{@"CheckListId":CheckListId,@"ScheduleId":ScheduleId,@"IsCheck":IsCheck}];
            
            [scheduleIdArray addObject:ScheduleId];
        }
    }];
    
    if(selectedCheckList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadMissingQrCodeFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"selectedCheckList":selectedCheckList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_selected_checklist] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckSUPCheckListObj = [responseObject objectForKey:@"AckSUPCheckListObj"];
        
        for (NSDictionary *dict in AckSUPCheckListObj) {

            BOOL IsSuccessful = [[dict valueForKey:@"IsSuccessful"] boolValue];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleId"] intValue]];
            
            if(IsSuccessful == YES)
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    //update schedule to finished sync
                    BOOL up = [db executeUpdate:@"update rt_schedule_detail set checklist_sync_flag = ? where schedule_id = ?",syncFinished,ScheduleId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadMissingQrCodeFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadMissingQrCodeFromSelf:fromSelf];
            });
        }
        
    }];
}


- (void)uploadMissingQrCodeFromSelf:(BOOL)fromSelf
{
    
    NSMutableArray *missQRCodeList = [[NSMutableArray alloc] init];
    
    NSNumber *zero = [NSNumber numberWithInt:0];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        //get the qr code to upload
        FMResultSet *rs = [db executeQuery:@"select * from rt_miss_qr_code where miss_qr_id = ? or miss_qr_id is null",zero];
        
        /*
         {
         "missQRCodeList" :  [
         { "ScanChkListBlkId" : 1 , "BlockId" : 1 , "ClientMissQrcodeId" : 1  }
         , { "ScanChkListBlkId" : 0 , "BlockId" : 1 , "ClientMissQrcodeId" : 2  }
         ]
         }
         */
        
        while ([rs next]) {
            NSNumber *ScanChkListBlkId = [NSNumber numberWithInt:[rs intForColumn:@"scanChkListBlkId"]];
            NSNumber *BlockId = [NSNumber numberWithInt:[rs intForColumn:@"block_id"]];
            NSNumber *ClientMissQrcodeId = [NSNumber numberWithInt:[rs intForColumn:@"client_miss_qr_id"]];
            
            [missQRCodeList addObject:@{@"ScanChkListBlkId":ScanChkListBlkId,@"BlockId":BlockId,@"ClientMissQrcodeId":ClientMissQrcodeId}];
        }
    }];
    
    if(missQRCodeList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScannedQrCodeFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"missQRCodeList":missQRCodeList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_missing_qr_code] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckMissQRCodeObj = [responseObject objectForKey:@"AckMissQRCodeObj"];
        
        for (NSDictionary *dict in AckMissQRCodeObj) {
            
            NSNumber *ClientMissQrcodeId = [NSNumber numberWithInt:[[dict valueForKey:@"ClientMissQrcodeId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSNumber *MissQrcodeId = [NSNumber numberWithInt:[[dict valueForKey:@"MissQrcodeId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    BOOL up = [db executeUpdate:@"update rt_miss_qr_code set miss_qr_id = ? where client_miss_qr_id = ?",MissQrcodeId,ClientMissQrcodeId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                    
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScannedQrCodeFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadScannedQrCodeFromSelf:fromSelf];
            });
        }
        
    }];
}


- (void)uploadScannedQrCodeFromSelf:(BOOL)fromSelf
{
    
    NSMutableArray *scannedQRCodeList = [[NSMutableArray alloc] init];
    
    NSNumber *zero = [NSNumber numberWithInt:0];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        //get the qr code to upload
        FMResultSet *rs = [db executeQuery:@"select * from rt_scanned_qr_code where scanned_qr_id = ? or scanned_qr_id is null",zero];
        
        /*
         {
         "scannedQRCodeList" :  [
         { "ScanChkListBlkId" : 1 , "BlockId" : 1 , "ClientMissQrcodeId" : 1  }
         , { "ScanChkListBlkId" : 0 , "BlockId" : 1 , "ClientMissQrcodeId" : 2  }
         ]
         }
         */
        
        while ([rs next]) {
            NSNumber *ScanChkListBlkId = [NSNumber numberWithInt:[rs intForColumn:@"scanChkListBlkId"]];
            NSNumber *BlockId = [NSNumber numberWithInt:[rs intForColumn:@"block_id"]];
            NSNumber *ClientScannedQrcodeId = [NSNumber numberWithInt:[rs intForColumn:@"client_scanned_qr_id"]];
            
            [scannedQRCodeList addObject:@{@"ScanChkListBlkId":ScanChkListBlkId,@"BlockId":BlockId,@"ClientScannedQrcodeId":ClientScannedQrcodeId}];
        }
    }];
    
    if(scannedQRCodeList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadRoofCheckAccessFromSelf:fromSelf];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"scannedQRCodeList":scannedQRCodeList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_scanned_qr_code] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckScannedQRCodeObj = [responseObject objectForKey:@"AckScannedQRCodeObj"];
        
        for (NSDictionary *dict in AckScannedQRCodeObj) {
            
            NSNumber *ClientScannedQrcodeId = [NSNumber numberWithInt:[[dict valueForKey:@"ClientScannedQrcodeId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSNumber *ScannedQrcodeId = [NSNumber numberWithInt:[[dict valueForKey:@"ScannedQrcodeId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    BOOL up = [db executeUpdate:@"update rt_scanned_qr_code set scanned_qr_id = ? where client_scanned_qr_id = ?",ScannedQrcodeId,ClientScannedQrcodeId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                    
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadRoofCheckAccessFromSelf:fromSelf];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self uploadRoofCheckAccessFromSelf:fromSelf];
            });
        }
        
    }];
}


- (void)uploadRoofCheckAccessFromSelf:(BOOL)fromSelf
{
    
    NSMutableArray *roofImageList = [[NSMutableArray alloc] init];
    
    NSNumber *zero = [NSNumber numberWithInt:0];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        //get the roof image to upload
        FMResultSet *rs = [db executeQuery:@"select * from rt_roof_check_image where roof_image_id = ? or roof_image_id is null limit 1",zero];
        
        while ([rs next]) {
            NSNumber *CilentRoofImageId = [NSNumber numberWithInt:[rs intForColumn:@"client_roof_image_id"]];
            NSNumber *RoofCheckSNO = [NSNumber numberWithInt:[rs intForColumn:@"roof_check_sno"]];
            
            NSNumber *Latitude = [NSNumber numberWithDouble:[rs doubleForColumn:@"latitude"]];
            NSNumber *Longitude = [NSNumber numberWithDouble:[rs doubleForColumn:@"longitude"]];
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsPath = [paths objectAtIndex:0];
            NSString *filePath = [documentsPath stringByAppendingPathComponent:[rs stringForColumn:@"image_name"]];
            
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            if([fileManager fileExistsAtPath:filePath] == NO) //file does not exist
                continue ;
            
            UIImage *image = [UIImage imageWithContentsOfFile:filePath];
            NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
            NSString *imageString = [imageData base64EncodedStringWithSeparateLines:NO];
            
            [roofImageList addObject:@{@"CilentRoofImageId":CilentRoofImageId,@"RoofCheckSNO":RoofCheckSNO,@"Latitude":Latitude,@"Longitude":Longitude,@"Image":imageString}];

        }
    }];
    
    if(roofImageList.count == 0)
    {
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self nextSyncMethod];
            });
        }
        
        return;
    }
    
    NSDictionary *params = @{@"roofImageList":roofImageList};

    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_roof_image] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckRoofImageObj = [responseObject objectForKey:@"AckRoofImageObj"];
        
        for (NSDictionary *dict in AckRoofImageObj) {
            
            NSNumber *CilentRoofImageId = [NSNumber numberWithInt:[[dict valueForKey:@"CilentRoofImageId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSNumber *RoofImageId = [NSNumber numberWithInt:[[dict valueForKey:@"RoofImageId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    BOOL up = [db executeUpdate:@"update rt_roof_check_image set roof_image_id = ? where client_roof_image_id = ?",RoofImageId,CilentRoofImageId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                    
                }];
            }
            
        }
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self nextSyncMethod];
            });
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        if(fromSelf)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self nextSyncMethod];
            });
        }
        
    }];
}


- (void)nextSyncMethod
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self uploadUnlockBlockInfoFromSelf:YES];
    });
}



#pragma mark - uploading of schedule
/*
 
 the following methods are only exclusive for schedule with status 3(complete) and does not follow sync routine
 
 */

- (void)uploadCheckListImagesWithScheduleId:(NSNumber *)scheduleId
{
    __block NSArray *scheduleImageList;
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        NSNumber *zero = [NSNumber numberWithInt:0];
        
        FMResultSet *rs = [db executeQuery:@"select * from rt_schedule_image where schedule_image_id = ? and schedule_id = ? ",zero,scheduleId];
        
        while ([rs next]) {
            NSNumber *CilentScheduleImageId = [NSNumber numberWithInt:[rs intForColumn:@"client_schedule_image_id"]];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *CheckListId = [NSNumber numberWithInt:[rs intForColumn:@"checklist_id"]];
            NSNumber *ImageType = [NSNumber numberWithInt:[rs intForColumn:@"image_type"]];
            NSString *Remark = [rs stringForColumn:@"remark"];
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsPath = [paths objectAtIndex:0];
            NSString *filePath = [documentsPath stringByAppendingPathComponent:[rs stringForColumn:@"image_name"]];
            
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            if([fileManager fileExistsAtPath:filePath] == NO) //file does not exist
                continue ;
            
            UIImage *image = [UIImage imageWithContentsOfFile:filePath];
            NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
            NSString *imageString = [imageData base64EncodedStringWithSeparateLines:NO];
            
            NSDictionary *dict = @{@"CilentScheduleImageId":CilentScheduleImageId,@"ScheduleId":ScheduleId,@"CheckListId":CheckListId,@"ImageType":ImageType,@"Remark":Remark,@"Image":imageString};
            
            scheduleImageList = [NSArray arrayWithObject:dict];
        }
    }];
    
    if(scheduleImageList.count == 0)
    {
        [self uploadCheckListWithScheduleId:scheduleId];
        
        return;
    }
    
    NSDictionary *params = @{@"scheduleImageList":scheduleImageList};

    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_schedule_image] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckScheduleImageObj = [responseObject objectForKey:@"AckScheduleImageObj"];
        
        for (NSDictionary *dict in AckScheduleImageObj) {
            NSNumber *CilentScheduleImageId = [NSNumber numberWithInt:[[dict valueForKey:@"CilentScheduleImageId"] intValue]];
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            NSNumber *ScheduleImageId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleImageId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]])
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    BOOL ups = [db executeUpdate:@"update rt_schedule_image set schedule_image_id = ? where client_schedule_image_id = ?",ScheduleImageId,CilentScheduleImageId];
                    
                    if(!ups)
                    {
                        *rollback = YES;
                        return;
                    }
                    
                }];
            }
            
        }
        
        [self uploadCheckListWithScheduleId:scheduleId];
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        [self uploadCheckListWithScheduleId:scheduleId];
        
    }];
}

- (void)uploadCheckListWithScheduleId:(NSNumber *)scheduleId
{
    NSMutableArray *selectedCheckList = [[NSMutableArray alloc] init];
    
    NSNumber *needToSync = [NSNumber numberWithInt:2];
    NSNumber *syncFinished = [NSNumber numberWithInt:1];
    NSNumber *yesBool = [NSNumber numberWithBool:YES];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        //get the checklist to upload
        FMResultSet *rs = [db executeQuery:@"select * from rt_checklist c left join rt_schedule_detail sd on c.schedule_id =  sd.schedule_id where sd.checklist_sync_flag = ? and c.is_checked = ? and c.schedule_id = ?",needToSync,yesBool,scheduleId];
        
        while ([rs next]) {
            NSNumber *CheckListId = [NSNumber numberWithInt:[rs intForColumn:@"checklist_id"]];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *IsCheck = [NSNumber numberWithBool:YES];
            
            [selectedCheckList addObject:@{@"CheckListId":CheckListId,@"ScheduleId":ScheduleId,@"IsCheck":IsCheck}];
            

        }
    }];
    
    if(selectedCheckList.count == 0)
    {
        [self uploadScheduleUpdateWithScheduleId:scheduleId];
        
        return;
    }
    
    NSDictionary *params = @{@"selectedCheckList":selectedCheckList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_selected_checklist] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSArray *AckSUPCheckListObj = [responseObject objectForKey:@"AckSUPCheckListObj"];
        
        for (NSDictionary *dict in AckSUPCheckListObj) {
            
            BOOL IsSuccessful = [[dict valueForKey:@"IsSuccessful"] boolValue];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleId"] intValue]];
            
            if(IsSuccessful == YES)
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    //update schedule to finished sync
                    BOOL up = [db executeUpdate:@"update rt_schedule_detail set checklist_sync_flag = ? where schedule_id = ?",syncFinished,ScheduleId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                }];
            }
            
        }
        
        [self uploadScheduleUpdateWithScheduleId:scheduleId];
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
        
        [self uploadScheduleUpdateWithScheduleId:scheduleId];
        
    }];
}

- (void)uploadScheduleUpdateWithScheduleId:(NSNumber *)scheduleId
{
    NSMutableArray *scheduleList = [[NSMutableArray alloc] init];
    NSNumber *needToSync = [NSNumber numberWithInt:2];
    NSNumber *syncFinished = [NSNumber numberWithInt:1];
    
    [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        FMResultSet *rs = [db executeQuery:@"select * from rt_schedule_detail where sync_flag = ? and schedule_id = ?",needToSync,scheduleId];
        while ([rs next]) {
            NSNumber *ScheduleId = [NSNumber numberWithInt:[rs intForColumn:@"schedule_id"]];
            NSNumber *Status = [NSNumber numberWithInt:[rs intForColumn:@"status"]];
            NSString *Remarks = [rs stringForColumn:@"remarks"];
            
            [scheduleList addObject:@{@"ScheduleId":ScheduleId,@"Status":Status,@"Remarks":Remarks}];
        }
    }];
    
    if(scheduleList.count == 0)
    {
        return;
    }
    
    NSDictionary *params = @{@"scheduleList":scheduleList};
    
    [myDatabase.AfManager POST:[NSString stringWithFormat:@"%@%@",myDatabase.api_url ,api_upload_update_sup_schedule] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        isFinishedUploadingSchedule = YES;
        
        NSArray *AckScheduleImageObj = [responseObject objectForKey:@"AckScheduleObj"];
        
        for (NSDictionary *dict in AckScheduleImageObj) {
            NSString *ErrorMessage = [dict valueForKey:@"ErrorMessage"];
            BOOL IsSuccessful = [[dict valueForKey:@"IsSuccessful"] boolValue];
            NSNumber *ScheduleId = [NSNumber numberWithInt:[[dict valueForKey:@"ScheduleId"] intValue]];
            
            if([ErrorMessage isEqual:[NSNull null]] && IsSuccessful == YES)
            {
                [myDatabase.databaseQ inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    
                    //update schedule to finished sync
                    BOOL up = [db executeUpdate:@"update rt_schedule_detail set sync_flag = ? where schedule_id = ?",syncFinished,ScheduleId];
                    
                    if(!up)
                    {
                        *rollback = YES;
                        return;
                    }
                }];
            }
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogVerbose(@"%@ [%@-%@]",error.localizedDescription,THIS_FILE,THIS_METHOD);
    }];
}

@end
