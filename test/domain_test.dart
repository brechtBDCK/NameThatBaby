import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/domain.dart';

void main() {
  test('No vetoes every matching combination', () {
    for (final value in VoteValue.values) {
      expect(matchTier(VoteValue.no, value), MatchTier.rejected);
      expect(matchTier(value, VoteValue.no), MatchTier.rejected);
    }
  });
  test('non-No values advance with the right tier', () {
    expect(matchTier(VoteValue.yes, VoteValue.yes), MatchTier.strong);
    expect(matchTier(VoteValue.maybe, VoteValue.yes), MatchTier.consider);
    expect(isValidCustomName('Amélie-Rose'), isTrue);
    expect(isValidCustomName('---'), isFalse);
  });
  test('country pool round robin deduplicates category identities', () {
    final pool = equalCountryPool(
      rankings: {
        'FR': [
          const Candidate(1, 'Elena', NameCategory.girls, ['FR'], 1),
        ],
        'US': [
          const Candidate(2, 'Elena', NameCategory.girls, ['US'], 1),
          const Candidate(3, 'Nora', NameCategory.girls, ['US'], 2),
        ],
      },
      seed: 1,
    );
    expect(pool.map((e) => e.name).toSet(), {'Elena', 'Nora'});
    expect(
      pool.singleWhere((candidate) => candidate.name == 'Elena').countries,
      ['FR', 'US'],
    );
  });
  test('decade ranking uses score then the specified tie breakers', () {
    final ranked = rankCountryDecade([
      for (var year = 2015; year <= 2024; year++) ...[
        AnnualNameRanking(
          id: 1,
          name: 'Zoe',
          country: 'US',
          category: NameCategory.girls,
          year: year,
          rank: 2,
        ),
        AnnualNameRanking(
          id: 2,
          name: 'Amy',
          country: 'US',
          category: NameCategory.girls,
          year: year,
          rank: 2,
        ),
      ],
    ]);

    expect(ranked.map((candidate) => candidate.name), ['Amy', 'Zoe']);
  });
  test('Swiss pairing avoids previous pair when possible', () {
    final pairs = scheduleRound(['a', 'b', 'c', 'd'], {}, {'a|b'});
    expect(
      pairs.any(
        (p) =>
            {p.left, p.right}.contains('a') && {p.left, p.right}.contains('b'),
      ),
      isFalse,
    );
  });

  test('Swiss pairing balances left and right presentation counts', () {
    final pairs = scheduleRound(
      ['a', 'b'],
      {},
      {},
      leftCounts: {'a': 3, 'b': 0},
      rightCounts: {'a': 0, 'b': 3},
    );

    expect(pairs.single.left, 'b');
    expect(pairs.single.right, 'a');
  });

  test('faceoff ranking sorts by score', () {
    final results = rankFaceoff(
      ['Zoë', 'Anna', 'Mila'],
      {'Zoë': 1, 'Anna': 2, 'Mila': 1},
      limit: 2,
    );

    expect(results.first.name, 'Anna');
    expect(results.map((result) => result.score), [2, 1]);
  });

  test('faceoff ranking uses opponent strength before name order', () {
    final results = rankFaceoff(
      ['Anna', 'Bella'],
      {'Anna': 2, 'Bella': 2},
      opponentsScores: {'Anna': 3, 'Bella': 5},
    );

    expect(results.map((result) => result.name), ['Bella', 'Anna']);
  });

  test('faceoff ranking uses unanimous wins then seed tier for ties', () {
    final results = rankFaceoff(
      ['A', 'B', 'C'],
      {'A': 3, 'B': 3, 'C': 3},
      opponentsScores: {'A': 4, 'B': 4, 'C': 4},
      unanimousWins: {'A': 1, 'B': 2, 'C': 1},
      seedTiers: {'A': 3, 'B': 1, 'C': 2},
    );

    expect(results.map((result) => result.name), ['B', 'A', 'C']);
  });

  test('large Face-off finishes only after comparisons and stable top ten', () {
    expect(
      shouldFinishFaceoff(
        entryCount: 11,
        comparisonCounts: List.filled(11, 3),
        topTenHistory: [
          List.generate(10, (index) => 'name$index'),
          List.generate(10, (index) => 'name$index'),
        ],
        completedRounds: 3,
      ),
      isTrue,
    );
    expect(
      shouldFinishFaceoff(
        entryCount: 11,
        comparisonCounts: List.filled(11, 2),
        topTenHistory: const [
          ['a'],
          ['a'],
        ],
        completedRounds: 3,
      ),
      isFalse,
    );
  });

  test('Face-off safety cap completes an unresolved large pool', () {
    expect(
      shouldFinishFaceoff(
        entryCount: 11,
        comparisonCounts: List.filled(11, 2),
        topTenHistory: const [],
        completedRounds: 7,
      ),
      isTrue,
    );
  });

  test('boundary tie-break selects only names tied across tenth place', () {
    final names = List.generate(12, (index) => 'name$index');
    final ties = boundaryTieBreakEntries(
      names,
      {for (final name in names) name: name == 'name11' ? 0 : 3},
      opponentsScores: {for (final name in names) name: 1},
      unanimousWins: {for (final name in names) name: 1},
      seedTiers: {for (final name in names) name: 2},
      seed: 7,
    );

    expect(ties, hasLength(11));
    expect(ties, isNot(contains('name11')));
  });

  test('pair key is independent of name order', () {
    expect(pairKey('Nora', 'Elena'), pairKey('Elena', 'Nora'));
  });
}
