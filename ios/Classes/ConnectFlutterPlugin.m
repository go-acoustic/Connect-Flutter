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
 Registers the ConnectFlutterPlugin with the Flutter plugin registrar, creating a communication channel between Flutter and native code.

 @param registrar An object conforming to the FlutterPluginRegistrar protocol.
 */
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"connect_flutter_plugin" binaryMessenger:[registrar messenger]];
    ConnectFlutterPlugin* instance = [[ConnectFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

/**
 Initializes the ConnectFlutterPlugin instance, configuring Connect integration and handling image-related settings.

 @return An instance of ConnectFlutterPlugin.
 */
- (id) init {
    self = [super init];
    _screenWidth  = -1;
    _screenHeight = -1;
    _scale   = [UIScreen mainScreen].scale;
    _fromWeb = false;
    
    [self resetScreenLoadTime];
    
    // [[ConnectApplicationHelper sharedInstance] enableConnectFramework];
    setenv("EODebug", "1", 1);
    setenv("TLF_DEBUG", "1", 1);

    ConnectApplicationHelper *ConnectApplicationHelperObj = [[ConnectApplicationHelper alloc] init];
        [ConnectApplicationHelperObj enableFramework];

    NSLog(@"Connect Enabled: %@", [[ConnectApplicationHelper sharedInstance] isTLFEnabled] ? @"Yes" : @"No");
    NSLog(@"Device Pixel Density (scale): %f", _scale);
    
    
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafBasicConfig" ofType:@"plist"];
    _basicConfig         = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    _layoutConfig        = [self getLayoutConfig];
    
    _lastHash            = @"";
    _imageFormat         = [self getBasicConfig][@"ScreenshotFormat"];
    _isJpgFormat         = [_imageFormat caseInsensitiveCompare:@"JPG"] == NSOrderedSame ||
                           [_imageFormat caseInsensitiveCompare:@"JPEG"] == NSOrderedSame;
    _mimeType            = _isJpgFormat ? @"jpg" : @"png";
    
    _imageAttributes     = @{
                            @"format":      _imageFormat,
                            @"isJpg":       @(_isJpgFormat),
                            @"scale":       @(_scale),
                            @"@mimeType":   (_isJpgFormat ? @"jpg" : @"png"),
                            @"%screenSize": @([_basicConfig[@"PercentOfScreenshotsSize"] floatValue]),
                            @"%compress":   @([_basicConfig[@"PercentToCompressImage"] floatValue] / 100.0)
                            };
    
    _lastDown            = 0L;
    _lastScreen          = @"";
    
    return self;
}

-(int) getOrientation {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    return (orientation == UIInterfaceOrientationLandscapeLeft) || (orientation == UIInterfaceOrientationLandscapeRight)
        ? 1 : 0;
}

-(void) resetScreenLoadTime {
    _screenLoadTime = [NSDate timeIntervalSinceReferenceDate];
}

- (NSNumber *) convertNSStringToNSNumber:(NSString *) stringNumber {
    NSNumber *number = [[[NSNumberFormatter alloc]init] numberFromString:stringNumber];
    return number;
}

- (long) checkParameterStringAsInteger:(NSDictionary *) map withKey:(NSString *) key {
    NSString *stringInteger = (NSString *) [self checkForParameter:map withKey:key];
    return [[self convertNSStringToNSNumber:stringInteger] longValue];
}

-(NSTimeInterval) getScreenViewOffset {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    return (_screenOffset = (now - _screenLoadTime) * 1000);
}

- (NSDictionary *) getAdvancedConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafAdvancedConfig" ofType:@"json"];
    NSLog(@"Tealeaf Advanced Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

- (NSDictionary *) getLayoutConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafLayoutConfig" ofType:@"json"];
    NSLog(@"Tealeaf Layout Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

- (NSMutableDictionary *) getBasicConfig {
    return _basicConfig;
}

- (NSString *) getBuildNumber {
    NSString * build = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    return build;
}

- (NSString *) getBasicLayoutConfigurationString {
    NSDictionary *autoLayout = _layoutConfig[@"AutoLayout"];
    //NSDictionary *globalScreenSettings = autoLayout[@"GlobalScreenSettings"];
    //return [self getJSONString:globalScreenSettings];
    return [self getJSONString:autoLayout];
}

- (NSString *) getGlobalConfigurationString {
    return [self getJSONString:_basicConfig];
}

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

- (void) alternateCustomEvent:(NSString *) name addData:(NSDictionary *) data {
    NSDictionary *customEventData = @{@"customData": @{@"name": name, @"data": data}};
    
    [self tlLogMessage:customEventData addType: @5];
}

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
 Applies a mask to an image with specified objects and their attributes.

 @param bgImage The background image to be masked.
 @param maskObjects An array of dictionaries containing text and position attributes for the mask.
 Each dictionary should contain keys: @"text" (NSString) and @"position" (NSDictionary).
 The @"position" dictionary should contain keys: @"x", @"y", @"width", @"height" (CGFloat).
 @return A new UIImage masked with the provided objects.
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


- (UIImage *) takeScreenShot {
    UIImage *screenImage = nil;
    UIViewController *rootController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
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
                        if (accessibility && accessibility[@"label"]) {
                            
                            bool masked = [self willMaskWithAccessibilityLabel:accessibility[@"label"] addLogicalPageName:logicalPageName];
                            
                            if (masked) {
                                [maskItems addObject:@{@"position": position, @"text": @""}];
                            } else {
                                NSDictionary *currentState = (NSDictionary *) newEntry[@"currState"];
                                NSString *text = @"";
                                
                                if (currentState != nil) {
                                    NSString *currentStateText = currentState[@"text"];
                                    if (currentStateText != nil) {
                                        text = currentStateText;
                                    }
                                }
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
        UIViewController *uv = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (uv.presentedViewController) {
            uv = uv.presentedViewController;
        }

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

/**
 * Logs an event for when a screen view context is unloaded.
 *
 * @param args A dictionary containing the parameters for the logging event.
 * The keys should include 'name' and 'referrer'.
 * 'name' is the logical name of the current page.
 * 'referrer' is the source that led the user to this page.
 */
- (void) tlLogScreenViewContextUnload: (NSDictionary *) args {
        // Checking for 'name' parameter in the args, which is supposed to be the logical name of the current page
        NSString *logicalPageName =  (NSString *) [self checkForParameter:args withKey:@"name"];
        // Checking for 'referrer' parameter in the args, which is supposed to be the source that led the user to this page
        NSString *referrer =  (NSString *) [self checkForParameter:args withKey:@"referrer"];

        NSString *cllasss = logicalPageName == nil ? @"Flutter" : [NSString stringWithFormat:@"Flutter_%@", logicalPageName];
        [[ConnectCustomEvent sharedInstance] logScreenViewContext:logicalPageName withClass:cllasss applicationContext:ConnectScreenViewTypeUnload referrer:referrer];
}


- (NSArray *)retrieveMaskAccessibilityLabelListFromJSON:(NSDictionary *)inputJSON forLogicalPage:(NSString *)logicalPageName {
    // Check if the input JSON exists and has the necessary structure
    if (inputJSON && [inputJSON isKindOfClass:[NSDictionary class]]) {
        // Check if the logicalPageName exists, if not, use "GlobalScreenSettings"
        NSDictionary *pageSettings = inputJSON[logicalPageName] ?: inputJSON[@"GlobalScreenSettings"];
        
        // Check if "Masking" and "HasMasking" properties exist for the logicalPageName or default page
        NSDictionary *masking = pageSettings[@"Masking"];
        NSNumber *hasMasking = masking[@"HasMasking"];
        if (masking && hasMasking && [hasMasking boolValue]) {
            NSArray *maskAccessibilityLabelList = masking[@"MaskAccessibilityLabelList"];
            
            // Check if "MaskAccessibilityLabelList" exists and is an array
            if (maskAccessibilityLabelList && [maskAccessibilityLabelList isKindOfClass:[NSArray class]]) {
                return maskAccessibilityLabelList;
            }
        }
    }
    
    // Return an empty array if the key doesn't exist or the structure is incorrect
    return @[];
}


- (BOOL)willMaskWithAccessibilityLabel:(NSString*)label addLogicalPageName:(NSString *) logicalPageName {
    EOApplicationHelper* helper = [[EOApplicationHelper sharedInstance] init];
    NSArray      *accessibilityLabelArray;
    
    id returnedObject = [helper getConfigItem:@"AutoLayout" forModuleName:@"TLFCoreModule"];

    // Casting the returned object to an NSDictionary
    if ([returnedObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *item = (NSDictionary *)returnedObject;
        
        accessibilityLabelArray = [self retrieveMaskAccessibilityLabelListFromJSON:item forLogicalPage:logicalPageName];
        
    } else {
        // Handle cases where the returned object is not an NSDictionary
        NSLog(@"Returned object is not an NSDictionary.");
    }
    
    
    // Check if accessibilityLabelArray is available and not empty
    if (accessibilityLabelArray && accessibilityLabelArray.count > 0) {
        // Iterate through each regex pattern in accessibilityLabelArray
        for(NSString *regstr in accessibilityLabelArray) {
            // Create NSRegularExpression object from the regex pattern
            NSError *error = nil;
            NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:regstr options:0 error:&error];
            
            // Handle error in regex creation, if any
            if (error) {
                NSLog(@"Error creating NSRegularExpression: %@", [error localizedDescription]);
                continue;
            }
            
            // Check if the given text matches the regex pattern
            NSRange textRange = NSMakeRange(0, [label length]);
            NSRange firstMatch = [regExp rangeOfFirstMatchInString:label options:0 range:textRange];
            
            // Return YES if there's a match, indicating masking is needed
            if (firstMatch.location != NSNotFound) {
                return YES;
            }
        }
    }
    
    // Return NO if no match found or if accessibilityLabelArray is empty
    return NO;
}


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

- (BOOL) tlLogMessage: (NSDictionary *) message addType: (NSNumber *) tlType {
    [self getScreenViewOffset];
    NSMutableDictionary *baseMessage = [@{@"fromWeb": @(_fromWeb), @"offset": @47, @"screenviewOffset": @(_screenOffset), @"type": @0} mutableCopy];
    
    baseMessage[@"type"] = tlType;
    [baseMessage addEntriesFromDictionary:message];
    
    NSString *logMessageString = [self getJSONString:baseMessage];
    
    NSLog(@"Logging Messsage: %@", logMessageString);
    
    return [[ConnectCustomEvent sharedInstance] logJSONMessagePayloadStr:logMessageString];
}

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




- (void) tlPointerEvent: (NSDictionary *) args {
    [self getPointerEvent:args];
}

NSString *processString(NSString *inputString) {
    NSError *error = nil;
    
    // Define a regular expression pattern to capture content within parentheses or the first word.
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([^)]+)\\)|(\\w+)" options:0 error:&error];
    
    if (!error) {
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


- (CGFloat)getAsFloat:(id)o {
    NSAssert(o != nil, @"Object cannot be nil");
    return [o floatValue];
}

- (NSDictionary<NSString *, id> *)getCurrentState:(NSDictionary<NSString *, id> *)wLayout {
    id currStateObject = wLayout[@"currState"];

    if ([currStateObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary<NSString *, id> *state = (NSDictionary<NSString *, id> *)currStateObject;
        return state;
    }
    return nil;
}

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

+ (float)getAsFloat:(NSString *)string {
    return [string floatValue];
}

+ (NSDictionary<NSString *, id> *)getCurrentState:(NSDictionary<NSString *, id> *)wLayout {
    // Implement this method based on your logic to get the current state.
    return nil;
}

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
                tlImage  = [[TlImage alloc] initWithImage:maskedScreenshot andSize:screenSize andConfig:_basicConfig];
            } else {
                tlImage  = [[TlImage alloc] initWithImage:screenshot andSize:screenSize andConfig:_basicConfig];
            }
            
            NSString *originalHash = [tlImage getOriginalHash];
            
            if ([_lastHash isEqualToString:originalHash]) {
                NSLog(@"Not logging screenview as unmasked screen has not updated, hash: %@", originalHash);
                return;
            }
            _lastHash = originalHash;
            
            NSString *base64ImageString = tlImage == nil ? @"" : [tlImage getBase64String];
            
            _lastScreen = base64ImageString.length > 0 ? base64ImageString : _lastScreen;

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
                [pointerEvents addObject:_lastMotionUpEvent != nil ? _lastMotionUpEvent : @"Tap"];
            }
            
            NSMutableArray *touches = [[NSMutableArray alloc] init];
            NSMutableArray *touch   = nil;
            int touchCount = (int) [pointerEvents count];

            for (int i = 0; i < touchCount; /* inc at bottom of loop for test */) {
                PointerEvent *pointerEvent = pointerEvents[i];
                
                if (touch == nil) {
                    touch = [[NSMutableArray alloc] init];
                }
                
                CGFloat x      = pointerEvent.x * _scale;
                CGFloat y      = pointerEvent.y * _scale;
                CGFloat relX   = x / _screenWidth;
                CGFloat relY   = y / _screenHeight;
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
                            @"height": @(_screenHeight),
                            @"width":  @(_screenWidth),
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
            _lastScreen = base64ImageString;

            NSMutableDictionary *gestureMessage =[@{
                @"event": [@{
                    @"type":    isPinch ? @"onScale" : _lastMotionUpEvent != nil ? _lastMotionUpEvent.action : @"Tap",
                    @"tlEvent": tlType
                } mutableCopy],
                @"touches": touches,
                @"base64Representation": _lastScreen
            } mutableCopy];
            
            if (direction != nil) {
                gestureMessage[@"direction"] = direction;
                gestureMessage[@"velocityX"] = @(vdx);
                gestureMessage[@"velocityY"] = @(vdy);
            }
            
            [self tlLogMessage:gestureMessage addType: @11];
            
            _lastDown = 0L;
            _lastMotionUpEvent = _firstMotionEvent = nil;
        
        } @catch (NSException *exception) {
            NSLog(@"An exception occurred: %@", exception);
        }
    });
}


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

- (void)tlSetBooleanConfigItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

- (void)tlSetStringItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

- (void)tlSetNumberItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    id value = call.arguments[@"value"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL success = [[EOApplicationHelper sharedInstance] setConfigItem:key value:value forModuleName:moduleName];
    result(@(success));
}

- (void)tlGetBooleanConfigItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    BOOL boolValue = [[EOApplicationHelper sharedInstance] getBOOLconfigItemForKey:key withDefault:NO forModuleName:moduleName];
    result(@(boolValue));
}

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

- (void)tlGetNumberItemForKey:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *key = (NSString *)[self checkForParameter:call.arguments withKey:@"key"];
    NSString *moduleName = (NSString *)[self checkForParameter:call.arguments withKey:@"moduleName"];
    moduleName = [self testModuleName:moduleName];
    NSNumber *numberValue = [[EOApplicationHelper sharedInstance] getNumberItemForKey:key withDefault:nil forModuleName:moduleName];
    result(numberValue);
}

- (NSString*)testModuleName:(NSString*)moduleName {
    if ([moduleName caseInsensitiveCompare:@"Tealeaf"] == NSOrderedSame) {
        return moduleName = @"TLFCoreModule";
    }
    return moduleName;
}

@end

