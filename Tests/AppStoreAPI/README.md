# App Store API workflow regression tests

Run from the repository root:

```sh
python3 Tests/AppStoreAPI/test_workflow.py
```

The 31 tests use Python's standard library and in-memory API clients. They do not
load API credentials, create JWTs, contact Apple, or change an App Store listing.
Network connection attempts fail immediately. Temporary state journals are
removed when each test finishes.

Coverage includes exact app/build guards, missing export-compliance answers,
unrelated review items, repeated submission without duplicate writes, refusal to
retry ambiguous API writes, and credential-origin restrictions. HTTP tests
also verify that nested Apple validation errors expose missing field details
without printing arbitrary metadata or credential content. They
verify recovery from transient GET failures and timeouts within three attempts,
and that POST, PATCH, and DELETE network failures are never retried. Media tests
cover replacement ordering, preservation of existing previews, safe resumption,
failed asset processing, and concurrent placement edits. They also cover delayed
visibility of processed specification IDs and placement ordering: read-only
retries stay bounded, actual specification mismatches stop the workflow, and
ordering requests are not sent twice. Batch tests require every upload to be
committed before processing waits begin, require the whole batch to be ready
before placements change, and prevent stale collection reads from causing a
second upload of a committed asset.

The live API's `ACTIVE` placement state is accepted only after exact asset,
device group, media type, localization, and processed-asset checks. Tests reject
inconsistent targets, failed linked assets, and other undocumented states.
Ordering tests enforce separate screenshot and preview requests within the same
device group, verify each type's sequence, and reject missing or foreign IDs.

These tests validate local workflow behavior; they do not replace checking the
current Apple API contract or reading back the actual submission result.
