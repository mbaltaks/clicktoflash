/*
 
 The MIT License
 
 Copyright (c) 2009 ClickToFlash Developers
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
*/

#import "CTFActionButton.h"
#import "CTFUtilities.h"
#import "Plugin.h"


@implementation CTFActionButton

+ (id) actionButton {
	CGFloat margin = 5.;
	CGFloat size = 20.;
	NSRect gearButtonRect = NSMakeRect( .0, .0, size + 2.*margin , size + 2.*margin );

	CTFActionButton * gearButton = [[[CTFActionButton alloc] initWithFrame: gearButtonRect] autorelease];
	[gearButton setButtonType: NSMomentaryPushInButton];
	
	return gearButton;
}



#pragma mark NSButton subclassing

+ (Class) cellClass {
	return NSClassFromString(@"CTFActionButtonCell");
}



- (id) initWithFrame: (NSRect) frameRect {
	self = [super initWithFrame: frameRect];
	if (self != nil) {
		[self setPlugin: nil];
	}
	return self;
}


- (void) dealloc {
	[self setPlugin: nil];
	[super dealloc];
}



- (void) mouseDown: (NSEvent *) event {
	[NSMenu popUpContextMenu:[self menuForEvent:event] withEvent:event forView:self];
}	



- (NSMenu*) menuForEvent: (NSEvent*) event {
	return [[self plugin] menuForEvent: event];
}



- (void) resizeWithOldSuperviewSize:(NSSize) oldBoundsSize {
	if ( [[self cell] gearVisible] && ![[self plugin] isFullScreen]) {
		[self setHidden:NO];
		NSRect myRect = [self bounds];
		NSSize superSize = [[self superview] bounds].size;
		NSPoint	newOrigin = NSMakePoint(.0, superSize.height - myRect.size.height);
		[self setFrameOrigin: newOrigin];
	}
	else {
		[self setHidden:YES];
	}
}
	




#pragma mark Accessors

- (CTFClickToFlashPlugin *) plugin {
	return plugin;
}

- (void) setPlugin: (CTFClickToFlashPlugin *) newPlugin {
	[newPlugin retain];
	[plugin release];
	plugin = newPlugin;
}

@end







#pragma mark -
#pragma mark NSView subclassing



@implementation CTFActionButtonCell

#pragma mark NSCell subclassing

- (void) drawWithFrame: (NSRect) rect inView:(NSView *) controlView {
	NSRect bounds = [[self controlView] bounds];
			
	NSImage * gearImage = [NSImage imageNamed:@"NSActionTemplate"];
	// On systems older than 10.5 we need to supply our own image.
	if (gearImage == nil) {
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"NSActionTemplate" ofType:@"png"];
		gearImage = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
			
	if( gearImage ) {
		const CGFloat padding = 3.;
		CGFloat gearSize = [gearImage size].width; // assumes the gear to be square
		CGFloat size = gearSize + 2.0 * padding;
		CGFloat x = round(bounds.size.width * .5) - round(size * .5);
		CGFloat y = round(bounds.size.height * .5 ) - round(size * .5);										
		NSRect backgroundFrame = NSMakeRect(x, y, size, size);
		
		NSBezierPath * circle = [NSBezierPath bezierPathWithOvalInRect:backgroundFrame];
		CGFloat alpha = ( [self isHighlighted] ) ? .9 : .7 ;
		[[NSColor colorWithDeviceWhite:1.0 alpha:alpha] set];
		[circle fill];
				
		// draw the gear image
		[gearImage drawAtPoint:NSMakePoint(x + padding, y + padding)
					  fromRect:NSZeroRect
					 operation:NSCompositeSourceOver
					  fraction:.9];
	}
}




#pragma mark Helper

- (BOOL) gearVisible {
	NSRect bounds = [[[self controlView] superview] bounds ];
	return NSWidth( bounds ) > 32 && NSHeight( bounds ) > 32;
}





#pragma mark Accessibility

- (NSArray *) accessibilityAttributeNames {
	NSMutableArray * attributes = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
	[attributes addObject: NSAccessibilityDescriptionAttribute];
	return attributes;
}



- (id) accessibilityAttributeValue: (NSString *) attribute {
	id value;
	
	if ( [attribute isEqualToString: NSAccessibilityDescriptionAttribute] ) {
		value = CtFLocalizedString( @"ClickTo Flash Menu", @"CTFActionButton Accessibility: Description");
	}
	else if ( [attribute isEqualToString: NSAccessibilityParentAttribute] ){
		value = NSAccessibilityUnignoredAncestor([[self controlView] superview]); 
	}
	else {
		value = [super accessibilityAttributeValue:attribute];
	}
	return value;
}


@end
