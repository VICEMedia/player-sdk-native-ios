//
//  WVPlayer.m
//  KALTURAPlayerSDK
//
//  Created by Nissim Pardo on 3/24/15.
//  Copyright (c) 2015 Kaltura. All rights reserved.
//
#if !(TARGET_IPHONE_SIMULATOR)
#import "WVPlayer.h"
#import "WViPhoneAPI.h"
#import "KPLog.h"

static NSString *kPortalKey = @"kaltura";

@interface WVPlayer()
@end

@implementation WVPlayer
@synthesize DRMKey, DRMDict;
- (void)setPlayerSource:(NSURL *)playerSource {
    [self.class DRMSource:playerSource.absoluteString
                      key:self.DRMDict
               completion:^(NSString *drmUrl) {
        super.playerSource = [NSURL URLWithString:drmUrl];
    }];
}


//+ (void)DRMSource:(NSString *)src key:(NSString *)key completion:(void (^)(NSString *))completion {
//    WV_Initialize(WVCallback, @{WVDRMServerKey: key, WVPortalKey: kPortalKey});
//    [self performSelector:@selector(fetchDRMParams:) withObject:@[src, completion] afterDelay:0.1];
//}

+ (void)DRMSource:(NSString *)src key:(NSDictionary *)dict completion:(void (^)(NSString *))completion {
//    NSDictionary *d = @{
//        WVDRMServerKey: [dict objectForKey:@"WVDRMServerKey"],
//        WVPortalKey: [dict objectForKey:@"WVPortalKey"],
//        WVCAUserDataKey: [dict objectForKey:@"WVCAUserDataKey"] != nil ? [dict objectForKey:@"WVCAUserDataKey"] : nil
//      };
    WV_Initialize(WVCallback, dict);
    [self performSelector:@selector(fetchDRMParams:) withObject:@[src, completion] afterDelay:0.1];
}

+ (void)fetchDRMParams:(NSArray *)params {
    NSMutableString *responseUrl = [NSMutableString string];
    WViOsApiStatus status = WV_Play(params.firstObject, responseUrl, 0);
    KPLogDebug(@"widevine response url: %@", responseUrl);
    if ( status != WViOsApiStatus_OK ) {
        KPLogError(@"ERROR: %u",status);
        return;
    }
    ((void(^)(NSString *))params.lastObject)(responseUrl);
}


WViOsApiStatus WVCallback( WViOsApiEvent event, NSDictionary *attributes ) {
    KPLogTrace(@"Enter");
    KPLogInfo( @"callback %d %@\n", event, NSStringFromWViOsApiEvent( event ) );
    
    KPLogTrace(@"Exit");
    return WViOsApiStatus_OK;
}

+ (BOOL)isPlayableMIMEType:(NSString *)mimeType {
    return @([AVURLAsset isPlayableExtendedMIMEType:mimeType]);
}

@end

#endif
