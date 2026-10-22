require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-opennhp"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = "OpenNHP"
  s.platforms    = { :ios => "15.1" }
  s.source       = { :git => "https://github.com/OpenNHP/opennhp.git", :tag => "main" }
  s.source_files = "ios/OpenNhp.h", "ios/OpenNhp.m"
  s.vendored_frameworks = "ios/Frameworks/nhpagent.xcframework"
  s.dependency "React-Core"
  s.frameworks = "Foundation", "CoreFoundation", "Security"
  s.libraries = "resolv", "c++"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "CLANG_ENABLE_MODULES" => "YES",
    "IPHONEOS_DEPLOYMENT_TARGET" => "15.1"
  }
end
