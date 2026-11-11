-- The enterprise type's tree evolves on its own: its tenants search their
-- contracts by title. The standard type's tree has no such migration.
CREATE INDEX ix_mt_contract_title ON mt_contract (title);
