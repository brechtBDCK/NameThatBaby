import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/data/bundled_name_repository.dart';

Future<String> _hash(List<int> bytes) async => (await Sha256().hash(
  bytes,
)).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test(
    'installs, retains, upgrades and recovers a verified database',
    () async {
      final directory = await Directory.systemTemp.createTemp('ntb-db-test-');
      addTearDown(() => directory.delete(recursive: true));
      final first = utf8.encode('first sqlite bytes');
      final second = utf8.encode('second sqlite bytes');
      var bytes = first;
      var build = 'one';
      Future<List<int>> load(String path) async =>
          path.endsWith('manifest.json')
          ? utf8.encode(
              jsonEncode({
                'build_id': build,
                'sqlite_sha256': await _hash(bytes),
              }),
            )
          : bytes;
      final installer = BundledDatabaseInstaller(
        loadBytes: load,
        directory: () async => directory.path,
      );

      final path = await installer.install(
        databaseAsset: 'names.sqlite',
        manifestAsset: 'manifest.json',
        fileName: 'names.sqlite',
      );
      expect(await File(path).readAsBytes(), first);
      final unchanged = await installer.install(
        databaseAsset: 'names.sqlite',
        manifestAsset: 'manifest.json',
        fileName: 'names.sqlite',
      );
      expect(unchanged, path);
      bytes = second;
      build = 'two';
      await installer.install(
        databaseAsset: 'names.sqlite',
        manifestAsset: 'manifest.json',
        fileName: 'names.sqlite',
      );
      expect(await File(path).readAsBytes(), second);
      await File(path).writeAsString('corrupt');
      await installer.install(
        databaseAsset: 'names.sqlite',
        manifestAsset: 'manifest.json',
        fileName: 'names.sqlite',
      );
      expect(await File(path).readAsBytes(), second);
    },
  );

  test(
    'reports a mismatched bundled asset without replacing a good copy',
    () async {
      final directory = await Directory.systemTemp.createTemp('ntb-db-test-');
      addTearDown(() => directory.delete(recursive: true));
      final bytes = utf8.encode('bad');
      final installer = BundledDatabaseInstaller(
        directory: () async => directory.path,
        loadBytes: (path) async => path.endsWith('manifest.json')
            ? utf8.encode(
                jsonEncode({'build_id': 'bad', 'sqlite_sha256': '0' * 64}),
              )
            : bytes,
      );
      await expectLater(
        installer.install(
          databaseAsset: 'names.sqlite',
          manifestAsset: 'manifest.json',
          fileName: 'names.sqlite',
        ),
        throwsA(isA<BundledDatabaseError>()),
      );
    },
  );
}
