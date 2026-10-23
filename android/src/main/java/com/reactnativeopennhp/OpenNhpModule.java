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
    run(
        promise,
        () -> {
          String blocked = AgentKeyStore.plaintextConfigError(workingDirectory);
          if (blocked != null) {
            promise.reject("E_OPENNHP", blocked);
            return;
          }
          AgentKeyStore.Material key = AgentKeyStore.load(getReactApplicationContext());
          if (key == null) {
            promise.resolve(false);
            return;
          }
          promise.resolve(
              NhpAgent.initializeAgentWithKey(
                  workingDirectory, logLevel, key.privateKey, key.cipher));
        });
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
    run(
        promise,
        () -> {
          String raw = NhpAgent.generateKeys(cipher);
          int separator = raw == null ? -1 : raw.indexOf('|');
          if (raw == null || separator <= 0 || separator >= raw.length() - 1) {
            promise.reject("E_OPENNHP", "OpenNHP generateKeys returned an unexpected value");
            return;
          }
          AgentKeyStore.save(
              getReactApplicationContext(), raw.substring(0, separator), cipher);
          promise.resolve(raw.substring(separator + 1));
        });
  }

  @ReactMethod
  public void getPublicKey(Promise promise) {
    run(
        promise,
        () -> {
          AgentKeyStore.Material key = AgentKeyStore.load(getReactApplicationContext());
          if (key == null) {
            promise.resolve("");
            return;
          }
          promise.resolve(NhpAgent.privateKeyToPublicKey(key.cipher, key.privateKey));
        });
  }

  @ReactMethod
  public void importAgentKey(String privateKey, int cipher, Promise promise) {
    run(
        promise,
        () -> {
          String publicKey = NhpAgent.privateKeyToPublicKey(cipher, privateKey);
          if (publicKey == null || publicKey.isEmpty()) {
            promise.reject("E_OPENNHP", "private key is not valid for this cipher");
            return;
          }
          AgentKeyStore.save(getReactApplicationContext(), privateKey, cipher);
          promise.resolve(publicKey);
        });
  }

  @ReactMethod
  public void requestRegistrationOtp(
      String workingDirectory,
      int logLevel,
      int cipher,
      String email,
      String deviceId,
      String orgId,
      String userData,
      String aspId,
      String resId,
      String cluster,
      Promise promise) {
    run(
        promise,
        () -> {
          String blocked = AgentKeyStore.plaintextConfigError(workingDirectory);
          if (blocked != null) {
            promise.reject("E_OPENNHP", blocked);
            return;
          }
          AgentKeyStore.Material stored = AgentKeyStore.load(getReactApplicationContext());
          String privateKey = stored == null ? "" : stored.privateKey;
          int cipherToUse = stored == null ? cipher : stored.cipher;
          String json =
              NhpAgent.requestRegistrationOtp(
                  workingDirectory,
                  logLevel,
                  privateKey,
                  cipherToUse,
                  email,
                  deviceId,
                  orgId,
                  userData,
                  aspId,
                  resId,
                  cluster);
          promise.resolve(
              AgentKeyStore.consumeRegistrationJson(
                  getReactApplicationContext(), json, cipherToUse));
        });
  }

  @ReactMethod
  public void registerDevice(
      String workingDirectory,
      int logLevel,
      int cipher,
      String email,
      String deviceId,
      String orgId,
      String userData,
      String aspId,
      String resId,
      String cluster,
      String otp,
      Promise promise) {
    run(
        promise,
        () -> {
          String blocked = AgentKeyStore.plaintextConfigError(workingDirectory);
          if (blocked != null) {
            promise.reject("E_OPENNHP", blocked);
            return;
          }
          AgentKeyStore.Material stored = AgentKeyStore.load(getReactApplicationContext());
          if (stored == null) {
            promise.reject(
                "E_OPENNHP",
                "No agent private key is stored. Call generateKeys, importAgentKey, or requestRegistrationOtp first.");
            return;
          }
          String json =
              NhpAgent.registerDevice(
                  workingDirectory,
                  logLevel,
                  stored.privateKey,
                  stored.cipher,
                  email,
                  deviceId,
                  orgId,
                  userData,
                  aspId,
                  resId,
                  cluster,
                  otp);
          promise.resolve(
              AgentKeyStore.consumeRegistrationJson(
                  getReactApplicationContext(), json, stored.cipher));
        });
  }
}
