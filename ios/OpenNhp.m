#import "OpenNhp.h"

#import <Nhpagent/Iossdk.objc.h>

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
  BOOL ok = IossdkNhpAgentInit(workingDirectory, logLevel.longValue);
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
  NSString *keys = IossdkNhpGenerateKeys(cipher.longValue);
  resolve(keys ?: @"");
}

RCT_EXPORT_METHOD(privateKeyToPublicKey : (nonnull NSNumber *)cipher
                  privateKey : (NSString *)privateKey
                  resolver : (RCTPromiseResolveBlock)resolve
                  rejecter : (RCTPromiseRejectBlock)reject)
{
  NSString *pub = IossdkNhpPrivkeyToPubkey(cipher.longValue, privateKey);
  resolve(pub ?: @"");
}

RCT_EXPORT_METHOD(requestRegistrationOtp : (NSString *)workingDirectory
                  logLevel : (nonnull NSNumber *)logLevel
                  privateKey : (NSString *)privateKey
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
  NSString *json = IossdkNhpAgentRequestOtp(workingDirectory, logLevel.longValue, privateKey, cipher.longValue, email, deviceId, orgId, userData, aspId, resId, cluster);
  resolve(json ?: @"");
}

RCT_EXPORT_METHOD(registerDevice : (NSString *)workingDirectory
                  logLevel : (nonnull NSNumber *)logLevel
                  privateKey : (NSString *)privateKey
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
  NSString *json = IossdkNhpAgentRegister(workingDirectory, logLevel.longValue, privateKey, cipher.longValue, email, deviceId, orgId, userData, aspId, resId, cluster, otp);
  resolve(json ?: @"");
}

@end
