//
// Copyright (C) 2020 Acoustic, L.P. All rights reserved.
//
// NOTICE: This file contains material that is confidential and proprietary to
// Acoustic, L.P. and/or other developers. No license is granted under any intellectual or
// industrial property rights of Acoustic, L.P. except as may be provided in an agreement with
// Acoustic, L.P. Any unauthorized copying or distribution of content from this file is
// prohibited.
//

/*Include this file into your xcode project's Target > Build Phases > Compile Sources as needed*/

#import "NSObject+TealeafEarlyLoads.h"

@implementation NSObject (TealeafEarlyLoads)

// Uncomment this method if you WANT tealeaf to inject WebView early (even before Tealeaf is enabled)
/*+(void)tealeafEarlyLoadWebView
{
    return;
}
*/
// Uncomment this method if you do not want Tealeaf to automatically inject into UIApplication
+(void)tealeafDoNotInjectForUIApplication
{
    return;
}

// Uncomment this method if you do not want Tealeaf to automatically inject into UIView
/*
+(void)tealeafDoNotInjectForUIView
{
}
*/
// Uncomment this method if you do not want Tealeaf to automatically inject into UIViewController
/*
+(void)tealeafDoNotInjectForUIViewController
{
    return;
}
*/
 
// Uncomment this method if you do not want Tealeaf to automatically inject into UITableView
/*
+(void)tealeafDoNotInjectForUITableView
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UITableViewCell
/*
+(void)tealeafDoNotInjectForUITableViewCell
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UIImage
/*
+(void)tealeafDoNotInjectForUIImage
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UIAlertAction
/*
+(void)tealeafDoNotInjectForUIAlertAction
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UIPageControl
/*
+(void)tealeafDoNotInjectForUIPageControl
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UIPickerView
/*
+(void)tealeafDoNotInjectForUIPickerView
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into UIDatePicker
/*
+(void)tealeafDoNotInjectForUIDatePicker
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into NSData
/*
+(void)tealeafDoNotInjectForNSData
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into WKWebView
/*
+(void)tealeafDoNotInjectForWKWebView
{
    return;
}
*/

// Uncomment this method if you do not want Tealeaf to automatically inject into NSURLSession
/*
+(void)tealeafDoNotInjectForNSURLSession
{
    return;
}
*/
@end
