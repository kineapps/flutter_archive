import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin test app'),
        ),
        body: Center(
          child: RaisedButton(
            child: Text("Test"),
            onPressed: () => _test(),
          ),
        ),
      ),
    );
  }

  final _appDataDir = Directory.systemTemp;

  static const _dataFilesBaseDirectoryName = "store";
  final _dataFiles = {
    "file1.txt": r"abc",
    "file2.txt": r"åäö",
    "subdir1/file3.txt": r"@_£$",
    "subdir1/subdir11/file4.txt": r"123",
  };

  Future _test() async {
    print("Start test");
    // test createFromDirectory
    // case 1
    var zipFile = await _testZip(includeBaseDirectory: false);
    await _testUnzip(zipFile, zipIncludesBaseDirectory: false);
    await _testUnzip(zipFile, progress: true);
    // case 2
    zipFile = await _testZip(includeBaseDirectory: true);
    await _testUnzip(zipFile, zipIncludesBaseDirectory: true);

    // test createFromFiles
    // case 1
    zipFile = await _testZipFiles(includeBaseDirectory: false);
    await _testUnzip(zipFile, zipIncludesBaseDirectory: false);
    // case 2
    zipFile = await _testZipFiles(includeBaseDirectory: true);
    await _testUnzip(zipFile, zipIncludesBaseDirectory: true);
    print("DONE!");
  }

  Future<File> _testZip({@required bool includeBaseDirectory}) async {
    print("_appDataDir=" + _appDataDir.path);
    final storeDir =
        Directory(_appDataDir.path + "/$_dataFilesBaseDirectoryName");

    _createTestFiles(storeDir);

    final zipFile = _createZipFile("testZip.zip");
    print("Writing to zip file: " + zipFile.path);

    try {
      await ZipFile.createFromDirectory(
          sourceDir: storeDir,
          zipFile: zipFile,
          recurseSubDirs: true,
          includeBaseDirectory: includeBaseDirectory);
    } on PlatformException catch (e) {
      print(e);
    }
    return zipFile;
  }

  Future<File> _testZipFiles({@required bool includeBaseDirectory}) async {
    print("_appDataDir=" + _appDataDir.path);
    final storeDir =
        Directory(_appDataDir.path + "/$_dataFilesBaseDirectoryName");

    final testFiles = _createTestFiles(storeDir);

    final zipFile = _createZipFile("testZipFiles.zip");
    print("Writing files to zip file: " + zipFile.path);

    try {
      await ZipFile.createFromFiles(
          sourceDir: storeDir,
          files: testFiles,
          zipFile: zipFile,
          includeBaseDirectory: includeBaseDirectory);
    } on PlatformException catch (e) {
      print(e);
    }
    return zipFile;
  }

  Future _testUnzip(File zipFile,
      {bool progress = false, bool zipIncludesBaseDirectory = false}) async {
    print("_appDataDir=" + _appDataDir.path);

    final destinationDir = Directory(_appDataDir.path + "/unzip");
    final destinationDir2 = Directory(_appDataDir.path + "/unzip2");

    if (destinationDir.existsSync()) {
      print("Deleting existing unzip directory: " + destinationDir.path);
      destinationDir.deleteSync(recursive: true);
    }
    if (destinationDir2.existsSync()) {
      print("Deleting existing unzip directory: " + destinationDir2.path);
      destinationDir2.deleteSync(recursive: true);
    }

    print("Extracting zip to directory: " + destinationDir.path);
    destinationDir.createSync();
    // test concurrent extraction
    final extractFutures = <Future>[];
    int onExtractingCallCount1 = 0;
    int onExtractingCallCount2 = 0;
    try {
      extractFutures.add(ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir,
          onExtracting: progress
              ? (zipEntry, progress) {
                  ++onExtractingCallCount1;
                  print('Extract #1:');
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
                }
              : null));

      extractFutures.add(ZipFile.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir2,
          onExtracting: progress
              ? (zipEntry, progress) {
                  ++onExtractingCallCount2;
                  print('Extract #2:');
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
                }
              : null));

      await Future.wait(extractFutures);
      assert(onExtractingCallCount1 == onExtractingCallCount2);
      assert(!progress || onExtractingCallCount1 > 0);
    } on PlatformException catch (e) {
      print(e);
    }

    // verify unzipped files
    if (zipIncludesBaseDirectory) {
      _verifyFiles(
          Directory(destinationDir.path + "/" + _dataFilesBaseDirectoryName));
      _verifyFiles(
          Directory(destinationDir2.path + "/" + _dataFilesBaseDirectoryName));
    } else {
      _verifyFiles(destinationDir);
      _verifyFiles(destinationDir2);
    }
  }

  File _createZipFile(String fileName) {
    final zipFilePath = _appDataDir.path + "/" + fileName;
    final zipFile = File(zipFilePath);

    if (zipFile.existsSync()) {
      print("Deleting existing zip file: " + zipFile.path);
      zipFile.deleteSync();
    }
    return zipFile;
  }

  List<File> _createTestFiles(Directory storeDir) {
    if (storeDir.existsSync()) {
      storeDir.deleteSync(recursive: true);
    }
    storeDir.createSync();
    final files = <File>[];
    for (final fileName in _dataFiles.keys) {
      final file = File(storeDir.path + "/" + fileName);
      file.createSync(recursive: true);
      print("Writing file: " + file.path);
      file.writeAsStringSync(_dataFiles[fileName]);
      files.add(file);
    }

    // verify created files
    _verifyFiles(storeDir);

    return files;
  }

  void _verifyFiles(Directory filesDir) {
    print("Verifying files at: ${filesDir.path}");
    final extractedItems = filesDir.listSync(recursive: true);
    print("File count: ${extractedItems.length}");
    assert(extractedItems.whereType<File>().length == _dataFiles.length,
        "Invalid number of files");
    for (final fileName in _dataFiles.keys) {
      final file = File('${filesDir.path}/$fileName');
      print("Verifying file: " + file.path);
      assert(file.existsSync(), "File not found: " + file.path);
      final content = file.readAsStringSync();
      assert(content == _dataFiles[fileName],
          "Invalid file content: " + file.path);
    }
    print("All files ok");
  }
}
