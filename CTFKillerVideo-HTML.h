//
//  CTFKillerVideo-HTML.h
//  ClickToFlash
//
//  Created by  Sven on 13.12.09.
//  Copyright 2009 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CTFKillerVideo.h"

@interface CTFKillerVideo (HTML)

- (void) _convertElementForMP4: (DOMElement*) element atURL: (NSString*) URLString;
- (void) _convertElementForVideoElement: (DOMElement*) element atURL: (NSString*) URLString;
- (void) convertToMP4ContainerUsingHD: (NSNumber*) useHD;
- (void) _convertToMP4ContainerAfterDelayUsingHD: (NSNumber*) useHDNumber;
- (void) _convertToMP4ContainerUsingHD: (BOOL) useHD;
- (DOMElement*) linkContainerElementUsingHD: (BOOL) useHD;

// Helper
- (BOOL) isVideoElementAvailable;



@end
