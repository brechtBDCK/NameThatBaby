# NameThatBaby — complete Codex build prompt

Copy this entire prompt into Codex from the root of the repository. Replace the values in the **Placeholders to fill before starting** section when known. Attach the selected UI concept image to the same Codex chat or place it at the referenced path.

---

## ROLE AND OPERATING MODE

Act as the lead mobile engineer, product engineer, privacy engineer, UI implementer, data-pipeline engineer, and test engineer for this repository.

Build a production-quality first version of a cross-platform mobile app called **NameThatBaby** for iOS and Android. Do not merely produce a plan, wireframes, isolated snippets, or pseudocode. Inspect the repository, plan the work, implement the app in coherent milestones, run every verification step available in the environment, repair failures, and leave the repository in a reviewable state.

Work autonomously within the requirements below. Ask me only when:

1. a missing product decision would materially change user-visible behavior;
2. a required credential, signing identity, protected resource, or permission is genuinely unavailable;
3. an irreversible or destructive operation would be required;
4. two requirements conflict and cannot both be satisfied.

Do not ask about decisions already stated in this prompt. For routine implementation details, choose the simplest robust option, document the choice, and proceed.

Before editing:

1. Read all applicable `AGENTS.md` files and repository documentation.
2. Inspect the existing tree, Git state, build configuration, and uncommitted changes.
3. Preserve all unrelated user changes.
4. Determine whether this is an empty repository, an existing Flutter project, or another project that must be adapted.
5. Produce a short execution plan with milestones and measurable completion criteria.
6. Then implement; do not stop after presenting the plan.

Keep a concise progress record in the Codex conversation. At the end of every milestone, run the relevant tests and static checks before continuing. If a check fails, diagnose and fix it rather than simply reporting it.

Do not publish the app, submit it to an app store, push to a remote repository, create a pull request, or access signing credentials unless I explicitly request that later.

## PLACEHOLDERS TO FILL BEFORE STARTING

Use these values if I fill them in. If a value remains bracketed, choose a reversible development-safe value and record it in `docs/DECISIONS.md`; do not block the entire build unless the value is required by a tool.

```text
PROJECT_DIRECTORY: [PATH_TO_REPOSITORY]
APP_DISPLAY_NAME: NameThatBaby
DART_PACKAGE_NAME: [name_that_baby]
IOS_BUNDLE_IDENTIFIER: [com.example.namethatbaby]
ANDROID_APPLICATION_ID: [com.example.namethatbaby]
DEVELOPER_OR_ORGANIZATION_NAME: [DEVELOPER_NAME]
MINIMUM_IOS_VERSION: [CHOOSE_A_CURRENT_PRACTICAL_MINIMUM]
MINIMUM_ANDROID_SDK: [CHOOSE_A_CURRENT_PRACTICAL_MINIMUM]
UI_REFERENCE_IMAGE: [ATTACH_UI_CONCEPT_5_OR_ENTER_LOCAL_PATH]
OPTIONAL_APP_ICON_SOURCE: [NONE_OR_PATH]
OPTIONAL_CUSTOM_FONT: [NONE_OR_FONT_PATH]
ALLOW_LOCAL_GIT_COMMITS: [NO]
MAX_CUSTOM_NAMES_PER_CATEGORY: [25]
MAX_CUSTOM_NAME_LENGTH: [40]
```

When package versions, Flutter versions, Gradle versions, iOS deployment targets, or SDK constraints are not explicitly given, inspect the installed toolchains and current official package metadata. Select mutually compatible stable versions. Do not invent version numbers.

## PRODUCT DEFINITION

NameThatBaby helps two partners independently evaluate baby names and discover the names they both like.

The product has three major phases:

1. **Choose:** each partner privately evaluates the same candidate names with No, Maybe, or Yes.
2. **Shortlist:** the app combines both partners' answers locally and keeps compatible names.
3. **Face-off:** both partners compare same-category names head-to-head until the app produces a shared top-10 list for girls' names and a shared top-10 list for boys' names.

The app must be:

- available for both iOS and Android;
- English-only in version one, but structured so localization can be added later;
- completely usable without an Internet connection after installation;
- free of developer-operated servers, accounts, cloud databases, remote configuration, push services, advertising, analytics, and runtime hosting costs;
- private by design, with all user data stored only on the phones unless the user explicitly displays or exports a QR payload;
- visually based on UI concept 5: warm, organic, joyful, polished, and inclusive without looking childish or nursery-themed.

## NON-NEGOTIABLE PRODUCT DECISIONS

Treat the following as final requirements, not suggestions:

1. Platforms: iOS and Android.
2. Framework: use Flutter and Dart unless the existing repository already contains a compelling, working cross-platform alternative. If so, stop and explain the conflict before replacing it.
3. Runtime architecture: fully local. No backend, hosted API, user account, developer server, analytics endpoint, ad SDK, cloud database, or remote name-data request.
4. Partner synchronization: QR scanning is acceptable and is the required MVP mechanism.
5. Candidate period: use the latest **10 complete years** available for each country dataset. Never use a partial current year.
6. Candidate count: target **150 girls' names and 150 boys' names per naming session**, subject to actual source coverage.
7. Country selection is a cultural candidate filter, not a strength or preference weight. Every selected country has equal opportunity to contribute names. The United States must not dominate smaller countries because it has more births.
8. Swipe decisions: No, Maybe, and Yes.
9. A name advances when neither partner voted No. Therefore Yes/Yes, Yes/Maybe, Maybe/Yes, and Maybe/Maybe all advance. Any pair containing No does not advance.
10. Names that occur in official data for both boys and girls remain independently eligible in both lists. Do not force them into one category and do not create a separate unisex category in version one.
11. Users may add custom names only when entering the Face-off phase, not during initial candidate swiping.
12. Custom names require a category choice: Girls, Boys, or Both. Choosing Both creates independent entries in both category tournaments.
13. Final results are separate top-10 girls' and boys' lists.
14. Use English UI copy only for the MVP.
15. Initial country list:

```text
United States
Canada
Belgium
Netherlands
Denmark
Norway
Sweden
Germany
France
Spain
Italy
Austria
United Kingdom
Ireland
Australia
```

Use stable internal ISO-style identifiers:

```text
US, CA, BE, NL, DK, NO, SE, DE, FR, ES, IT, AT, GB, IE, AU
```

The United Kingdom may require several underlying sources—England and Wales, Scotland, and Northern Ireland—but it should appear as one selectable country in the app. Define and document the aggregation method.

Licensing analysis is not a blocker for the prototype. Retrieve and bundle the actual name rankings where reasonably possible. Nevertheless, preserve source URLs, provider names, edition dates, retrieval dates, and attribution text so release licensing can be reviewed later. Do not claim that redistribution rights have been cleared.

## DEFINITION OF FULLY LOCAL

The finished MVP must satisfy all of these conditions:

- First launch and the entire user journey work in airplane mode.
- All name lists and supporting metadata are bundled in the installed app.
- The app does not create an account or ask for an email address, phone number, social login, or partner identity.
- The app makes no runtime HTTP, WebSocket, telemetry, advertising, or remote-config request.
- Partner pairing and synchronization work through QR codes generated and scanned entirely on-device.
- Vote state, matches, face-off comparisons, custom names, and results are stored in the app sandbox.
- Android production manifests do not request the `INTERNET` permission.
- Android backups are disabled for the local session database and secrets.
- iOS session data is excluded from iCloud backup, and stored secrets must not be synchronizable through iCloud Keychain.
- No crash-reporting or analytics SDK is included.
- No user choices, session keys, decrypted QR payloads, custom names, or result lists are written to logs.
- Deleting a naming session securely removes its locally stored records and locally stored session key.
- Uninstalling the app removes app data through normal operating-system behavior, except for any file the user explicitly exported.

Build-time Internet access is allowed for installing dependencies and retrieving public name datasets. That is distinct from runtime app behavior.

## RECOMMENDED TECHNICAL STACK

Use current stable, mutually compatible packages and document the selected versions. Prefer mature and actively maintained dependencies.

Recommended architecture:

- Flutter/Dart for UI and application logic.
- Feature-first project organization.
- Riverpod or an equivalently testable dependency/state-management system.
- SQLite for both the bundled read-only names database and local user/session data.
- Drift or an equivalently typed SQLite abstraction with explicit migrations.
- GoRouter or an equivalently declarative router.
- A mature local QR renderer.
- A mature on-device camera barcode scanner.
- A well-reviewed cryptography implementation supporting authenticated encryption.
- Secure storage backed by iOS Keychain and Android Keystore, explicitly configured not to synchronize.
- A Python 3 data-ingestion and database-build tool under `tools/name_data/`.

Do not add Firebase, Supabase, Appwrite, Amplify, Realm Sync, CloudKit synchronization, Google Sign-In, advertising frameworks, analytics, hosted feature flags, or any dependency that requires a runtime service.

Prefer platform-standard capabilities and the smallest adequate dependency set. Run dependency-health checks where available. Record every direct dependency and why it is needed in `docs/DEPENDENCIES.md`.

## REQUIRED REPOSITORY STRUCTURE

Adapt this structure to existing conventions if the repository is not empty:

```text
/
  AGENTS.md
  README.md
  pubspec.yaml
  analysis_options.yaml
  assets/
    data/
      names.sqlite
      manifest.json
    illustrations/
    fonts/
  lib/
    main.dart
    app/
      app.dart
      router.dart
      theme/
    core/
      crypto/
      database/
      errors/
      ids/
      qr/
      result/
      time/
      widgets/
    features/
      onboarding/
      country_selection/
      pairing/
      home/
      choosing/
      synchronization/
      shortlist/
      custom_names/
      faceoff/
      results/
      settings/
      data_sources/
    data/
      bundled/
      local/
      models/
      repositories/
    domain/
      candidate_pool/
      matching/
      faceoff/
      synchronization/
  test/
  integration_test/
  tools/
    name_data/
      adapters/
      fixtures/
      raw_cache/
      tests/
      sources.yaml
      build_database.py
      validate_database.py
  docs/
    ARCHITECTURE.md
    DATA_PIPELINE.md
    DATA_SOURCES.md
    PRIVACY.md
    QR_PROTOCOL.md
    DECISIONS.md
    DEPENDENCIES.md
    TESTING.md
```

Do not create empty architecture layers merely for appearance. Each abstraction must have a real purpose and tests where appropriate.

## DOMAIN MODEL

Use immutable domain objects and explicit value types where that prevents invalid state.

At minimum model:

```text
Country
DataSource
DatasetEdition
NameIdentity
NameObservation
NameCategory (girl, boy)
CountryNameRanking
CandidatePoolConfiguration
CandidateEntry
NamingSession
LocalParticipant
VoteValue (no, maybe, yes)
NameVote
SyncEnvelope
SyncEvent
SharedMatch
CustomName
FaceoffEntry
FaceoffPairing
FaceoffChoice
FaceoffRound
FaceoffStanding
FinalRanking
```

Never use an email, phone number, contact, or personally identifying value as an identifier. Generate random local identifiers.

Recommended tables or equivalent normalized storage:

```text
country(
  code PRIMARY KEY,
  display_name,
  enabled
)

data_source(
  id PRIMARY KEY,
  country_code,
  provider,
  source_url,
  edition,
  retrieved_at,
  license_status,
  methodology_notes
)

name(
  id PRIMARY KEY,
  display_name,
  normalized_key
)

name_observation(
  name_id,
  source_id,
  year,
  category,
  count NULLABLE,
  source_rank,
  PRIMARY KEY(name_id, source_id, year, category)
)

naming_session(
  id PRIMARY KEY,
  dataset_hash,
  protocol_version,
  selected_country_codes,
  year_window,
  target_count_per_category,
  deterministic_seed,
  phase,
  created_at,
  updated_at
)

participant(
  id PRIMARY KEY,
  session_id,
  local_label,
  is_local_device
)

vote(
  session_id,
  participant_id,
  category,
  name_id,
  value,
  revision,
  updated_at,
  PRIMARY KEY(session_id, participant_id, category, name_id)
)

custom_name(
  id PRIMARY KEY,
  session_id,
  created_by_participant_id,
  display_name,
  normalized_key,
  category,
  created_at
)

sync_event(
  id PRIMARY KEY,
  session_id,
  source_participant_id,
  sequence_number,
  event_type,
  payload_hash,
  applied_at,
  UNIQUE(session_id, source_participant_id, sequence_number)
)

faceoff_pairing(
  id PRIMARY KEY,
  session_id,
  category,
  round_number,
  left_entry_id,
  right_entry_id,
  pairing_key
)

faceoff_vote(
  pairing_id,
  participant_id,
  chosen_entry_id NULLABLE,
  is_skipped,
  revision,
  PRIMARY KEY(pairing_id, participant_id)
)

faceoff_standing(
  session_id,
  category,
  entry_id,
  score,
  opponents_score,
  comparisons_completed,
  rank
)
```

The bundled names database may be read-only and separate from the mutable session database. If separate databases simplify updates and integrity, use that approach.

## NAME NORMALIZATION RULES

Preserve names faithfully.

1. Store and display the source spelling.
2. Normalize a separate comparison key using Unicode NFC and locale-independent case folding.
3. Trim leading/trailing whitespace and normalize repeated internal whitespace.
4. Preserve diacritics in both display and identity comparison unless a source explicitly provides only an unaccented representation.
5. Do not transliterate names.
6. Do not merge names merely because they sound alike.
7. Do not automatically merge variant spellings such as Sofia/Sophia, Karl/Carl, or Amelia/Amélia.
8. When a source itself groups variants, record that source methodology in metadata; do not pretend the source supplied separate observations.
9. Hyphenated and space-containing names are valid.
10. Reject control characters and invisible formatting characters in custom names.
11. Enforce the configured custom-name length after Unicode normalization.
12. Custom-name duplicate checks are category-specific and compare normalized keys.

The same display name can be present in both girl and boy categories. Treat `(name identity, category)` as the effective candidate identity.

## DATA INGESTION REQUIREMENTS

Build a reproducible data pipeline. Runtime scraping is forbidden.

### Source priority

For each country, use this order:

1. official national statistics or civil-registration open data;
2. official constituent-state/region data where no national dataset exists;
3. a reputable national language/statistics organization where government data is unavailable;
4. a clearly documented public ranking snapshot as a temporary prototype fallback.

Do not silently invent names or rankings. Test fixtures may be synthetic, but the production bundled database must clearly distinguish real imported data from fixtures.

Research and implement adapters for:

| Code | Country | Preferred starting point |
| --- | --- | --- |
| US | United States | Social Security Administration baby-name files |
| CA | Canada | Statistics Canada first names at birth |
| BE | Belgium | Statbel newborn first names |
| NL | Netherlands | Sociale Verzekeringsbank annual child-name rankings or another official national source |
| DK | Denmark | Statistics Denmark newborn names |
| NO | Norway | Statistics Norway Statbank names table |
| SE | Sweden | Statistics Sweden newborn names table |
| DE | Germany | Search for an authoritative national source; if no government series exists, use a reputable documented national ranking source and label it |
| FR | France | INSEE first-name files |
| ES | Spain | Instituto Nacional de Estadística or another official birth-name table |
| IT | Italy | ISTAT newborn-name data or its official query/download interface |
| AT | Austria | Statistics Austria newborn first names |
| GB | United Kingdom | ONS England/Wales + National Records of Scotland + NISRA Northern Ireland; document aggregation |
| IE | Ireland | Central Statistics Office baby names |
| AU | Australia | state and territory birth-registry/open-data lists; document coverage and aggregate without letting populous states dominate |

For every adapter:

- pin or record the upstream edition/date;
- cache the raw downloaded file under a Git-ignored `raw_cache/` directory;
- save a checksum of the raw input;
- parse without depending on spreadsheet UI;
- normalize into a common intermediate format;
- validate year, category, rank, count, text encoding, and duplicates;
- emit actionable errors when the source format changes;
- include a small committed fixture derived from the source structure for adapter tests, when redistribution is reasonable;
- never commit secrets, cookies, session tokens, or signed URLs.

Create `tools/name_data/sources.yaml` with at least:

```yaml
- country_code: US
  provider: Social Security Administration
  source_url: https://www.ssa.gov/oact/babynames/limits.html
  adapter: ssa_us
  expected_format: zip_csv
  enabled: true
  license_status: review_before_release
  notes: names with fewer than the source privacy threshold are omitted
```

Use equivalent records for every country.

### Ten-year window

For each underlying country dataset:

1. Determine its newest complete published year.
2. Select that year and the previous nine complete years.
3. Store the exact chosen year range in the manifest.
4. Do not make all countries use the same ending year if their official publication schedules differ.
5. Do not include a partial year.
6. If fewer than 10 years are available, use the available complete years and flag reduced coverage in metadata and the Data Sources screen.

### Deriving a per-country decade ranking

Convert every country's annual rankings into one deterministic decade ranking for each category.

Use the following default scoring method unless an upstream source only supports a materially different method:

```text
annual_rank_score = 1 / log2(source_rank + 1)
decade_score = sum(annual_rank_score for all available years in the selected window)
```

Give every year in the 10-year window equal weight. The product decision selected a decade window; do not add an unapproved recency preference.

Tie-break in this order:

1. appearance in more years;
2. better rank in the latest available year;
3. better best-ever rank within the window;
4. normalized name key in ascending deterministic order.

If rank is absent but count is present, compute rank within `(country/source group, year, category)` using descending count with deterministic tied ranks. If both are present, preserve the official rank.

### Combining selected countries without weighting them

Selected countries define the eligible cultural pool. They are not population weights and not preference strengths.

Construct exactly one target list of up to 150 unique names per category as follows:

1. Obtain the decade ranking for each selected country.
2. Create a deterministic round-robin iterator over selected country codes sorted by their stable internal code.
3. On each country's turn, take its next highest-ranked name not already in the combined category pool.
4. If that name is already present, continue down that country's list until a new eligible name is found or the list is exhausted.
5. Continue cycling through countries until the category pool reaches 150 unique names or every country list is exhausted.
6. This algorithm gives every selected country equal opportunities to contribute regardless of birth counts or population.
7. Record the countries in which each combined candidate appeared and its best/decade ranks for optional display.
8. Once the pool is complete, shuffle it with the session's deterministic cryptographic seed so partners see the same order without names being grouped by country or popularity.

Do not multiply a country's score because it is listed first or marked as “home.” Version one does not need a primary-country concept.

If only one country is selected, use that country's first 150 unique decade-ranked names per category.

If the selected union contains fewer than 150 names in a category, use every available name and show the actual count. Never pad with names from unselected countries or synthetic entries.

### Bundled database output

The pipeline must produce:

```text
assets/data/names.sqlite
assets/data/manifest.json
docs/DATA_SOURCES.md
```

The manifest must contain:

- schema version;
- generated timestamp;
- deterministic build identifier;
- SHA-256 hash of the SQLite file;
- each country's provider, source URL, edition, retrieval date, covered years, source type, coverage limitations, and adapter version;
- total names and observations by country/category/year;
- validation results;
- a prominent `redistribution_review_required: true` flag until licensing review is completed.

Make database generation deterministic from identical inputs. Add a test that builds twice from fixtures and compares output checksums after normalizing unavoidable SQLite metadata.

## SESSION CREATION AND COUNTRY SELECTION

The first-run experience must not request an account.

Required flow:

1. Welcome screen with app name and concise privacy promise.
2. “Create a naming session” and “Join partner” choices.
3. Creator selects one or more countries from the fixed supported list.
4. Creator selects Girls, Boys, or Both. Default to Both, but make the choice explicit.
5. Show fixed settings: latest 10 complete years and 150 target names per selected category.
6. Creator confirms and the app generates a session.
7. Creator displays a pairing QR.
8. Partner chooses Join and scans that QR.
9. Partner sees a human-readable summary of countries, categories, dataset edition, and candidate counts before accepting.
10. Both devices deterministically generate the same candidate IDs and ordering.

Do not encode the names themselves in the invite when both devices have the same bundled dataset. Encode configuration plus a dataset hash and deterministic seed.

If dataset hashes differ, block joining with a clear message. Do not silently generate different candidate pools.

Suggested user-facing messages:

```text
Private by design
Your names and choices stay on these phones.

Pair your phones
Scan this code on your partner's phone. Nothing is uploaded.

Different name data versions
Both phones need the same NameThatBaby data version before they can pair.
```

## HOME SCREEN

Implement the selected warm-organic visual direction.

The home screen should include:

- NameThatBaby title/wordmark treatment;
- short line: “Find the name you both love.”;
- Girls progress card with percent complete and remaining count;
- Boys progress card with percent complete and remaining count;
- primary “Continue choosing” action;
- partner synchronization status;
- “Private & offline” indicator;
- entry point to Shared favorites when available;
- entry point to Face-off when eligible;
- settings/data-sources access.

Progress must be derived from persisted votes, not an in-memory counter. It must survive process death and app restart.

## CHOOSING / SWIPE PHASE

The core name card must show:

- name in large type;
- current category;
- exact number of names remaining;
- a compact list of selected countries in which the name appears;
- optional decade popularity hint based only on bundled data;
- No, Maybe, and Yes controls with both icons and labels;
- Undo for at least the most recent decision;
- a way to leave and resume without losing progress.

Gestures:

- swipe left = No;
- swipe up or a deliberate middle gesture = Maybe, only if discoverable and accessible;
- swipe right = Yes;
- always provide visible buttons as an equivalent interaction;
- include subtle haptic feedback when enabled by platform/user settings;
- respect reduced-motion preferences;
- prevent accidental double votes during animation.

Do not use color as the only distinction between No, Maybe, and Yes. Ensure screen readers announce the name, category, remaining count, metadata, and action labels.

Partner choices must remain hidden until both vote states are exchanged after the choosing phase. Do not show hints such as “your partner liked this.”

When the current category is complete, show completion state and clear next actions. When both enabled categories are complete, guide the user to QR vote synchronization.

## VOTE MATCHING RULES

Implement exactly this matrix:

| Partner A | Partner B | Advances? | Match tier |
| --- | --- | --- | --- |
| Yes | Yes | Yes | Strong |
| Yes | Maybe | Yes | Consider |
| Maybe | Yes | Yes | Consider |
| Maybe | Maybe | Yes | Consider |
| No | Yes | No | Rejected |
| Yes | No | No | Rejected |
| No | Maybe | No | Rejected |
| Maybe | No | No | Rejected |
| No | No | No | Rejected |

No is a veto for advancement. Maybe always remains eligible when paired with Yes or Maybe.

Store rejected names locally so Undo/history and future local review remain possible, but keep them out of Face-off.

## QR PAIRING AND SYNCHRONIZATION PROTOCOL

Implement a documented, versioned, testable protocol. Do not use a third-party QR generation or decoding web service.

### Security goals

- Prevent accidental cross-session imports.
- Detect corrupted, truncated, modified, replayed, and wrong-version payloads.
- Keep vote/custom-name content unreadable to a casual third-party QR scan after pairing.
- Avoid storing or logging plaintext payloads outside the encrypted local database/application state.
- Make repeated scans idempotent.

### Pairing invite

The creator generates:

- random session ID;
- random local participant/device ID;
- random 256-bit session secret using the operating system CSPRNG;
- deterministic candidate-shuffle seed;
- protocol version;
- dataset schema version and content hash;
- selected countries;
- enabled categories;
- fixed window and target count;
- creation timestamp and optional expiry for the invitation display.

The initial pairing QR may carry the session secret because it is the out-of-band local pairing ceremony. Explain that anyone who scans the invite while visible could join; allow the creator to regenerate the invitation before voting begins.

After scanning, the joining phone creates its own participant ID and displays a short confirmation code derived from the session key and both participant IDs. Show the same short code on both devices so the partners can visually confirm pairing.

### Update envelopes

Use a compact canonical binary representation such as CBOR, optional compression, and authenticated encryption such as AES-GCM or ChaCha20-Poly1305 through a reviewed library.

Each encrypted update envelope must include:

```text
protocol_version
event_type
session_id
source_participant_id
sequence_number
dataset_hash
created_at
payload
nonce
authentication_tag
```

Supported event types should include at least:

```text
PAIR_ACCEPT
CHOOSING_VOTES
CUSTOM_NAMES
FACEOFF_VOTES
MERGED_STATE_ACKNOWLEDGEMENT
```

Use stable numeric candidate IDs from the bundled data instead of name strings in choosing-vote packets. Encode three-way votes compactly. Include custom-name text only in encrypted custom-name events.

The receiver must validate, in order:

1. QR framing and payload length limits;
2. protocol version;
3. session ID;
4. source participant ID;
5. dataset hash where relevant;
6. authenticated decryption;
7. payload schema;
8. sequence/replay status;
9. semantic validity of referenced IDs and categories;
10. transactional database merge.

If validation fails, make no partial changes.

Merges must be idempotent. Use event identity and per-record revisions so scanning the same QR twice does not duplicate or regress data.

### QR size and framing

- Measure actual encoded sizes with 150 names per category and both categories enabled.
- Prefer one QR per update when possible.
- If the encrypted payload exceeds a reliable QR capacity at an accessible scanning distance, implement deterministic chunking or animated multi-frame QR with frame index, total frames, envelope hash, and reassembly validation.
- Do not reduce cryptographic integrity to fit a QR.
- Limit and validate custom-name count and length using the configured placeholders.
- Show scanning progress for multi-frame payloads.

### Required exchange UX

At the end of choosing:

1. Device A displays its vote-update QR; Device B scans it.
2. Device B displays its vote-update QR; Device A scans it.
3. Each device calculates the same shortlist.
4. Each device shows a comparable match-count summary.

Use the same bidirectional pattern for custom-name changes and Face-off round votes. If an acknowledgement QR can safely reduce confusion, implement it, but do not require unnecessary extra scans.

Show clear state such as:

```text
Your choices are ready
Waiting for partner's choices
Partner choices received
Both phones are up to date
```

## SHARED SHORTLIST

After both choosing-vote packets are present, show:

- separate Girls and Boys tabs;
- count of Strong matches and Consider matches;
- Strong matches first by default;
- alphabetical and source-popularity sort options;
- each name's two vote values without identifying people beyond “You” and “Partner”;
- country occurrence metadata;
- action to begin Face-off.

Do not rank the final top 10 purely from initial popularity. Popularity chooses candidates; the partners' Face-off choices determine their result.

## CUSTOM NAMES

Custom names are available only at the transition from Shortlist to Face-off and from a dedicated Face-off setup screen.

Rules:

- Do not expose custom-name entry during onboarding or initial choosing.
- Either partner may add a custom name.
- Require a category selection: Girls, Boys, or Both.
- Normalize and deduplicate within each category.
- When Both is selected, create linked but independent girl and boy Face-off entries.
- Enforce the configured maximum length and maximum count.
- Permit apostrophes, hyphens, spaces, and Unicode letters.
- Reject blank strings, control characters, all-punctuation values, and invisible-only values.
- Show which entries were manually added, but do not visually penalize them.
- Synchronize custom names through an encrypted QR update before starting the first Face-off round.
- Resolve simultaneous duplicate additions deterministically by normalized key/category.
- Allow deletion only before the first Face-off vote involving that custom entry. After it has been compared, require restarting the Face-off phase to remove it so standings remain consistent.

## FACE-OFF / SWISS-STYLE RANKING

The UI may call the phase “Face-off” or “Knockout,” but the ranking engine must not be a fragile single-elimination bracket.

Run girls' and boys' tournaments independently. Never create a girl-versus-boy pairing, even when the same display name exists in both categories.

### Entry pool

For each category:

```text
Face-off entries = all advanced shared matches in that category
                  + synchronized custom entries in that category
```

If there are zero entries, show an empty result with an option to add custom names.

If there are 1–10 entries, comparison may be offered to order them, but do not eliminate any merely to force 10.

If there are more than 10 entries, run sufficient comparisons to derive a stable top 10.

### Initial seeding

Use the following only for initial pairing and final tie-breaking:

```text
Yes/Yes     seed tier 3
Yes/Maybe   seed tier 2
Maybe/Yes   seed tier 2
Maybe/Maybe seed tier 1
Custom      seed tier 2
```

Do not let official name popularity decide Face-off scores.

### Pair scheduling

Implement a deterministic Swiss-style scheduler:

- pair entries with similar current scores;
- avoid repeat pairings until unavoidable;
- balance left/right presentation counts;
- ensure every viable entry receives a similar number of comparisons;
- use deterministic IDs and the session seed for stable tie-breaking;
- support an odd entry count with a bye that does not count as a win;
- generate identical pairings on both phones from identical synchronized state;
- persist the round before accepting votes;
- never regenerate different active pairings after an app restart.

### Partner voting

Each screen shows two names from the same category and asks which name the user prefers.

Required actions:

- choose left;
- choose right;
- skip this pairing without assigning a winner;
- Undo the most recent unsynchronized comparison vote.

Partner votes remain private until the round QR exchange.

### Shared scoring

For each pairing after both votes are synchronized:

- both partners choose the same entry: chosen entry gets 3 points, other gets 0;
- partners choose opposite entries: both get 1 point, representing a draw;
- one or both partners skip: do not score the pairing; reschedule each affected entry against different opponents later;
- never eliminate an entry solely because the partners disagreed in one pairing.

Use opponent-strength score as the first standings tie-breaker. Then use:

1. number of unanimous wins;
2. initial seed tier;
3. deterministic session-seeded ordering.

Do not use alphabetical order as a user-visible ranking tie-breaker.

### Stability and stopping

Create a pure, heavily tested ranking engine.

For more than 10 entries, continue rounds until:

- every entry has at least `[MIN_COMPARISONS_PER_ENTRY: 3]` scored comparisons where feasible; and
- the membership of the top 10 remains unchanged across `[STABLE_ROUNDS_REQUIRED: 2]` completed scored rounds; or
- a documented safety maximum of `[MAX_COMPARISONS_PER_ENTRY: 7]` is reached.

If the maximum is reached with unresolved ties crossing the tenth-place boundary, generate targeted tie-break pairings among only the tied boundary group.

Document the exact algorithm and invariants in `docs/ARCHITECTURE.md`. The algorithm must be deterministic from the synchronized event set.

### Face-off progress

Show:

- current category;
- round number;
- comparisons remaining on this device;
- synchronization state;
- current provisional standings only after both partners' round votes have been synchronized;
- an explanation that disagreements keep both names in contention.

## FINAL RESULTS

Produce separate Girls and Boys results.

Each result screen must:

- show ranks 1 through up to 10;
- show fewer than 10 honestly when fewer entries exist;
- mark custom names discreetly;
- show original mutual vote tier;
- provide a compact country occurrence/popularity summary for bundled names;
- permit adding a local private note to a result;
- support re-opening the final standings without rerunning the tournament;
- offer a local share/export preview only if it can be implemented without a server.

If export is included, generate entirely on-device and use the operating system share sheet. Make clear that after the user invokes the share sheet, the chosen destination may be online and is outside NameThatBaby's control. Do not enable export by default if it would add excessive scope.

## VISUAL DESIGN — USE CONCEPT 5

Use the attached/provided UI reference as the primary visual target. Reproduce its design language, not its literal phone-frame mockup.

Design character:

- warm organic joy;
- soft oat/cream surfaces;
- forest green primary text/actions;
- terracotta, sky blue, and marigold accents;
- hand-drawn botanical motifs;
- gently irregular rounded containers where practical;
- friendly humanist typography;
- tactile but restrained paper-like texture;
- polished and calm;
- inclusive and adult;
- no baby photography;
- no nursery clichés;
- no pink-for-girls/blue-for-boys system;
- no excessive decorative density during long choosing sessions.

Start with these provisional semantic tokens, then tune them against the supplied reference while preserving contrast:

```text
background:        #F6F0E4
surface:           #FFF9EF
surfaceMuted:      #EFE4D3
primaryForest:     #244B38
primaryForestDark: #173326
terracotta:        #C65D3B
sky:               #AFCEDB
marigold:          #D79A29
textPrimary:       #183128
textSecondary:     #56665C
outline:           #D7C9B6
danger:            #A94438
```

Treat these as design starting points, not permission to violate accessibility contrast.

Create semantic theme tokens for:

- color roles;
- typography roles;
- spacing scale;
- radii;
- elevation/shadows;
- animation durations/curves;
- icon sizing;
- minimum touch targets.

Do not hard-code raw colors and spacing repeatedly inside feature widgets.

Use code-native vector/simple illustration assets, locally bundled SVGs, or `CustomPainter` when appropriate. Do not copy third-party artwork. Do not fetch decorative assets at runtime.

If no custom font is provided, use a platform-appropriate bundled/system humanist sans-serif. Do not add a runtime font fetch. If an open-source font is bundled, include its license.

Support light theme first. Structure tokens so a future dark theme is possible, but do not let dark-mode work delay the MVP.

## REQUIRED SCREENS

Implement complete, navigable states for:

1. Welcome/privacy promise.
2. Create or join session.
3. Country multi-selection.
4. Category selection and session summary.
5. Pairing QR display.
6. Pairing QR scanner and confirmation.
7. Home/dashboard.
8. Choosing/swipe card.
9. Choosing completion.
10. Vote QR display.
11. Vote QR scanner/import result.
12. Shared shortlist.
13. Add custom names.
14. Custom-name QR synchronization.
15. Face-off introduction.
16. Face-off comparison.
17. Face-off round completion and QR sync.
18. Provisional standings.
19. Final Girls ranking.
20. Final Boys ranking.
21. Settings/privacy/delete session.
22. Data Sources and dataset coverage.
23. Error/recovery states for invalid QR, wrong session, bad authentication, different dataset, duplicated packet, camera denial, and interrupted scan.

Do not leave core screens as disconnected gallery examples. They must read and update real local state.

## ACCESSIBILITY

Meet platform accessibility expectations and target WCAG 2.2 AA contrast for relevant text and controls.

- Minimum touch target of 44×44 logical points or the platform equivalent.
- Dynamic text sizing without clipping critical actions.
- Meaningful semantics for all controls and progress.
- Screen-reader order follows visual/task order.
- Icons have labels; color is never the sole signal.
- Gestures have visible button alternatives.
- Reduced-motion preference disables or simplifies card movement.
- QR instructions are spoken clearly and do not rely only on animation.
- Error messages explain recovery action.
- Focus is moved to the result/status after a scan or import.
- Botanical decoration is excluded from the semantics tree.
- Test at high text scale and narrow supported screens.

## ERROR HANDLING AND RECOVERY

Use typed/domain errors and user-actionable messages.

Handle at least:

- bundled database missing or corrupt;
- manifest/database hash mismatch;
- unsupported country data;
- selected country has insufficient names;
- session resume after process termination;
- camera permission denied;
- invalid or unrelated QR;
- QR from a different NameThatBaby session;
- payload from a newer unsupported protocol;
- authentication failure;
- duplicate/replayed update;
- dataset version mismatch;
- partial multi-frame QR transfer;
- database transaction failure;
- simultaneous custom-name additions;
- face-off round state differs between phones;
- fewer than 10 final candidates;
- zero candidates after mutual voting.

Never reset or discard a session automatically after a recoverable error. Provide retry, back, and delete-session choices as appropriate.

## PRIVACY AND PLATFORM HARDENING

Implement and document:

- secure random session identifiers and keys;
- authenticated encryption for post-pairing QR content;
- non-synchronizing secure-key storage;
- database file protection appropriate to each platform;
- Android backup/data-extraction exclusions;
- iOS backup exclusion for session data;
- database parameter binding, never interpolated SQL;
- no sensitive debug logging;
- release-mode removal/disablement of development logs;
- validation and length limits for every decoded payload;
- transactional imports;
- clearing plaintext buffers where the language/runtime reasonably allows;
- explicit session deletion;
- a local privacy page that plainly explains what is and is not stored.

Do not make unverifiable claims such as “military-grade encryption” or “100% secure.”

Suggested privacy copy:

```text
Your choices stay on your phones.

NameThatBaby has no account and no server. Name lists are included with the app.
You share a session only by showing and scanning codes with your partner.
```

## TESTING STRATEGY

Create meaningful tests, not only smoke tests.

### Unit tests

Test:

- Unicode name normalization;
- category-independent duplicate behavior;
- decade ranking from annual ranks;
- equal-country round-robin candidate assembly;
- deterministic candidate ordering from a seed;
- exact 150-name target when enough source data exists;
- graceful short pool when fewer names exist;
- complete 3×3 vote matching matrix;
- progress/remaining calculations;
- Undo and persisted resume;
- custom-name validation and deduplication;
- names in both categories remain in both;
- Face-off pair scheduling;
- repeat-pair avoidance;
- left/right balance;
- bye behavior;
- unanimous win, disagreement draw, and skip scoring;
- opponent-strength tie-break;
- stability/top-10 stopping condition;
- boundary tie-break scheduling;
- event idempotency;
- sequence/replay validation;
- QR encrypt/decrypt round-trip;
- tamper detection;
- wrong-key and wrong-session rejection;
- deterministic merge convergence regardless of import order.

### Property/fuzz tests

Where practical, generate randomized sessions and verify:

- candidate pool never contains an unselected-country-only name;
- candidate pool contains no duplicate `(normalized key, category)`;
- country iterator is not population-weighted;
- Face-off never pairs across categories;
- every pairing contains two different entries;
- score totals follow the scoring rules;
- merged states converge on both devices;
- corrupted QR bytes never partially mutate storage;
- arbitrary Unicode custom input cannot crash rendering or persistence.

### Widget/golden tests

Cover the main states at:

- a compact phone size;
- a typical modern iPhone size;
- a typical modern Android size;
- default and large text scale;
- light theme;
- reduced motion where testable.

Golden-test at least Home, Choosing, Shared shortlist, Add custom names, Face-off, and Final results. Keep golden updates intentional and documented.

### Integration tests

Implement a two-device simulation at the repository/domain level:

1. Device A creates session.
2. Device B imports invite.
3. Both produce the same candidate pool.
4. Each votes differently.
5. They exchange serialized QR payloads.
6. Both derive identical shortlists.
7. Both add/synchronize custom names.
8. Both generate identical Face-off pairings.
9. They exchange round votes in different import orders.
10. Both converge to identical standings and final top 10.

Add an airplane-mode/manual QA checklist covering the complete physical-device flow.

## DATA VALIDATION

The pipeline and app startup validation should fail clearly on:

- duplicate source rows;
- invalid country code;
- invalid category;
- year outside plausible bounds;
- rank less than 1;
- negative count;
- name empty after normalization;
- invalid encoding;
- duplicate bundled primary IDs;
- source/manifest mismatch;
- missing required decade coverage without an explicit coverage exception;
- app database schema newer than the app supports.

Generate summary statistics and inspect for implausible anomalies, such as a country/category with zero names or a sudden order-of-magnitude row-count change.

## PERFORMANCE TARGETS

- Cold start should not parse large JSON name files; query indexed SQLite.
- Swiping should remain smooth on mid-range supported devices.
- Vote persistence should complete before advancing irreversibly to the next card.
- Candidate pool generation should be deterministic and complete quickly from bundled indices.
- QR encoding should not block the UI thread.
- SQLite queries must use appropriate indices.
- Do not load the entire historical observation table into widget memory.
- Measure and report the bundled database size and release asset impact.

## REQUIRED DOCUMENTATION

Create or update:

### `README.md`

Include:

- product overview;
- privacy/offline promise;
- screenshots or placeholders for screenshots;
- supported platforms;
- prerequisites;
- exact setup commands;
- how to run tests;
- how to rebuild name data;
- current country/data coverage;
- known limitations;
- explicit statement that licensing review remains before public distribution.

### `AGENTS.md`

Include durable repository instructions for future Codex work:

- architecture boundaries;
- formatting/analyze/test commands;
- generated-file rules;
- data-source adapter conventions;
- no-runtime-network invariant;
- QR protocol compatibility requirements;
- migration requirements;
- how to update goldens;
- files that must not contain secrets;
- definition of done for feature changes.

### `docs/ARCHITECTURE.md`

Document module boundaries, dependency direction, databases, session lifecycle, candidate algorithm, match matrix, Face-off algorithm, and deterministic-state requirements.

### `docs/DATA_PIPELINE.md`

Document source acquisition, adapters, normalization, decade ranking, equal-country round-robin assembly, database generation, validation, and update procedure.

### `docs/DATA_SOURCES.md`

List all 15 countries, actual source URLs, editions, year windows, methodology caveats, coverage status, and licensing-review status.

### `docs/QR_PROTOCOL.md`

Document versions, envelope format, encryption/authentication, event types, sequence handling, replay behavior, chunking, limits, error codes, and compatibility policy. Do not include actual secrets or sample production keys.

### `docs/PRIVACY.md`

Document runtime data flow, storage locations, backup exclusions, permissions, logs, deletion behavior, build-time network use, and share-sheet caveat.

### `docs/DECISIONS.md`

Record important implementation choices, especially any placeholder value selected by Codex and any data-source fallback.

### `docs/TESTING.md`

Document automated commands and the real-device iPhone↔Android QR test matrix.

## IMPLEMENTATION MILESTONES

Proceed in this order unless the existing repository makes a different order necessary.

### Milestone 0 — repository assessment

- Inspect repository and instructions.
- Record toolchain versions.
- Identify existing user changes.
- Create implementation plan and risk list.
- Resolve placeholder defaults that do not require user input.

Completion criteria: repository state understood; no unrelated files overwritten.

### Milestone 1 — Flutter foundation and design system

- Scaffold/repair Flutter iOS and Android targets.
- Add routing, state management, typed persistence, theme tokens, and core error model.
- Implement concept-5 design foundation and reusable widgets.
- Add linting, initial tests, and documentation skeleton.

Completion criteria: app launches to Welcome on supported local target; formatting, analysis, and tests pass.

### Milestone 2 — vertical slice with deterministic fixtures

- Create a small committed fixture database.
- Implement onboarding, session creation, country/category selection, Home, Choosing, persistence, Undo, completion, matching, shortlist, custom names, a minimal Face-off, and results using fixtures.
- Implement domain logic before relying on real datasets.

Completion criteria: one-device simulated end-to-end flow works after restart; unit/widget tests pass.

### Milestone 3 — QR protocol and two-device convergence

- Implement local invite QR.
- Implement encrypted vote/custom-name/Face-off updates.
- Add validation, idempotency, replays, mismatch handling, and two-device simulation.
- Add camera permission UX.

Completion criteria: two simulated devices converge; tamper/wrong-session tests pass; no runtime service exists.

### Milestone 4 — real data pipeline

- Implement reusable pipeline foundation.
- Add adapters country by country.
- Prefer completing US, CA, GB, FR, BE, NO, DK, SE, AT, and IE first because strong structured sources are likely available.
- Then complete NL, DE, ES, IT, and AU using documented authoritative/fallback methods.
- Generate and validate production bundled database and manifest.

Completion criteria: all 15 countries appear in the app with real name data or an explicitly documented temporary coverage fallback; database validation passes; licensing remains flagged but does not block prototype completion.

### Milestone 5 — complete Swiss-style Face-off

- Implement deterministic scheduling, scoring, standings, stopping, boundary tie-breaks, persistence, synchronization, and all edge cases.
- Replace any simplistic milestone-2 ranking logic.

Completion criteria: property tests and two-device convergence tests pass; top-10 membership is deterministic.

### Milestone 6 — accessibility, privacy, and platform hardening

- Complete screen semantics, large text, contrast, reduced motion, backup exclusions, non-syncing secure storage, session deletion, no-log review, manifest permissions, and offline audit.

Completion criteria: documented privacy checklist passes; Android has no Internet permission; no runtime endpoint/dependency remains.

### Milestone 7 — final verification and handoff

- Run formatter, analyzer, unit tests, widget tests, golden tests, pipeline tests, integration tests, and supported platform builds.
- Inspect UI renders/screenshots.
- Fix failures.
- Update all docs.
- Produce a concise handoff with completed features, commands run, data coverage, known limitations, and exact next manual steps.

Completion criteria: every available automated check passes or a toolchain-specific limitation is clearly evidenced with the exact command/output and remaining action.

## VERIFICATION COMMANDS

Adapt commands to the repository and installed toolchain, but expect to run equivalents of:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
python3 -m pytest tools/name_data/tests
python3 tools/name_data/validate_database.py assets/data/names.sqlite assets/data/manifest.json
flutter build apk --debug
```

Run an iOS simulator build when on macOS with Xcode. If the environment cannot build iOS, do not pretend it succeeded; validate the Dart/Flutter code and iOS project configuration as far as possible, then state the exact macOS/Xcode command required.

Also audit:

```text
- Android merged manifest contains no INTERNET permission.
- No runtime HTTP client usage or endpoint configuration exists.
- No analytics/crash-reporting/ad package is present.
- Session database and keys are excluded from cloud backup/synchronization.
- Bundled data loads in airplane mode.
- App resumes at the exact persisted progress after forced termination.
```

## CODE QUALITY RULES

- Prefer clear, boring, testable code over clever abstractions.
- Keep domain algorithms pure and independent of Flutter widgets.
- Inject clocks, random/seed sources, storage, and cryptography boundaries for tests.
- Use exhaustive enum handling.
- Avoid untyped maps beyond serialization boundaries.
- Keep generated files generated; never hand-edit them.
- Use database transactions for imports and multi-record state changes.
- Write migrations for mutable database schema changes.
- Use parameterized SQL.
- Do not swallow exceptions.
- Convert technical failures into typed errors and actionable UI.
- Comment the why, not obvious syntax.
- Do not leave TODOs for core requirements.
- Temporary coverage fallbacks must have issue-style documentation with country, reason, source, and replacement plan.
- Keep secrets and personal data out of fixtures and logs.

## ACCEPTANCE TEST SCENARIO

The implementation is not complete until this scenario works:

1. Install release-like builds on one iPhone and one Android phone.
2. Enable airplane mode on both; re-enable only camera functionality needed by the OS.
3. Device A creates a session selecting United States, France, and Netherlands, both categories.
4. App generates at most 150 girls' and 150 boys' candidates using equal-country contribution—not raw birth-count weighting.
5. Device B joins by scanning Device A's invite QR.
6. Both phones show identical session configuration and candidate counts.
7. Both users make different Yes/Maybe/No choices.
8. Progress and remaining names persist after force-closing and reopening each app.
9. They exchange vote QRs in both directions.
10. Yes/Yes, Yes/Maybe, Maybe/Yes, and Maybe/Maybe advance; every combination with No does not.
11. A name present in both categories remains available separately in both.
12. Each partner adds at least one custom name during Face-off setup, including one categorized Both.
13. They exchange custom-name QR updates and both phones converge.
14. They complete multiple Face-off rounds, including one unanimous result, one disagreement, and one skipped pairing.
15. They exchange round QRs and see identical standings.
16. Face-off ends with identical top-10 membership and ranking on both devices.
17. The app displays separate Girls and Boys final results.
18. Neither phone made a runtime network request or required a developer-operated service.
19. Deleting the session removes it and its key locally.

## FINAL HANDOFF FORMAT

When work is complete, answer with:

1. **Outcome:** what is implemented and usable.
2. **Key decisions:** only decisions not already dictated by this prompt.
3. **Data coverage:** one row per country with source, years, record counts, and limitations.
4. **Privacy verification:** evidence that runtime networking, backups, analytics, and logs meet requirements.
5. **Tests and builds:** exact commands and pass/fail status.
6. **Files to review:** the most important source and documentation files.
7. **Manual testing remaining:** especially physical iPhone↔Android QR tests and signing.
8. **Known limitations:** specific and honest.
9. **Next recommended milestone:** one concise recommendation.

Do not claim success for checks you did not run. Do not call the app production-ready until physical cross-platform QR testing, release signing, source licensing review, accessibility review, and store review requirements are completed.

## START NOW

Begin by inspecting the repository and applicable instructions. Then present the short milestone plan and immediately implement Milestone 0 and Milestone 1. Continue through later milestones autonomously while the environment and permissions allow. Preserve unrelated work, verify after each milestone, and keep the fully-local privacy invariant intact throughout.

