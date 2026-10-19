#import "SMOResources.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *digestData(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString new];
    for (unsigned i = 0; i < sizeof digest; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static NSString *digestFile(NSString *path) {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    [stream open];
    CC_SHA256_CTX ctx; CC_SHA256_Init(&ctx);
    uint8_t *buffer = malloc(1024 * 1024);
    if (!buffer) { [stream close]; return nil; }
    NSInteger n;
    while ((n = [stream read:buffer maxLength:1024 * 1024]) > 0) CC_SHA256_Update(&ctx, buffer, (CC_LONG)n);
    free(buffer); [stream close];
    if (n < 0) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString new];
    for (unsigned i = 0; i < sizeof digest; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

NSString *SMOCheckResources(NSString *documents, NSDictionary *expected, NSString *cachePath,
                           void (^progress)(NSUInteger, NSUInteger)) {
    NSString *manifestPath = [documents stringByAppendingPathComponent:@"resource_manifest.json"];
    NSData *raw = [NSData dataWithContentsOfFile:manifestPath];
    if (!raw) return @"Missing resource_manifest.json. Copy romfs/, msl/ and resource_manifest.json into this app in Files, then tap Check again.";
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
    if (![manifest isKindOfClass:NSDictionary.class]) return @"resource_manifest.json is invalid. Restore the resource package again.";
    // The public shell carries no compiled game library, so it validates the
    // manifest's chain. A personal IPA always enforces its compiled chain.
    if ([expected[@"package_kind"] isEqual:@"shell"]) {
        NSString *chain = manifest[@"shader_chain"];
        NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
        if (![chain isKindOfClass:NSString.class] || chain.length != 12 || [chain rangeOfCharacterFromSet:invalid].location != NSNotFound)
            return @"The resource manifest's shader chain is invalid.";
        NSMutableDictionary *checked = [expected mutableCopy]; checked[@"shader_chain"] = chain; expected = checked;
    }
    for (NSString *key in @[@"format", @"title_id", @"game_version", @"nxnative_commit", @"shader_chain", @"build_ids"]) {
        if (!expected[key] || ![manifest[key] isEqual:expected[key]])
            return [NSString stringWithFormat:@"Resource version mismatch (%@). Use this build's merged 1.4.1 resources and shaders.", key];
    }
    NSString *manifestHash = digestData(raw);
    if (expected[@"resource_manifest_sha256"] && ![expected[@"resource_manifest_sha256"] isEqual:manifestHash])
        return @"This resource manifest belongs to another personal IPA. Download the matching resource package.";
    NSArray *files = manifest[@"files"];
    if (![files isKindOfClass:NSArray.class] || !files.count) return @"The resource manifest contains no files.";
    NSDictionary *old = cachePath ? [NSDictionary dictionaryWithContentsOfFile:cachePath] : nil;
    NSDictionary *cached = [old[@"manifest"] isEqual:manifestHash] ? old[@"files"] : nil;
    NSMutableDictionary *verified = [NSMutableDictionary new];
    NSMutableSet *seen = [NSMutableSet new];
    BOOL hasMarker = NO, hasShader = NO;
    NSString *root = [[documents stringByResolvingSymlinksInPath] stringByAppendingString:@"/"];
    NSString *shaderPrefix = [NSString stringWithFormat:@"msl/b-%@/", expected[@"shader_chain"]];
    NSUInteger done = 0;
    for (id item in files) {
        if (![item isKindOfClass:NSDictionary.class]) return @"Invalid resource manifest entry.";
        NSDictionary *row = item;
        NSString *name = row[@"path"], *hash = row[@"sha256"];
        if (![name isKindOfClass:NSString.class] || ![hash isKindOfClass:NSString.class] || hash.length != 64 ||
            ![row[@"bytes"] isKindOfClass:NSNumber.class] || [name hasPrefix:@"/"] ||
            [name containsString:@"\\"] || [name containsString:@":"] || [name.pathComponents containsObject:@".."] ||
            [seen containsObject:name] || !([name hasPrefix:@"romfs/"] || [name hasPrefix:shaderPrefix]))
            return @"Invalid or duplicate resource manifest path.";
        [seen addObject:name];
        NSString *path = [documents stringByAppendingPathComponent:name];
        if (![[path stringByResolvingSymlinksInPath] hasPrefix:root]) return @"A resource path escapes the app's Documents directory.";
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if (![attributes[NSFileType] isEqual:NSFileTypeRegular] || ![attributes[NSFileSize] isEqual:row[@"bytes"]])
            return [NSString stringWithFormat:@"Missing or incomplete file: %@. Copy it again from the restored resource package.", name];
        NSDictionary *stamp = @{@"bytes": row[@"bytes"], @"mtime": @([attributes[NSFileModificationDate] timeIntervalSince1970]),
                               @"created": @([attributes[NSFileCreationDate] timeIntervalSince1970]), @"sha256": hash};
        if (![cached[name] isEqual:stamp] && ![digestFile(path) isEqual:hash])
            return [NSString stringWithFormat:@"Checksum failed: %@. Restore and copy this file again.", name];
        verified[name] = stamp;
        hasMarker |= [name isEqualToString:@"romfs/SoundData/SeResourceStd2nd.aras"];
        hasShader |= [name hasPrefix:shaderPrefix] && [name hasSuffix:@"_b.metallib"];
        done++;
        if (progress && (done % 100 == 0 || done == files.count)) progress(done, files.count);
    }
    if (!hasMarker || !hasShader) return @"The resource package is missing the RomFS marker or the expected iOS shader libraries.";
    if (cachePath) [@{@"manifest": manifestHash, @"files": verified} writeToFile:cachePath atomically:YES];
    return nil;
}
