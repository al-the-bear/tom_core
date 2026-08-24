-- Second schema under the same data source, for the multi-schema test.
--
-- Its version number is deliberately **000 — the same as
-- `fixture_schema/[000]-create_fixture_widget.sql`** — because that is what
-- makes the fixture discriminating. Each schema keeps its own
-- `<schema>_versioning` history, so two schemas may legitimately both be at
-- version 0. A migrator that carried one schema's applied-version list into the
-- next would see version 0 already recorded here and skip this script without a
-- word (or fail on the differing description), leaving `fixture_gadget`
-- uncreated while reporting success.
--
-- The description differs from the widget migration's on purpose: under the
-- cross-contaminated reading the version matches but the description does not,
-- which surfaces as a checksum/description mismatch rather than a silent skip —
-- either way the fixture fails loudly if the per-schema binding regresses.
CREATE TABLE IF NOT EXISTS fixture_gadget (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NULL,
  PRIMARY KEY (id)
);
