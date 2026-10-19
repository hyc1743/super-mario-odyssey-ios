#import <Foundation/Foundation.h>

// Returns nil only after the identity, completeness and file hashes match.
NSString *SMOCheckResources(NSString *documents, NSDictionary *expected, NSString *cachePath,
                           void (^progress)(NSUInteger done, NSUInteger total));
