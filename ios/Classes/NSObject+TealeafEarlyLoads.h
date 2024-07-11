//
// Copyright (C) 2020 Acoustic, L.P. All rights reserved.
//
// NOTICE: This file contains material that is confidential and proprietary to
// Acoustic, L.P. and/or other developers. No license is granted under any intellectual or
// industrial property rights of Acoustic, L.P. except as may be provided in an agreement with
// Acoustic, L.P. Any unauthorized copying or distribution of content from this file is
// prohibited.
//

#import <Foundation/Foundation.h>

@interface NSObject (TealeafEarlyLoads)
/*
 Please read Implementation file for details. Please uncomment methods as needed and as suggested in there.
*/
+(void)tealeafEarlyLoadWebView;
+(void)tealeafDoNotInjectForUIView;
+(void)tealeafDoNotInjectForUIViewController;
+(void)tealeafDoNotInjectForUITableView;
+(void)tealeafDoNotInjectForUITableViewCell;
+(void)tealeafDoNotInjectForUIImage;
+(void)tealeafDoNotInjectForUIAlertAction;
+(void)tealeafDoNotInjectForUIPageControl;
+(void)tealeafDoNotInjectForUIPickerView;
+(void)tealeafDoNotInjectForUIDatePicker;
+(void)tealeafDoNotInjectForNSData;
+(void)tealeafDoNotInjectForWKWebView;
+(void)tealeafDoNotInjectForNSURLSession;
@end
