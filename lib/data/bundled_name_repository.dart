import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../core/domain.dart';

/// Read-only access to the SQLite asset included in every installation.
///
/// The copy lives in the app database directory because mobile SQLite APIs
/// cannot query an asset directly. It is never downloaded or modified.
class BundledNameRepository {
  static const _assetPath = 'assets/data/names.sqlite';
  static const _databaseFileName = 'namethatbaby-names-v1.sqlite';

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
    final path = '${await getDatabasesPath()}/$_databaseFileName';
    if (!await File(path).exists()) {
      final bytes = await rootBundle.load(_assetPath);
      await File(path).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }
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
      '''SELECT source.country_code, name.id AS name_id, name.display_name,
                observation.year, observation.source_rank
         FROM name_observation AS observation
         JOIN data_source AS source ON source.id = observation.source_id
         JOIN name ON name.id = observation.name_id
         WHERE observation.category = ? AND source.country_code IN ($marks)
         ORDER BY source.country_code, observation.year, observation.source_rank, name.normalized_key''',
      [
        category == NameCategory.girls ? 'girl' : 'boy',
        ...countries.toList()..sort(),
      ],
    );
    final observations = <String, List<AnnualNameRanking>>{};
    for (final row in rows) {
      final country = row['country_code']! as String;
      final nameId = row['name_id']! as int;
      observations
          .putIfAbsent(country, () => [])
          .add(
            AnnualNameRanking(
              id: nameId * 2 + (category == NameCategory.girls ? 0 : 1),
              name: row['display_name']! as String,
              country: country,
              category: category,
              year: row['year']! as int,
              rank: row['source_rank']! as int,
            ),
          );
    }
    return {
      for (final entry in observations.entries)
        entry.key: rankCountryDecade(entry.value),
    };
  }
}
