//
//  KPIMAPlayerViewController.m
//  KALTURAPlayerSDK
//
//  Created by Nissim Pardo on 1/26/15.
//  Copyright (c) 2015 Kaltura. All rights reserved.
//

#import "KPIMAPlayerViewController.h"
#import "NSString+Utilities.h"
#import "KPLog.h"
#import "IMAHandler.h"
//@import GoogleInteractiveMediaAds;


@interface KPIMAPlayerViewController () {
    void(^AdEventsListener)(NSDictionary *adEventParams);
}

/// Contains the params for the logic layer
@property (nonatomic, copy) NSMutableDictionary *adEventParams;

/// Content video player.
@property(nonatomic, strong) AVPlayer *contentPlayer;


// SDK
/// Entry point for the SDK. Used to make ad requests.
@property(nonatomic, strong) id<AdsLoader> adsLoader;
// Container which lets the SDK know where to render ads.
@property(nonatomic, strong) id<AdDisplayContainer> adDisplayContainer;
// Rendering settings for ads.
@property(nonatomic, strong) id<AdsRenderingSettings> adsRenderingSettings;

/// Main point of interaction with the SDK. Created by the SDK as the result of an ad request.
@property(nonatomic, strong) id<AdsManager> adsManager;

@property (nonatomic, strong) id<AVPlayerContentPlayhead> playhead;
@end

@implementation KPIMAPlayerViewController

#pragma mark Public Methods

- (void)loadIMAAd:(NSString *)adLink withContentPlayer:(AVPlayer *)contentPlayer eventsListener:(void (^)(NSDictionary *))adListener  {
    AdEventsListener = [adListener copy];
    
    // Load AVPlayer with path to our content.
    self.contentPlayer = contentPlayer;
    id<AdsRequest> request = [[NSClassFromString(@"IMAAdsRequest") alloc] initWithAdTagUrl:adLink
                                                                        adDisplayContainer:self.adDisplayContainer
                                                                               userContext:nil];
    
    [self.adsLoader requestAdsWithRequest:request];
}

- (void)contentCompleted {
    [self.adsLoader contentComplete];
}

- (void)removeIMAPlayer {
    
    
    AdEventsListener = nil;
    [_adEventParams removeAllObjects];
    _adEventParams = nil;
    _adsLoader.delegate = nil;
    _adsLoader = nil;
    _adDisplayContainer = nil;
    _adsRenderingSettings = nil;
    _contentPlayer = nil;
    _playhead = nil;
    _contentPlayer = nil;
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
    [self.adsManager pause];
    [self.adsManager destroy];
}


#pragma mark View methods
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor clearColor];
    self.view.frame = (CGRect){0, 0, self.view.frame.size.width, _adPlayerHeight};
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




#pragma mark Lazy Initialization
- (NSMutableDictionary *)adEventParams {
    if (!_adEventParams) {
        _adEventParams = [NSMutableDictionary new];
    }
    return _adEventParams;
}


// Create ads rendering settings to tell the SDK to use the in-app browser.
- (id<AdsRenderingSettings>)adsRenderingSettings {
    if (!_adsRenderingSettings) {
        _adsRenderingSettings = [NSClassFromString(@"IMAAdsRenderingSettings") new];
        _adsRenderingSettings.webOpenerPresentingController = self;
        _adsRenderingSettings.webOpenerDelegate = self;
        //        _adsRenderingSettings.uiElements = @[];
    }
    return _adsRenderingSettings;
}


// Create our AdDisplayContainer. Initialize it with our videoView as the container. This
- (id<AdDisplayContainer>)adDisplayContainer {
    if (!_adDisplayContainer) {
        _adDisplayContainer = [[NSClassFromString(@"IMAAdDisplayContainer") alloc] initWithAdContainer:self.view
                                                                                        companionSlots:nil];
    }
    return _adDisplayContainer;
}

- (id<AdsLoader>)adsLoader {
    if (!_adsLoader) {
        id<Settings> settings = nil;
        if (![_locale isKindOfClass:[NSNull class]] && _locale.length) {
            settings = [NSClassFromString(@"IMASettings") new];
            settings.language = _locale;
        }
        _adsLoader = [(id<AdsLoader>)[NSClassFromString(@"IMAAdsLoader") alloc] initWithSettings:settings];
        _adsLoader.delegate = self;
    }
    return _adsLoader;
}

- (id<AVPlayerContentPlayhead>)playhead {
    if (!_playhead) {
        _playhead = [[NSClassFromString(@"IMAAVPlayerContentPlayhead") alloc] initWithAVPlayer:self.contentPlayer];
    }
    return _playhead;
}



#pragma mark IMAAdsLoaderDelegate
- (void)adsLoader:(id<AdsLoader>)loader adsLoadedWithData:(id<AdsLoadedData>)adsLoadedData {
    // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    // Initialize the ads manager.
    [self.adsManager initializeWithContentPlayhead:self.playhead
                              adsRenderingSettings:self.adsRenderingSettings];
    if (AdEventsListener) {
        AdEventsListener(AdLoadedEventKey.nullVal);
    }
}


- (void)adsLoader:(id<AdsLoader>)loader failedWithErrorData:(id<AdLoadingErrorData>)adErrorData {
    // Something went wrong loading ads. Log the error and play the content.
    NSLog(@"Error loading ads: %@", adErrorData.adError.message);
    [self.contentPlayer play];
}



#pragma mark AdsManager Delegates
- (void)adsManager:(id<AdsManager>)adsManager
 didReceiveAdEvent:(id<AdEvent>)event {
    // When the SDK notified us that ads have been loaded, play them.
    NSDictionary *eventParams = nil;
    switch (event.type) {
        case kAdEvent_LOADED:
            [adsManager start];
            self.adEventParams.isLinear = event.ad.isLinear;
            self.adEventParams.adID = event.ad.adId;
            self.adEventParams.adSystem = @"null";
            self.adEventParams.adPosition = event.ad.adPodInfo.adPosition;
            eventParams = self.adEventParams.toJSON.adLoaded;
            
            break;
        case kAdEvent_STARTED:
            self.view.hidden = NO;
            self.adEventParams.duration = event.ad.duration;
            eventParams = self.adEventParams.toJSON.adStart;
            break;
        case kAdEvent_COMPLETE:
            self.adEventParams.adID = event.ad.adId;
            eventParams = self.adEventParams.toJSON.adCompleted;
            self.view.hidden = YES;
            break;
        case kAdEvent_ALL_ADS_COMPLETED:
            eventParams = AllAdsCompletedKey.nullVal;
            AdEventsListener(nil);
            break;
            //        case kIMAAdEvent_PAUSE:
            //            eventParams = ContentPauseRequestedKey.nullVal;
            //            break;
            //        case kIMAAdEvent_RESUME:
            //            eventParams = ContentResumeRequestedKey.nullVal;
            //            break;
        case kAdEvent_FIRST_QUARTILE:
            eventParams = FirstQuartileKey.nullVal;
            break;
        case kAdEvent_MIDPOINT:
            eventParams = MidPointKey.nullVal;
            break;
        case kAdEvent_THIRD_QUARTILE:
            eventParams = ThirdQuartileKey.nullVal;
            break;
        case kAdEvent_TAPPED:
            
            
            break;
        case kAdEvent_CLICKED:
            self.adEventParams.isLinear = event.ad.isLinear;
            eventParams = self.adEventParams.toJSON.adClicked;
            break;
        case kAdEvent_SKIPPED:
//            AdEventsListener(nil);
            break;
        default:
            break;
    }
    self.adEventParams = nil;
    if (AdEventsListener && eventParams) {
        AdEventsListener(eventParams);
    }
    eventParams = nil;
}

- (void)adsManager:(id<AdsManager>)adsManager
 didReceiveAdError:(id<AdError>)error {
    // Something went wrong with the ads manager after ads were loaded. Log the error and play the
    // content.
    
    if (AdEventsListener) {
        AdEventsListener(AdsLoadErrorKey.nullVal);
    }
    NSLog(@"AdsManager error: %@", error.message);
    [self.contentPlayer play];
}

- (void)adsManagerDidRequestContentPause:(id<AdsManager>)adsManager {
    // The SDK is going to play ads, so pause the content.
    //    [self.contentPlayer pause];
    if (AdEventsListener) {
        AdEventsListener(ContentPauseRequestedKey.nullVal);
    }
}

- (void)adsManagerDidRequestContentResume:(id<AdsManager>)adsManager {
    // The SDK is done playing ads (at least for now), so resume the content.
    //    [self.contentPlayer play];
    if (AdEventsListener) {
        AdEventsListener(ContentResumeRequestedKey.nullVal);
    }
}

- (void)adDidProgressToTime:(NSTimeInterval)mediaTime totalTime:(NSTimeInterval)totalTime {
    if (AdEventsListener) {
        NSMutableDictionary *timeParams = [NSMutableDictionary new];
        timeParams.time = mediaTime;
        timeParams.duration = totalTime;
        timeParams.remain = totalTime - mediaTime;
        AdEventsListener(timeParams.toJSON.adRemainingTimeChange);
    }
}

- (void)dealloc {
    KPLogInfo(@"Dealloc");
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

