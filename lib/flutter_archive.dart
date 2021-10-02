// Copyright (c) 2020 KineApps. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum ZipFileOperation { includeItem, skipItem, cancel }
typedef OnExtracting = ZipFileOperation Function(
    ZipEntry zipEntry, double progress);

typedef OnZipping = ZipFileOperation Function(
    String filePath, bool isDirectory, double progress);

String _progressOperationToString(ZipFileOperation extractOperation) {
  switch (extractOperation) {
    case ZipFileOperation.skipItem:
      return "skipItem";
    case ZipFileOperation.cancel:
      return "cancel";
    default:
      return "includeItem";
  }
}

/// Utility class for creating and extracting zip archive files.
class ZipFile {
  static const MethodChannel _channel = MethodChannel('flutter_archive');

  /// Compress and save all files in [sourceDir] to [zipFile].
  ///
  /// Set [includeBaseDirectory] to true to include the directory name from
  /// [sourceDir] at the root of the archive. Set [includeBaseDirectory] to
  /// false to include only the contents of the [sourceDir].
  ///
  /// By default zip all subdirectories recursively. Set [recurseSubDirs]
  /// to false to disable recursive zipping.
  ///
  /// Optional callback function [onZipping] is called before zipping a file
  /// or a directory. [onZipping] must return one of the following values:
  /// [ZipFileOperation.includeItem] - include this file/directory in zip
  /// [ZipFileOperation.skipItem] - exclude this file or directory from the zip
  /// [ZipFileOperation.cancel] - cancel the operation
  static Future<void> createFromDirectory(
      {required Directory sourceDir,
      required File zipFile,
      bool includeBaseDirectory = false,
      bool recurseSubDirs = true,
      OnZipping? onZipping}) async {
    final reportProgress = onZipping != null;
    if (reportProgress) {
      if (!_isMethodCallHandlerSet) {
        _channel.setMethodCallHandler(_channelMethodCallHandler);
        _isMethodCallHandlerSet = true;
      }
    }
    final jobId = ++_jobId;
    try {
      if (onZipping != null) {
        _onZippingHandlerByJobId[jobId] = onZipping;
      }

      await _channel.invokeMethod<void>('zipDirectory', <String, dynamic>{
        'sourceDir': sourceDir.path,
        'zipFile': zipFile.path,
        'recurseSubDirs': recurseSubDirs,
        'includeBaseDirectory': includeBaseDirectory,
        'reportProgress': reportProgress,
        'jobId': jobId,
      });
    } finally {
      _onZippingHandlerByJobId.remove(jobId);
    }
  }

  /// Compress given list of [files] and save the resulted archive to [zipFile].
  /// [sourceDir] is the root directory of [files] (all [files] must reside
  /// under the [sourceDir]).
  ///
  /// Set [includeBaseDirectory] to true to include the directory name from
  /// [sourceDir] at the root of the archive. Set [includeBaseDirectory] to
  /// false to include only the contents of the [sourceDir].
  static Future<void> createFromFiles({
    required Directory sourceDir,
    required List<File> files,
    required File zipFile,
    bool includeBaseDirectory = false,
  }) async {
    var sourceDirPath =
        includeBaseDirectory ? sourceDir.parent.path : sourceDir.path;
    if (!sourceDirPath.endsWith(Platform.pathSeparator)) {
      sourceDirPath += Platform.pathSeparator;
    }

    final sourceDirPathLen = sourceDirPath.length;

    final relativeFilePaths = <String>[];
    for (final f in files) {
      if (!f.path.startsWith(sourceDirPath)) {
        throw Exception('Files must reside under the rootDir');
      }
      final relativeFilePath = f.path.substring(sourceDirPathLen);
      assert(!relativeFilePath.startsWith(Platform.pathSeparator));
      relativeFilePaths.add(relativeFilePath);
    }
    await _channel.invokeMethod<void>('zipFiles', <String, dynamic>{
      'sourceDir': sourceDir.path,
      'files': relativeFilePaths,
      'zipFile': zipFile.path,
      'includeBaseDirectory': includeBaseDirectory
    });
  }

  /// Extract [zipFile] to a given [destinationDir]. Optional callback function
  /// [onExtracting] is called before extracting a zip entry.
  ///
  /// [onExtracting] must return one of the following values:
  /// [ZipFileOperation.includeItem] - extract this file/directory
  /// [ZipFileOperation.skipItem] - do not extract this file/directory
  /// [ZipFileOperation.cancel] - cancel the operation
  static Future<void> extractToDirectory(
      {required File zipFile,
      required Directory destinationDir,
      OnExtracting? onExtracting}) async {
    final reportProgress = onExtracting != null;
    if (reportProgress) {
      if (!_isMethodCallHandlerSet) {
        _channel.setMethodCallHandler(_channelMethodCallHandler);
        _isMethodCallHandlerSet = true;
      }
    }
    final jobId = ++_jobId;
    try {
      if (onExtracting != null) {
        _onExtractingHandlerByJobId[jobId] = onExtracting;
      }

      await _channel.invokeMethod<void>('unzip', <String, dynamic>{
        'zipFile': zipFile.path,
        'destinationDir': destinationDir.path,
        'reportProgress': reportProgress,
        'jobId': jobId,
      });
    } finally {
      _onExtractingHandlerByJobId.remove(jobId);
    }
  }

  static bool _isMethodCallHandlerSet = false;
  static int _jobId = 0;
  static final _onExtractingHandlerByJobId = <int, OnExtracting>{};
  static final _onZippingHandlerByJobId = <int, OnZipping>{};

  static Future<dynamic> _channelMethodCallHandler(MethodCall call) {
    if (call.method == 'progress') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final jobId = args["jobId"] as int? ?? 0;
      final zipEntry = ZipEntry.fromMap(args);
      final progress = args["progress"] as double? ?? 0;
      final onExtractHandler = _onExtractingHandlerByJobId[jobId];
      if (onExtractHandler != null) {
        final result = onExtractHandler(zipEntry, progress);
        return Future<String>.value(_progressOperationToString(result));
      } else {
        final onZippingHandler = _onZippingHandlerByJobId[jobId];
        if (onZippingHandler != null) {
          final result =
              onZippingHandler(zipEntry.name, zipEntry.isDirectory, progress);
          return Future<String>.value(_progressOperationToString(result));
        } else {
          return Future<void>.value();
        }
      }
    }
    return Future<void>.value();
  }
}

enum CompressionMethod { none, deflated }

class ZipEntry {
  const ZipEntry(
      {required this.name,
      required this.isDirectory,
      this.modificationDate,
      this.uncompressedSize,
      this.compressedSize,
      this.crc,
      this.compressionMethod});

  factory ZipEntry.fromMap(Map<String, dynamic> map) {
    return ZipEntry(
      name: map['name'] as String? ?? '',
      isDirectory: (map['isDirectory'] as bool?) == true,
      modificationDate: DateTime.fromMillisecondsSinceEpoch(
          map['modificationDate'] as int? ?? 0),
      uncompressedSize: map['uncompressedSize'] as int?,
      compressedSize: map['compressedSize'] as int?,
      crc: map['crc'] as int?,
      compressionMethod: map['compressionMethod'] == 'none'
          ? CompressionMethod.none
          : CompressionMethod.deflated,
    );
  }

  final String name;
  final bool isDirectory;
  final DateTime? modificationDate;
  final int? uncompressedSize;
  final int? compressedSize;
  final int? crc;
  final CompressionMethod? compressionMethod;
}
