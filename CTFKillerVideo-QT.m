//
//  CTFKillerVideo-QT.m
//  ClickToFlash
//
//  Created by  Sven on 13.12.09.
//  Copyright 2009 earthlingsoft. All rights reserved.
//

#import "CTFKillerVideo-QT.h"
#import "CTFUserDefaultsController.h"
#import "Plugin.h"
#import <QTKit/QTKit.h>
#import "CTFButtonsView.h"


NSString * sVideoVolumeLevelDefaultsKey = @"Video Volume Level";



@implementation CTFKillerVideo (QuickTime)

/* This is 10.5 and higher only. It is only used for QTMovie-style playback which requires 10.5 as well. */
+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *) key {
	NSSet * result = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"HDButtonTooltip"]) {
		result = [result setByAddingObject: @"usingHD"];
	}
	
	return result;
}



+ (BOOL) shouldUseQTKit {
	BOOL result = (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_5);
	result = result && [[CTFUserDefaultsController standardUserDefaults] boolForKey: sUseQTKitDefaultsKey];
	return result;
}





#pragma mark -
#pragma mark Insert Video using QTKit - 10.5 and higher only

- (void) setupQuickTimeUsingHD: (NSNumber*) useHDNumber {
	NSThread * thread = [[[NSThread alloc] initWithTarget:self selector:@selector(reallySetupQuickTimeUsingHD:) object:useHDNumber] autorelease];
	[thread setName: @"CTFKillerVideo movieSetup"];
	[self setMovieSetupThread: thread];
	[thread start];
}



- (void) reallySetupQuickTimeUsingHD: (NSNumber *) useHDNumber {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSView * mainContainer = [[self plugin] containerView];
	NSRect bounds;
	if (mainContainer != nil) {
		bounds = [mainContainer bounds];
	}
	else {
		bounds = NSZeroRect;
	}
	
	QTMovieView * myMovieView = [self movieView];
	BOOL needToInsertMovieView = NO;
	
	if ( myMovieView == nil ) {
		myMovieView = [[[QTMovieView alloc] initWithFrame:bounds] autorelease];
		[myMovieView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];		
		[myMovieView setPreservesAspectRatio:YES];
		[myMovieView setWantsLayer: YES]; // video seems invisible without the layer
		//		[myMovieView setCustomButtonVisible:YES];
		if ( [[self plugin] isFullScreen] ) {
			[myMovieView setFillColor: [NSColor blackColor]];			
		}
		else {
			[myMovieView setFillColor: [NSColor clearColor]];
		}
		
		if ( myMovieView == nil ) { // ERROR
			NSLog(@"CTFKillerVideo: Could not create movie view in -reallySetupQuickTimeUsingHD:");
			return; 
		}
		
		[self setMovieView: myMovieView];
		needToInsertMovieView = YES;
	}
	
	// Add progress indicator. It will be removed when the film has loaded sufficiently or when loading fails.
	[self addProgressIndicator];
	
	QTMovie * myMovie = [self movieForHD: useHDNumber];
	if ( myMovie != nil && ![[self movieSetupThread] isCancelled] ) {
		[self setMovie: myMovie];
		[myMovieView setMovie: myMovie];
		
		// It seems like QTMovieView has two subviews: one displaying the film, one for the controller. The controller view seems to end up _not_ wanting the layer. This can cause the controller to disappear after switching tags. So we sneakily set all subviews of the QTMovieView to want a layer here.
		NSEnumerator * viewEnumerator = [[myMovieView subviews] objectEnumerator];
		NSView * view;
		while ( ( view = [viewEnumerator nextObject] ) ) {
			[view setWantsLayer:YES];
		}
		
		if (needToInsertMovieView) {
			[mainContainer addSubview: myMovieView positioned: NSWindowBelow relativeTo: nil];
			[[self plugin] setNextKeyView: myMovieView];
			[myMovieView setNextKeyView: (NSView*)[[self plugin] mainButton]];
		}
		[[[self plugin] mainButton] setHidden:YES];
		[[[self plugin] window] makeFirstResponder: myMovieView];
	}
	
	[self setMovieSetupThread: nil];
	
	// not doing this on the main thread seems to hang the application
	// [self performSelectorOnMainThread:@selector(resizeToFitMovie) withObject:nil waitUntilDone:NO];
	
	[pool release];	
}



- (QTMovie *) movieForHD: (NSNumber *) useHDNumber {
	BOOL useHD = [self useVideoHD];
	if ( useHDNumber != nil ) {
		useHD = [useHDNumber boolValue];
	}
	
	NSString * movieURLString = [self videoURLStringForHD: useHD];
	NSURL * movieURL = [NSURL URLWithString: movieURLString];
	NSError * error = nil;
	QTMovie * myMovie = nil;
	//	movie = [QTMovie movieWithURL: movieURL error: &error];
	float volumeLevel = 1.;
	NSNumber * volumeNumber = [[CTFUserDefaultsController standardUserDefaults] objectForKey: sVideoVolumeLevelDefaultsKey];
	if ( volumeNumber != nil ) {
		volumeLevel = MAX(.0 , MIN( [volumeNumber floatValue], 1.));
	}
	volumeNumber = [NSNumber numberWithFloat: volumeLevel];
	
	NSDictionary * movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
									  movieURL, QTMovieURLAttribute, 
									  [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
									  volumeNumber, QTMovieVolumeAttribute,
									  //									  [NSNumber numberWithBool:YES], QTMovieOpenForPlaybackAttribute,
									  nil];
	
	myMovie = [QTMovie movieWithAttributes:movieAttributes error:&error];
	//	NSLog(@"CTFKillerVideo -movieForHD: movie attributes %@", [[myMovie movieAttributes] description]);
	if ( myMovie == nil ) {
		// If we get nil, just try again. This seems to cover a bunch of the random loading problems. It would probably be better to load the 'hash' or other extra info again before retrying to also cover timeout problems
		myMovie = [QTMovie movieWithAttributes:movieAttributes error:&error];
	}
	if (myMovie == nil){
		// It seems like we occasionally get an error "The file is not a movie file" here. No idea why as the same URL appears to work again a bit later. Some clever retrying or reasonable handling of that might be nice.
		NSLog(@"ClickToFlash CTFKillerVideo -movieForHD: Error: %@ (%@)", [error localizedDescription], movieURLString);
	}	
	else {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieVolumeChanged:) name:QTMovieVolumeDidChangeNotification object:myMovie];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieLoadStateChanged:) name:QTMovieLoadStateDidChangeNotification object:myMovie];
		
		if ([self autoPlay]) {
			[myMovie autoplay];
		}		
	}
	
	return myMovie;	
}



- (void) movieVolumeChanged: (NSNotification *) notification {
	NSNumber * volumeNumber = [NSNumber numberWithFloat:[[self movie] volume]];
	[[CTFUserDefaultsController standardUserDefaults] setObject:volumeNumber forKey: sVideoVolumeLevelDefaultsKey];
}



- (void) movieLoadStateChanged: (NSNotification *) notification {
    long loadState = [[[self movie] attributeForKey:QTMovieLoadStateAttribute] longValue];
#if LOGGING_ENABLED
	NSLog(@"CTFKillerVideo -movieLoadStateChanged: %i", loadState);
#endif
	
    if (loadState >= QTMovieLoadStatePlayable) {
        // The movie has loaded enough media data to begin playing. Remove the progress indicator first and then start playing, if appropriate.
		[self removeProgressIndicator];
		
		// Sometimes loading is slow and the load state keeps toggling between Playable and PlaythroughOK. This can cause the film to toggle stopping and starting many times in a row. To prevent that from happening, make sure we only autoPlay once.
		if ([self autoPlay] && ![self hasAutoPlayed]) {
			[[self movie] play];
			[self setHasAutoPlayed:YES];
		}
    }
	if (loadState >= QTMovieLoadStateLoaded) {
        // The movie atom has loaded. It's safe to query movie properties like the size now.
		[self adjustButtonPositions:YES];
		
		// Set refresh status back to NO in case a HD toggle is coming and could use a refresh again.
		hasRefreshedURLs = NO;
    }
    else if (loadState == -1) {
		// Loading the movie failed.
		
		// Try refreshing the URL once. It may just be that the hash/token used in our URL has expired because it has been a while since we set things up.
		if ( ![self hasRefreshedURLs] ) {
			[self refreshVideoURLs];
			[self setupQuickTimeUsingHD: nil];
			[self setHasRefreshedURLs: YES];
		}
		else {
			// Refreshing the URL did not do the trick. Remove progress indicator.
			[self removeProgressIndicator];
			// It'd be nice to do something helpful here (fall back to Flash? display error message?)
			NSLog(@"CTFKillerVideo -movieLoadStateChanged: An error occurred when trying to load the movie\n%@", [[[self movie] movieAttributes] description]);
		}
    }
}



// Adds the progress indicator shown used while loading the video
- (void) addProgressIndicator {
	// We only want a single progress indicator, so make sure we don't create a new one in case it already exists.
	if ([self progressIndicator] == nil) {
		const CGFloat pISize = 32.;
		
		NSRect pIRect = NSMakeRect(NSMidX([[self plugin] bounds]) - pISize*.5,
								   NSMidY([[self plugin] bounds]) - pISize*.5,
								   pISize,
								   pISize);
		
		NSProgressIndicator * theProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:pIRect];
		[self setProgressIndicator: theProgressIndicator];
		
		[theProgressIndicator setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
		[theProgressIndicator setStyle: NSProgressIndicatorSpinningStyle];
		[theProgressIndicator setWantsLayer: YES];
		
		[theProgressIndicator startAnimation: self];
		[[[self plugin] containerView] addSubview:theProgressIndicator];
	}
}



// Removes the progress indicator shown while loading the video
- (void) removeProgressIndicator {
	if ([self progressIndicator]) {
		[[self progressIndicator] stopAnimation: self];
		[progressIndicator removeFromSuperview];
		[self setProgressIndicator: nil];
	}
}



/* 
 Move the buttons container around if necessary.  
 We want:
 * standard display behaviour before the film is loaded
 * The buttons container to be full width at the top of the screen in fullscreen mode 
 * The buttons container fitting into the bounds of the displayed movie when the movie view is present
 */
- (void) adjustButtonPositions:(BOOL) smoothly {
	NSRect movieRect;
	
	if ([self movieView]) {
		if ([[self plugin] isFullScreen]) {
			movieRect = [[[[self plugin] window] screen] frame];
		}
		else {
			movieRect = [[self movieView] movieBounds];
			movieRect.size.height += [[self movieView] controllerBarHeight];
			movieRect.origin.y -= [[self movieView] controllerBarHeight];		
		}
		
		if (smoothly && (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_5)) {
			[[[[self plugin] buttonsContainer] animator] setFrame: movieRect];
		}
		else {
			[[[self plugin] buttonsContainer] setFrame: movieRect];
		}
	}
}



/* Adds button to toggle between the SD and HD version of a film. Only appears when two versions are available and serves as an indicator for the currently playing version */
- (NSButton *) addHDButton {
	NSButton * button = nil;
	
	if ([self hasVideo] && [self hasVideoHD]) {
		button = [[[self plugin] buttonsView] viewWithTag: CTFHDButtonTag];
		if (button == nil) {
			NSCellStateValue state = NSOnState;
			if ( ![self useVideoHD] ) { state = NSOffState; }
			[self setUsingHD: state];
			
			button = [CTFButtonsView button];
			[button setTitle: CtFLocalizedString( @"HD", @"CTFKillerVideo: Label for HD button")];
			[button sizeToFit];
			[button setButtonType: NSPushOnPushOffButton];
			[button setTag: CTFHDButtonTag];
			[button setTarget: self];
			[button setAction: @selector(toggleHD:)];
			[[[self plugin] buttonsView] addButton: button];
			[button bind:@"toolTip" toObject:self withKeyPath:@"HDButtonTooltip" options:nil];
			[button bind:@"value" toObject:self withKeyPath:@"usingHD" options:nil];
		}
	}	
	return button;
}



/* Used for tooltip in HD button via bindings */
- (NSString *) HDButtonTooltip {
	NSString * tooltip = @"";
	
	if ([self usingHD] == NSOnState) {
		tooltip = CtFLocalizedString( @"Use smaller version of the movie", @"CTFKillerVideo: Tooltip for HD button when it is turned ON" );
	}
	else {
		tooltip = CtFLocalizedString( @"Use larger version of the movie", @"CTFKillerVideo: Tooltip for HD button when it is turned OFF" );	
	}
	
	return tooltip;
}



/* Adds button to download the currently playing movie as a file */
- (NSButton *) addDownloadButton {
	// CTFDownloadButton * button = nil;
	NSButton * button = nil;
	
	if ([self hasVideo] || [self hasVideoHD]) {
		button = [[[self plugin] buttonsView] viewWithTag: CTFDownloadButtonTag];
		if (button == nil) {
			// button = [CTFDownloadButton downloadButton];
			button = [CTFButtonsView button];
			
			NSImage * downloadImage = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[CTFClickToFlashPlugin class]] pathForResource:@"download" ofType:@"png"]] autorelease];
			[button setImage: downloadImage];
			[button setToolTip: CtFLocalizedString( @"Download video file", @"CTFKillerVideo: Tooltip for Video Download button" )];
			[button sizeToFit];
			[button setTag: CTFDownloadButtonTag];
			// [button setURLProvider: self];
			[button setTarget: self];
			[button setAction: @selector(downloadVideoUsingHD:)];
			[[[self plugin] buttonsView] addButton: button];
		}
	}	
	return button;
}



// called from the -setVideo: and -setVideoHD: setters
- (void) addButtons {
	[[self plugin] addFullScreenButton];
	[self addDownloadButton];
	[self addHDButton];
}



- (IBAction) toggleHD: (id) sender {
	[self setupQuickTimeUsingHD: [NSNumber numberWithBool: [self usingHD]]];
}



// If someone can figure out how we can resize our view to fully fill the width of the containing DOM element and setting the height of said element while remaining flexibe (i.e. just like using width:100%; in CSS), please speak up. 
/*
// Resize the plugin view to keep its width and have the aspect ratio of the movie
- (void) resizeToFitMovie {
	if ( [self movie] != nil && [self movieView] != nil ) {
		CGFloat movieAspectRatio = [[self movieView] movieBounds].size.width / [[self movieView] movieBounds].size.height;
		CGFloat newWidth = [[self plugin] frame].size.width;
		CGFloat newHeight = newWidth / movieAspectRatio + [[self movieView] controllerBarHeight];
		[[[self plugin] animator] setFrameSize: NSMakeSize(newWidth,newHeight)];
		[[self plugin] setNeedsDisplay:YES];
		// DOMCSSStyleDeclaration * style = [[[self plugin] container] style];
		//[style setProperty:@"height" value:@"auto" priority:nil];	
		// [style setProperty:@"width" value:@"100%" priority:nil];
	}
}
*/







#pragma mark -
#pragma mark Accessors

- (BOOL)hasAutoPlayed {
	return hasAutoPlayed;
}

- (void)setHasAutoPlayed:(BOOL)newHasAutoPlayed {
	hasAutoPlayed = newHasAutoPlayed;
}


- (NSCellStateValue) usingHD {
	return usingHD;
}

- (void) setUsingHD:(NSCellStateValue)newUsingHD {
	usingHD = newUsingHD;
}


- (NSProgressIndicator *) progressIndicator {
	return progressIndicator;
}

- (void) setProgressIndicator: (NSProgressIndicator *) newProgressIndicator {
	[newProgressIndicator retain];
	[progressIndicator release];
	progressIndicator = newProgressIndicator;
}


- (QTMovieView *) movieView {
	return movieView;
}

- (void) setMovieView: (QTMovieView *) newMovieView {
	[newMovieView retain];
	[movieView release];
	movieView = newMovieView;
}


- (QTMovie *) movie {
	return movie;
}

- (void) setMovie: (QTMovie *) newMovie {
	[newMovie retain];
	[movie stop];
	[movie release];
	movie = newMovie;
}


- (NSThread *) movieSetupThread {
	return movieSetupThread;
}

- (void) setMovieSetupThread: (NSThread *) newMovieSetupThread {
	[newMovieSetupThread retain];
	// Cancelling threads requires 10.5. We only use QTKit video playback on 10.5 and higher, so we should be fine.
	if ( [movieSetupThread respondsToSelector: @selector(cancel)] ) {
		[movieSetupThread performSelector:@selector(cancel)];
	}
	[movieSetupThread release];
	movieSetupThread = newMovieSetupThread;
}




@end
