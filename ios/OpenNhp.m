#import "OpenNhp.h"

#import <Nhpagent/Iossdk.objc.h>
#import <Security/Security.h>

static NSString *const OpenNhpKeychainService = @"org.opennhp.agent";
static NSString *const OpenNhpKeychainAccount = @"agent-private-key";
static NSString *const OpenNhpPlaintextKeyMessage =
    @"etc/config.toml contains PrivateKeyBase64. Delete that file. This module stores the agent private key in the device secure store and will not read it from disk.";

static NSDictionary *OpenNhpKeychainQuery(void)
{
  return @{
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService : OpenNhpKeychainService,
    (__bridge id)kSecAttrAccount : OpenNhpKeychainAccount,
  };
}

static BOOL OpenNhpStoreAgentKey(NSString *privateKey, NSInteger cipher, NSError **error)
{
  NSString *payload = [NSString stringWithFormat:@"%ld|%@", (long)cipher, privateKey];
  NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableDictionary *query = [OpenNhpKeychainQuery() mutableCopy];
  SecItemDelete((__bridge CFDictionaryRef)query);
  query[(__bridge id)kSecValueData] = data;
  query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
  OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
  if (status != errSecSuccess) {
    if (error != nil) {
      *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                   code:status
                               userInfo:@{NSLocalizedDescriptionKey : @"Unable to store the OpenNHP agent key in the Keychain."}];
    }
    return NO;
  }
  return YES;
}

static BOOL OpenNhpLoadAgentKey(NSString **privateKey, NSInteger *cipher)
{
  NSMutableDictionary *query = [OpenNhpKeychainQuery() mutableCopy];
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  CFTypeRef result = NULL;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
  if (status != errSecSuccess || result == NULL) {
    return NO;
  }
  NSData *data = (__bridge_transfer NSData *)result;
  NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSRange separator = [payload rangeOfString:@"|"];
  if (separator.location == NSNotFound || separator.location == 0 || separator.location + 1 >= payload.length) {
    return NO;
  }
  *cipher = [[payload substringToIndex:separator.location] integerValue];
  *privateKey = [payload substringFromIndex:separator.location + 1];
  return (*privateKey).length > 0;
}

static NSString *OpenNhpTomlValue(NSString *line)
{
  NSRange equals = [line rangeOfString:@"="];
  if (equals.location == NSNotFound || equals.location + 1 >= line.length) {
    return @"";
  }
  NSString *value = [[line substringFromIndex:equals.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (value.length == 0) {
    return @"";
  }
  unichar quote = [value characterAtIndex:0];
  if (quote == '"' || quote == '\'') {
    if (value.length < 2) {
      return @"";
    }
    NSRange closing = [value rangeOfString:[NSString stringWithCharacters:&quote length:1] options:0 range:NSMakeRange(1, value.length - 1)];
    if (closing.location == NSNotFound) {
      return @"";
    }
    return [value substringWithRange:NSMakeRange(1, closing.location - 1)];
  }
  NSRange comment = [value rangeOfString:@"#"];
  if (comment.location != NSNotFound) {
    value = [value substringToIndex:comment.location];
  }
  return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

static NSString *OpenNhpPlaintextKeyError(NSString *workingDirectory)
{
  if (workingDirectory.length == 0) {
    return nil;
  }
  NSString *path = [workingDirectory stringByAppendingPathComponent:@"etc/config.toml"];
  NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  if (text == nil) {
    return nil;
  }
  NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  for (NSString *line in lines) {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0 || [trimmed hasPrefix:@"#"]) {
      continue;
    }
    if (![trimmed hasPrefix:@"PrivateKeyBase64"]) {
      continue;
    }
    if (OpenNhpTomlValue(trimmed).length > 0) {
      return OpenNhpPlaintextKeyMessage;
    }
  }
  return nil;
}

static NSString *OpenNhpPublicKey(NSString *privateKey, NSInteger cipher)
{
  if (privateKey.length == 0) {
    return @"";
  }
  return IossdkNhpPrivkeyToPubkey(cipher, privateKey) ?: @"";
}

static NSString *OpenNhpRegistrationJSON(NSString *json, NSString **privateKeyOut)
{
  if (privateKeyOut != nil) {
    *privateKeyOut = nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil) {
    return @"{\"errCode\":\"-1\",\"errMsg\":\"OpenNHP returned an empty registration response\"}";
  }
  NSError *error = nil;
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
  if (![parsed isKindOfClass:[NSMutableDictionary class]]) {
    return @"{\"errCode\":\"-1\",\"errMsg\":\"OpenNHP returned a registration response that was not JSON\"}";
  }
  NSMutableDictionary *object = parsed;
  id key = object[@"privateKey"];
  if ([key isKindOfClass:[NSString class]] && [(NSString *)key length] > 0 && privateKeyOut != nil) {
    *privateKeyOut = key;
  }
  [object removeObjectForKey:@"privateKey"];
  NSData *encoded = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
  if (encoded == nil) {
    return @"{\"errCode\":\"1\",\"errMsg\":\"failed to encode registration result\"}";
  }
  return [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
}

@implementation OpenNhp

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (dispatch_queue_t)methodQueue
{
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create("com.reactnativeopennhp", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

- (NSDictionary *)constantsToExport
{
  NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                   inDomains:NSUserDomainMask];
  NSString *path = urls.firstObject.path ?: @"";
  return @{@"defaultWorkingDirectory" : path};
}

RCT_EXPORT_METHOD(initializeAgent : (NSString *)workingDirectory
                  logLevel : (nonnull NSNumber *)logLevel
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *blocked = OpenNhpPlaintextKeyError(workingDirectory);
  if (blocked != nil) {
    reject(@"E_OPENNHP", blocked, nil);
    return;
  }
  NSString *privateKey = nil;
  NSInteger cipher = 0;
  if (!OpenNhpLoadAgentKey(&privateKey, &cipher)) {
    resolve(@NO);
    return;
  }
  BOOL ok = IossdkNhpAgentInitWithKey(workingDirectory, logLevel.longValue, privateKey, cipher);
  resolve(@(ok));
}

RCT_EXPORT_METHOD(close : (RCTPromiseResolveBlock)resolve rejecter : (RCTPromiseRejectBlock)reject)
{
  IossdkNhpAgentClose();
  resolve(nil);
}

RCT_EXPORT_METHOD(startKnockLoop : (RCTPromiseResolveBlock)resolve rejecter : (RCTPromiseRejectBlock)reject)
{
  resolve(@(IossdkNhpAgentKnockloopStart()));
}

RCT_EXPORT_METHOD(stopKnockLoop : (RCTPromiseResolveBlock)resolve rejecter : (RCTPromiseRejectBlock)reject)
{
  IossdkNhpAgentKnockloopStop();
  resolve(nil);
}

RCT_EXPORT_METHOD(setKnockUser : (NSString *)userId
                  deviceId : (NSString *)deviceId
                  orgId : (NSString *)orgId
                  userData : (NSString *)userData
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  BOOL ok = IossdkNhpAgentSetKnockUser(userId, deviceId, orgId, userData);
  resolve(@(ok));
}

RCT_EXPORT_METHOD(addServer : (NSString *)pubkey
                  ip : (NSString *)ip
                  host : (NSString *)host
                  port : (nonnull NSNumber *)port
                  expire : (nonnull NSNumber *)expire
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  BOOL ok = IossdkNhpAgentAddServer(pubkey, ip, host, port.longValue, expire.longLongValue);
  resolve(@(ok));
}

RCT_EXPORT_METHOD(removeServer : (NSString *)pubkey
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  IossdkNhpAgentRemoveServer(pubkey);
  resolve(nil);
}

RCT_EXPORT_METHOD(addResource : (NSString *)aspId
                  resId : (NSString *)resId
                  cluster : (NSString *)cluster
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  BOOL ok = IossdkNhpAgentAddResource(aspId, resId, cluster);
  resolve(@(ok));
}

RCT_EXPORT_METHOD(removeResource : (NSString *)aspId
                  resId : (NSString *)resId
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  IossdkNhpAgentRemoveResource(aspId, resId);
  resolve(nil);
}

RCT_EXPORT_METHOD(knockResource : (NSString *)aspId
                  resId : (NSString *)resId
                  cluster : (NSString *)cluster
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *json = IossdkNhpAgentKnockResource(aspId, resId, cluster);
  resolve(json ?: @"");
}

RCT_EXPORT_METHOD(exitResource : (NSString *)aspId
                  resId : (NSString *)resId
                  cluster : (NSString *)cluster
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  BOOL ok = IossdkNhpAgentExitResource(aspId, resId, cluster);
  resolve(@(ok));
}

RCT_EXPORT_METHOD(generateKeys : (nonnull NSNumber *)cipher
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *raw = IossdkNhpGenerateKeys(cipher.longValue) ?: @"";
  NSRange separator = [raw rangeOfString:@"|"];
  if (separator.location == NSNotFound || separator.location == 0 || separator.location + 1 >= raw.length) {
    reject(@"E_OPENNHP", @"OpenNHP generateKeys returned an unexpected value", nil);
    return;
  }
  NSString *privateKey = [raw substringToIndex:separator.location];
  NSString *publicKey = [raw substringFromIndex:separator.location + 1];
  NSError *error = nil;
  if (!OpenNhpStoreAgentKey(privateKey, cipher.longValue, &error)) {
    reject(@"E_OPENNHP", error.localizedDescription, error);
    return;
  }
  resolve(publicKey);
}

RCT_EXPORT_METHOD(getPublicKey : (RCTPromiseResolveBlock)resolve rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *privateKey = nil;
  NSInteger cipher = 0;
  if (!OpenNhpLoadAgentKey(&privateKey, &cipher)) {
    resolve(@"");
    return;
  }
  resolve(OpenNhpPublicKey(privateKey, cipher));
}

RCT_EXPORT_METHOD(importAgentKey : (NSString *)privateKey
                  cipher : (nonnull NSNumber *)cipher
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *publicKey = OpenNhpPublicKey(privateKey, cipher.longValue);
  if (publicKey.length == 0) {
    reject(@"E_OPENNHP", @"private key is not valid for this cipher", nil);
    return;
  }
  NSError *error = nil;
  if (!OpenNhpStoreAgentKey(privateKey, cipher.longValue, &error)) {
    reject(@"E_OPENNHP", error.localizedDescription, error);
    return;
  }
  resolve(publicKey);
}

RCT_EXPORT_METHOD(requestRegistrationOtp : (NSString *)workingDirectory
                  logLevel : (nonnull NSNumber *)logLevel
                  cipher : (nonnull NSNumber *)cipher
                  email : (NSString *)email
                  deviceId : (NSString *)deviceId
                  orgId : (NSString *)orgId
                  userData : (NSString *)userData
                  aspId : (NSString *)aspId
                  resId : (NSString *)resId
                  cluster : (NSString *)cluster
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *blocked = OpenNhpPlaintextKeyError(workingDirectory);
  if (blocked != nil) {
    reject(@"E_OPENNHP", blocked, nil);
    return;
  }
  NSString *storedKey = nil;
  NSInteger storedCipher = 0;
  NSString *privateKey = @"";
  NSInteger cipherType = cipher.longValue;
  if (OpenNhpLoadAgentKey(&storedKey, &storedCipher)) {
    privateKey = storedKey;
    cipherType = storedCipher;
  }
  NSString *json = IossdkNhpAgentRequestOtp(workingDirectory, logLevel.longValue, privateKey, cipherType, email, deviceId, orgId, userData, aspId, resId, cluster);
  NSString *generated = nil;
  NSString *safe = OpenNhpRegistrationJSON(json, &generated);
  if (generated.length > 0) {
    NSError *error = nil;
    if (!OpenNhpStoreAgentKey(generated, cipherType, &error)) {
      reject(@"E_OPENNHP", error.localizedDescription, error);
      return;
    }
  }
  resolve(safe ?: @"");
}

RCT_EXPORT_METHOD(registerDevice : (NSString *)workingDirectory
                  logLevel : (nonnull NSNumber *)logLevel
                  cipher : (nonnull NSNumber *)cipher
                  email : (NSString *)email
                  deviceId : (NSString *)deviceId
                  orgId : (NSString *)orgId
                  userData : (NSString *)userData
                  aspId : (NSString *)aspId
                  resId : (NSString *)resId
                  cluster : (NSString *)cluster
                  otp : (NSString *)otp
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  (void)cipher;
  NSString *blocked = OpenNhpPlaintextKeyError(workingDirectory);
  if (blocked != nil) {
    reject(@"E_OPENNHP", blocked, nil);
    return;
  }
  NSString *privateKey = nil;
  NSInteger storedCipher = 0;
  if (!OpenNhpLoadAgentKey(&privateKey, &storedCipher)) {
    reject(@"E_OPENNHP", @"No agent private key is stored. Call generateKeys, importAgentKey, or requestRegistrationOtp first.", nil);
    return;
  }
  NSString *json = IossdkNhpAgentRegister(workingDirectory, logLevel.longValue, privateKey, storedCipher, email, deviceId, orgId, userData, aspId, resId, cluster, otp);
  NSString *unused = nil;
  resolve(OpenNhpRegistrationJSON(json, &unused) ?: @"");
}

@end
