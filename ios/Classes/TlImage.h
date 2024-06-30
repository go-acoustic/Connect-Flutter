@interface TlImage : NSObject

@property (nonatomic) BOOL          isUpdated;
@property (nonatomic) NSString      *imageBase64;
@property (nonatomic) NSString      *imageMd5;
@property (nonatomic) NSString      *originalImageMd5;
@property (nonatomic) UIImage       *uiImage;
@property (nonatomic) NSDictionary  *config;
@property (nonatomic) CGSize        size;

- (id) initWithImage:(UIImage *)image andSize: (CGSize) size andConfig: (NSDictionary *) config;
- (NSString *) getBase64String;
- (NSString *) getHash;
- (NSString *) getOriginalHash;
- (UIImage *)  getImage;
- (NSString *) getMimeType;
- (void)       updateWithImage:(UIImage *) newImage;
@end
