#import "TlImage.h"
#import <CommonCrypto/CommonDigest.h>

@implementation TlImage : NSObject

- (id) initWithImage:(UIImage *)image andSize:(CGSize) size andConfig:(NSDictionary *) config {
    self = [super init];
    
    if (self) {
        self.config = config;
        self.size   = size;
        
        [self setImage:image];
        
        self.isUpdated = false;
        self.originalImageMd5 = self.imageMd5;
    }
    return self;
}

- (void) setImage:(UIImage *) image {
    NSData *data = [self uiImageToData:image withWidth:self.size.width withHeight:self.size.height];

    if (data != nil) {
        self.imageBase64 = [data base64EncodedStringWithOptions:0];

        unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

        CC_MD5(data.bytes, (uint)data.length, md5Buffer);

        NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [output appendFormat:@"%02x", md5Buffer[i]];
        }
        self.imageMd5 = output;
    }
    
    self.uiImage = image;
}

- (void) updateWithImage: (UIImage *) newImage {
    self.isUpdated = true;
    
    [self setImage:newImage];
}

- (UIImage*)scaleImage:(UIImage*) image andSize:(CGSize) size
{
    UIImage *scaledImage = nil;
    @try
    {
        UIGraphicsBeginImageContext(size);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(context, 0.0, size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), image.CGImage);
        scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    @catch (NSException *exception)
    {
        NSLog(@"scaleImage caused an exception: %@", [exception reason]);
    }
    @finally
    {
        // NOP
    }
    return scaledImage;
}

-(NSData *) uiImageToData:(UIImage *)image withWidth:(CGFloat) width withHeight:(CGFloat) height {
    NSData *imageData = nil;

    if (image != nil)
    @try {
        NSUInteger percentOfScreenshotsSize = MAX(50, MIN(100, (NSUInteger) self.config[@"PercentOfScreenshotsSize"]));
        
        CGFloat normalizedWidth  = width * percentOfScreenshotsSize * 0.01;
        CGFloat normalizedHeight = height * percentOfScreenshotsSize * 0.01;
        CGSize size = CGSizeMake(normalizedWidth, normalizedHeight);

        if (self.config[@"isJpg"])
        {
            CGFloat percentCompress =  [(NSNumber *) self.config[@"%compress"] floatValue];
            
            imageData = UIImageJPEGRepresentation([self scaleImage:image andSize:size], percentCompress);
            NSLog(@"converted image to jpeg data of size: %tu", [imageData length]);
        }
        else {
            imageData = UIImagePNGRepresentation([self scaleImage:image andSize:size]);
            NSLog(@"converted image data to png of size: %tu", [imageData length]);
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception: %@", [exception reason]);
    }
    @finally {
        // NOP
    }
    
    return imageData;
}

- (NSString *) getMimeType {
    return self.config[@"mimeType"];
}

- (NSString *) getBase64String {
    return _imageBase64;
}

- (NSString *) getHash {
    return _imageMd5;
}

- (NSString *) getOriginalHash {
    return _originalImageMd5;
}

- (UIImage *) getImage {
    return _uiImage;
}
@end
