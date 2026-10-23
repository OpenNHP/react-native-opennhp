const { NativeModules } = require("react-native");

const native = NativeModules.OpenNhp;

const LogLevel = {
  SILENT: 0,
  ERROR: 1,
  INFO: 2,
  DEBUG: 3,
  VERBOSE: 4,
};

const Cipher = {
  CURVE25519: 0,
  SM2: 1,
};

const DEFAULT_SERVER_PORT = 62206;

function getNative() {
  if (native == null) {
    throw new Error(
      "react-native-opennhp is not linked. Install the package, run pod install on iOS, then rebuild the app."
    );
  }
  return native;
}

function asString(value) {
  if (value == null) {
    return "";
  }
  return String(value);
}

function userDataString(userData) {
  if (userData == null || userData === "") {
    return "";
  }
  if (typeof userData === "string") {
    return userData;
  }
  return JSON.stringify(userData);
}

function initializeAgent(workingDirectory, logLevel = LogLevel.INFO) {
  if (typeof workingDirectory !== "string" || workingDirectory.length === 0) {
    return Promise.reject(
      new Error("workingDirectory must be a writable path containing etc/config.toml")
    );
  }
  return getNative().initializeAgent(workingDirectory, logLevel | 0);
}

function close() {
  return getNative().close();
}

function startKnockLoop() {
  return getNative().startKnockLoop();
}

function stopKnockLoop() {
  return getNative().stopKnockLoop();
}

function setKnockUser(user = {}) {
  return getNative().setKnockUser(
    asString(user.userId),
    asString(user.deviceId),
    asString(user.orgId),
    userDataString(user.userData)
  );
}

function addServer(server) {
  if (server == null || asString(server.pubkey).length === 0) {
    return Promise.reject(new Error("addServer requires a server public key"));
  }
  return getNative().addServer(
    asString(server.pubkey),
    asString(server.ip),
    asString(server.host),
    server.port == null ? 0 : server.port | 0,
    server.expire == null ? 0 : Number(server.expire)
  );
}

function removeServer(pubkey) {
  return getNative().removeServer(asString(pubkey));
}

function addResource(aspId, resId, cluster) {
  return getNative().addResource(asString(aspId), asString(resId), asString(cluster));
}

function removeResource(aspId, resId) {
  return getNative().removeResource(asString(aspId), asString(resId));
}

function knockResource(aspId, resId, cluster) {
  return getNative()
    .knockResource(asString(aspId), asString(resId), asString(cluster))
    .then((json) => {
      try {
        return JSON.parse(json);
      } catch (error) {
        return {
          errCode: -1,
          errMsg: "OpenNHP returned a knock response that was not JSON",
          raw: json,
        };
      }
    });
}

function exitResource(aspId, resId, cluster) {
  return getNative().exitResource(asString(aspId), asString(resId), asString(cluster));
}

function generateKeys(cipher = Cipher.CURVE25519) {
  return getNative().generateKeys(cipher | 0).then((raw) => {
    const separator = raw.indexOf("|");
    if (separator <= 0 || separator === raw.length - 1) {
      throw new Error("OpenNHP generateKeys returned an unexpected value");
    }
    return {
      privateKey: raw.slice(0, separator),
      publicKey: raw.slice(separator + 1),
    };
  });
}

function privateKeyToPublicKey(privateKey, cipher = Cipher.CURVE25519) {
  return getNative().privateKeyToPublicKey(cipher | 0, asString(privateKey));
}

function parseSdkJson(json, fallbackMessage) {
  try {
    return JSON.parse(json);
  } catch (error) {
    return {
      errCode: "-1",
      errMsg: fallbackMessage,
      raw: json,
    };
  }
}

function registrationFields(options = {}) {
  return [
    asString(options.workingDirectory),
    options.logLevel == null ? LogLevel.INFO : options.logLevel | 0,
    asString(options.privateKey),
    options.cipher == null ? Cipher.CURVE25519 : options.cipher | 0,
    asString(options.email),
    asString(options.deviceId),
    asString(options.orgId),
    userDataString(options.userData),
    asString(options.aspId),
    asString(options.resId),
    asString(options.cluster),
  ];
}

function requestRegistrationOtp(options = {}) {
  if (!options || asString(options.email).length === 0) {
    return Promise.reject(new Error("requestRegistrationOtp requires an email address"));
  }
  return getNative()
    .requestRegistrationOtp(...registrationFields(options))
    .then((json) => parseSdkJson(json, "OpenNHP returned an OTP response that was not JSON"));
}

function registerDevice(options = {}) {
  if (!options || asString(options.otp).length === 0) {
    return Promise.reject(new Error("registerDevice requires the one-time password"));
  }
  if (asString(options.privateKey).length === 0) {
    return Promise.reject(new Error("registerDevice requires the privateKey returned by requestRegistrationOtp"));
  }
  return getNative()
    .registerDevice(...registrationFields(options), asString(options.otp))
    .then((json) => parseSdkJson(json, "OpenNHP returned a registration response that was not JSON"));
}

function getDefaultWorkingDirectory() {
  const directory = getNative().defaultWorkingDirectory;
  if (typeof directory !== "string" || directory.length === 0) {
    throw new Error("OpenNHP did not provide a default working directory");
  }
  return directory;
}

module.exports = {
  LogLevel,
  Cipher,
  DEFAULT_SERVER_PORT,
  getDefaultWorkingDirectory,
  initializeAgent,
  close,
  startKnockLoop,
  stopKnockLoop,
  setKnockUser,
  addServer,
  removeServer,
  addResource,
  removeResource,
  knockResource,
  exitResource,
  generateKeys,
  privateKeyToPublicKey,
  requestRegistrationOtp,
  registerDevice,
};
