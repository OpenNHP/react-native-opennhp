# iOS and Android setup

The package is autolinked. After `npm install` and an iOS `pod install`, rebuild the native app. A Metro reload is not enough, because the OpenNHP libraries are native binaries.

## React Native and Expo

Works in apps that compile their own native projects (the React Native CLI, or Expo with `expo prebuild` / a development build).

Expo Go does not include this module. Add the package, run `npx expo prebuild`, then `npx expo run:ios` and `npx expo run:android`.

The module is a classic React Native native module (`NativeModules.OpenNhp`). Current React Native releases load that style of module through the New Architecture interop layer.

## iOS

- Deployment target 15.1 or newer. The podspec sets this on the pod. Set the app target to 15.1 or newer as well.
- `cd ios && pod install` after every install or upgrade of this package.
- The pod vendors `ios/Frameworks/nhpagent.xcframework` (device `arm64`, simulator `arm64` and `x86_64`).
- Linked system libraries: Foundation, CoreFoundation, Security, `libresolv`, and `libc++`.

Local-network knocks need an app `Info.plist` entry:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app contacts the local OpenNHP server.</string>
```

Outbound UDP to a public host does not need that key. There is no extra background mode. Knocks run while the app process is alive. `close` when the user is done, because iOS can suspend the process.

## Android

- `minSdkVersion` 24 or newer. The `.so` files themselves are built with Android API 21.
- Java 17 for the library module.
- ABIs packaged: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`. Restrict the app's `abiFilters` to a subset of these. An ABI outside this list fails the native build.
- `android.permission.INTERNET` is merged from this package. No storage permission is required when the working directory is `getDefaultWorkingDirectory()` (the app files directory).
- `arm64-v8a` libraries are aligned for 16 KB memory pages.

The emulator's `10.0.2.2` is the host machine. `127.0.0.1` is the emulator itself. A physical device needs the server's LAN or public address, and the network must allow UDP to the nhp-server port.

## Manual linking

Autolinking covers React Native 0.60 and newer. In an older app:

**iOS.** Add `react-native-opennhp.podspec` as a pod and run `pod install`.

**Android.** Add the package project in `android/settings.gradle` and register `com.reactnativeopennhp.OpenNhpPackage` in the host `MainApplication`.

## Upgrading the package

Install the new version, run `pod install`, then clean-build both apps. The native binary changes even when the JavaScript API does not.
