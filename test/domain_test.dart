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
}
