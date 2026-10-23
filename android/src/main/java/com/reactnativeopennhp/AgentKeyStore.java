package com.reactnativeopennhp;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

final class AgentKeyStore {
  static final String SERVICE = "org.opennhp.agent";
  static final String ACCOUNT = "agent-private-key";

  private static final String PREFS = "org.opennhp.agent";
  private static final String CIPHER_PREF = "agent-cipher";
  private static final int GCM_IV_LENGTH = 12;
  private static final int GCM_TAG_BITS = 128;
  private static final String PLAINTEXT_KEY_MESSAGE =
      "etc/config.toml contains PrivateKeyBase64. Delete that file. This module stores the agent private key in the device secure store and will not read it from disk.";

  static final class Material {
    final String privateKey;
    final int cipher;

    Material(String privateKey, int cipher) {
      this.privateKey = privateKey;
      this.cipher = cipher;
    }
  }

  private AgentKeyStore() {}

  static void save(Context context, String privateKey, int cipher) throws Exception {
    byte[] iv = new byte[GCM_IV_LENGTH];
    new java.security.SecureRandom().nextBytes(iv);
    Cipher aes = Cipher.getInstance("AES/GCM/NoPadding");
    aes.init(Cipher.ENCRYPT_MODE, secretKey(), new GCMParameterSpec(GCM_TAG_BITS, iv));
    byte[] encrypted = aes.doFinal(privateKey.getBytes(StandardCharsets.UTF_8));
    byte[] blob = new byte[iv.length + encrypted.length];
    System.arraycopy(iv, 0, blob, 0, iv.length);
    System.arraycopy(encrypted, 0, blob, iv.length, encrypted.length);
    boolean stored =
        preferences(context)
            .edit()
            .putString(ACCOUNT, Base64.encodeToString(blob, Base64.NO_WRAP))
            .putInt(CIPHER_PREF, cipher)
            .commit();
    if (!stored) {
      throw new IllegalStateException("Unable to store the OpenNHP agent key.");
    }
  }

  static Material load(Context context) throws Exception {
    SharedPreferences preferences = preferences(context);
    String encoded = preferences.getString(ACCOUNT, null);
    if (encoded == null || encoded.isEmpty()) {
      return null;
    }
    byte[] blob = Base64.decode(encoded, Base64.NO_WRAP);
    if (blob.length <= GCM_IV_LENGTH) {
      return null;
    }
    byte[] iv = new byte[GCM_IV_LENGTH];
    byte[] encrypted = new byte[blob.length - GCM_IV_LENGTH];
    System.arraycopy(blob, 0, iv, 0, iv.length);
    System.arraycopy(blob, iv.length, encrypted, 0, encrypted.length);
    Cipher aes = Cipher.getInstance("AES/GCM/NoPadding");
    aes.init(Cipher.DECRYPT_MODE, secretKey(), new GCMParameterSpec(GCM_TAG_BITS, iv));
    String privateKey = new String(aes.doFinal(encrypted), StandardCharsets.UTF_8);
    if (privateKey.isEmpty()) {
      return null;
    }
    return new Material(privateKey, preferences.getInt(CIPHER_PREF, 0));
  }

  static String consumeRegistrationJson(Context context, String json, int cipher) throws Exception {
    if (json == null || json.isEmpty()) {
      return "{\"errCode\":\"-1\",\"errMsg\":\"OpenNHP returned an empty registration response\"}";
    }
    JSONObject object;
    try {
      object = new JSONObject(json);
    } catch (org.json.JSONException error) {
      return "{\"errCode\":\"-1\",\"errMsg\":\"OpenNHP returned a registration response that was not JSON\"}";
    }
    String privateKey = object.optString("privateKey", "");
    object.remove("privateKey");
    if (!privateKey.isEmpty()) {
      save(context, privateKey, cipher);
    }
    return object.toString();
  }

  static String plaintextConfigError(String workingDirectory) {
    if (workingDirectory == null || workingDirectory.isEmpty()) {
      return null;
    }
    java.io.File file = new java.io.File(workingDirectory, "etc/config.toml");
    if (!file.isFile()) {
      return null;
    }
    String text;
    try (java.io.InputStream input = new java.io.FileInputStream(file);
        java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
      byte[] buffer = new byte[4096];
      int read;
      while ((read = input.read(buffer)) != -1) {
        output.write(buffer, 0, read);
      }
      text = output.toString(StandardCharsets.UTF_8.name());
    } catch (java.io.IOException error) {
      return null;
    }
    for (String line : text.split("\n")) {
      String trimmed = line.trim();
      if (trimmed.isEmpty() || trimmed.startsWith("#") || !trimmed.startsWith("PrivateKeyBase64")) {
        continue;
      }
      if (!tomlValue(trimmed).isEmpty()) {
        return PLAINTEXT_KEY_MESSAGE;
      }
    }
    return null;
  }

  private static String tomlValue(String line) {
    int equals = line.indexOf('=');
    if (equals < 0 || equals + 1 >= line.length()) {
      return "";
    }
    String value = line.substring(equals + 1).trim();
    if (value.isEmpty()) {
      return "";
    }
    char quote = value.charAt(0);
    if (quote == '"' || quote == '\'') {
      int closing = value.indexOf(quote, 1);
      if (closing < 0) {
        return "";
      }
      return value.substring(1, closing);
    }
    int comment = value.indexOf('#');
    if (comment >= 0) {
      value = value.substring(0, comment);
    }
    return value.trim();
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }

  private static SecretKey secretKey() throws Exception {
    KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
    keyStore.load(null);
    if (!keyStore.containsAlias(SERVICE)) {
      KeyGenerator generator =
          KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
      generator.init(
          new KeyGenParameterSpec.Builder(
                  SERVICE, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
              .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
              .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
              .setKeySize(256)
              .build());
      generator.generateKey();
    }
    return (SecretKey) keyStore.getKey(SERVICE, null);
  }
}
