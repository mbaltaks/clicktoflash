//
//  CTFKillerVideo-QT.h
//  ClickToFlash
//
//  Created by  Sven on 13.12.09.
//  Copyright 2009 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CTFKillerVideo.h"


@interface CTFKillerVideo (QuickTime)

+ (BOOL) shouldUseQTKit;


// QuickTime
- (void) setupQuickTimeUsingHD: (NSNumber*) useHDNumber;
- (void) reallySetupQuickTimeUsingHD: (NSNumber *) useHDNumber;
- (QTMovie *) movieForHD: (NSNumber *) useHDNumber;
- (void) addProgressIndicator;
- (void) removeProgressIndicator;
- (void) adjustButtonPositions: (BOOL) smoothly;
- (NSButton *) addHDButton;
- (NSButton *) addDownloadButton;
- (void) addButtons;
- (IBAction) toggleHD: (id) sender;
// - (void) resizeToFitMovie;


// Accessors
- (BOOL) hasAutoPlayed;
- (void) setHasAutoPlayed:(BOOL)newHasAutoPlayed;
- (NSCellStateValue) usingHD;
- (void) setUsingHD:(NSCellStateValue)newUsingHD;
- (NSProgressIndicator *) progressIndicator;
- (void) setProgressIndicator: (NSProgressIndicator *) newProgressIndicator;
- (QTMovieView *) movieView;
- (void) setMovieView: (QTMovieView *) newMovieView;
- (QTMovie *) movie;
- (void) setMovie: (QTMovie *) newMovie;
- (NSThread *) movieSetupThread;
- (void) setMovieSetupThread: (NSThread *) newMovieSetupThread;


@end
