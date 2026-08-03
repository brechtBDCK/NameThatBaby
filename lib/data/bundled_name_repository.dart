import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../core/domain.dart';

class BundledDatabaseError implements Exception {
  const BundledDatabaseError(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef AssetBytesLoader = Future<List<int>> Function(String path);

/// Installs a verified asset into a replaceable sandbox file. The old verified
/// copy remains in place until the new bytes have been checked and renamed.
class BundledDatabaseInstaller {
  BundledDatabaseInstaller({required this.loadBytes, required this.directory});

  final AssetBytesLoader loadBytes;
  final Future<String> Function() directory;
  static final _hash = Sha256();

  Future<String> install({
    required String databaseAsset,
    required String manifestAsset,
    required String fileName,
  }) async {
    Map<String, Object?> manifest;
    try {
      manifest =
          (jsonDecode(utf8.decode(await loadBytes(manifestAsset))) as Map)
              .cast<String, Object?>();
    } catch (_) {
      throw const BundledDatabaseError(
        'Name data manifest is missing or corrupt.',
      );
    }
    final expected = manifest['sqlite_sha256'];
    final buildId = manifest['build_id'];
    if (expected is! String || expected.length != 64 || buildId is! String) {
      throw const BundledDatabaseError('Name data manifest is invalid.');
    }
    late final List<int> bytes;
    try {
      bytes = await loadBytes(databaseAsset);
    } on Object {
      throw const BundledDatabaseError(
        'Bundled name data is missing or corrupt.',
      );
    }
    final actual = (await _hash.hash(
      bytes,
    )).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    if (actual != expected) {
      throw const BundledDatabaseError(
        'Bundled name data does not match its manifest.',
      );
    }
    final target = File('${await directory()}/$fileName');
    final marker = File('${target.path}.build');
    final existingMatches =
        await target.exists() &&
        await marker.exists() &&
        await marker.readAsString() == '$buildId:$expected' &&
        await _fileHash(target) == expected;
    if (existingMatches) return target.path;
    final temporary = File('${target.path}.new');
    final temporaryMarker = File('${marker.path}.new');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await _fileHash(temporary) != expected) {
        throw const BundledDatabaseError(
          'Installed name data could not be verified.',
        );
      }
      await temporaryMarker.writeAsString('$buildId:$expected', flush: true);
      await temporary.rename(target.path);
      await temporaryMarker.rename(marker.path);
    } on BundledDatabaseError {
      rethrow;
    } on Object {
      throw const BundledDatabaseError(
        'Name data could not be installed. Retry or reinstall the app.',
      );
    }
    return target.path;
  }

  Future<String> _fileHash(File file) async {
    final digest = await _hash.hash(await file.readAsBytes());
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// Read-only access to the SQLite asset included in every installation.
///
/// The copy lives in the app database directory because mobile SQLite APIs
/// cannot query an asset directly. It is never downloaded or modified.
class BundledNameRepository {
  static const _assetPath = 'assets/data/names.sqlite';
  static const _databaseFileName = 'namethatbaby-names-v2.sqlite';

  Future<List<Candidate>> candidatePool({
    required Set<String> countries,
    required Set<NameCategory> categories,
    required int seed,
    int target = 150,
  }) async {
    final database = await _open();
    try {
      final candidates = <Candidate>[];
      for (final category in categories) {
        final rankings = await _rankings(database, countries, category);
        candidates.addAll(
          equalCountryPool(rankings: rankings, seed: seed, target: target),
        );
      }
      return candidates;
    } finally {
      await database.close();
    }
  }

  Future<Database> _open() async {
    final installer = BundledDatabaseInstaller(
      directory: getDatabasesPath,
      loadBytes: (path) async {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      },
    );
    final path = await installer.install(
      databaseAsset: _assetPath,
      manifestAsset: 'assets/data/manifest.json',
      fileName: _databaseFileName,
    );
    return openDatabase(path, readOnly: true);
  }

  Future<Map<String, List<Candidate>>> _rankings(
    Database database,
    Set<String> countries,
    NameCategory category,
  ) async {
    if (countries.isEmpty) return const {};
    final marks = List.filled(countries.length, '?').join(', ');
    final rows = await database.rawQuery(
      '''SELECT ranking.country_code, name.id AS name_id, name.display_name,
                ranking.source_rank
         FROM country_decade_ranking AS ranking
         JOIN name ON name.id = ranking.name_id
         WHERE ranking.category = ? AND ranking.country_code IN ($marks)
         ORDER BY ranking.country_code, ranking.source_rank, name.normalized_key''',
      [
        category == NameCategory.girls ? 'girl' : 'boy',
        ...countries.toList()..sort(),
      ],
    );
    final rankings = <String, List<Candidate>>{};
    for (final row in rows) {
      final country = row['country_code']! as String;
      final nameId = row['name_id']! as int;
      rankings
          .putIfAbsent(country, () => [])
          .add(
            Candidate(
              nameId * 2 + (category == NameCategory.girls ? 0 : 1),
              row['display_name']! as String,
              category,
              [country],
              row['source_rank']! as int,
            ),
          );
    }
    return rankings;
  }
}
