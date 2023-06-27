# Tarsier

[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/dimpart/tarsier/master/LICENSE)
[![Version](https://img.shields.io/badge/alpha-1.0.0-red.svg)](https://github.com/dimpart/tarsier/archive/master.zip)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dimpart/tarsier/pulls)
[![Platform](https://img.shields.io/badge/Platform-Flutter%203-brightgreen.svg)](https://github.com/dimpart/tarsier/wiki)
[![GitHub Issues](https://img.shields.io/github/issues/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/issues)
[![GitHub Forks](https://img.shields.io/github/forks/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/network)
[![GitHub Stars](https://img.shields.io/github/stars/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/stargazers)

Secure chat application, powered by [DIM-Flutter](https://github.com/dimchat/demo-flutter).

## Getting started

### 0. Download source codes and requirements

```
cd ~/Documents/
mkdir github.com; cd github.com/

# requirements
mkdir moky; cd moky/
git clone https://github.com/moky/StarGate.git
cd ..
mkdir dimchat; cd dimchat/
git clone https://github.com/dimchat/demo-flutter.git
cd ..

# project source codes
mkdir dimpart; cd dimpart/
git clone https://github.com/dimpart/tarsier.git
```

### 1. Test Android

Just open ```tarsier``` project by **Android Studio** and run it in a simulator.

### 2. Test iOS

After android peoject run, the **Android Studio** will also generate Podfile for iOS too.

2.1. Edit ```tarsier/ios/Podfile```, add permissions setting:

```
platform :ios, '12.0'

...

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
      '$(inherited)',
      # dart: PermissionGroup.camera
      'PERMISSION_CAMERA=1',
      # dart: PermissionGroup. photos
      'PERMISSION_PHOTOS=1',
      'PERMISSION_PHOTOS_ADD_ONLY=1',
      # dart: PermissionGroup.microphone
      'PERMISSION_MICROPHONE=1',
      ]
    end 
    
  end
end
```
then try to build iOS in **Android Studio** (click menu ```Build -> Flutter -> Build iOS```), this step will install pods and initialize project configs;

2.2. Open ```tarsier/ios/Runner.xcworkspace``` by Xcode

A) Set your team in ```TARGETS -> Runner -> Signing & Capabilities```;

B) If error occurred while launching:

```
dyld[48747]: Library not loaded: @rpath/libswiftCore.dylib
  Referenced from: <XXXX-YYYY> /Users/..../Runner.app/Runner
  Reason: tried: '/Users/..../libswiftCore.dylib' (no such file),
    '/Applications/..../libswiftCore.dylib' (no such file),
    ...
```

click ```TARGETS -> Runner -> Build Settings``` in Xcode, search "rpath", check ```Runpath Search Paths```, make sure "/usr/lib/swift" exists:

```
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					/usr/lib/swift,
					"@executable_path/Frameworks",
				);
```

C) If error occurred with C++, search "Linker", check ```Other Linker Flags```, make sure the flag "-lc++" exists:

```
				OTHER_LDFLAGS = (
					"$(inherited)",
					"-ObjC",
					"-lc++",
					"-l\"DIMClient\"",
					"-l\"DIMCore\"",
					"-l\"DIMPlugins\"",
					"-l\"DIMSDK\"",
					"-l\"DaoKeDao\"",
					"-l\"FMDB\"",
					"-l\"FiniteStateMachine\"",
					"-l\"Mantle\"",
					"-l\"MingKeMing\"",
					"-l\"ObjectKey\"",
					"-l\"OrderedSet\"",
					"-l\"SDWebImage\"",
					"-l\"SDWebImageWebPCoder\"",
					"-l\"StarTrek\"",
					"-l\"device_info_plus\"",
					"-l\"dim_flutter\"",
					"-l\"flutter_image_compress\"",
					"-l\"flutter_inappwebview\"",
					"-l\"image_picker_ios\"",
					"-l\"libwebp\"",
					"-l\"package_info_plus\"",
					"-l\"permission_handler_apple\"",
					"-l\"sqflite\"",
					"-l\"sqlite3\"",
					"-framework",
					"\"Foundation\"",
					"-framework",
					"\"ImageIO\"",
					"-framework",
					"\"Security\"",
				);
```

If nothing unexpected happens, your iOS app should be able to run now!


----
Copyright &copy; 2023 Albert Moky
