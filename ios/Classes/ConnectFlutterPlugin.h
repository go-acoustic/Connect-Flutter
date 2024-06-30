#import <Flutter/Flutter.h>
#import <Connect/Connect.h>
//#import <Tealeaf/TLFUIEventsLogger.h>

@interface ConnectFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic) BOOL fromWeb;
@property (nonatomic) int  screenLoadTime;

@end
