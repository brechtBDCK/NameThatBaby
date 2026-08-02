import 'dart:convert';
import 'dart:math';

enum NameCategory { girls, boys }

enum VoteValue { no, maybe, yes }

enum MatchTier { rejected, consider, strong }

String normalizeName(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return compact.toLowerCase();
}

bool isValidCustomName(String value, {int maxLength = 40}) {
  final normalized = normalizeName(value);
  if (normalized.isEmpty || normalized.runes.length > maxLength) return false;
  if (RegExp(
    r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u2060\ufeff]',
  ).hasMatch(value)) {
    return false;
  }
  return RegExp(r"[\p{L}]", unicode: true).hasMatch(normalized);
}

MatchTier matchTier(VoteValue mine, VoteValue partner) {
  if (mine == VoteValue.no || partner == VoteValue.no) {
    return MatchTier.rejected;
  }
  return mine == VoteValue.yes && partner == VoteValue.yes
      ? MatchTier.strong
      : MatchTier.consider;
}

class Candidate {
  const Candidate(this.id, this.name, this.category, this.countries, this.rank);
  final int id;
  final String name;
  final NameCategory category;
  final List<String> countries;
  final int rank;
}

class AnnualNameRanking {
  const AnnualNameRanking({
    required this.id,
    required this.name,
    required this.country,
    required this.category,
    required this.year,
    required this.rank,
  });

  final int id;
  final String name;
  final String country;
  final NameCategory category;
  final int year;
  final int rank;
}

/// Applies the product's equal-year decade ranking rules to one country.
List<Candidate> rankCountryDecade(Iterable<AnnualNameRanking> observations) {
  final byId = <int, List<AnnualNameRanking>>{};
  for (final observation in observations) {
    byId.putIfAbsent(observation.id, () => []).add(observation);
  }
  final ranked = byId.values.toList()
    ..sort((left, right) {
      double scoreOf(List<AnnualNameRanking> rows) =>
          rows.fold(0, (score, row) => score + 1 / (log(row.rank + 1) / ln2));
      final score = scoreOf(right).compareTo(scoreOf(left));
      if (score != 0) return score;
      final years = right
          .map((row) => row.year)
          .toSet()
          .length
          .compareTo(left.map((row) => row.year).toSet().length);
      if (years != 0) return years;
      int latestRank(List<AnnualNameRanking> rows) {
        final latest = rows.map((row) => row.year).reduce(max);
        return rows
            .where((row) => row.year == latest)
            .map((row) => row.rank)
            .reduce(min);
      }

      final latest = latestRank(left).compareTo(latestRank(right));
      if (latest != 0) return latest;
      final best = left
          .map((row) => row.rank)
          .reduce(min)
          .compareTo(right.map((row) => row.rank).reduce(min));
      if (best != 0) return best;
      return normalizeName(
        left.first.name,
      ).compareTo(normalizeName(right.first.name));
    });
  return [
    for (var index = 0; index < ranked.length; index++)
      Candidate(
        ranked[index].first.id,
        ranked[index].first.name,
        ranked[index].first.category,
        [ranked[index].first.country],
        index + 1,
      ),
  ];
}

List<Candidate> equalCountryPool({
  required Map<String, List<Candidate>> rankings,
  required int seed,
  int target = 150,
}) {
  final countries = rankings.keys.toList()..sort();
  final origins = <String, Set<String>>{};
  for (final entry in rankings.entries) {
    for (final candidate in entry.value) {
      origins
          .putIfAbsent(
            '${candidate.category.name}:${normalizeName(candidate.name)}',
            () => <String>{},
          )
          .add(entry.key);
    }
  }
  final positions = <String, int>{for (final country in countries) country: 0};
  final seen = <String>{};
  final selected = <Candidate>[];
  while (selected.length < target) {
    var progressed = false;
    for (final country in countries) {
      final names = rankings[country]!;
      while (positions[country]! < names.length) {
        final candidate = names[positions[country]!];
        positions[country] = positions[country]! + 1;
        if (seen.add(
          '${candidate.category.name}:${normalizeName(candidate.name)}',
        )) {
          selected.add(candidate);
          progressed = true;
          break;
        }
      }
      if (selected.length == target) break;
    }
    if (!progressed) break;
  }
  selected.shuffle(Random(seed));
  return selected
      .map(
        (candidate) => Candidate(
          candidate.id,
          candidate.name,
          candidate.category,
          origins['${candidate.category.name}:${normalizeName(candidate.name)}']!
              .toList()
            ..sort(),
          candidate.rank,
        ),
      )
      .toList();
}

class Pairing {
  const Pairing(this.left, this.right);
  final String left;
  final String right;
}

class FaceoffResult {
  const FaceoffResult(
    this.name,
    this.score,
    this.opponentsScore,
    this.unanimousWins,
    this.seedTier,
  );

  final String name;
  final int score;
  final int opponentsScore;
  final int unanimousWins;
  final int seedTier;
}

/// Deterministic Swiss-style next-round pairing: score proximity, no repeats,
/// then a seed-stable order. An odd name receives a bye and is not scored.
List<Pairing> scheduleRound(
  List<String> entries,
  Map<String, int> score,
  Set<String> previous, {
  int seed = 0,
  Map<String, int> comparisons = const {},
  Map<String, int> leftCounts = const {},
  Map<String, int> rightCounts = const {},
  Map<String, int> seedTiers = const {},
}) {
  final pool = [...entries]
    ..sort((a, b) {
      final byScore = (score[b] ?? 0).compareTo(score[a] ?? 0);
      if (byScore != 0) return byScore;
      final byComparisons = (comparisons[a] ?? 0).compareTo(
        comparisons[b] ?? 0,
      );
      if (byComparisons != 0) return byComparisons;
      final bySeedTier = (seedTiers[b] ?? 0).compareTo(seedTiers[a] ?? 0);
      if (bySeedTier != 0) return bySeedTier;
      return _seedOrder(a, seed).compareTo(_seedOrder(b, seed));
    });
  final result = <Pairing>[];
  while (pool.length > 1) {
    final first = pool.removeAt(0);
    pool.sort((a, b) {
      final aRepeat = previous.contains(pairKey(first, a));
      final bRepeat = previous.contains(pairKey(first, b));
      if (aRepeat != bRepeat) return aRepeat ? 1 : -1;
      final aScoreGap = ((score[first] ?? 0) - (score[a] ?? 0)).abs();
      final bScoreGap = ((score[first] ?? 0) - (score[b] ?? 0)).abs();
      if (aScoreGap != bScoreGap) return aScoreGap.compareTo(bScoreGap);
      final aComparisonGap = ((comparisons[first] ?? 0) - (comparisons[a] ?? 0))
          .abs();
      final bComparisonGap = ((comparisons[first] ?? 0) - (comparisons[b] ?? 0))
          .abs();
      if (aComparisonGap != bComparisonGap) {
        return aComparisonGap.compareTo(bComparisonGap);
      }
      return _seedOrder(a, seed).compareTo(_seedOrder(b, seed));
    });
    final second = pool.removeAt(0);
    final firstLeft =
        _sideImbalance(first, leftCounts, rightCounts, true) +
        _sideImbalance(second, leftCounts, rightCounts, false);
    final secondLeft =
        _sideImbalance(second, leftCounts, rightCounts, true) +
        _sideImbalance(first, leftCounts, rightCounts, false);
    result.add(
      firstLeft <= secondLeft ? Pairing(first, second) : Pairing(second, first),
    );
  }
  return result;
}

int _sideImbalance(
  String name,
  Map<String, int> leftCounts,
  Map<String, int> rightCounts,
  bool onLeft,
) =>
    ((leftCounts[name] ?? 0) +
            (onLeft ? 1 : 0) -
            (rightCounts[name] ?? 0) -
            (onLeft ? 0 : 1))
        .abs();

int _seedOrder(String name, int seed) {
  var value = seed;
  for (final codeUnit in normalizeName(name).codeUnits) {
    value = (value * 31 + codeUnit) & 0x7fffffff;
  }
  return value;
}

String pairKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

List<FaceoffResult> rankFaceoff(
  Iterable<String> entries,
  Map<String, int> scores, {
  Map<String, int> opponentsScores = const {},
  Map<String, int> unanimousWins = const {},
  Map<String, int> seedTiers = const {},
  int seed = 0,
  int limit = 10,
}) {
  final ranked =
      entries
          .map(
            (name) => FaceoffResult(
              name,
              scores[name] ?? 0,
              opponentsScores[name] ?? 0,
              unanimousWins[name] ?? 0,
              seedTiers[name] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          final byOpponents = b.opponentsScore.compareTo(a.opponentsScore);
          if (byOpponents != 0) return byOpponents;
          final byUnanimous = b.unanimousWins.compareTo(a.unanimousWins);
          if (byUnanimous != 0) return byUnanimous;
          final bySeedTier = b.seedTier.compareTo(a.seedTier);
          if (bySeedTier != 0) return bySeedTier;
          return _seedOrder(a.name, seed).compareTo(_seedOrder(b.name, seed));
        });
  return ranked.take(limit).toList();
}

bool shouldFinishFaceoff({
  required int entryCount,
  required Iterable<int> comparisonCounts,
  required List<List<String>> topTenHistory,
  required int completedRounds,
  int minimumComparisons = 3,
  int maximumComparisons = 7,
}) {
  if (completedRounds >= maximumComparisons) return true;
  if (entryCount <= 10 ||
      comparisonCounts.any((count) => count < minimumComparisons)) {
    return false;
  }
  if (topTenHistory.length < 2) return false;
  final current = topTenHistory[topTenHistory.length - 1].toSet();
  final previous = topTenHistory[topTenHistory.length - 2].toSet();
  return current.length == previous.length && current.containsAll(previous);
}

List<String> boundaryTieBreakEntries(
  List<String> entries,
  Map<String, int> scores, {
  Map<String, int> opponentsScores = const {},
  Map<String, int> unanimousWins = const {},
  Map<String, int> seedTiers = const {},
  int seed = 0,
}) {
  if (entries.length <= 10) return const [];
  final ranked = rankFaceoff(
    entries,
    scores,
    opponentsScores: opponentsScores,
    unanimousWins: unanimousWins,
    seedTiers: seedTiers,
    seed: seed,
    limit: entries.length,
  );
  final boundary = ranked[9];
  final tied = ranked
      .where(
        (result) =>
            result.score == boundary.score &&
            result.opponentsScore == boundary.opponentsScore &&
            result.unanimousWins == boundary.unanimousWins &&
            result.seedTier == boundary.seedTier,
      )
      .map((result) => result.name)
      .toList();
  final positions = tied.map(
    (name) => ranked.indexWhere((r) => r.name == name),
  );
  return positions.any((index) => index < 10) &&
          positions.any((index) => index >= 10)
      ? tied
      : const [];
}

String canonicalPacket(Map<String, Object?> value) => jsonEncode(value);
