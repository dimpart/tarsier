# Tarsier

[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/dimgame/tarsier/master/LICENSE)
[![Version](https://img.shields.io/badge/alpha-1.0.0-red.svg)](https://github.com/dimgame/tarsier/archive/master.zip)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dimgame/tarsier/pulls)
[![Platform](https://img.shields.io/badge/Platform-Flutter%203-brightgreen.svg)](https://github.com/dimgame/tarsier/wiki)
[![GitHub Issues](https://img.shields.io/github/issues/dimgame/tarsier.svg)](https://github.com/dimgame/tarsier/issues)
[![GitHub Forks](https://img.shields.io/github/forks/dimgame/tarsier.svg)](https://github.com/dimgame/tarsier/network)
[![GitHub Stars](https://img.shields.io/github/stars/dimgame/tarsier.svg)](https://github.com/dimgame/tarsier/stargazers)

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
mkdir dimgame; cd dimgame/
git clone https://github.com/dimgame/tarsier.git
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

2.2. Try to build iOS in **Android Studio**, this step will install pods and init project configs;

2.3. Open ```tarsier/ios/Runner.xcworkspace``` by Xcode, check general & signing info;

2.4. Open ```TARGETS -> Runner -> Build Settings``` in Xcode

A) search "rpath", check ```Runpath Search Paths```, make sure "/usr/lib/swift" exists:

```
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					/usr/lib/swift,
					"@executable_path/Frameworks",
				);
```

B) search "Linker", check ```Other Linker Flags```, make sure the flag "-lc++" exists:

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


Copyright &copy; 2023 Albert Moky
