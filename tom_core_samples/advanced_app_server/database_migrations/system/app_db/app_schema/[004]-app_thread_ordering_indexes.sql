-- Composite indexes for the two ordered child reads on an item: the comment
-- thread and the subtask checklist.
--
-- Untagged on purpose: schema, not demo content, so it reaches every
-- environment — the ordering these support is part of the contract
-- (`appListComments` returns oldest-first, `appListSubtasks` returns
-- position-ordered), not a convenience of the demo seed.
--
-- **Why this is a separate migration rather than an edit to [000].** The
-- `app_comments` / `app_subtasks` tables and their single-column `item_id` keys
-- were created there and are already deployed; a migration list is append-only,
-- so a schema change is a new consecutively numbered file (G-MIG-1) even when
-- it refines a table an earlier file created.
--
-- **Why the existing `item_id` keys are not enough.** `fk_app_comments_item`
-- and `fk_app_subtasks_item` index `item_id` alone, which is what the foreign
-- key needs — it makes the child lookup cheap, but leaves the rows for one item
-- in no particular order. Both new reads select by `item_id` *and* order within
-- it, so a single-column index gets the engine to the right rows and then makes
-- it sort them. Extending the index with the sort column lets the ordering come
-- out of the index itself: no filesort, and — more importantly for a reference
-- sample — the order the endpoint promises is the order the storage layer
-- actually maintains, rather than one re-established on every read.
--
-- The columns are deliberately in read order (the equality predicate first, the
-- sort key second): an index on `(created_at, item_id)` would satisfy neither
-- read, because the leading column is not the one being filtered on.
--
-- `IF NOT EXISTS` keeps the file re-runnable against a database that already
-- has the indexes, matching the `CREATE TABLE IF NOT EXISTS` convention the
-- other migrations in this folder use.

CREATE INDEX IF NOT EXISTS idx_app_comments_item_created
  ON app_comments (item_id, created_at);

CREATE INDEX IF NOT EXISTS idx_app_subtasks_item_position
  ON app_subtasks (item_id, position);
