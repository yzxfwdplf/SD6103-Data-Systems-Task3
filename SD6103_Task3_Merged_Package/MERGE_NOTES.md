# Source integration record

| Input | Preserved | Corrected or replaced |
|---|---|---|
| Prior 2023–2025 package | Audited scoped CSVs, source-row identity, date constraint, six analytical questions, fresh-market unknown status, independent recomputation, academic report layout | Six logical tables and new measurements after integration |
| Teammate GitHub repository | Proximity lookup, bulk loading, verification workflow, native/macOS convenience | No destructive housing reset; no all-history leakage; no optional indexes before baseline; no timing-only simplified queries |
| Uploaded Task3_queries SQL | Query intent and sale-deduplication principle | Replace 1997–1999 Q1 and unrestricted Q2–Q6 with the agreed 2023–2025 scope; deduplicate smaller memberships before sales |

The canonical measurement source is `sql/queries/Q1.sql`–`Q6.sql`. `sql/04_queries.sql` is the concatenated manual execution copy; hashes are stored in each raw observation. Rebuild the manual copy after editing a canonical query.

The final conceptual ER remains the agreed town / HDB address / transaction / hawker structure with the nearby association. `proximity_level` is a logical reference table. It has three disjoint bands: [0,500), [500,1000), [1000,2000] metres. The matching view exposes numeric rank for display order. `hdb_flat` is explicitly a block-address grain; no unit-level identity is invented.

Q5 uses SGD 700,000, fixed before this measurement series, yielding 5 of 22 eligible towns in S5. The teammate's SGD 350,000 is not silently reused: it selects all eligible towns in this scoped sample, defeating the intended selective-budget demonstration.

The archive `provenance/team_repository_snapshot.json` records the retrieved text files and blob identities. Its `tree_sha` is a tree identity, not a commit identity. `provenance/uploaded_Task3_queries.sql` is an unmodified input copy, not the final executable query set.

The Task 4 selection rule was group-level: actual plan usage and geometric ratio < 0.98. It selected the three-index teammate group. Full confirmation retains all three; the two unused members are explicitly identified as pruning candidates, without misrepresenting a not-yet-measured one-index deployment.

The delivered experiment is genuinely executed in PGlite/WASM. The native runner is supplied and syntax-checked, but native server execution and pgAdmin capture remain to be performed. The original historical five-file scaling protocol is distinct from the chosen 36-month hash-partition protocol.
