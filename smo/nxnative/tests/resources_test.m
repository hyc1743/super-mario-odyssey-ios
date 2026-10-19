#import "SMOResources.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *hash(NSData *data) {
    unsigned char bytes[32]; CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *result = [NSMutableString new];
    for (int i = 0; i < 32; i++) [result appendFormat:@"%02x", bytes[i]];
    return result;
}

int main(void) {
    @autoreleasepool {
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSFileManager *fm = NSFileManager.defaultManager;
        NSDictionary *expected = @{@"format": @1, @"title_id": @"0100000000010000", @"game_version": @"1.4.1",
            @"nxnative_commit": @"test", @"shader_chain": @"test", @"build_ids": @{@"main": @"test"}};
        [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        NSCAssert(SMOCheckResources(root, expected, nil, nil) != nil, @"Missing manifest must fail");
        NSMutableArray *files = [NSMutableArray new];
        NSData *data = [@"verified" dataUsingEncoding:NSUTF8StringEncoding];
        for (NSString *name in @[@"romfs/SoundData/SeResourceStd2nd.aras", @"msl/b-test/shader_b.metallib"]) {
            NSString *path = [root stringByAppendingPathComponent:name];
            [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            [data writeToFile:path atomically:YES];
            [files addObject:@{@"path": name, @"bytes": @(data.length), @"sha256": hash(data)}];
        }
        NSMutableDictionary *manifest = [expected mutableCopy]; manifest[@"files"] = files;
        NSString *path = [root stringByAppendingPathComponent:@"resource_manifest.json"];
        [[NSJSONSerialization dataWithJSONObject:manifest options:0 error:nil] writeToFile:path atomically:YES];
        NSCAssert(SMOCheckResources(root, expected, nil, nil) == nil, @"Matching complete resources must pass");
        NSMutableDictionary *wrong = [expected mutableCopy]; wrong[@"game_version"] = @"v0";
        NSCAssert(SMOCheckResources(root, wrong, nil, nil) != nil, @"Wrong version must fail");
        wrong = [expected mutableCopy]; wrong[@"shader_chain"] = @"old";
        NSCAssert(SMOCheckResources(root, wrong, nil, nil) != nil, @"Wrong shader chain must fail");
        wrong = [expected mutableCopy]; wrong[@"resource_manifest_sha256"] = @"wrong";
        NSCAssert(SMOCheckResources(root, wrong, nil, nil) != nil, @"Mismatched personal package must fail");
        NSString *shader = [root stringByAppendingPathComponent:@"msl/b-test/shader_b.metallib"];
        [[@"corrupt!" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:shader atomically:YES];
        NSCAssert(SMOCheckResources(root, expected, nil, nil) != nil, @"Same-size corruption must fail");
        [fm removeItemAtPath:shader error:nil];
        NSCAssert(SMOCheckResources(root, expected, nil, nil) != nil, @"Incomplete copy must fail");
        [fm removeItemAtPath:root error:nil];
        puts("Native resource validation: PASS");
    }
    return 0;
}
