SET search_path = housing, public; -- Use the measured schema.

CREATE INDEX t4_team_month_type ON resale_transaction(sale_month,flat_type); -- Re-test the teammate's general date/type index.

CREATE INDEX t4_team_flat ON resale_transaction(flat_id); -- Re-test the teammate's foreign-key lookup index.

CREATE INDEX t4_team_lease ON resale_transaction(remaining_lease_months); -- Test whether CASE grouping benefits in practice.
