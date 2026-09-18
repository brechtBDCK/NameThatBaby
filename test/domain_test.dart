import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/domain.dart';

Candidate candidate(
  int id,
  String name,
  NameCategory category,
  String country,
  int rank, {
  PopularityTrend? trend,
}) => Candidate(
  id: id,
  name: name,
  category: category,
  popularity: [
    CountryPopularity(
      country: country,
      decadeRank: rank,
      decadeScore: 1 / rank,
      observedYears: trend == null ? 1 : 2,
      latestObservedYear: 2024,
      latestRank: rank,
      bestRank: rank,
      sourceId: '$country-source',
      trend: trend,
    ),
  ],
  combinedPoolPosition: 0,
  combinedRelevanceScore: 0,
);

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
        'FR': [candidate(1, 'Elena', NameCategory.girls, 'FR', 1)],
        'US': [
          candidate(2, 'Elena', NameCategory.girls, 'US', 1),
          candidate(3, 'Nora', NameCategory.girls, 'US', 2),
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
  test('unshuffled country pool preserves round-robin rank order', () {
    final pool = equalCountryPool(
      rankings: {
        'A': [candidate(1, 'Ada', NameCategory.girls, 'A', 1)],
        'B': [candidate(2, 'Bea', NameCategory.girls, 'B', 1)],
      },
      seed: 1,
      shuffle: false,
    );
    expect(pool.map((candidate) => candidate.name), ['Ada', 'Bea']);
  });
  test('country pool is capped at 150 and deterministic', () {
    List<Candidate> ranked(String country, int offset) => [
      for (var rank = 1; rank <= 200; rank++)
        candidate(
          offset + rank,
          '$country-$rank',
          NameCategory.girls,
          country,
          rank,
        ),
    ];
    final rankings = {'FR': ranked('FR', 0), 'US': ranked('US', 1000)};
    final first = equalCountryPool(rankings: rankings, seed: 42);
    final second = equalCountryPool(rankings: rankings, seed: 42);

    expect(first, hasLength(150));
    expect(
      first.map((candidate) => candidate.id),
      second.map((candidate) => candidate.id),
    );
    expect(
      first.where((candidate) => candidate.countries.single == 'FR'),
      hasLength(75),
    );
    expect(
      first.where((candidate) => candidate.countries.single == 'US'),
      hasLength(75),
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
    expect(ranked.first.popularity.single.trend, PopularityTrend.stable);
  });
  test('one-country pool retains truthful country metadata', () {
    final pool = equalCountryPool(
      rankings: {
        'BE': [candidate(8, 'Lina', NameCategory.girls, 'BE', 12)],
      },
      seed: 4,
      shuffle: false,
    );

    expect(pool.single.countries, ['BE']);
    expect(pool.single.popularityLabel, 'Popular in Belgium');
    expect(pool.single.combinedPoolPosition, 1);
  });
  test(
    'three-country pool rewards cross-country relevance without duplicates',
    () {
      final pool = equalCountryPool(
        rankings: {
          'BE': [candidate(1, 'Nora', NameCategory.girls, 'BE', 2)],
          'FR': [candidate(2, 'Nora', NameCategory.girls, 'FR', 3)],
          'NL': [candidate(3, 'Nora', NameCategory.girls, 'NL', 4)],
        },
        seed: 7,
        shuffle: false,
      );

      expect(pool, hasLength(1));
      expect(pool.single.countries, ['BE', 'FR', 'NL']);
      expect(pool.single.combinedRelevanceScore, greaterThan(1));
      expect(
        pool.single.popularityLabel,
        'Popular across 3 selected countries',
      );
    },
  );
  test('same spelling remains separate for girls and boys', () {
    final pool = equalCountryPool(
      rankings: {
        'US': [
          candidate(1, 'Robin', NameCategory.girls, 'US', 1),
          candidate(2, 'Robin', NameCategory.boys, 'US', 1),
        ],
      },
      seed: 1,
      shuffle: false,
    );

    expect(
      pool.map((value) => value.category),
      containsAll([NameCategory.girls, NameCategory.boys]),
    );
  });
  test('short country lists do not starve any selected country', () {
    final pool = equalCountryPool(
      rankings: {
        'A': [candidate(1, 'Ada', NameCategory.girls, 'A', 1)],
        'B': [candidate(2, 'Bea', NameCategory.girls, 'B', 1)],
        'C': [candidate(3, 'Cia', NameCategory.girls, 'C', 1)],
      },
      seed: 1,
      shuffle: false,
    );

    expect(pool.map((value) => value.countries.single), ['A', 'B', 'C']);
  });
  test(
    'seed changes presentation order, never candidate membership or IDs',
    () {
      final rankings = {
        'A': [
          for (var i = 1; i <= 12; i++)
            candidate(i, 'A$i', NameCategory.girls, 'A', i),
        ],
        'B': [
          for (var i = 1; i <= 12; i++)
            candidate(100 + i, 'B$i', NameCategory.girls, 'B', i),
        ],
      };
      final first = equalCountryPool(rankings: rankings, seed: 1);
      final second = equalCountryPool(rankings: rankings, seed: 2);

      expect(
        first.map((value) => value.id).toSet(),
        second.map((value) => value.id).toSet(),
      );
      expect(
        first.map((value) => value.id).toList(),
        isNot(second.map((value) => value.id).toList()),
      );
    },
  );
  test('aggregate popularity has no trend while annual popularity may', () {
    final aggregate = candidate(1, 'Lina', NameCategory.girls, 'BE', 1);
    final annual = candidate(
      2,
      'Lina',
      NameCategory.girls,
      'FR',
      1,
      trend: PopularityTrend.rising,
    );

    expect(aggregate.popularity.single.trend, isNull);
    expect(annual.popularity.single.trend, PopularityTrend.rising);
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
