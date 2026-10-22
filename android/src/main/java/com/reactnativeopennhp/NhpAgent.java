package com.reactnativeopennhp;

public final class NhpAgent {
  static {
    System.loadLibrary("nhpagent");
    System.loadLibrary("opennhpjni");
  }

  private NhpAgent() {}

  public static native boolean initializeAgent(String workingDirectory, int logLevel);

  public static native void close();

  public static native int startKnockLoop();

  public static native void stopKnockLoop();

  public static native boolean setKnockUser(
      String userId, String deviceId, String orgId, String userData);

  public static native boolean addServer(
      String pubkey, String ip, String host, int port, long expire);

  public static native void removeServer(String pubkey);

  public static native boolean addResource(String aspId, String resId, String cluster);

  public static native void removeResource(String aspId, String resId);

  public static native String knockResource(String aspId, String resId, String cluster);

  public static native boolean exitResource(String aspId, String resId, String cluster);

  public static native String generateKeys(int cipher);

  public static native String privateKeyToPublicKey(int cipher, String privateKey);
}
