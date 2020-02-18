# flutter_archive

Create and extract ZIP archive files. Uses Android/iOS platform APIs for high performance and optimal memory usage.

## Features

- Supports Android and iOS.
- Modern plugin implementation based on Kotlin (Android) and Swift (iOS).
- Zip all files in a directory (optionally recursively).
- Zip a given list of files.
- Unzip an archive file to a given directory.

## Examples

### Zip a directory

```dart
  final dataDir = Directory("data_dir_path");
  try {
    final zipFile = File("zip_file_path");
    FlutterArchive.zipDirectory(
        sourceDir: dataDir, zipFile: zipFile, recurseSubDirs: true);
  } catch (e) {
    print(e);
  }
```

### Zip files

```dart
  final sourceDir = Directory("source_dir");
  final files = [
    File(sourceDir.path + "file1"),
    File(sourceDir.path + "file2")
  ];
  final zipFile = File("zip_file_path");
  try {
    FlutterArchive.zipFiles(
        sourceDir: sourceDir, files: files, zipFile: zipFile);
  } catch (e) {
    print(e);
  }
```

### Unzip a ZIP archive

```dart
  final zipFile = File("zip_file_path");
  final destinationDir = Directory("destination_dir_path");
  try {
    FlutterArchive.unzip(zipFile: zipFile, destinationDir: destinationDir);
  } catch (e) {
    print(e);
  }
```
