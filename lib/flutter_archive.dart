// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Utility class for zipping and unzipping ZIP archive files.
class FlutterArchive {
  static const MethodChannel _channel = MethodChannel('flutter_archive');

  /// Compress and save all files in [sourceDir] to [zipFile]. Recurse
  /// subdirectories if [recurseSubDirs] is true.
  static Future<void> zipDirectory(
      Directory sourceDir, File zipFile, bool recurseSubDirs) async {
    await _channel.invokeMethod('zipDirectory', <String, dynamic>{
      'sourceDir': sourceDir.path,
      'zipFile': zipFile.path,
      'recurseSubDirs': recurseSubDirs
    });
  }

  /// Compress given list of [files] and save the resulted archive to [zipFile].
  /// [sourceDir] is the root directory of [files] (all [files] must reside
  /// under the [sourceDir]).
  static Future<void> zipFiles(
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
    await _channel.invokeMethod('zipFiles', <String, dynamic>{
      'sourceDir': sourceDir.path,
      'files': relativeFilePaths,
      'zipFile': zipFile.path,
    });
  }

  /// Uncompress [zipFile] to a given [destinationDir].
  static Future<void> unzip(File zipFile, Directory destinationDir) async {
    await _channel.invokeMethod('unzip', <String, dynamic>{
      'zipFile': zipFile.path,
      'destinationDir': destinationDir.path
    });
  }
}
