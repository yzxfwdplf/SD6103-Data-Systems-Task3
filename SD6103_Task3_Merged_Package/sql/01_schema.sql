BEGIN; -- Create one consistent six-relation instance.
CREATE SCHEMA housing; -- Use a new database or a fresh dedicated schema.
SET search_path = housing, public; -- Resolve unqualified project table names.
CREATE TABLE town ( -- Store town names once.
 town_id integer PRIMARY KEY, -- Preserve stable source town identifiers.
 town_name varchar(80) NOT NULL UNIQUE -- Prevent duplicate town names.
);
CREATE TABLE hdb_flat ( -- Represent one geocoded block-address record.
 flat_id bigint PRIMARY KEY, -- Map the conceptual flat key to the audited block key.
 town_id integer NOT NULL REFERENCES town(town_id), -- Assign each address to one town.
 block varchar(16) NOT NULL, -- Retain the block number, including letter suffixes.
 street_name varchar(120) NOT NULL, -- Retain the normalized street name.
 postal_code char(6), -- Preserve nullable postal codes as text.
 latitude numeric(9,6) NOT NULL, -- Use the audited HDB coordinate precision.
 longitude numeric(9,6) NOT NULL, -- Use the audited HDB coordinate precision.
 UNIQUE(block,street_name), -- Permit only one row per block and street.
 CHECK(postal_code IS NULL OR postal_code ~ '^[0-9]{6}$') -- Reject invalid nonempty postcodes.
);
CREATE TABLE resale_transaction ( -- Store a sale observation separately from its address.
 transaction_id bigint PRIMARY KEY, -- Keep the original transaction identifier.
 flat_id bigint NOT NULL REFERENCES hdb_flat(flat_id), -- Link each sale to one address.
 sale_month date NOT NULL, -- Store the first day of each sale month.
 flat_type varchar(20) NOT NULL, -- Keep room type at transaction grain.
 storey_range varchar(20) NOT NULL, -- Keep the reported storey interval.
 floor_area_sqm numeric(7,2) NOT NULL CHECK(floor_area_sqm>0), -- Require positive area.
 flat_model varchar(60) NOT NULL, -- Preserve the source model description.
 lease_commence_year smallint NOT NULL, -- Keep the declared lease start year.
 remaining_lease_months integer NOT NULL CHECK(remaining_lease_months BETWEEN 0 AND 1188), -- Use a common month unit.
 resale_price numeric(12,2) NOT NULL CHECK(resale_price>0), -- Require a positive nominal SGD amount.
 source_row_key char(64) NOT NULL UNIQUE, -- Preserve distinct source observations.
 CHECK(sale_month >= DATE '2023-01-01' AND sale_month < DATE '2026-01-01'), -- Enforce the common 36-month scope.
 CHECK(sale_month=date_trunc('month',sale_month)::date) -- Require a first-of-month date.
);
CREATE TABLE hawker_centre ( -- Retain the supplied reference snapshot.
 hawker_id integer PRIMARY KEY, -- Preserve the source hawker key.
 hawker_name varchar(200) NOT NULL UNIQUE, -- Store one centre name per key.
 address varchar(300), -- Keep missing addresses as NULL.
 latitude numeric(12,9) NOT NULL, -- Preserve the source coordinate precision.
 longitude numeric(12,9) NOT NULL, -- Preserve the source coordinate precision.
 market_stall_count smallint CHECK(market_stall_count>=0), -- Keep unknown counts nullable.
 has_fresh_market boolean GENERATED ALWAYS AS ( -- Derive status from the source stall count.
  CASE WHEN market_stall_count IS NULL THEN NULL -- Preserve unknown status.
       ELSE market_stall_count>0 END -- Distinguish confirmed yes from confirmed no.
 ) STORED -- Prevent independent edits that contradict the count.
);
CREATE TABLE proximity_level ( -- Keep the teammate's configurable three-band lookup.
 proximity_level_id smallint PRIMARY KEY, -- Use the band key as its display rank.
 level_name varchar(20) NOT NULL UNIQUE, -- Name each distance class once.
 min_distance_m integer NOT NULL, -- Store the inclusive lower boundary in metres.
 max_distance_m integer NOT NULL, -- Store the upper boundary in metres.
 upper_inclusive boolean NOT NULL DEFAULT false, -- Include only the last upper boundary.
 CHECK(min_distance_m>=0 AND max_distance_m>min_distance_m), -- Reject inverted intervals.
 EXCLUDE USING gist (numrange(min_distance_m::numeric,max_distance_m::numeric,
  CASE WHEN upper_inclusive THEN '[]' ELSE '[)' END) WITH &&) -- Reject overlapping bands.
);
CREATE TABLE nearby ( -- Map the M:N address-hawker relationship.
 flat_id bigint NOT NULL REFERENCES hdb_flat(flat_id), -- Identify the linked address.
 hawker_id integer NOT NULL REFERENCES hawker_centre(hawker_id), -- Identify the linked centre.
 distance_m numeric(9,2) NOT NULL CHECK(distance_m BETWEEN 0 AND 2000), -- Store only retained distances.
 PRIMARY KEY(flat_id,hawker_id) -- Prevent duplicate address-centre pairs.
);
CREATE VIEW nearby_classified AS -- Classify stored distances from the shared lookup.
SELECT n.flat_id,n.hawker_id,n.distance_m, -- Preserve each relationship key and exact distance.
 p.proximity_level_id,p.level_name AS proximity_class, -- Expose the configured band.
 p.proximity_level_id AS proximity_rank -- Keep near, medium and far in numeric order.
FROM nearby n -- Read one row per address-centre pair.
JOIN proximity_level p ON n.distance_m>=p.min_distance_m -- Include the lower boundary.
 AND (n.distance_m<p.max_distance_m -- Exclude ordinary upper boundaries.
      OR (p.upper_inclusive AND n.distance_m<=p.max_distance_m)); -- Include the final 2 km endpoint.
COMMIT; -- Publish the new schema without deleting any existing team schema.
