-- Extensions and schema for the postgis-patterns demo.
-- The column types enforce geometry type and SRID at write time.

CREATE EXTENSION IF NOT EXISTS postgis;

SELECT 'PostGIS version' AS check_name, postgis_version() AS result;

CREATE SCHEMA IF NOT EXISTS demo;

CREATE TABLE IF NOT EXISTS demo.service_areas (
    area_id integer PRIMARY KEY,
    name text NOT NULL UNIQUE,
    geom geometry(MultiPolygon, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS demo.service_sites (
    site_id integer PRIMARY KEY,
    name text NOT NULL,
    category text NOT NULL,
    opened_on date NOT NULL,
    geom geometry(Point, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS demo.parcels (
    parcel_id text PRIMARY KEY,
    land_use text NOT NULL,
    assessed_value numeric(12, 2) NOT NULL,
    geom geometry(Polygon, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS demo.sensor_observations (
    observation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    site_id integer NOT NULL REFERENCES demo.service_sites(site_id),
    observed_at timestamptz NOT NULL,
    reading_value numeric(8, 2) NOT NULL,
    geom geometry(Point, 4326) NOT NULL
);

COMMENT ON TABLE demo.service_areas IS 'Synthetic service-area polygons used by the examples.';
COMMENT ON TABLE demo.service_sites IS 'Synthetic point locations used by the examples.';
COMMENT ON TABLE demo.parcels IS 'Synthetic parcel-like polygons; not real property data.';
COMMENT ON TABLE demo.sensor_observations IS 'Synthetic time-stamped observations at service sites.';
