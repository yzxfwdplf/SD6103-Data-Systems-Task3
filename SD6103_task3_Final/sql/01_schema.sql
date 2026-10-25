\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS housing CASCADE;
CREATE SCHEMA housing;
SET search_path = housing, public;

CREATE TABLE town (
    town_id      integer PRIMARY KEY,
    town_name    text NOT NULL UNIQUE
);

CREATE TABLE hdb_flat (
    flat_id       bigint PRIMARY KEY,
    town_id       integer NOT NULL REFERENCES town(town_id),
    block         text NOT NULL,
    street_name   text NOT NULL,
    postal_code   char(6),
    latitude      double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude     double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    UNIQUE (block, street_name)
);

CREATE TABLE resale_transaction (
    transaction_id          bigint PRIMARY KEY,
    flat_id                 bigint NOT NULL REFERENCES hdb_flat(flat_id),
    source_row_key          text NOT NULL UNIQUE,
    sale_month              date NOT NULL,
    flat_type               text NOT NULL,
    storey_range            text NOT NULL,
    floor_area_sqm          numeric(8,2) NOT NULL CHECK (floor_area_sqm > 0),
    flat_model              text NOT NULL,
    lease_commence_year     integer NOT NULL,
    remaining_lease_months  integer NOT NULL CHECK (remaining_lease_months BETWEEN 0 AND 1188),
    resale_price            numeric(14,2) NOT NULL CHECK (resale_price > 0)
);

CREATE TABLE hawker_centre (
    hawker_id           integer PRIMARY KEY,
    hawker_name         text NOT NULL,
    address             text,
    latitude            double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude           double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    market_stall_count  integer CHECK (market_stall_count >= 0),
    has_fresh_market    boolean GENERATED ALWAYS AS (
        CASE
            WHEN market_stall_count IS NULL THEN NULL
            ELSE market_stall_count > 0
        END
    ) STORED
);

CREATE TABLE proximity_level (
    proximity_level_id  smallint PRIMARY KEY,
    level_name           text NOT NULL UNIQUE,
    min_distance_m       numeric(8,2) NOT NULL,
    max_distance_m       numeric(8,2) NOT NULL,
    upper_inclusive      boolean NOT NULL DEFAULT false,
    CHECK (min_distance_m >= 0 AND max_distance_m > min_distance_m)
);

CREATE TABLE nearby (
    flat_id      bigint NOT NULL REFERENCES hdb_flat(flat_id),
    hawker_id    integer NOT NULL REFERENCES hawker_centre(hawker_id),
    distance_m   numeric(8,2) NOT NULL CHECK (distance_m >= 0 AND distance_m <= 2000),
    PRIMARY KEY (flat_id, hawker_id)
);
