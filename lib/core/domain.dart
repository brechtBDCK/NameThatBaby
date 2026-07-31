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

List<Candidate> equalCountryPool({
  required Map<String, List<Candidate>> rankings,
  required int seed,
  int target = 150,
}) {
  final countries = rankings.keys.toList()..sort();
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
  return selected;
}

class Pairing {
  const Pairing(this.left, this.right);
  final String left;
  final String right;
}

/// Deterministic Swiss-style next-round pairing: score proximity, no repeats,
/// then a seed-stable order. An odd name receives a bye and is not scored.
List<Pairing> scheduleRound(
  List<String> entries,
  Map<String, int> score,
  Set<String> previous, {
  int seed = 0,
}) {
  final pool = [...entries]
    ..sort((a, b) {
      final byScore = (score[b] ?? 0).compareTo(score[a] ?? 0);
      return byScore != 0 ? byScore : a.compareTo(b);
    });
  final result = <Pairing>[];
  while (pool.length > 1) {
    final left = pool.removeAt(0);
    var index = pool.indexWhere(
      (right) => !previous.contains(_pairKey(left, right)),
    );
    if (index < 0) index = 0;
    result.add(Pairing(left, pool.removeAt(index)));
  }
  return result;
}

String _pairKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

String canonicalPacket(Map<String, Object?> value) => jsonEncode(value);
