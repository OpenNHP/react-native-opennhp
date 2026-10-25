#include <jni.h>

typedef unsigned char GoUint8;
typedef long long GoInt64;

extern void nhp_free_cstring(char *ptr);
extern GoUint8 nhp_agent_init_with_key(char *workingDir, int logLevel, char *privateKey, int cipherType);
extern void nhp_agent_close(void);
extern int nhp_agent_knockloop_start(void);
extern void nhp_agent_knockloop_stop(void);
extern GoUint8 nhp_agent_set_knock_user(char *userId, char *devId, char *orgId, char *userData);
extern GoUint8 nhp_agent_add_server(char *pubkey, char *ip, char *host, int port, GoInt64 expire);
extern void nhp_agent_remove_server(char *pubkey);
extern GoUint8 nhp_agent_add_resource(char *aspId, char *resId, char *cluster);
extern void nhp_agent_remove_resource(char *aspId, char *resId);
extern char *nhp_agent_knock_resource(char *aspId, char *resId, char *cluster);
extern GoUint8 nhp_agent_exit_resource(char *aspId, char *resId, char *cluster);
extern char *nhp_generate_keys(int cipherType);
extern char *nhp_privkey_to_pubkey(int cipherType, char *privateBase64);
extern char *nhp_agent_request_otp(char *workingDir, int logLevel, char *privateKey, int cipherType, char *email, char *deviceId, char *orgId, char *userData, char *aspId, char *resId, char *cluster);
extern char *nhp_agent_register(char *workingDir, int logLevel, char *privateKey, int cipherType, char *email, char *deviceId, char *orgId, char *userData, char *aspId, char *resId, char *cluster, char *otp);
extern char *nhp_agent_take_generated_key(void);

static const char *lock_string(JNIEnv *env, jstring value) {
  if (value == NULL) {
    return NULL;
  }
  const char *chars = (*env)->GetStringUTFChars(env, value, NULL);
  if (chars == NULL || chars[0] == '\0') {
    if (chars != NULL) {
      (*env)->ReleaseStringUTFChars(env, value, chars);
    }
    return NULL;
  }
  return chars;
}

static void unlock_string(JNIEnv *env, jstring value, const char *chars) {
  if (value != NULL && chars != NULL) {
    (*env)->ReleaseStringUTFChars(env, value, chars);
  }
}

static jstring adopt_cstring(JNIEnv *env, char *value) {
  if (value == NULL) {
    return (*env)->NewStringUTF(env, "");
  }
  jstring result = (*env)->NewStringUTF(env, value);
  nhp_free_cstring(value);
  return result;
}

JNIEXPORT jboolean JNICALL Java_com_reactnativeopennhp_NhpAgent_initializeAgentWithKey(
    JNIEnv *env, jclass clazz, jstring workingDirectory, jint logLevel, jstring privateKey, jint cipher) {
  (void)clazz;
  const char *directory = lock_string(env, workingDirectory);
  const char *key = lock_string(env, privateKey);
  GoUint8 ok = nhp_agent_init_with_key((char *)directory, logLevel, (char *)key, cipher);
  unlock_string(env, workingDirectory, directory);
  unlock_string(env, privateKey, key);
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_reactnativeopennhp_NhpAgent_close(JNIEnv *env, jclass clazz) {
  (void)env;
  (void)clazz;
  nhp_agent_close();
}

JNIEXPORT jint JNICALL Java_com_reactnativeopennhp_NhpAgent_startKnockLoop(JNIEnv *env, jclass clazz) {
  (void)env;
  (void)clazz;
  return nhp_agent_knockloop_start();
}

JNIEXPORT void JNICALL Java_com_reactnativeopennhp_NhpAgent_stopKnockLoop(JNIEnv *env, jclass clazz) {
  (void)env;
  (void)clazz;
  nhp_agent_knockloop_stop();
}

JNIEXPORT jboolean JNICALL Java_com_reactnativeopennhp_NhpAgent_setKnockUser(
    JNIEnv *env, jclass clazz, jstring userId, jstring deviceId, jstring orgId, jstring userData) {
  (void)clazz;
  const char *user = lock_string(env, userId);
  const char *device = lock_string(env, deviceId);
  const char *org = lock_string(env, orgId);
  const char *data = lock_string(env, userData);
  GoUint8 ok = nhp_agent_set_knock_user((char *)user, (char *)device, (char *)org, (char *)data);
  unlock_string(env, userId, user);
  unlock_string(env, deviceId, device);
  unlock_string(env, orgId, org);
  unlock_string(env, userData, data);
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_reactnativeopennhp_NhpAgent_addServer(
    JNIEnv *env, jclass clazz, jstring pubkey, jstring ip, jstring host, jint port, jlong expire) {
  (void)clazz;
  const char *pub = lock_string(env, pubkey);
  const char *address = lock_string(env, ip);
  const char *hostname = lock_string(env, host);
  GoUint8 ok = nhp_agent_add_server((char *)pub, (char *)address, (char *)hostname, port, (GoInt64)expire);
  unlock_string(env, pubkey, pub);
  unlock_string(env, ip, address);
  unlock_string(env, host, hostname);
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_reactnativeopennhp_NhpAgent_removeServer(
    JNIEnv *env, jclass clazz, jstring pubkey) {
  (void)clazz;
  const char *pub = lock_string(env, pubkey);
  nhp_agent_remove_server((char *)pub);
  unlock_string(env, pubkey, pub);
}

JNIEXPORT jboolean JNICALL Java_com_reactnativeopennhp_NhpAgent_addResource(
    JNIEnv *env, jclass clazz, jstring aspId, jstring resId, jstring cluster) {
  (void)clazz;
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  const char *name = lock_string(env, cluster);
  GoUint8 ok = nhp_agent_add_resource((char *)asp, (char *)res, (char *)name);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
  unlock_string(env, cluster, name);
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL Java_com_reactnativeopennhp_NhpAgent_removeResource(
    JNIEnv *env, jclass clazz, jstring aspId, jstring resId) {
  (void)clazz;
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  nhp_agent_remove_resource((char *)asp, (char *)res);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_knockResource(
    JNIEnv *env, jclass clazz, jstring aspId, jstring resId, jstring cluster) {
  (void)clazz;
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  const char *name = lock_string(env, cluster);
  char *json = nhp_agent_knock_resource((char *)asp, (char *)res, (char *)name);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
  unlock_string(env, cluster, name);
  return adopt_cstring(env, json);
}

JNIEXPORT jboolean JNICALL Java_com_reactnativeopennhp_NhpAgent_exitResource(
    JNIEnv *env, jclass clazz, jstring aspId, jstring resId, jstring cluster) {
  (void)clazz;
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  const char *name = lock_string(env, cluster);
  GoUint8 ok = nhp_agent_exit_resource((char *)asp, (char *)res, (char *)name);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
  unlock_string(env, cluster, name);
  return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_generateKeys(
    JNIEnv *env, jclass clazz, jint cipher) {
  (void)clazz;
  return adopt_cstring(env, nhp_generate_keys(cipher));
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_privateKeyToPublicKey(
    JNIEnv *env, jclass clazz, jint cipher, jstring privateKey) {
  (void)clazz;
  const char *key = lock_string(env, privateKey);
  char *pub = nhp_privkey_to_pubkey(cipher, (char *)key);
  unlock_string(env, privateKey, key);
  return adopt_cstring(env, pub);
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_requestRegistrationOtp(
    JNIEnv *env, jclass clazz, jstring workingDirectory, jint logLevel, jstring privateKey, jint cipher,
    jstring email, jstring deviceId, jstring orgId, jstring userData, jstring aspId, jstring resId, jstring cluster) {
  (void)clazz;
  const char *dir = lock_string(env, workingDirectory);
  const char *key = lock_string(env, privateKey);
  const char *mail = lock_string(env, email);
  const char *device = lock_string(env, deviceId);
  const char *org = lock_string(env, orgId);
  const char *data = lock_string(env, userData);
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  const char *name = lock_string(env, cluster);
  char *json = nhp_agent_request_otp((char *)dir, logLevel, (char *)key, cipher, (char *)mail, (char *)device, (char *)org, (char *)data, (char *)asp, (char *)res, (char *)name);
  unlock_string(env, workingDirectory, dir);
  unlock_string(env, privateKey, key);
  unlock_string(env, email, mail);
  unlock_string(env, deviceId, device);
  unlock_string(env, orgId, org);
  unlock_string(env, userData, data);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
  unlock_string(env, cluster, name);
  return adopt_cstring(env, json);
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_registerDevice(
    JNIEnv *env, jclass clazz, jstring workingDirectory, jint logLevel, jstring privateKey, jint cipher,
    jstring email, jstring deviceId, jstring orgId, jstring userData, jstring aspId, jstring resId, jstring cluster, jstring otp) {
  (void)clazz;
  const char *dir = lock_string(env, workingDirectory);
  const char *key = lock_string(env, privateKey);
  const char *mail = lock_string(env, email);
  const char *device = lock_string(env, deviceId);
  const char *org = lock_string(env, orgId);
  const char *data = lock_string(env, userData);
  const char *asp = lock_string(env, aspId);
  const char *res = lock_string(env, resId);
  const char *name = lock_string(env, cluster);
  const char *code = lock_string(env, otp);
  char *json = nhp_agent_register((char *)dir, logLevel, (char *)key, cipher, (char *)mail, (char *)device, (char *)org, (char *)data, (char *)asp, (char *)res, (char *)name, (char *)code);
  unlock_string(env, workingDirectory, dir);
  unlock_string(env, privateKey, key);
  unlock_string(env, email, mail);
  unlock_string(env, deviceId, device);
  unlock_string(env, orgId, org);
  unlock_string(env, userData, data);
  unlock_string(env, aspId, asp);
  unlock_string(env, resId, res);
  unlock_string(env, cluster, name);
  unlock_string(env, otp, code);
  return adopt_cstring(env, json);
}

JNIEXPORT jstring JNICALL Java_com_reactnativeopennhp_NhpAgent_takeGeneratedKey(
    JNIEnv *env, jclass clazz) {
  (void)clazz;
  return adopt_cstring(env, nhp_agent_take_generated_key());
}
