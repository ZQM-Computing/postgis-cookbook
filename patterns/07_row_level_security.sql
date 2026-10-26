-- Pattern 07: Row-level security for spatial data
-- Demonstrates role-specific visibility using spatial predicates against
-- small, stable service-area geometries. All changes are transactional and
-- the demo refuses to reuse pre-existing roles.
--
-- Production notes:
--   * Prefer stable tenant/jurisdiction attributes when they express the rule.
--   * Spatial policies can add per-row work; verify plans and index usage on
--     representative data rather than assuming a GiST index will be selected.
--   * FORCE ROW LEVEL SECURITY subjects table owners to policies; superusers
--     and roles with BYPASSRLS remain able to bypass row security.
--   * This script is a disposable-demo pattern, not a production role design.

BEGIN;

-- Use namespaced role names. Refuse to touch roles that may belong to a user.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname IN (
            'postgis_cb_north_ops',
            'postgis_cb_coastal_ops',
            'postgis_cb_read_all_geo'
        )
    ) THEN
        RAISE EXCEPTION
            'A postgis-cookbook demo role already exists; inspect it before rerunning pattern 07';
    END IF;
END
$$;

CREATE ROLE postgis_cb_north_ops NOLOGIN;
CREATE ROLE postgis_cb_coastal_ops NOLOGIN;
CREATE ROLE postgis_cb_read_all_geo NOLOGIN;

-- The cookbook runner connects as patterns. Grant membership so SET ROLE can
-- demonstrate each policy; the transaction removes these memberships below.
GRANT postgis_cb_north_ops TO patterns;
GRANT postgis_cb_coastal_ops TO patterns;
GRANT postgis_cb_read_all_geo TO patterns;

GRANT USAGE ON SCHEMA demo
    TO postgis_cb_north_ops, postgis_cb_coastal_ops, postgis_cb_read_all_geo;
GRANT SELECT ON demo.service_areas, demo.service_sites, demo.parcels
    TO postgis_cb_north_ops, postgis_cb_coastal_ops, postgis_cb_read_all_geo;

ALTER TABLE demo.service_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo.service_sites FORCE ROW LEVEL SECURITY;
ALTER TABLE demo.parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo.parcels FORCE ROW LEVEL SECURITY;

CREATE POLICY postgis_cb_north_sites ON demo.service_sites
    FOR SELECT TO postgis_cb_north_ops
    USING (
        ST_Intersects(
            geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'North service area')
        )
    );

CREATE POLICY postgis_cb_coastal_sites ON demo.service_sites
    FOR SELECT TO postgis_cb_coastal_ops
    USING (
        ST_Intersects(
            geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'Coastal service area')
        )
    );

CREATE POLICY postgis_cb_read_all_sites ON demo.service_sites
    FOR SELECT TO postgis_cb_read_all_geo
    USING (true);

CREATE POLICY postgis_cb_north_parcels ON demo.parcels
    FOR SELECT TO postgis_cb_north_ops
    USING (
        ST_Intersects(
            geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'North service area')
        )
    );

CREATE POLICY postgis_cb_coastal_parcels ON demo.parcels
    FOR SELECT TO postgis_cb_coastal_ops
    USING (
        ST_Intersects(
            geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'Coastal service area')
        )
    );

CREATE POLICY postgis_cb_read_all_parcels ON demo.parcels
    FOR SELECT TO postgis_cb_read_all_geo
    USING (true);

-- Table owners are subject to FORCE RLS too, so perform the "all rows" view
-- explicitly under the read-all role instead of implying the owner bypasses it.
SET ROLE postgis_cb_north_ops;

SELECT 'north_ops' AS perspective, site_id, name, category
FROM demo.service_sites
ORDER BY site_id;

SELECT 'north_ops parcels' AS perspective, count(*) AS parcel_count
FROM demo.parcels;

DO $$
BEGIN
    IF (SELECT count(*) FROM demo.service_sites) <> 3 THEN
        RAISE EXCEPTION 'North policy should expose exactly 3 sites';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM demo.service_sites AS site
        WHERE NOT ST_Intersects(
            site.geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'North service area')
        )
    ) THEN
        RAISE EXCEPTION 'North policy exposed a site outside the North service area';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM demo.parcels AS parcel
        WHERE NOT ST_Intersects(
            parcel.geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'North service area')
        )
    ) THEN
        RAISE EXCEPTION 'North policy exposed a parcel outside the North service area';
    END IF;
END
$$;

RESET ROLE;
SET ROLE postgis_cb_coastal_ops;

SELECT 'coastal_ops' AS perspective, site_id, name, category
FROM demo.service_sites
ORDER BY site_id;

SELECT 'coastal_ops parcels' AS perspective, count(*) AS parcel_count
FROM demo.parcels;

DO $$
BEGIN
    IF (SELECT count(*) FROM demo.service_sites) <> 4 THEN
        RAISE EXCEPTION 'Coastal policy should expose exactly 4 sites';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM demo.service_sites AS site
        WHERE NOT ST_Intersects(
            site.geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'Coastal service area')
        )
    ) THEN
        RAISE EXCEPTION 'Coastal policy exposed a site outside the Coastal service area';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM demo.parcels AS parcel
        WHERE NOT ST_Intersects(
            parcel.geom,
            (SELECT geom FROM demo.service_areas WHERE name = 'Coastal service area')
        )
    ) THEN
        RAISE EXCEPTION 'Coastal policy exposed a parcel outside the Coastal service area';
    END IF;
END
$$;

RESET ROLE;
SET ROLE postgis_cb_read_all_geo;

SELECT 'read_all_geo' AS perspective, count(*) AS site_count
FROM demo.service_sites;

DO $$
BEGIN
    IF (SELECT count(*) FROM demo.service_sites) <> 9 THEN
        RAISE EXCEPTION 'Read-all policy should expose all 9 sites';
    END IF;
    IF (SELECT count(*) FROM demo.parcels) <> 24 THEN
        RAISE EXCEPTION 'Read-all policy should expose all 24 parcels';
    END IF;
END
$$;

RESET ROLE;

-- Remove only the roles created by this script and restore the original
-- fixture state. Any error above rolls the entire transaction back.
DROP POLICY postgis_cb_north_sites ON demo.service_sites;
DROP POLICY postgis_cb_coastal_sites ON demo.service_sites;
DROP POLICY postgis_cb_read_all_sites ON demo.service_sites;
DROP POLICY postgis_cb_north_parcels ON demo.parcels;
DROP POLICY postgis_cb_coastal_parcels ON demo.parcels;
DROP POLICY postgis_cb_read_all_parcels ON demo.parcels;

ALTER TABLE demo.service_sites NO FORCE ROW LEVEL SECURITY;
ALTER TABLE demo.service_sites DISABLE ROW LEVEL SECURITY;
ALTER TABLE demo.parcels NO FORCE ROW LEVEL SECURITY;
ALTER TABLE demo.parcels DISABLE ROW LEVEL SECURITY;

REVOKE SELECT ON demo.service_areas, demo.service_sites, demo.parcels
    FROM postgis_cb_north_ops, postgis_cb_coastal_ops, postgis_cb_read_all_geo;
REVOKE USAGE ON SCHEMA demo
    FROM postgis_cb_north_ops, postgis_cb_coastal_ops, postgis_cb_read_all_geo;

REVOKE postgis_cb_north_ops FROM patterns;
REVOKE postgis_cb_coastal_ops FROM patterns;
REVOKE postgis_cb_read_all_geo FROM patterns;

DROP ROLE postgis_cb_north_ops;
DROP ROLE postgis_cb_coastal_ops;
DROP ROLE postgis_cb_read_all_geo;

COMMIT;

SELECT 'Pattern 07 (spatial row-level security) completed and cleaned up' AS result;
