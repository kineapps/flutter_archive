import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_archive');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return true;
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    // TODO
  });

  test('isZipFile', () async {
    expect(await isZipFile(MockFile(true)), true);
    expect(await isZipFile(MockFile(false)), false);
  });
}

class MockFile extends Mock implements File, RandomAccessFile {
  final bool _isZipFile;

  MockFile(this._isZipFile);

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    return this;
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    return this;
  }

  @override
  Future<Uint8List> read(int count) async {
    if (_isZipFile) {
      return Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
    } else {
      return Uint8List.fromList([]);
    }
  }
}
