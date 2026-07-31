# Architecture

`lib/core/domain.dart` holds pure normalization, matching, candidate pool and Swiss-style pairing functions. `SessionStore` owns local app state; UI widgets only render state and dispatch actions. Candidates are category-specific identities. The candidate combiner cycles country codes in lexical order, skips duplicate normalized category names, then seed-shuffles the completed pool. A No vote vetoes a match; Yes/Yes is Strong and every non-No mixed pair is Consider.

The next-round scheduler orders by score, avoids prior pairs where possible, and leaves an odd entry unpaired (a non-scoring bye). A production implementation must persist transactions and encrypted events before accepting votes.
