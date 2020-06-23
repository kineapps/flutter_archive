# flutter_archive

Create and extract ZIP archive files. Uses Android/iOS platform APIs for high performance and optimal memory usage.

## Features

- Supports Android and iOS.
- Modern plugin implementation based on Kotlin (Android) and Swift (iOS).
- Uses background processing to keep UI responsive.
- Zip all files in a directory (optionally recursively).
- Zip a given list of files.
- Unzip an archive file to a given directory.
- Progress reporting while extracting an archive. Get details of zip entries being extracted and allow skip extracting a zip entry.

## Examples

### Create a zip file from a directory

```dart
  final dataDir = Directory("data_dir_path");
  try {
    final zipFile = File("zip_file_path");
    ZipFile.createFromDirectory(
        sourceDir: dataDir, zipFile: zipFile, recurseSubDirs: true);
  } catch (e) {
    print(e);
  }
```

### Create a zip file from a given list of files.

```dart
  final sourceDir = Directory("source_dir");
  final files = [
    File(sourceDir.path + "file1"),
    File(sourceDir.path + "file2")
  ];
  final zipFile = File("zip_file_path");
  try {
    ZipFile.createFromFiles(
        sourceDir: sourceDir, files: files, zipFile: zipFile);
  } catch (e) {
    print(e);
  }
```

### Extract a ZIP archive

```dart
  final zipFile = File("zip_file_path");
  final destinationDir = Directory("destination_dir_path");
  try {
    ZipFile.extractToDirectory(zipFile: zipFile, destinationDir: destinationDir);
  } catch (e) {
    print(e);
  }
```

### Get progress info while extracting a zip archive.

```dart
  final zipFile = File("zip_file_path");
  final destinationDir = Directory("destination_dir_path");
  try {
    await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: destinationDir,
        onExtracting: (zipEntry, progress) {
          print('progress: ${progress.toStringAsFixed(1)}%');
          print('name: ${zipEntry.name}');
          print('isDirectory: ${zipEntry.isDirectory}');
          print(
              'modificationDate: ${zipEntry.modificationDate.toLocal().toIso8601String()}');
          print('uncompressedSize: ${zipEntry.uncompressedSize}');
          print('compressedSize: ${zipEntry.compressedSize}');
          print('compressionMethod: ${zipEntry.compressionMethod}');
          print('crc: ${zipEntry.crc}');
          return ExtractOperation.extract;
        });
  } catch (e) {
    print(e);
  }
```
