-- Reference migration for the subject-key store of crypto-shredding
-- (`TomSqlSubjectKeyStore`).
--
-- Creates `tom_subject_key`: one row per data subject, the key their personal
-- values in the audit trail are sealed under, wrapped under a key-encryption
-- key that never reaches the database. Erasing the subject deletes the row and
-- with it every way to read those values; the trail is never rewritten. This
-- file is the canonical DDL and is kept in sync with `subjectKeyTable()` in
-- `lib/src/tomserver/privacy/subject_keys_sql.dart`;
-- `test/framework_schema_test.dart` replays this chain and compares the schema
-- it builds against the descriptor, so the two cannot drift apart.
--
-- Apply this file when the application's database user is not permitted to run
-- DDL, and configure the store with `createSchema: false`. Under tenancy with a
-- database or schema per tenant, apply it in each tenant's tree.
--
-- Notes on the shape:
--
--  * the primary key is `(tenant, subject_id)`; `tenant` is '' outside tenancy.
--  * `wrapped_key` is the key encrypted under the key-encryption key `kek_id`
--    names (base64): the table never holds a usable key.
CREATE TABLE IF NOT EXISTS tom_subject_key (
  tenant      VARCHAR(32)  NOT NULL,
  subject_id  VARCHAR(191) NOT NULL,
  kek_id      VARCHAR(128) NOT NULL,
  wrapped_key VARCHAR(255) NOT NULL,
  created_at  DATETIME(6)  NOT NULL,
  PRIMARY KEY (tenant, subject_id)
);
