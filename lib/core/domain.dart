import 'dart:convert';
import 'dart:math';

enum NameCategory { girls, boys }

enum VoteValue { no, maybe, yes }

enum MatchTier { rejected, consider, strong }

enum PopularityTrend { rising, falling, stable }

String countryDisplayName(String code) =>
    const {
      'US': 'United States',
      'CA': 'Canada',
      'BE': 'Belgium',
      'NL': 'Netherlands',
      'DK': 'Denmark',
      'NO': 'Norway',
      'SE': 'Sweden',
      'DE': 'Germany',
      'FR': 'France',
      'ES': 'Spain',
      'IT': 'Italy',
      'AT': 'Austria',
      'GB': 'United Kingdom',
      'IE': 'Ireland',
      'AU': 'Australia',
    }[code] ??
    code;

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
  const Candidate({
    required this.id,
    required this.name,
    required this.category,
    required this.popularity,
    required this.combinedPoolPosition,
    required this.combinedRelevanceScore,
  });
  final int id;
  final String name;
  final NameCategory category;
  final List<CountryPopularity> popularity;

  /// Position in the deterministic, relevance-scored combined pool. The
  /// presentation order is intentionally shuffled separately for discovery.
  final int combinedPoolPosition;
  final double combinedRelevanceScore;

  List<String> get countries =>
      popularity.map((value) => value.country).toSet().toList()..sort();

  String get popularityLabel => countries.length == 1
      ? 'Popular in ${countryDisplayName(countries.single)}'
      : 'Popular across ${countries.length} selected countries';
}

class CountryPopularity {
  const CountryPopularity({
    required this.country,
    required this.decadeRank,
    required this.decadeScore,
    required this.observedYears,
    required this.latestObservedYear,
    required this.latestRank,
    required this.bestRank,
    required this.sourceId,
    this.trend,
  });

  final String country;
  final int decadeRank;
  final double decadeScore;
  final int observedYears;
  final int latestObservedYear;
  final int latestRank;
  final int bestRank;
  final String sourceId;
  final PopularityTrend? trend;
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

double _decadeScore(Iterable<AnnualNameRanking> rows) =>
    rows.fold(0, (score, row) => score + 1 / (log(row.rank + 1) / ln2));

int _latestRank(List<AnnualNameRanking> rows) {
  final latest = rows.map((row) => row.year).reduce(max);
  return rows
      .where((row) => row.year == latest)
      .map((row) => row.rank)
      .reduce(min);
}

PopularityTrend? _annualTrend(List<AnnualNameRanking> rows) {
  final years = rows.map((row) => row.year).toSet();
  if (years.length < 2) return null;
  final first = years.reduce(min);
  final firstRank = rows
      .where((row) => row.year == first)
      .map((row) => row.rank)
      .reduce(min);
  final latest = _latestRank(rows);
  return latest < firstRank
      ? PopularityTrend.rising
      : latest > firstRank
      ? PopularityTrend.falling
      : PopularityTrend.stable;
}

/// Applies the product's equal-year decade ranking rules to one country.
List<Candidate> rankCountryDecade(Iterable<AnnualNameRanking> observations) {
  final byId = <int, List<AnnualNameRanking>>{};
  for (final observation in observations) {
    byId.putIfAbsent(observation.id, () => []).add(observation);
  }
  final ranked = byId.values.toList()
    ..sort((left, right) {
      final score = _decadeScore(right).compareTo(_decadeScore(left));
      if (score != 0) return score;
      final years = right
          .map((row) => row.year)
          .toSet()
          .length
          .compareTo(left.map((row) => row.year).toSet().length);
      if (years != 0) return years;
      final latest = _latestRank(left).compareTo(_latestRank(right));
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
        id: ranked[index].first.id,
        name: ranked[index].first.name,
        category: ranked[index].first.category,
        popularity: [
          CountryPopularity(
            country: ranked[index].first.country,
            decadeRank: index + 1,
            decadeScore: _decadeScore(ranked[index]),
            observedYears: ranked[index].map((row) => row.year).toSet().length,
            latestObservedYear: ranked[index]
                .map((row) => row.year)
                .reduce(max),
            latestRank: _latestRank(ranked[index]),
            bestRank: ranked[index].map((row) => row.rank).reduce(min),
            sourceId: 'derived',
            trend: _annualTrend(ranked[index]),
          ),
        ],
        combinedPoolPosition: index + 1,
        combinedRelevanceScore: _decadeScore(ranked[index]),
      ),
  ];
}

/// Builds a varied, deterministic pool from ordered country preferences.
///
/// A country's positional weight is `1 / sqrt(position)`, normalized across
/// the selected list.  A name receives the weighted sum of its country
/// popularity (`1 / log2(rank + 1)`) plus 0.10 for every extra country in
/// which it appears.  Each country reserves up to 20 unique entries before
/// the remaining slots are filled by relevance, so a lower priority never
/// disappears behind a large top-country ranking.
List<Candidate> weightedCountryPool({
  required Map<String, List<Candidate>> rankings,
  required List<String> countryPriority,
  required int seed,
  int target = 200,
  bool shuffle = true,
}) {
  final countries = [
    ...countryPriority.where(rankings.containsKey),
    ...(rankings.keys.where((code) => !countryPriority.contains(code)).toList()
      ..sort()),
  ];
  final rawWeights = <String, double>{
    for (var index = 0; index < countries.length; index++)
      countries[index]: 1 / sqrt(index + 1),
  };
  final totalWeight = rawWeights.values.fold<double>(0, (a, b) => a + b);
  final weights = {
    for (final entry in rawWeights.entries)
      entry.key: entry.value / totalWeight,
  };
  final appearances = <String, List<CountryPopularity>>{};
  for (final entry in rankings.entries) {
    for (final candidate in entry.value) {
      appearances
          .putIfAbsent(
            '${candidate.category.name}:${normalizeName(candidate.name)}',
            () => <CountryPopularity>[],
          )
          .addAll(candidate.popularity);
    }
  }
  final seen = <String>{};
  final selected = <Candidate>[];
  final reserve = min(20, max(1, target ~/ max(1, countries.length)));
  for (final country in countries) {
    var contributed = 0;
    for (final candidate in rankings[country]!) {
      if (contributed == reserve || selected.length == target) break;
      if (seen.add(
        '${candidate.category.name}:${normalizeName(candidate.name)}',
      )) {
        selected.add(candidate);
        contributed++;
      }
    }
  }
  final all = <Candidate>[];
  final allSeen = <String>{};
  for (final country in countries) {
    for (final candidate in rankings[country]!) {
      if (allSeen.add(
        '${candidate.category.name}:${normalizeName(candidate.name)}',
      )) {
        all.add(candidate);
      }
    }
  }
  Candidate combine(Candidate candidate) {
    final popularity = [
      ...appearances['${candidate.category.name}:${normalizeName(candidate.name)}']!,
    ]..sort((left, right) => left.country.compareTo(right.country));
    final relevance =
        popularity.fold<double>(
          0,
          (total, value) =>
              total +
              (weights[value.country] ?? 0) / (log(value.decadeRank + 1) / ln2),
        ) +
        (popularity.length - 1) * .10;
    return Candidate(
      id: candidate.id,
      name: candidate.name,
      category: candidate.category,
      popularity: popularity,
      combinedPoolPosition: 0,
      combinedRelevanceScore: relevance,
    );
  }

  final combined = all.map(combine).toList();
  combined.sort((left, right) {
    final score = right.combinedRelevanceScore.compareTo(
      left.combinedRelevanceScore,
    );
    return score != 0
        ? score
        : normalizeName(left.name).compareTo(normalizeName(right.name));
  });
  for (final candidate in combined) {
    if (selected.length == target) break;
    if (seen.add(
      '${candidate.category.name}:${normalizeName(candidate.name)}',
    )) {
      selected.add(candidate);
    }
  }
  final positioned = [
    for (var index = 0; index < selected.length; index++)
      Candidate(
        id: combine(selected[index]).id,
        name: combine(selected[index]).name,
        category: combine(selected[index]).category,
        popularity: combine(selected[index]).popularity,
        combinedPoolPosition: index + 1,
        combinedRelevanceScore: combine(selected[index]).combinedRelevanceScore,
      ),
  ];
  positioned.sort(
    (a, b) => b.combinedRelevanceScore.compareTo(a.combinedRelevanceScore),
  );
  if (shuffle) {
    final random = Random(seed);
    for (var start = 0; start < positioned.length; start += 25) {
      final end = min(start + 25, positioned.length);
      final band = positioned.sublist(start, end)..shuffle(random);
      positioned.replaceRange(start, end, band);
    }
  }
  return positioned;
}

/// Backwards-compatible entry point for tests and older callers.
List<Candidate> equalCountryPool({
  required Map<String, List<Candidate>> rankings,
  required int seed,
  int target = 200,
  bool shuffle = true,
}) => weightedCountryPool(
  rankings: rankings,
  countryPriority: rankings.keys.toList()..sort(),
  seed: seed,
  target: target,
  shuffle: shuffle,
);

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
