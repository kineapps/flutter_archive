// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlutterArchive {
  static const MethodChannel _channel = MethodChannel('flutter_archive');

  static Future<bool> zip(
      Directory sourceDir, File zipFile, bool recurseSubDirs) async {
    final bool success = await _channel.invokeMethod('zip', <String, dynamic>{
      'sourceDir': sourceDir.path,
      'zipFile': zipFile.path,
      'recurseSubDirs': recurseSubDirs
    });
    return success;
  }

  static Future<bool> zipFiles(
      {@required Directory sourceDir,
      @required List<File> files,
      @required File zipFile}) async {
    var sourceDirPath = sourceDir.path;
    if (!sourceDirPath.endsWith(Platform.pathSeparator)) {
      sourceDirPath += Platform.pathSeparator;
    }
    final sourceDirPathLen = sourceDirPath.length;

    final relativeFilePaths = <String>[];
    files.forEach((f) {
      if (!f.path.startsWith(sourceDirPath)) {
        throw Exception('Files must reside under the rootDir');
      }
      final relativeFilePath = f.path.substring(sourceDirPathLen);
      assert(!relativeFilePath.startsWith(Platform.pathSeparator));
      relativeFilePaths.add(relativeFilePath);
    });
    final bool success =
        await _channel.invokeMethod('zipFiles', <String, dynamic>{
      'sourceDir': sourceDir.path,
      'files': relativeFilePaths,
      'zipFile': zipFile.path,
    });
    return success;
  }

  static Future<bool> unzip(File zipFile, Directory destinationDir) async {
    final bool success = await _channel.invokeMethod('unzip', <String, dynamic>{
      'zipFile': zipFile.path,
      'destinationDir': destinationDir.path
    });
    return success;
  }
}
