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

#import "CTFLoader.h"
#import "CTFUtilities.h"


@implementation CTFLoader

- (id) initWithURL: (NSURL *) theURL delegate: (id) theDelegate selector: (SEL) theSelector {
	self = [super init];
	id result = nil;
	
	if (self != nil && theURL != nil && theDelegate != nil && theSelector != NULL) {
		[self setURL: theURL];
		[self setDelegate: theDelegate];
		[self setCallbackSelector: theSelector];

		data = [[NSMutableData alloc] init];
		identifier = nil;
		response = nil;
		
		result = self;
	}
	
	return result;
}



// Calls -reallyStart on the main thread. -reallyStart opens an NSURLConnection which calls its delegate methods on the same thread it was initialised on (and does nothing when that thread doesn't exist anymore). As this method can be called on a different thread, we make sure that the delegate methods can be called when they are due.
- (void) start {
	[self performSelectorOnMainThread:@selector(reallyStart) withObject:nil waitUntilDone:YES];
}



// Starts the NSURLConnection to do the fetching. This should be invoked by calling the -start method.
- (void) reallyStart {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL: URL];
	if ([self HEADOnly]) {
		[request setHTTPMethod:@"HEAD"];
	}
	[[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
}



- (void) finish {
	[delegate performSelector:callbackSelector withObject:self];
}



- (void) dealloc {
	[data release];
	[delegate release];
	[identifier release];
	[super dealloc];
}




#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *) newData {
	[data appendData: newData];
}



- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)theResponse {
	[self setResponse: theResponse];
	
	// We need to cancel HEAD fetching connections here as 10.5 may proceed to download the whole file otherwise ( http://openradar.appspot.com/7019347 )
	if ( [self HEADOnly] && [(NSHTTPURLResponse*) theResponse statusCode] == 200 ) {
		[self finish];
		[connection cancel];
	}
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self finish];		
}



- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"ClickToFlash Loader download failure: %@", [error description]);
	[self finish];
}



- (NSURLRequest *)connection:(NSURLConnection *)connection 
			 willSendRequest:(NSURLRequest *)request 
			redirectResponse:(NSURLResponse *)redirectResponse
{
#if LOGGING_ENABLED
	NSLog(@"CTFLoader redirect to: %@", [[request URL] absoluteString]);
#endif
	NSURLRequest * result = request;
	
	// For the head fetching we need to fix the redirects to make sure the method they use is HEAD.
	if ( [self HEADOnly] ) {
		if (![[request HTTPMethod] isEqualTo:@"HEAD"]) {
			NSMutableURLRequest * newRequest = [[request mutableCopy] autorelease];
			[newRequest setHTTPMethod:@"HEAD"];
			result = newRequest;
		}
	} 		
	
	[self setLastRequest: request];

	return result;
}






#pragma mark -
#pragma mark Accessors

- (NSData*)data {
	return data;
}


- (NSURL *)URL {
	return URL;
}

- (void)setURL:(NSURL *)newURL {
#if LOGGING_ENABLED
	NSLog(@"CTFLoader setURL: %@", newURL);
#endif
	
	[newURL retain];
	[URL release];
	URL = newURL;
}


- (NSURLResponse *)response {
	return response;
}

- (void)setResponse:(NSURLResponse *)newResponse {
	[newResponse retain];
	[response release];
	response = newResponse;
}


- (NSURLRequest *)lastRequest {
	return lastRequest;
}

- (void)setLastRequest:(NSURLRequest *)newLastRequest {
	[newLastRequest retain];
	[lastRequest release];
	lastRequest = newLastRequest;
}


- (id)identifier {
	return identifier;
}

- (void)setIdentifier:(id)newIdentifier {
	[newIdentifier retain];
	[identifier release];
	identifier = newIdentifier;
}


- (BOOL)HEADOnly {
	return HEADOnly;
}

- (void)setHEADOnly:(BOOL)newHEADOnly {
	HEADOnly = newHEADOnly;
}


- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id)newDelegate {
	[newDelegate retain];
	[delegate release];
	delegate = newDelegate;
}


- (SEL)callbackSelector {
	return callbackSelector;
}

- (void)setCallbackSelector:(SEL)newCallbackSelector {
	callbackSelector = newCallbackSelector;
}


@end
