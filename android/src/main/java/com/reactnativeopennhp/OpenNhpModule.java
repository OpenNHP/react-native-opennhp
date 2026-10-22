package com.reactnativeopennhp;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class OpenNhpModule extends ReactContextBaseJavaModule {
  private final ExecutorService executor = Executors.newSingleThreadExecutor();

  public OpenNhpModule(ReactApplicationContext context) {
    super(context);
  }

  @Override
  public String getName() {
    return "OpenNhp";
  }

  @Override
  public Map<String, Object> getConstants() {
    Map<String, Object> constants = new HashMap<>();
    constants.put(
        "defaultWorkingDirectory", getReactApplicationContext().getFilesDir().getAbsolutePath());
    return Collections.unmodifiableMap(constants);
  }

  private void run(Promise promise, Runnable work) {
    executor.execute(
        () -> {
          try {
            work.run();
          } catch (Throwable error) {
            promise.reject("E_OPENNHP", error);
          }
        });
  }

  @ReactMethod
  public void initializeAgent(String workingDirectory, int logLevel, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.initializeAgent(workingDirectory, logLevel)));
  }

  @ReactMethod
  public void close(Promise promise) {
    run(
        promise,
        () -> {
          NhpAgent.close();
          promise.resolve(null);
        });
  }

  @ReactMethod
  public void startKnockLoop(Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.startKnockLoop()));
  }

  @ReactMethod
  public void stopKnockLoop(Promise promise) {
    run(
        promise,
        () -> {
          NhpAgent.stopKnockLoop();
          promise.resolve(null);
        });
  }

  @ReactMethod
  public void setKnockUser(
      String userId, String deviceId, String orgId, String userData, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.setKnockUser(userId, deviceId, orgId, userData)));
  }

  @ReactMethod
  public void addServer(
      String pubkey, String ip, String host, int port, double expire, Promise promise) {
    run(
        promise,
        () -> promise.resolve(NhpAgent.addServer(pubkey, ip, host, port, (long) expire)));
  }

  @ReactMethod
  public void removeServer(String pubkey, Promise promise) {
    run(
        promise,
        () -> {
          NhpAgent.removeServer(pubkey);
          promise.resolve(null);
        });
  }

  @ReactMethod
  public void addResource(String aspId, String resId, String cluster, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.addResource(aspId, resId, cluster)));
  }

  @ReactMethod
  public void removeResource(String aspId, String resId, Promise promise) {
    run(
        promise,
        () -> {
          NhpAgent.removeResource(aspId, resId);
          promise.resolve(null);
        });
  }

  @ReactMethod
  public void knockResource(String aspId, String resId, String cluster, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.knockResource(aspId, resId, cluster)));
  }

  @ReactMethod
  public void exitResource(String aspId, String resId, String cluster, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.exitResource(aspId, resId, cluster)));
  }

  @ReactMethod
  public void generateKeys(int cipher, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.generateKeys(cipher)));
  }

  @ReactMethod
  public void privateKeyToPublicKey(int cipher, String privateKey, Promise promise) {
    run(promise, () -> promise.resolve(NhpAgent.privateKeyToPublicKey(cipher, privateKey)));
  }
}
