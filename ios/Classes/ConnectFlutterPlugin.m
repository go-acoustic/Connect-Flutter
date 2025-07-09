//
// Copyright (C) 2025 Acoustic, L.P. All rights reserved.
//
// NOTICE: This file contains material that is confidential and proprietary to
// Acoustic, L.P. and/or other developers. No license is granted under any intellectual or
// industrial property rights of Acoustic, L.P. except as may be provided in an agreement with
// Acoustic, L.P. Any unauthorized copying or distribution of content from this file is
// prohibited.
//

#import "ConnectFlutterPlugin.h"
#import "TlImage.h"
#import "PointerEvent.h"

#import <EOCore/EOApplicationHelper.h>


@interface Position : NSObject

@property (nonatomic, assign) CGRect rect;
@property (nonatomic, assign) int x;
@property (nonatomic, assign) int y;
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic, copy) NSString *label;

@end

@implementation Position

// You can implement custom initializers or other methods here if needed

@end


/**
 * ConnectFlutterPlugin
 *
 * Integrates Connect analytics and monitoring capabilities into Flutter apps.
 */
@implementation ConnectFlutterPlugin {
    NSInteger _screenWidth;
    NSInteger _screenHeight;
    CGFloat   _scale;
    CGFloat   _adjustWidth;
    CGFloat   _adjustHeight;
    NSString  *_imageFormat;
    NSString  *_lastHash;
    BOOL      _isJpgFormat;
    NSString  *_mimeType;
    int _screenOffset;
    NSMutableDictionary *_basicConfig;
    NSDictionary *_layoutConfig;
    NSDictionary *_imageAttributes;
    PointerEvent *_firstMotionEvent;
    PointerEvent *_lastMotionUpEvent;
    NSString *_lastScreen;
    long _lastDown;
}

/**
 * Registers the ConnectFlutterPlugin with the Flutter plugin registrar.
 * This creates a communication channel between Flutter and native code.
 *
 * @param registrar An object conforming to the FlutterPluginRegistrar protocol.
 */
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"connect_flutter_plugin" binaryMessenger:[registrar messenger]];
    ConnectFlutterPlugin* instance = [[ConnectFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

/**
 * Initializes the ConnectFlutterPlugin instance.
 * Configures Connect integration and handles image-related settings.
 *
 * @return An instance of ConnectFlutterPlugin.
 */
- (id) init {
    self = [super init];
    _screenWidth  = -1;
    _screenHeight = -1;
    _scale   = [UIScreen mainScreen].scale;
    _fromWeb = false;
    
    [self resetScreenLoadTime];
    
    setenv("EODebug", "1", 1);
    setenv("TLF_DEBUG", "1", 1);

    // Initialize basic properties
    _lastHash            = @"";
    _lastDown            = 0L;
    _lastScreen          = @"";
    
    // Disable native SDK auto instrumentation to avoid duplicatation and meta data.
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUIButton value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUIDatePicker value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUIPageControl value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUIPickerView value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUIScrollView value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUISegmentedControl value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUISwitch value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemAddGestureRecognizerUITextView value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemDisableAlertAutoCapture value:@"true" forModuleName:kTLFCoreModule];

    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemSetGestureDetector value:@"false" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:kConfigurableItemLogViewLayoutOnScreenTransition value:@"false" forModuleName:kTLFCoreModule];

    [[EOApplicationHelper sharedInstance] setConfigItem:@"textBox:textChange" value:@"false" forModuleName:kTLFCoreModule];

    [[EOApplicationHelper sharedInstance] setConfigItem:@"gestures" value:@"0" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:@"autolog:FlutterView:click" value:@"0" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:@"autolog:canvas:click" value:@"0" forModuleName:kTLFCoreModule];
    [[EOApplicationHelper sharedInstance] setConfigItem:@"canvas:click" value:@"0" forModuleName:kTLFCoreModule];
    
    [self loadConnectConfig];
    
    ConnectApplicationHelper *ConnectApplicationHelperObj = [[ConnectApplicationHelper alloc] init];
    [ConnectApplicationHelperObj enableFramework];

    NSLog(@"Connect Enabled: %@", [[ConnectApplicationHelper sharedInstance] isTLFEnabled] ? @"Yes" : @"No");
    NSLog(@"Device Pixel Density (scale): %f", self->_scale);
    
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"ConnectResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"ConnectBasicConfig" ofType:@"plist"];
    self->_basicConfig   = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    self->_layoutConfig  = [self getLayoutConfig];
    
    self->_imageFormat   = [self getBasicConfig][@"ScreenshotFormat"];
    self->_isJpgFormat   = [self->_imageFormat caseInsensitiveCompare:@"JPG"] == NSOrderedSame ||
                            [self->_imageFormat caseInsensitiveCompare:@"JPEG"] == NSOrderedSame;
    self->_mimeType      = self->_isJpgFormat ? @"jpg" : @"png";
    
    self->_imageAttributes = @{
                            @"format":      self->_imageFormat,
                            @"isJpg":       @(self->_isJpgFormat),
                            @"scale":       @(self->_scale),
                            @"@mimeType":   (self->_isJpgFormat ? @"jpg" : @"png"),
                            @"%screenSize": @([self->_basicConfig[@"PercentOfScreenshotsSize"] floatValue]),
                            @"%compress":   @([self->_basicConfig[@"PercentToCompressImage"] floatValue] / 100.0)
                            };
    
    return self;
}


- (void)loadConnectConfig {
    NSArray *eocoreKeys = @[@"CachingLevel", @"DoPostAppComesFromBackground", @"DoPostAppGoesToBackground", @"DoPostAppGoesToClose", @"DoPostAppIsLaunched", @"DoPostOnIntervals", @"DynamicConfigurationEnabled", @"HasToPersistLocalCache", @"LoggingLevel", @"ManualPostEnabled", @"PostMessageLevelCellular", @"PostMessageLevelWiFi", @"PostMessageTimeIntervals", @"CachedFileMaxBytesSize", @"CompressPostMessage", @"DefaultOrientation", @"LibraryVersion", @"MaxNumberOfFilesToCache", @"MessageVersion", @"PostMessageMaxBytesSize", @"PostMessageTimeout",@"TurnOffCorrectOrientationUpdates"];
    NSArray *tealeafKeys = @[@"AppKey", @"DisableAutoInstrumentation", @"GetImageDataOnScreenLayout", @"JavaScriptInjectionDelay", @"KillSwitchEnabled", @"KillSwitchMaxNumberOfTries",@"KillSwitchTimeInterval", @"KillSwitchTimeout", @"KillSwitchUrl", @"UseWhiteList", @"WhiteListParam", @"LogLocationEnabled", @"MaxStringsLength", @"PercentOfScreenshotsSize", @"PercentToCompressImage", @"ScreenShotPixelDensity", @"PostMessageUrl", @"DoPostOnScreenChange", @"printScreen", @"ScreenshotFormat", @"SessionTimeout", @"SessionizationCookieName", @"CookieSecure", @"disableTLTDID",@"SetGestureDetector", @"AddGestureRecognizerUIButton", @"AddGestureRecognizerUIDatePicker", @"AddGestureRecognizerUIPageControl", @"AddGestureRecognizerUIPickerView", @"AddGestureRecognizerUIScrollView", @"AddGestureRecognizerUISegmentedControl", @"AddGestureRecognizerUISwitch", @"AddGestureRecognizerUITextView", @"AddGestureRecognizerWKWebView", @"AddMessageTypeHeader", @"DisableAlertAutoCapture", @"DisableAlertBackgroundForDisabledLogViewLayout", @"DisableKeyboardCapture", @"EnableWebViewInjectionForDisabledAutoCapture", @"FilterMessageTypes", @"InitialZIndex", @"IpPlaceholder", @"LibraryVersion", @"LogFullRequestResponsePayloads", @"LogViewLayoutOnScreenTransition", @"MessageTypeHeader", @"MessageTypes", @"RemoveIp", @"RemoveSwiftUIDuplicates", @"SubViewArrayZIndexIncrementTrigger", @"SwiftUICaptureNonVariadic", @"TextFieldBeingEditedUseSender", @"TreatJsonDictionariesAsString", @"UICPayload", @"UIKeyboardCaptureTouches", @"UseJPGForReplayImagesExtension", @"UseXpathId", @"actionSheet:buttonIndex", @"actionSheet:show", @"alertView:buttonIndex", @"alertView:show", @"autolog:pageControl", @"autolog:textBox:_searchFieldEndEditing", @"button:click", @"button:load", @"canvas:click", @"connection", @"customEvent", @"datePicker:dateChange", @"exception", @"gestures", @"label:load", @"label:textChange", @"layout", @"location", @"mobileState", @"orientation", @"pageControl:valueChanged", @"pickerView:valueChanged", @"screenChangeLevel", @"scroller:scrollChange", @"selectList:UITableViewSelectionDidChangeNotification", @"selectList:load", @"selectList:valueChange", @"slider:valueChange", @"stepper:valueChange", @"textBox:_searchFieldBeginChanged", @"textBox:_searchFieldBeginEditing", @"textBox:_searchFieldEditingChanged", @"textBox:textChange", @"textBox:textChanged", @"textBox:textFieldDidChange", @"toggleButton:click"];
    
    NSBundle *bundle = [NSBundle bundleForClass:self.classForCoder];
    NSURL *bundleURL = [[bundle resourceURL] URLByAppendingPathComponent:@"AcousticConnectConfig.bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleURL];
    NSString *path = [resourceBundle pathForResource:@"AcousticConnectConfig" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    
    if (jsonData != nil) {
        NSDictionary *connectData = [jsonData objectForKey:@"Connect"];
        for (NSString* key in connectData) {
            id value = connectData[key];
            
            if ([tealeafKeys containsObject:key]) {
                [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:kTLFCoreModule];
            } else if ([eocoreKeys containsObject:key]) {
                [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:kEOCoreModule];
            } else if ([key isEqualToString:@"layoutConfigIos"]) {
                [[EOApplicationHelper sharedInstance] setConfigItem:@"AutoLayout" value:[(NSDictionary*)value objectForKey:@"AutoLayout"] forModuleName:kTLFCoreModule];
                [[EOApplicationHelper sharedInstance] setConfigItem:@"AppendMapIds" value:[(NSDictionary*)value objectForKey:@"AppendMapIds"] forModuleName:kTLFCoreModule];
            }
        }
    }
    
}


/**
 * Retrieves the current screen orientation.
 *
 * @return An integer representing the orientation: 1 for landscape, 0 for portrait.
 */
-(int) getOrientation {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].windows.firstObject.windowScene.interfaceOrientation;
    return (orientation == UIInterfaceOrientationLandscapeLeft) || (orientation == UIInterfaceOrientationLandscapeRight)
        ? 1 : 0;
}

/**
 * Resets the screen load time to the current time.
 */
-(void) resetScreenLoadTime {
    _screenLoadTime = [NSDate timeIntervalSinceReferenceDate];
}

/**
 * Converts a string to an NSNumber.
 *
 * @param stringNumber The string to convert.
 * @return The converted NSNumber.
 */
- (NSNumber *) convertNSStringToNSNumber:(NSString *) stringNumber {
    NSNumber *number = [[[NSNumberFormatter alloc]init] numberFromString:stringNumber];
    return number;
}

/**
 * Checks if a parameter exists in a dictionary and converts it to a long integer.
 *
 * @param map The dictionary containing the parameter.
 * @param key The key of the parameter to check.
 * @return The parameter value as a long integer.
 */
- (long) checkParameterStringAsInteger:(NSDictionary *) map withKey:(NSString *) key {
    NSString *stringInteger = (NSString *) [self checkForParameter:map withKey:key];
    return [[self convertNSStringToNSNumber:stringInteger] longValue];
}

/**
 * Calculates the screen view offset in milliseconds.
 *
 * @return The screen view offset as a time interval.
 */
-(NSTimeInterval) getScreenViewOffset {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    return (_screenOffset = (now - _screenLoadTime) * 1000);
}

/**
 * Retrieves advanced configuration settings from a JSON file.
 *
 * @return A dictionary containing the advanced configuration.
 */
- (NSDictionary *) getAdvancedConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"ConnectResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"ConnectAdvancedConfig" ofType:@"json"];
    NSLog(@"Connect Advanced Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

/**
 * Retrieves layout configuration settings from a JSON file.
 *
 * @return A dictionary containing the layout configuration.
 */
- (NSDictionary *) getLayoutConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"ConnectResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"ConnectLayoutConfig" ofType:@"json"];
    NSLog(@"Connect Layout Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

/**
 * Retrieves basic configuration settings.
 *
 * @return A mutable dictionary containing the basic configuration.
 */
- (NSMutableDictionary *) getBasicConfig {
    return _basicConfig;
}

/**
 * Retrieves the build number of the application.
 *
 * @return A string representing the build number.
 */
- (NSString *) getBuildNumber {
    NSString * build = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    return build;
}

/**
 * Converts a layout configuration dictionary to a JSON string.
 *
 * @return A JSON string representing the basic layout configuration.
 */
- (NSString *) getBasicLayoutConfigurationString {
    NSDictionary *autoLayout = _layoutConfig[@"AutoLayout"];
    //NSDictionary *globalScreenSettings = autoLayout[@"GlobalScreenSettings"];
    //return [self getJSONString:globalScreenSettings];
    return [self getJSONString:autoLayout];
}

/**
 * Converts the global configuration dictionary to a JSON string.
 *
 * @return A JSON string representing the global configuration.
 */
- (NSString *) getGlobalConfigurationString {
    return [self getJSONString:_basicConfig];
}

/**
 * Converts an object to a JSON string.
 *
 * @param obj The object to convert.
 * @return A JSON string representation of the object.
 */
- (NSString *) getJSONString: (NSObject *) obj {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj
                                            options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care
                                            error:&error];
    if (!jsonData) {
        NSLog(@"JSON conversion error: %@", error);
        return @"";
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

/**
 * Checks for a parameter in a dictionary and throws an exception if not found.
 *
 * @param map The dictionary to check.
 * @param key The key of the parameter to check.
 * @param subKey The subkey to check within the parameter.
 * @return The parameter value.
 */
- (NSObject *) checkForParameter:(NSDictionary *) map withKey:(NSString*) key withSubKey:(NSString *) subKey {
    NSObject *object = map[key];
    
    NSLog(@"Checking for primary key parameter %@, description: %@", key, [object description]);
    
    if (object == nil) {
        NSString *msg    = [NSString stringWithFormat:@"Parameter (Primary key) %@ not found in %@", key, map.description];
        NSString *reason = [NSString stringWithFormat:@"Flutter iOS native method call error: %@", msg];
        
        NSLog(@"%@", msg);
        
        NSException* parameterException = [NSException
            exceptionWithName:@"ParameterError"
            reason: reason
            userInfo:nil];
        @throw parameterException;
    }
    
    return [self checkForParameter:(NSDictionary *) object withKey:subKey];
}

/**
 * Checks for a parameter in a dictionary and throws an exception if not found.
 *
 * @param map The dictionary to check.
 * @param key The key of the parameter to check.
 * @return The parameter value.
 */
- (NSObject *) checkForParameter:(NSDictionary *) map withKey:(NSString*) key {
    NSObject *object = map[key];
    
    NSLog(@"Checking for parameter %@, description: %@", key, [object description]);
    
    if (object == nil) {
        NSString *msg    = [NSString stringWithFormat:@"Parameter %@ not found in %@", key, map.description];
        NSString *reason = [NSString stringWithFormat:@"Flutter iOS native method call error: %@", msg];
        
        NSLog(@"%@", msg);
        
        NSException* parameterException = [NSException
            exceptionWithName:@"ParameterError"
            reason: reason
            userInfo:nil];
        @throw parameterException;
    }
    return object;
}


/**
 * Sends a custom event with the specified name and additional data.
 *
 * @param name The name of the custom event to be sent.
 * @param data A dictionary containing additional data to be included with the event.
 */
- (void) alternateCustomEvent:(NSString *) name addData:(NSDictionary *) data {
    NSDictionary *customEventData = @{@"customData": @{@"name": name, @"data": data}};
    
    [self tlLogMessage:customEventData addType: @5];
}


/**
 * Retrieves a PointerEvent object from the provided dictionary.
 *
 * @param map A dictionary containing the data required to construct a PointerEvent.
 *            The dictionary should include the necessary keys and values to map
 *            to the properties of a PointerEvent.
 * @return A PointerEvent object created using the data from the dictionary.
 */
- (PointerEvent *) getPointerEvent:(NSDictionary *) map {
    NSString *event  = (NSString *) [self checkForParameter:map withKey:@"action"];
    CGFloat  dx = [(NSNumber *)[self checkForParameter:map withKey:@"position" withSubKey:@"dx"] floatValue];
    CGFloat  dy = [(NSNumber *)[self checkForParameter:map withKey:@"position" withSubKey:@"dy"] floatValue];
    float    pressure = (float) [(NSNumber *) [self checkForParameter:map withKey:@"pressure"] floatValue];
    int      device = (int) [(NSNumber *) [self checkForParameter:map withKey:@"kind"] intValue];
    NSString *tsString = (NSString *) [self checkForParameter:map withKey:@"timestamp"];
    long     timestamp = [[self convertNSStringToNSNumber:tsString] longValue];
    long     downTime  = timestamp - (_lastDown == 0L ? timestamp : _lastDown);
    
    PointerEvent *pe = [[PointerEvent alloc] initWith:event andX:dx andY:dy andTs:tsString andDown:downTime andPressure:pressure andKind:device];
    
    if (_firstMotionEvent == nil) {
        _firstMotionEvent = pe;
    }
    if ([event isEqualToString:@"DOWN"]) {
        _lastDown = timestamp;
    }
    else if ([event isEqualToString:@"UP"]) {
        _lastMotionUpEvent = pe;
    }
    return pe;
}

/**
 * Applies a mask to an image with specified objects and their attributes.
 *
 * @param bgImage The background image to be masked.
 * @param maskObjects An array of dictionaries containing text and position attributes for the mask.
 * Each dictionary should contain keys: @"text" (NSString) and @"position" (NSDictionary).
 * The @"position" dictionary should contain keys: @"x", @"y", @"width", @"height" (CGFloat).
 * @return A new UIImage masked with the provided objects.
 */
- (UIImage *)maskImageWithObjects:(UIImage *)bgImage withObjects:(NSArray *)maskObjects {
    CGFloat fontScale = 0.72f;
    UIImage *maskedUIImage = nil;
    CGSize bgImageSize = bgImage.size;
    UIColor *textColor = [UIColor whiteColor]; // Changed text color to white
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(bgImageSize, NO, UIScreen.mainScreen.scale);
    } else {
        UIGraphicsBeginImageContext(bgImageSize);
    }
    
    [bgImage drawInRect:CGRectMake(0, 0, bgImageSize.width, bgImageSize.height)];
    [[UIColor lightGrayColor] set];
    
    for (NSDictionary *atts in maskObjects) {
        NSString *text = (NSString *)atts[@"text"];
        NSDictionary *position = (NSDictionary *)atts[@"position"];
        CGFloat x = 0;
        CGFloat y = [position[@"y"] floatValue];
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        CGFloat height = [position[@"height"] floatValue];
        CGRect rect = CGRectMake(x, y, width, height);
        
        CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
        
        NSArray *lines = [text componentsSeparatedByString:@"\n"];
        CGFloat lineHeight = height / (float)lines.count;
        UIFont *font = [UIFont systemFontOfSize:(lineHeight * fontScale)];
        NSDictionary *attrs = @{NSForegroundColorAttributeName: textColor, NSFontAttributeName: font};
        
        for (NSString *line in lines) {
            [line drawInRect:CGRectIntegral(rect) withAttributes:attrs];
            rect.origin.y += lineHeight;
        }
    }
    
    maskedUIImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return maskedUIImage;
}

/**
 * Captures a screenshot of the current screen.
 *
 * @return A UIImage representing the screenshot.
 */
- (UIImage *) takeScreenShot {
    UIImage *screenImage = nil;
    UIViewController *rootController = [self getCurrentMainViewController];
    
    if (rootController && [rootController respondsToSelector:@selector(view)])
    {
        UIView *view = rootController.view;
                    
        if (view) {
            CGSize size = view.bounds.size;
            
            if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
                UIGraphicsBeginImageContextWithOptions(size, NO, _scale);
            }
            else {
                UIGraphicsBeginImageContext(size);
            }
            if ([view drawViewHierarchyInRect:view.frame afterScreenUpdates:NO])
            {
               screenImage = UIGraphicsGetImageFromCurrentImageContext();
            }
            //[view.layer renderInContext:UIGraphicsGetCurrentContext()];
            //screenImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSLog(@"Screen shot size: %@, scale: %f", [screenImage description], _scale);
        }
    }
    
    return screenImage;
}

/**
 * Processes layout entries and applies masking rules.
 *
 * @param controls An array of layout entries to process.
 * @param logicalPageName The logical name of the page for masking rules.
 * @param maskItems A mutable array to store mask objects.
 * @return An updated array of layout entries.
 */
- (NSMutableArray *) fixupLayoutEntries:(NSArray *) controls addLogicalPageName: (NSString *) logicalPageName returnMaskArray: (NSMutableArray *) maskItems {
    NSMutableArray *newControls = [controls mutableCopy];
    
    @try {
        for (int i = 0; i < [newControls count]; i++) {
            NSObject *entry = newControls[i];
        
            if ([entry isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *newEntry = [((NSDictionary *) entry) mutableCopy];
 
                NSString *isMasked = newEntry[@"masked"];
                
                if (isMasked != nil && [isMasked isEqualToString:@"true"]) {
                    NSDictionary *position = (NSDictionary *) newEntry[@"position"];
                
                    if (position != nil) {
                        // Use label as masking regex
                        NSDictionary *accessibility = (NSDictionary *) newEntry[@"accessibility"];
                        NSString *objId = newEntry && newEntry[@"id"] ? newEntry[@"id"] : @"";
                        NSString *accId = accessibility && accessibility[@"id"] ? accessibility[@"id"] : @"";
                        NSString *accLabel = accessibility && accessibility[@"label"] ? accessibility[@"label"] : @"";
                        NSDictionary *currentState = (NSDictionary *) newEntry[@"currState"];
                        NSString *currentStateText;
                        if (currentState != nil) {
                            currentStateText = currentState[@"text"];
                        }
                        
                        bool willMask = [self willMaskWithAccessibility:objId text:currentStateText accId:accId accLabel:accLabel addLogicalPageName:logicalPageName];
                        if (willMask) {
                            [maskItems addObject:@{@"position": position, @"text": @""}];
                            // Remove value to mask
                            if (currentStateText != nil) {
                                NSMutableDictionary *mutableCurrentState = [currentState mutableCopy];
                                mutableCurrentState[@"text"] = @"";
                                newEntry[@"currState"] = mutableCurrentState;
                            }
                        }
                        
                    }
                }
                
                NSDictionary *image = newEntry[@"image"];
            
                if (image != nil) {
                    NSMutableDictionary *newImage = [image mutableCopy];
                    TlImage *tlImage = nil;
                
                    // Note: The incoming data is RAW byte data and needs to be converted to base64
                    FlutterStandardTypedData *rawData = (FlutterStandardTypedData *) image[@"base64Image"];
                    int imageWidth = [newImage[@"width"] intValue];
                    int imageHeight = [newImage[@"height"] intValue];
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGSize size = CGSizeMake(imageWidth, imageHeight);
                        
                    CGContextRef bitmapContext = CGBitmapContextCreate(
                        (void *) [rawData.data bytes],
                        imageWidth,
                        imageHeight,
                        8,              // bitsPerComponent
                        4*imageWidth,   // bytesPerRow
                        colorSpace,
                        kCGImageAlphaNoneSkipLast);

                    CFRelease(colorSpace);

                    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
                        
                    if (cgImage != nil) {
                        UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage];
                        if (uiImage != nil) {
                            tlImage = [[TlImage alloc] initWithImage:uiImage andSize:size andConfig:_imageAttributes];
                        }
                    }
                
                    if (tlImage != nil) {
                        newImage[@"mimeExtension"] = [tlImage getMimeType];
                        newImage[@"base64Image"] = [tlImage getBase64String];
                        newImage[@"value"] = [tlImage getHash];
            
                        newEntry[@"image"] = newImage;
                    }
                }
                newControls[i] = newEntry;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Controls fixup caused an exception: %@", [exception reason]);
    }

    return newControls;
}

/**
 * @discussion Logs the layout of the screen with a specified name and delay.
 *
 * @remarks This method logs the layout of the screen by capturing the current view controller and sending it to the Connect framework for recording. If the delay is greater than 0, it waits for the specified duration before logging the view.
 * This method should be called from the main thread.
 */
- (void) tlLogScreenLayout: (NSDictionary *) args {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *uv = [self getCurrentMainViewController];
//        NSString *tlType = (NSString *) [self checkForParameter:args withKey:@"tlType"];
        NSString *name = (NSString *) [self checkForParameter:args withKey:@"name"];
        NSNumber *delay = 0;
        
        if (args.count == 3) {
            delay = (NSNumber *) [self checkForParameter:args withKey:@"delay"];
        }
        
        [[ConnectCustomEvent sharedInstance] logScreenViewPageName:name];

        if (delay.floatValue <= 0) {
            [[ConnectCustomEvent sharedInstance] logScreenLayoutWithViewController:uv andName:name];
        } else {
            [[ConnectCustomEvent sharedInstance] logScreenLayoutWithViewController:uv andDelay:0.5 andName:name];
        }
        NSLog(@"ConnectFlutterPlugin - logScreenLayout: %@", name);
    });
}

- (UIViewController*) getCurrentMainViewController {
    UIViewController *topController;
    @try {
        topController = EOApplicationHelper.sharedInstance.getUIWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        
        if ([topController isKindOfClass:[UITabBarController class]] &&
            ((UITabBarController*) topController).selectedViewController != nil) {
            topController = ((UITabBarController*) topController).selectedViewController;
        }
    }
    @catch(NSException* exception) {
        @throw exception;
    }
    @finally {
        // Nothing to be done in finally
    }
    return topController;
}

/**
 * Logs a screen view context unload event.
 *
 * @param args A dictionary containing the parameters for the event.
 * Keys include:
 * - "name": Logical name of the current page.
 * - "referrer": Source that led the user to this page.
 */
- (void) tlLogScreenViewContextUnload: (NSDictionary *) args {
        // Checking for 'name' parameter in the args, which is supposed to be the logical name of the current page
        NSString *logicalPageName =  (NSString *) [self checkForParameter:args withKey:@"name"];
        // Checking for 'referrer' parameter in the args, which is supposed to be the source that led the user to this page
        NSString *referrer =  (NSString *) [self checkForParameter:args withKey:@"referrer"];

        NSString *cllasss = logicalPageName == nil ? @"Flutter" : [NSString stringWithFormat:@"Flutter_%@", logicalPageName];
        [[ConnectCustomEvent sharedInstance] logScreenViewContext:logicalPageName withClass:cllasss applicationContext:ConnectScreenViewTypeUnload referrer:referrer];
}

/**
 * Retrieves a list of accessibility labels for masking from a JSON configuration.
 *
 * @param inputJSON The JSON configuration dictionary.
 * @param logicalPageName The logical page name to retrieve masking settings for.
 * @return An array of accessibility labels for masking.
 */
- (NSArray *)retrieveMaskAccessibilityListFromJSON:(NSDictionary *)inputJSON forLogicalPage:(NSString *)logicalPageName forKey:(NSString *)key {
    
    // Check if the input JSON exists and has the necessary structure
    if (inputJSON && [inputJSON isKindOfClass:[NSDictionary class]]) {
        // Check if the logicalPageName exists, if not, use "GlobalScreenSettings"
        NSDictionary *pageSettings = inputJSON[logicalPageName] ?: inputJSON[@"GlobalScreenSettings"];
        
        // Check if "Masking" and "HasMasking" properties exist for the logicalPageName or default page
        NSDictionary *masking = pageSettings[@"Masking"];
        NSNumber *hasMasking = masking[@"HasMasking"];
        if (masking && hasMasking && [hasMasking boolValue]) {
            NSArray *maskAccessibilityLabelList = masking[key];
            // Check if exists and is an array
            if (maskAccessibilityLabelList && [maskAccessibilityLabelList isKindOfClass:[NSArray class]]) {
                return maskAccessibilityLabelList;
            }
        }
    }
    
    // Return an empty array if the key doesn't exist or the structure is incorrect
    return @[];
}


/**
 * Determines whether masking is required based on accessibility attributes and logical page name.
 *
 * @param objId The object ID to check against masking rules.
 * @param text The text value to check against masking rules.
 * @param accId The accessibility ID to check against masking rules.
 * @param label The accessibility label to check against masking rules.
 * @param logicalPageName The logical page name used to retrieve masking settings.
 * @return YES if masking is required, NO otherwise.
 */
- (BOOL)willMaskWithAccessibility:(NSString*) objId text:(NSString*) text accId:(NSString *) accId accLabel:(NSString *) label addLogicalPageName:(NSString *) logicalPageName {
    // Retrieve the shared instance of EOApplicationHelper
    EOApplicationHelper* helper = [[EOApplicationHelper sharedInstance] init];
    NSDictionary *item; // Configuration dictionary
    NSArray *accessibilityIdArray; // Array of accessibility IDs for masking
    NSArray *accessibilityLabelArray; // Array of accessibility labels for masking
    NSArray *tagRegexArray; // Array of regex patterns for masking based on tags
    NSArray *valueRegexArray; // Array of regex patterns for masking based on values
    
    // Fetch the configuration item for "AutoLayout" from the TLFCoreModule
    id returnedObject = [helper getConfigItem:@"AutoLayout" forModuleName:@"TLFCoreModule"];
    
    // Ensure the returned object is a dictionary
    if ([returnedObject isKindOfClass:[NSDictionary class]]) {
        item = (NSDictionary *)returnedObject;
    } else {
        // Log an error if the returned object is not a dictionary
        NSLog(@"Returned object is not an NSDictionary.");
        return NO;
    }
    
    // Retrieve masking rules from the configuration dictionary
    tagRegexArray = [self retrieveMaskAccessibilityListFromJSON:item forLogicalPage:logicalPageName forKey:@"MaskIdList"];
    valueRegexArray = [self retrieveMaskAccessibilityListFromJSON:item forLogicalPage:logicalPageName forKey:@"MaskValueList"];
    accessibilityLabelArray = [self retrieveMaskAccessibilityListFromJSON:item forLogicalPage:logicalPageName forKey:@"MaskAccessibilityLabelList"];
    accessibilityIdArray = [self retrieveMaskAccessibilityListFromJSON:item forLogicalPage:logicalPageName forKey:@"MaskAccessibilityIdList"];
    
    // Check if any of the attributes match the masking rules
    if ([self willMaskWithAccessibilityHelper:tagRegexArray str:objId] ||
        [self willMaskWithAccessibilityHelper:valueRegexArray str:text] ||
        [self willMaskWithAccessibilityHelper:accessibilityIdArray str:accId] ||
        [self willMaskWithAccessibilityHelper:accessibilityLabelArray str:label]) {
        return YES; // Masking is required
    }
    
    // Return NO if no match is found
    return NO;
}

/**
 * Determines whether masking should be applied using an accessibility helper.
 *
 * @param accArray An array of accessibility-related objects or data used for masking logic.
 * @param testStr A string parameter that may influence the masking decision.
 * @return A boolean value indicating whether masking should be applied.
 */
- (BOOL)willMaskWithAccessibilityHelper:(NSArray*)accArray str:(NSString*)testStr {
    if (accArray &&
        accArray.count > 0 &&
        testStr != nil) {
        // Iterate through each regex pattern in accessibilityLabelArray
        for(NSString *regstr in accArray) {
            // Create NSRegularExpression object from the regex pattern
            NSError *error = nil;
            NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:regstr options:0 error:&error];
            
            // Handle error in regex creation, if any
            if (error) {
                NSLog(@"Error creating NSRegularExpression: %@", [error localizedDescription]);
                continue;
            }
            
            // Check if the given text matches the regex pattern
            NSRange textRange = NSMakeRange(0, [testStr length]);
            NSRange firstMatch = [regExp rangeOfFirstMatchInString:testStr options:0 range:textRange];
            
            // Return YES if there's a match, indicating masking is needed
            if (firstMatch.location != NSNotFound) {
                return YES;
            }
        }
    }
    
    // Return NO if no match found or if accessibilityLabelArray is empty
    return NO;
}

/**
 * Logs a screen view and its layout, including masking rules and screenshots.
 *
 * @param screenViewType The type of screen view (e.g., "LOAD", "UNLOAD").
 * @param referrer The referrer for the screen view.
 * @param layouts An array of layout entries to process.
 * @param logicalPageName The logical name of the page.
 */
- (void) tlScreenviewAndLayout:(NSString *) screenViewType addRef:(NSString *) referrer addLayouts:(NSArray *) layouts addLogicalPageName: (NSString *) logicalPageName {
    if (referrer == nil) {
        referrer = @"none";
    }
    UIImage *maskedScreenshot = nil;
    UIImage *screenshot       = [self takeScreenShot];
    
    NSMutableArray *maskObjects = [@[] mutableCopy];
    NSArray *updatedLayouts = [self fixupLayoutEntries:layouts addLogicalPageName: (NSString *) logicalPageName returnMaskArray:maskObjects];
    
    if ([maskObjects count] > 0 && screenshot != nil) {
        maskedScreenshot = [self maskImageWithObjects:screenshot withObjects:maskObjects];
    }
    if (screenshot == nil) {
        screenshot = [UIImage imageNamed:@""];
    }
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    TlImage *tlImage  = [[TlImage alloc] initWithImage:screenshot andSize:screenSize andConfig:_basicConfig];
    
    if (maskedScreenshot != nil) {
        [tlImage updateWithImage:maskedScreenshot];
    }
    
    NSString *originalHash = [tlImage getOriginalHash];
    
    if ([_lastHash isEqualToString:originalHash]) {
        NSLog(@"Not logging screenview as unmasked screen has not updated, hash: %@", originalHash);
        return;
    }
    _lastHash = originalHash;
    
    NSString *hash = tlImage == nil ? @"" : [tlImage getHash];
    NSString *base64ImageString = tlImage == nil ? @"" : [tlImage getBase64String];
    
    NSMutableDictionary *screenContext = [@{
        @"screenview":@{
            @"type": screenViewType,
            @"name": logicalPageName,
            @"class": logicalPageName,
            @"referrer": referrer
        }
    } mutableCopy];
    /*
    if ([base64ImageString length] > 0) {
        screenContext[@"base64Representation"] = base64ImageString;
    }
    */
    [self tlLogMessage:screenContext addType: @2];
    
    _lastScreen = base64ImageString;
    
    // Now add the layout data
    int      orientation = [self getOrientation];
    int      width = round(_screenWidth / _scale);
    int      height = round(_screenHeight / _scale);
    //NSMutableArray *maskItems = [NSMutableArray alloc];
    //NSArray *updatedLayouts = [self fixupLayoutEntries:layouts returnMaskArray:maskItems];
    
    NSMutableDictionary *layout = [@{
        @"layout": @{
            @"name": logicalPageName,
            @"class": logicalPageName,
            @"controls": updatedLayouts   // aka controls
        },
        @"version": @"1.0",
        @"orientation": @(orientation),
        @"deviceWidth": @(width),
        @"deviceHeight": @(height),
    } mutableCopy];
    
    if ([base64ImageString length] > 0) {
        layout[@"backgroundImage"] = @{
            @"base64Image": base64ImageString,
            @"type": @"image",
            @"mimeExtension": _mimeType,
            //@"height": @(height),
            //@"width": @(width),
            @"value": hash
        };
    }

    [self tlLogMessage:layout addType: @10];
}

/**
 * Sets the environment configuration for the screen dimensions.
 *
 * @param args A dictionary containing screen width and height.
 */
- (void) tlSetEnvironment: (NSDictionary *) args {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    NSNumber *width = (NSNumber *) [self checkForParameter:args withKey:@"screenw"];
    NSNumber *height = (NSNumber *) [self checkForParameter:args withKey:@"screenh"];
    
    _screenWidth  = [(NSNumber *) width integerValue];
    _screenHeight = [(NSNumber *) height integerValue];
    _adjustWidth  = _screenWidth / screenSize.width;
    _adjustHeight = _screenHeight / screenSize.height;
    
    NSLog(@"Flutter screen dimensions, width: %@, height: %@", [width description], [height description]);
}

/**
 * Logs an exception event with details such as name, message, stack trace, and whether it was handled.
 *
 * @param args A dictionary containing exception details.
 */
- (void) tlException: (NSDictionary *) args {
    NSString *name = (NSString *) [self checkForParameter:args withKey:@"name"];
    NSString *message = (NSString *) [self checkForParameter:args withKey:@"message"];
    NSString *stackTrace = (NSString *) [self checkForParameter:args withKey:@"stacktrace"];
    BOOL handled = [(NSNumber *) [self checkForParameter:args withKey:@"handled"] boolValue];
    
    NSDictionary *exceptionMessage = @{
        @"exception": @{
            @"name":        name,
            @"description": message,
            @"unhandled":   @(!handled),
            @"stacktrace":  stackTrace
        }
    };
    
    [self tlLogMessage:exceptionMessage addType:@6];
}

/**
 * Logs a connection event with details such as URL, status code, response size, and timings.
 *
 * @param args A dictionary containing connection details.
 */
- (void) tlConnection: (NSDictionary *) args {
    NSString *url = (NSString *)[self checkForParameter:args withKey:@"url"];
    int statusCode = (int) [self checkParameterStringAsInteger:args withKey:@"statusCode"];
    long responseDataSize = (int) [self checkParameterStringAsInteger:args withKey:@"responseDataSize"];
    long initTime = [self checkParameterStringAsInteger:args withKey:@"initTime"];
    long loadTime = [self checkParameterStringAsInteger:args withKey:@"loadTime"];
    long responseTime = [self checkParameterStringAsInteger:args withKey:@"responseTime"];
    NSString *description = (NSString *) [self checkForParameter:args withKey:@"description"];
    
    // TBD: logLevel check?
    NSDictionary *connectionMessage = @{
        @"connection": @{
            @"url":              url,
            @"statusCode":       @(statusCode),
            @"responseDataSize": @(responseDataSize),
            @"initTime":         @(initTime),
            @"responseTime":     @(responseTime),
            @"loadTime":         @(loadTime),
            @"description":      description
        },
    };
    
    [self tlLogMessage:connectionMessage addType: @3];
}

/**
 * Logs a custom event with a specified name and data.
 *
 * @param args A dictionary containing event details.
 */
- (void) tlCustomEvent: (NSDictionary *) args {
    NSString *eventName = (NSString *) [self checkForParameter:args withKey:@"eventname"];
    NSDictionary *data  = (NSDictionary *)[self checkForParameter:args withKey:@"data"];
    NSNumber *logLevel  = args[@"loglevel"];
    
    if (logLevel == (NSNumber *) [NSNull null]) {
        [self alternateCustomEvent:eventName addData:data];
        //[[ConnectCustomEvent sharedInstance] logEvent:eventName values:data];
    }
    else {
        kConnectMonitoringLevelType level = (kConnectMonitoringLevelType) [logLevel intValue];
        [[ConnectCustomEvent sharedInstance] logEvent:eventName values:data level:level];
    }
}

/**
 * Logs a signal event with specified data and log level.
 *
 * @param args A dictionary containing signal details.
 */
- (void) tlLogSignal: (NSDictionary *) args {
    NSDictionary *data  = (NSDictionary *)[self checkForParameter:args withKey:@"data"];
    NSNumber *logLevel  = args[@"loglevel"];
    
    if (logLevel == (NSNumber *) [NSNull null]) {
        [[ConnectCustomEvent sharedInstance] logSignal:data];
    }
    else {
        kConnectMonitoringLevelType level = (kConnectMonitoringLevelType) [logLevel intValue];
        [[ConnectCustomEvent sharedInstance] logSignal:data level:level];
    }
}

/**
 * Logs a message with a specified type.
 *
 * @param message The message dictionary to log.
 * @param tlType The type of the message.
 * @return YES if the message was logged successfully, NO otherwise.
 */
- (BOOL) tlLogMessage: (NSDictionary *) message addType: (NSNumber *) tlType {
    [self getScreenViewOffset];
    NSMutableDictionary *baseMessage = [@{@"fromWeb": @(_fromWeb), @"offset": @47, @"screenviewOffset": @(_screenOffset), @"type": @0} mutableCopy];
    
    baseMessage[@"type"] = tlType;
    [baseMessage addEntriesFromDictionary:message];
    
    NSString *logMessageString = [self getJSONString:baseMessage];
    
    NSLog(@"Logging Messsage: %@", logMessageString);
    
    return [[ConnectCustomEvent sharedInstance] logJSONMessagePayloadStr:logMessageString];
}

/**
 * Logs a screen view event with a delay to ensure the UI is fully rendered.
 *
 * @param args A dictionary containing screen view details.
 */
- (void) tlScreenview: (NSDictionary *) args {
  // Delay to ensure UI screen is fully rendered
  double delayInSeconds = 0.5;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    // Code to be executed after a delay of 0.5 seconds (500 milliseconds)
    NSString *tlType = (NSString *) [self checkForParameter:args withKey:@"tlType"];
    NSString *logicalPageName = (NSString *) [self checkForParameter:args withKey:@"logicalPageName"];
    NSObject *layouts  = args[@"layoutParameters"];
     
    if (layouts != nil) {
      if ([layouts isKindOfClass:[NSArray class]]) {
        NSLog(@"layoutParameters: %@", [layouts class]);
      }
      else {
        NSLog(@"Error in layout type");
        layouts = nil;
      }
    }

    [self tlScreenviewAndLayout:tlType addRef:nil addLayouts:(NSArray *)layouts addLogicalPageName:logicalPageName];
     
    NSLog(@"Screenview, tlType: %@", tlType);
  });
}

/**
 * Handles pointer events with the given arguments.
 *
 * @param args A dictionary containing the arguments for the pointer event.
 *             The expected keys and values in the dictionary should be defined
 *             based on the specific requirements of the pointer event handling.
 */
- (void) tlPointerEvent: (NSDictionary *) args {
    [self getPointerEvent:args];
}

/**
 * Processes a string to extract specific content based on a regular expression pattern.
 *
 * @param inputString The input string to process.
 * @return The extracted content within parentheses or the first word, or nil if no match is found.
 */
NSString *processString(NSString *inputString) {
    NSError *error = nil;
    
    // Define a regular expression pattern to capture content within parentheses or the first word.
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([^)]+)\\)|(\\w+)" options:0 error:&error];
    
    if (!error) {
        // Find the first match in the input string.
        NSTextCheckingResult *match = [regex firstMatchInString:inputString options:0 range:NSMakeRange(0, [inputString length])];
        if (match) {
            if ([match rangeAtIndex:1].location != NSNotFound) {
                // Content within parentheses found, use it.
                return [inputString substringWithRange:[match rangeAtIndex:1]];
            } else if ([match rangeAtIndex:2].location != NSNotFound) {
                // No parentheses found, use the first word.
                return [inputString substringWithRange:[match rangeAtIndex:2]];
            }
        }
    }
    
    // If no match is found, return nil or an appropriate default value.
    return nil;
}

/**
 * Converts the given object to a CGFloat value.
 *
 * @param o The object to be converted. It is expected to be a type that can
 *          be interpreted as a floating-point number, such as NSNumber or NSString.
 * @return A CGFloat representation of the input object. If the object cannot
 *         be converted, the behavior should be defined within the implementation.
 */
- (CGFloat)getAsFloat:(id)o {
    NSAssert(o != nil, @"Object cannot be nil");
    return [o floatValue];
}

/**
 * Retrieves the current state based on the provided layout dictionary.
 *
 * @param wLayout A dictionary containing the layout information used to determine the current state.
 *                 The keys and values in this dictionary should represent layout properties.
 * @return A dictionary containing the current state information. The keys and values in this dictionary
 *         represent the state properties derived from the provided layout.
 */
- (NSDictionary<NSString *, id> *)getCurrentState:(NSDictionary<NSString *, id> *)wLayout {
    id currStateObject = wLayout[@"currState"];

    if ([currStateObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *state = (NSDictionary<NSString *, id> *)currStateObject;
        return state;
    }
    return nil;
}

/**
 * Retrieves a Position object based on the provided layout dictionary.
 *
 * @param wLayout A dictionary containing layout information with keys as NSString
 *                and values as id. This dictionary is expected to define the layout
 *                properties required to determine the position.
 * @return A Position object derived from the layout information provided in the dictionary.
 */
- (Position *)getPositionFromLayout:(NSDictionary<NSString *, id> *)wLayout {
    CGFloat pixelDensity = [UIScreen mainScreen].scale;;
    BOOL isMasked = [[NSString stringWithFormat:@"%@", wLayout[@"masked"]] isEqualToString:@"true"];
    id positionObject = wLayout[@"position"];
    Position *position = [[Position alloc] init];

    if ([positionObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, NSString *> *widgetPosition = (NSDictionary<NSString *, NSString *> *)positionObject;
        int x = roundf([self getAsFloat:widgetPosition[@"x"]] * pixelDensity);
        int y = roundf([self getAsFloat:widgetPosition[@"y"]] * pixelDensity);
        int width = roundf([self getAsFloat:widgetPosition[@"width"]] * pixelDensity);
        int height = roundf([self getAsFloat:widgetPosition[@"height"]] * pixelDensity);
        CGRect rect = CGRectMake(x, y, width, height);
        
        NSDictionary<NSString *, id> *currentState = [self getCurrentState:wLayout];
        NSString *text = (currentState == nil) ? @"" : [NSString stringWithFormat:@"%@", currentState[@"text"]];

//        [ConnectFlutterPlugin.LOGGER logWithLevel:LevelInfo message:[NSString stringWithFormat:@"*** Layout -- x: %d, y: %d, text: %@", x, y, text]];
        NSLog(@"Position: rect = %@, x = %d, y = %d, width = %d, height = %d, label = %@",
              NSStringFromCGRect(position.rect), position.x, position.y, position.width, position.height, position.label);
        
        [position setRect:rect];
        [position setX:x];
        [position setY:y];
        [position setHeight:height];
        [position setWidth:isMasked ? 0 : width];
        [position setLabel:isMasked ? text : nil];
    }

    return position;
}

/**
 * Converts the given NSString to a float value.
 *
 * @param string The NSString to be converted to a float.
 *               It is expected to contain a valid numeric representation.
 * @return A float value parsed from the input string.
 *         If the string cannot be converted, the behavior may depend on the implementation.
 */
+ (float)getAsFloat:(NSString *)string {
    return [string floatValue];
}

+ (NSDictionary<NSString *, id> *)getCurrentState:(NSDictionary<NSString *, id> *)wLayout {
    // Implement this method based on your logic to get the current state.
    return nil;
}

/**
 * Processes gesture events such as swipe and pinch and logs them.
 *
 * @param args A dictionary containing gesture event details.
 */
- (void) tlGestureEvent: (NSDictionary *) args {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @try {
            NSString *tlType = (NSString *) [self checkForParameter:args withKey:@"tlType"];
            NSString *wid    = (NSString *) [self checkForParameter:args withKey:@"id"];
            NSString *target = (NSString *) [self checkForParameter:args withKey:@"target"];
            NSObject *layouts   = args[@"layoutParameters"];
            

            BOOL     isSwipe = [tlType isEqualToString:@"swipe"];
            BOOL     isPinch = [tlType isEqualToString:@"pinch"];
            
            CGFloat        vdx = 0, vdy = 0;
            NSString       *direction = nil;
            NSMutableArray *pointerEvents = [[NSMutableArray alloc] init];

            NSDictionary *data = (NSDictionary *) args[@"data"];
            NSDictionary *accessibility = [[NSDictionary alloc] init];

            if (data != (NSDictionary *) [NSNull null]) {
                accessibility = data[@"accessibility"];
            }
            
            // New screenshot needed
            UIImage *maskedScreenshot = nil;
            UIImage *screenshot       = [self takeScreenShot];
            
            NSMutableArray *maskObjects = [@[] mutableCopy];
            
            NSString *logicalPageName = @"";
            [self fixupLayoutEntries:(NSArray *)layouts addLogicalPageName: (NSString *) logicalPageName returnMaskArray:maskObjects];
            
            if ([maskObjects count] > 0 && screenshot != nil) {
                maskedScreenshot = [self maskImageWithObjects:screenshot withObjects:maskObjects];
            }
            if (screenshot == nil) {
                screenshot = [UIImage imageNamed:@""];
            }
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            
            TlImage *tlImage;
            if (maskedScreenshot != nil) {
                tlImage  = [[TlImage alloc] initWithImage:maskedScreenshot andSize:screenSize andConfig:self->_basicConfig];
            } else {
                tlImage  = [[TlImage alloc] initWithImage:screenshot andSize:screenSize andConfig:self->_basicConfig];
            }
            
            NSString *originalHash = [tlImage getOriginalHash];
            
            if ([self->_lastHash isEqualToString:originalHash]) {
                NSLog(@"Not logging screenview as unmasked screen has not updated, hash: %@", originalHash);
                return;
            }
            self->_lastHash = originalHash;
            
            NSString *base64ImageString = tlImage == nil ? @"" : [tlImage getBase64String];
            
            self->_lastScreen = base64ImageString.length > 0 ? base64ImageString : self->_lastScreen;

            if (isPinch || isSwipe) {
                PointerEvent *pointerEvent1, *pointerEvent2;

                NSDictionary *data = (NSDictionary *) [self checkForParameter:args withKey:@"data"];
             
                CGFloat  x1   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer1" withSubKey:@"dx"] floatValue];
                CGFloat  y1   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer1" withSubKey:@"dy"] floatValue];
                NSString *ts1 = isPinch ? @"0" : (NSString *)[self checkForParameter:data withKey:@"pointer1" withSubKey:@"ts"];
                
                pointerEvent1 = [[PointerEvent alloc] initWith:@"DOWN" andX:x1 andY:y1 andTs:ts1 andDown:0 andPressure:0 andKind:0];
                
                CGFloat  x2   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer2" withSubKey:@"dx"] floatValue];
                CGFloat  y2   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer2" withSubKey:@"dy"] floatValue];
                NSString *ts2 = isPinch ? @"0" : (NSString *)[self checkForParameter:data withKey:@"pointer2" withSubKey:@"ts"];
                    
                pointerEvent2 = [[PointerEvent alloc] initWith:@"DOWN" andX:x2 andY:y2 andTs:ts2 andDown:0 andPressure:0 andKind:0];
                
                vdx       = [(NSNumber *) [self checkForParameter:data withKey:@"velocity" withSubKey:@"dx"] floatValue];
                vdy       = [(NSNumber *) [self checkForParameter:data withKey:@"velocity" withSubKey:@"dy"] floatValue];
                direction = (NSString *)  [self checkForParameter:data withKey:@"direction"];
                
                int times = isPinch ? 2 : 1;
                
                for (int i = 0; i < times; i++) {
                    [pointerEvents addObject:pointerEvent1];
                    [pointerEvents addObject:pointerEvent2];
                }
            }
            else {
                [pointerEvents addObject:self->_lastMotionUpEvent != nil ? self->_lastMotionUpEvent : @"Tap"];
            }
            
            NSMutableArray *touches = [[NSMutableArray alloc] init];
            NSMutableArray *touch   = nil;
            int touchCount = (int) [pointerEvents count];

            for (int i = 0; i < touchCount; /* inc at bottom of loop for test */) {
                PointerEvent *pointerEvent = pointerEvents[i];
                
                if (touch == nil) {
                    touch = [[NSMutableArray alloc] init];
                }
                
                CGFloat x      = pointerEvent.x *  self->_scale;
                CGFloat y      = pointerEvent.y * self->_scale;
                CGFloat relX   = x /  self->_screenWidth;
                CGFloat relY   = y / self->_screenHeight;
                NSString *xy   = [NSString stringWithFormat:@"%f,%f", relX, relY];
                
                NSString *type = @"";
                if (target != nil && target.length > 0) {
                    type = processString(target);
                }

                [touch addObject: @{
                    @"position": @{
                        @"x": @(pointerEvent.x),
                        @"y": @(pointerEvent.y)
                    },
                    @"control":  @{
                        @"position": @{
                            @"height": @( self->_screenHeight),
                            @"width":  @(self->_screenWidth),
                            @"relXY":  xy,
                        },
                        @"id":       wid,
                        @"idType":   @(-4),
                        @"type":     type,
                        @"subType":  @"FlutterViewGeneric",
                        @"tlType":   type,
                        @"accessibility": (accessibility ?: [NSNull null]),
                    },
                }];
                // After two 'touch' entries, move to next element in touches arrays (for pinch and swipe)
                i += 1;
                if ((i % 2) == 0 || i >= touchCount) {
                    [touches addObject:touch];
                    touch = nil;
                }
            }
            
//            UIImage *screenshot       = [self takeScreenShot];
//            CGSize screenSize = [UIScreen mainScreen].bounds.size;
//            TlImage *tlImage  = [[TlImage alloc] initWithImage:screenshot andSize:screenSize andConfig:_basicConfig];
//            NSString *base64ImageString = tlImage == nil ? @"" : [tlImage getBase64String];
            self->_lastScreen = base64ImageString;

            NSMutableDictionary *gestureMessage =[@{
                @"event": [@{
                    @"type":    isPinch ? @"onScale" : self->_lastMotionUpEvent != nil ? self->_lastMotionUpEvent.action : @"Tap",
                    @"tlEvent": tlType
                } mutableCopy],
                @"touches": touches,
                @"base64Representation": self->_lastScreen
            } mutableCopy];
            
            if (direction != nil) {
                gestureMessage[@"direction"] = direction;
                gestureMessage[@"velocityX"] = @(vdx);
                gestureMessage[@"velocityY"] = @(vdy);
            }
            
            [self tlLogMessage:gestureMessage addType: @11];
            
            self->_lastDown = 0L;
            self->_lastMotionUpEvent = self->_firstMotionEvent = nil;
        
        } @catch (NSException *exception) {
            NSLog(@"An exception occurred: %@", exception);
        }
    });
}

/**
 * Logs focus change events for widgets.
 *
 * @param args A dictionary containing focus change details.
 */
- (void) tlFocusChanged: (NSDictionary *) args {
    @try {
        NSString *wid = (NSString *) [self checkForParameter:args withKey:@"widgetId"];
        NSString *focused = (NSString *) [self checkForParameter:args withKey:@"focused"];
        NSString *type = [focused boolValue] ? @"OnFocusChange_In" : @"OnFocusChange_Out";
        NSString *tlEvent = @"textChange";

        NSDictionary *focusMessage = @{
                @"event": @{
                        @"tlType":  wid,
                        @"type":    type,
                        @"tlEvent": tlEvent
                },
        };

        [self tlLogMessage:focusMessage addType: @4];
    
    } @catch (NSException *exception) {
        NSLog(@"An exception occurred: %@", exception);
    }
}

/**
 * Logs performance events such as navigation timings.
 *
 * @param args A dictionary containing performance event details.
 * @return YES if the performance event was logged successfully, NO otherwise.
 */
- (BOOL) tlLogPerformanceEvent: (NSDictionary *) args {
    NSString *type = @"NAVIGATE";
    long redirectCount = [self checkParameterStringAsInteger:args withKey:@"redirectCount"];
    long navigationStart = [self checkParameterStringAsInteger:args withKey:@"navigationStart"];
    long unloadEventStart = [self checkParameterStringAsInteger:args withKey:@"unloadEventStart"];
    long unloadEventEnd = [self checkParameterStringAsInteger:args withKey:@"unloadEventEnd"];
    long redirectStart = [self checkParameterStringAsInteger:args withKey:@"redirectStart"];
    long redirectEnd = [self checkParameterStringAsInteger:args withKey:@"redirectEnd"];
    long loadEventStart = [self checkParameterStringAsInteger:args withKey:@"loadEventStart"];
    long loadEventEnd = [self checkParameterStringAsInteger:args withKey:@"loadEventEnd"];
    

    NSDictionary *performanceMessage = @{
        @"performance": @{
            @"navigation": @{
                @"type":          type,
                @"redirectCount": @(redirectCount),
            },
            @"timing": @{
                @"navigationStart":             @(navigationStart),
                @"unloadEventStart":            @(unloadEventStart),
                @"unloadEventEnd":              @(unloadEventEnd),
                @"redirectStart":               @(redirectStart),
                @"redirectEnd":                 @(redirectEnd),
                @"loadEventStart":              @(loadEventStart),
                @"loadEventEnd":                @(loadEventEnd),
                @"fetchStart":                  @(-1),
                @"domainLookupStart":           @(-1),
                @"domainLookupEnd":             @(-1),
                @"connectStart":                @(-1),
                @"connectEnd":                  @(-1),
                @"secureConnectionStart":       @(-1),
                @"requestStart":                @(-1),
                @"responseStart":               @(-1),
                @"responseEnd":                 @(-1),
                @"domLoading":                  @(-1),
                @"domInteractive":              @(-1),
                @"domContentLoadedEventStart":  @(-1),
                @"domContentLoadedEventEnd":    @(-1),
                @"domComplete":                 @(-1),
            },
        },
    };

    return [self tlLogMessage:performanceMessage addType: @7];
}

/**
 * Handles method calls from Flutter and routes them to the appropriate native methods.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    @try {
        if ([@"getPlatformVersion" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSString *platformVersion = [[UIDevice currentDevice] systemVersion];
            NSLog(@"Platform Version: %@", platformVersion);
            result([@"iOS " stringByAppendingString: platformVersion]);
        }
        else if ([@"getConnectVersion" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSDictionary *dict = [self getAdvancedConfig];
            NSLog(@"Lib version: %@", dict[@"LibraryVersion"]);
            result(dict[@"LibraryVersion"]);
        }
        else if ([@"getConnectSessionId" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSString *sessionId = [[ConnectApplicationHelper sharedInstance] currentSessionId];
            NSLog(@"Session ID: %@", sessionId);
            result(sessionId);
        }
        else if ([@"getAppKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSMutableDictionary *dict = [self getBasicConfig];
            result(dict[@"AppKey"]);
        }
        else if ([@"setEnv" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlSetEnvironment:call.arguments];
            result(nil);
        }
        else if ([@"getGlobalConfiguration" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            result([self getBasicLayoutConfigurationString]);
        }
        else if ([@"pointerEvent" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlPointerEvent:call.arguments];
            result(nil);
        }
        else if ([@"gesture" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlGestureEvent:call.arguments];
            result(nil);
        }
        else if ([@"screenView" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlScreenview:call.arguments];
            result(nil);
        }
        else if ([@"logScreenLayout" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlLogScreenLayout:call.arguments];
            result(nil);
        }
        else if ([@"logScreenViewContextUnload" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlLogScreenViewContextUnload:call.arguments];
            result(nil);
        }
        else if ([@"exception" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlException:call.arguments];
            result(nil);
        }
        else if ([@"connection" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlConnection:call.arguments];
            result(nil);
        }
        else if ([@"customEvent" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlCustomEvent:call.arguments];
            result(nil);
        }
        else if ([@"logSignal" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlLogSignal:call.arguments];
            result(nil);
        }
        else if ([@"focuschanged" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlFocusChanged:call.arguments];
            result(nil);
        }
        else if ([@"logPerformanceEvent" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            result(@([self tlLogPerformanceEvent:call.arguments]));
        }
        else if ([@"setBooleanConfigItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlSetBooleanConfigItemForKey:call result:result];
        }
        else if ([@"setStringItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlSetStringItemForKey:call result:result];
        }
        else if ([@"setNumberItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlSetNumberItemForKey:call result:result];
        }
        else if ([@"getBooleanConfigItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlGetBooleanConfigItemForKey:call result:result];
        }
        else if ([@"getStringItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlGetStringItemForKey:call result:result];
        }
        else if ([@"getNumberItemForKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlGetNumberItemForKey:call result:result];
        }
        else {
            result(FlutterMethodNotImplemented);
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception in methodcall, request: %@, name: %@, reason: %@", call.method, exception.name, exception.reason);
        
        NSArray *stackTrace = exception.callStackSymbols;
        NSString *stackTraceAsString = [stackTrace componentsJoinedByString:@"\n"];
        
        result([FlutterError errorWithCode:exception.name message:exception.reason details:stackTraceAsString]);
    }
    @finally {
        NSLog(@"MethodChannel handler, method: %@, args: %@", call.method, [call.arguments description]);
    }
}

/**
 * Sets a boolean configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlSetBooleanConfigItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

/**
 * Sets a string configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlSetStringItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

/**
 * Sets a number configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlSetNumberItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

/**
 * Retrieves a boolean configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlGetBooleanConfigItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL boolValue = [[EOApplicationHelper sharedInstance] getBOOLconfigItemForKey:key withDefault:NO forModuleName:moduleName];
    result(@(boolValue));
}

/**
 * Retrieves a string configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlGetStringItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];

    NSString *stringValue = [[EOApplicationHelper sharedInstance] getStringItemForKey:key withDefault:nil forModuleName:moduleName];
    if (stringValue == nil) {
        EOApplicationHelper *helper = [EOApplicationHelper sharedInstance];
        id configValue = [helper getConfigItem:key forModuleName:moduleName];
        
        if ([NSJSONSerialization isValidJSONObject:configValue]) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:configValue
                                                               options:NSJSONWritingWithoutEscapingSlashes
                                                                 error:&error];
            if (!error) {
                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                NSLog(@"JSON as String: %@", jsonString);
                result(jsonString);
            } else {
                NSLog(@"Error converting to JSON string: %@", error.localizedDescription);
                result(@"");
            }
        }
    } else {
        result(stringValue);
    }
}

/**
 * Retrieves a number configuration item for a specified key and module.
 *
 * @param call The Flutter method call object.
 * @param result The Flutter result callback.
 */
- (void)tlGetNumberItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    NSNumber *numberValue = [[EOApplicationHelper sharedInstance] getNumberItemForKey:key withDefault:nil forModuleName:moduleName];
    result(numberValue);
}

/**
 * Tests and adjusts the module name for compatibility.
 *
 * @param moduleName The module name to test.
 * @return The adjusted module name.
 */
- (NSString*)testModuleName:(NSString*)moduleName {
    if ([moduleName caseInsensitiveCompare:@"Tealeaf"] == NSOrderedSame) {
        return moduleName = @"TLFCoreModule";
    }
    return moduleName;
}

@end

