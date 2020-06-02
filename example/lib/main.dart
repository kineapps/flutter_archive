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

  final _dataFiles = {
    "file1.txt": r"abc",
    "file2.txt": r"åäö",
    "subdir1/file3.txt": r"@_£$",
    "subdir1/subdir11/file4.txt": r"123",
  };

  Future _test() async {
    print("Start test");
    var zipFile = await _testZip();
    await _testUnzip(zipFile);
    await _testUnzip(zipFile, progress: true);
    zipFile = await _testZipFiles();
    await _testUnzip(zipFile);
    print("DONE!");
  }

  Future<File> _testZip() async {
    print("_appDataDir=" + _appDataDir.path);
    final storeDir = Directory(_appDataDir.path + "/store");

    _createTestFiles(storeDir);

    final zipFile = _createZipFile("testZip.zip");
    print("Writing to zip file: " + zipFile.path);

    try {
      await FlutterArchive.zipDirectory(
          sourceDir: storeDir, zipFile: zipFile, recurseSubDirs: true);
    } on PlatformException catch (e) {
      print(e);
    }
    return zipFile;
  }

  Future<File> _testZipFiles() async {
    print("_appDataDir=" + _appDataDir.path);
    final storeDir = Directory(_appDataDir.path + "/store");

    final testFiles = _createTestFiles(storeDir);

    final zipFile = _createZipFile("testZipFiles.zip");
    print("Writing files to zip file: " + zipFile.path);

    try {
      await FlutterArchive.zipFiles(
          sourceDir: storeDir, files: testFiles, zipFile: zipFile);
    } on PlatformException catch (e) {
      print(e);
    }
    return zipFile;
  }

  Future _testUnzip(File zipFile, {bool progress = false}) async {
    print("_appDataDir=" + _appDataDir.path);

    final destinationDir = Directory(_appDataDir.path + "/unzip");
    if (destinationDir.existsSync()) {
      print("Deleting existing unzip directory: " + destinationDir.path);
      destinationDir.deleteSync(recursive: true);
    }

    print("Extracting zip to directory: " + destinationDir.path);
    destinationDir.createSync();
    try {
      await FlutterArchive.unzip(
          zipFile: zipFile,
          destinationDir: destinationDir,
          onUnzipProgress: progress
              ? (zipEntry, progress) {
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
              : null);
    } on PlatformException catch (e) {
      print(e);
    }

    // verify unzipped files
    _verifyFiles(destinationDir);
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
      final file = File(filesDir.path + "/" + fileName);
      print("Verifying file: " + file.path);
      assert(file.existsSync(), "File not found: " + file.path);
      final content = file.readAsStringSync();
      assert(content == _dataFiles[fileName],
          "Invalid file content: " + file.path);
    }
    print("All files ok");
  }
}
