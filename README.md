# Tarsier - Secure Chat

[![License](https://img.shields.io/github/license/dimpart/tarsier)](https://raw.githubusercontent.com/dimpart/tarsier/master/LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dimpart/tarsier/pulls)
[![Platform](https://img.shields.io/badge/Platform-Flutter%203-brightgreen.svg)](https://github.com/dimpart/tarsier/wiki)
[![Issues](https://img.shields.io/github/issues/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/issues)
[![Repo Size](https://img.shields.io/github/repo-size/dimpart/tarsier)](https://github.com/dimpart/tarsier/archive/refs/heads/main.zip)
[![Tags](https://img.shields.io/github/tag/dimpart/tarsier)](https://github.com/dimpart/tarsier/tags)

[![Watchers](https://img.shields.io/github/watchers/dimpart/tarsier)](https://github.com/dimpart/tarsier/watchers)
[![Forks](https://img.shields.io/github/forks/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/network)
[![Stars](https://img.shields.io/github/stars/dimpart/tarsier.svg)](https://github.com/dimpart/tarsier/stargazers)
[![Followers](https://img.shields.io/github/followers/dimpart)](https://github.com/orgs/dimpart/followers)

Secure chat application, powered by [DIM-Flutter](https://github.com/dimpart/demo-flutter).

## Getting started

### 0. Download source codes and requirements

```
cd ~/Documents/
mkdir github.com; cd github.com/
mkdir dimpart; cd dimpart/

# requirements
git clone https://github.com/dimpart/demo-flutter.git
git clone https://github.com/dimpart/tarsier.git
```

### 1. Test Android

Just open ```tarsier``` project by **Android Studio** and run it in a simulator.

### 2. Test iOS

After android peoject run, the **Android Studio** will also generate Podfile for iOS too.

2.1. Edit ```dimpart/tarsier/ios/Podfile```, add permissions setting:

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

2.2. Open ```dimpart/tarsier/ios/Runner.xcworkspace``` by Xcode

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

### 3. Test Windows

3.1. Edit ```dimpart/demo-flutter/dim_flutter/pubspec.yaml```

```
dependencies:

  ...

  sqflite: ^2.2.6
  sqflite_common_ffi: ^2.3.3
#  sqflite_common_ffi_web: ^0.4.2

  fvp: ^0.16.1
  video_player: ^2.8.3
  chewie: ^1.8.1
  castscreen: ^1.0.2
```

3.2. Edit ```dimpart/demo-flutter/dim_flutter/lib/src/common/platform.dart```

```
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:fvp/fvp.dart';

import 'package:lnc/log.dart';

class DevicePlatform {

  ...

  /// patch for SQLite
  static void patchSQLite() {
    if (_sqlitePatched) {
      return;
    }
    if (isWeb) {
      // TODO: open for Web
      // // Change default factory on the web
      // databaseFactory = databaseFactoryFfiWeb;
    } else if (isWindows || isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    }
    _sqlitePatched = true;
  }
  static bool _sqlitePatched = false;

  /// patch for Video Player
  static void patchVideoPlayer() {
    if (_videoPlayerPatched) {
      return;
    }
    if (isAndroid || isIOS || isMacOS || isWeb) {
      // Video Player support:
      // - Android SDK 16+
      // - iOS 12.0+
      // - macOS 10.14+
      // - Web Any*
    } else {
      // - Windows
      // - Linux
      // ...
      Log.info('register video player for Windows, Linux, ...');
      registerWith();
    }
    _videoPlayerPatched = true;
  }
  static bool _videoPlayerPatched = false;

}
```

If nothing unexpected happens, your desktop app should be able to run now!

----
Copyright &copy; 2024 Albert Moky
