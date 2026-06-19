## 6.3.0

- [iOS] Raised declared deployment target to 13.0 to match the minimum already required by Flutter 3.44+
- [macOS] Raised declared deployment target to 10.15 to match Flutter's current minimum
- [Android] Bumped Kotlin to 2.3.20, raised minSdk to 24, and modernized the `lint`/test configuration
- [Example] Migrated the Android example to Kotlin DSL + AGP 9 / built-in Kotlin

## 6.2.0

- [iOS][macOS] Added Swift Package Manager (SPM) support alongside existing CocoaPods support. Thanks to [@olekeke999](https://github.com/olekeke999)!
- [iOS][macOS] Unified the iOS and macOS implementations into a single shared `darwin` package.
- [Example] Migrated the iOS and macOS example apps to Swift Package Manager.

## 6.1.0
- Updates minimum supported SDK version to Flutter 3.44 / Dart 3.12
- [Android] Migrates to built-in Kotlin (applies the Kotlin Gradle Plugin only on AGP < 9)

## 6.0.4
- [Android] Updated compileSdkVersion to 36, Gradle to 8.14 and Java/Kotlin compatibility to version 17

## 6.0.3
- [iOS] Fixed build issue #78

## 6.0.2
- [iOS] Upgraded to ZIPFoundation 0.9.19

## 6.0.1
- [iOS] Upgraded to ZIPFoundation 0.9.18 (thanks to AliakseiT)

## 6.0.0
- [Andfroid] Fix AGP 8.0 compile error
- [Andfroid] Updated gradle version 7.3.1 and Kotlin version 1.7.10
- [Andfroid] Set compileSdkVersion to 33

## 5.0.0

- [iOS] BRAKING CHANGE: minimum iOS version is now iOS 12.0 
- [iOS] Upgraded to ZIPFoundation 0.9.13 (thanks to daniel-possienke)

## 4.2.2

- [iOS] fixed: progress never 100% (thanks to Lan-tb)
- [iOS] added charset support (thanks to Lan-tb)

## 4.2.1

- [Android] Fixed build issue related to Result.error
- fixed sdk constraints

## 4.2.0

- [Android] Fixed #25: added parameter zipFileCharset to ZipFile.extractToDirectory for defining the charset to use

## 4.1.1

- Fixed #43

## 4.1.0

- fixed: skipping file in ZipFile.extractToDirectory did not work
- [Android] updated to Kotlin 1.5.30
- [Android] upgraded gradle
- [Android] jcenter => mavenCentral
- [Android] set compileSdkVersion to 31
- [Android] Removed V1 embedding
- [Android] Fixed warning "inappropriate blocking method call"
- [iOS] updated podspec (added s.swift_version etc.)

## 4.0.1

[iOS] ZipFile.createFromDirectory: fixed issues with file paths

## 4.0.0

- ZipFile.createFromDirectory: added a new parameter onZipping for progress reporting and to allow filtering files to be included in the zip (#30)
- BREAKING CHANGE: replaced enum ExtractOperation with ZipFileOperation
- [iOS] fixed: recurseSubDirs parameter in ZipFile.createFromDirectory was ignored
- [Android] Updated compileSdkVersion and targetSdkVersion to 30

## 3.0.0

- null safety

## 2.0.2

- Fixed minor lint issues
- Experimental fix to #26 (publish plugin from Mac)

## 2.0.1

- Added support for iOS 9

## 2.0.0

- Added support for macOS (thanks for the PR to [tonycn](https://github.com/tonycn))

## 1.0.3

- Fixed #13: Extracting multiple zip files in parallel does not work when using onExtracting callback

## 1.0.2

- [Android] Fixed: java.lang.ClassCastException: java.util.zip.ZipFile
  cannot be cast to java.io.Closeable occurring if API level < 19

## 1.0.1

- Fixed "MissingPluginException"

## 1.0.0

- Renamed FlutterArchive as ZipFile, renamed also methods
- Support for progress reporting in unzip (ZipFile.extractToDirectory)
- Added support for including base directory name to file paths
- [iOS] Upgraded to ZIPFoundation 0.9.11

## 0.1.4

- [Android] Fixed: unzipping some files could fail to "java.util.zip.ZipException: invalid stored block lengths"
- [Android] Fixed: any thrown exception during zip/unzip caused crash

## 0.1.3

- [Android] Improved error handling.

## 0.1.2

- [iOS] Zip/unzip files in a background thread to keep UI more responsive.

## 0.1.1+1

- Minor cleanup.

## 0.1.1

- Added support for Android V2 embedding.

## 0.1.0

- Updated public API.
- Improved documentation.
- Added code samples.

## 0.0.2

- Documented public APIs and updated README.md.

## 0.0.1

- Initial release.
