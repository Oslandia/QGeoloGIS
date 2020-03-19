--
-- PostgreSQL database dump
--

-- Dumped from database version 10.12 (Ubuntu 10.12-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.12 (Ubuntu 10.12-0ubuntu0.18.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: measure; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA measure;


ALTER SCHEMA measure OWNER TO postgres;

--
-- Name: metadata; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA metadata;


ALTER SCHEMA metadata OWNER TO postgres;

--
-- Name: SCHEMA metadata; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA metadata IS 'Schema where metadata about imported data are stored';


--
-- Name: qgis; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA qgis;


ALTER SCHEMA qgis OWNER TO postgres;

--
-- Name: SCHEMA qgis; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA qgis IS 'Schema where views for QGIS visualisation are stored';


--
-- Name: ref; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ref;


ALTER SCHEMA ref OWNER TO postgres;

--
-- Name: SCHEMA ref; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA ref IS 'Schema where references and constants are stored';


--
-- Name: station; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA station;


ALTER SCHEMA station OWNER TO postgres;

--
-- Name: SCHEMA station; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA station IS 'Main schema where data about drill station are stored';


--
-- Name: tr; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tr;


ALTER SCHEMA tr OWNER TO postgres;

--
-- Name: SCHEMA tr; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA tr IS 'Schema where descriptions and translations are stored';


--
-- Name: utils; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA utils;


ALTER SCHEMA utils OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA utils;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: rgb_hex; Type: DOMAIN; Schema: ref; Owner: postgres
--

CREATE DOMAIN ref.rgb_hex AS text
	CONSTRAINT rgb_hex_check CHECK ((VALUE ~ '^#[0123456789abcdef]{6}$'::text));


ALTER DOMAIN ref.rgb_hex OWNER TO postgres;

--
-- Name: DOMAIN rgb_hex; Type: COMMENT; Schema: ref; Owner: postgres
--

COMMENT ON DOMAIN ref.rgb_hex IS 'Text representation of RGB colors with html format #rrggbb';


--
-- Name: roc_code_authority; Type: TYPE; Schema: ref; Owner: postgres
--

CREATE TYPE ref.roc_code_authority AS ENUM (
    'USGS'
);


ALTER TYPE ref.roc_code_authority OWNER TO postgres;

--
-- Name: borehole_type; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.borehole_type AS ENUM (
    'Piezometer',
    'CoreDrill',
    'FilledUpDrill',
    'GeotechnicDrill',
    'Borehole',
    'Well',
    'DrainWell'
);


ALTER TYPE station.borehole_type OWNER TO postgres;

--
-- Name: chimney_type; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.chimney_type AS ENUM (
    'Chimney'
);


ALTER TYPE station.chimney_type OWNER TO postgres;

--
-- Name: device_type; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.device_type AS ENUM (
    'MeasurementDevice',
    'DrainagePump'
);


ALTER TYPE station.device_type OWNER TO postgres;

--
-- Name: hydrology_station_type; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.hydrology_station_type AS ENUM (
    'River',
    'Spring'
);


ALTER TYPE station.hydrology_station_type OWNER TO postgres;

--
-- Name: sample_family; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.sample_family AS ENUM (
    'Air',
    'Ground',
    'Water',
    'Animal',
    'Plant'
);


ALTER TYPE station.sample_family OWNER TO postgres;

--
-- Name: station_family; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.station_family AS ENUM (
    'Borehole',
    'Chimney',
    'Weather_Station',
    'Hydrology_Station',
    'Sample',
    'Device'
);


ALTER TYPE station.station_family OWNER TO postgres;

--
-- Name: weather_station_type; Type: TYPE; Schema: station; Owner: postgres
--

CREATE TYPE station.weather_station_type AS ENUM (
    'Pluviometer',
    'WeatherStation',
    'WeatherMast'
);


ALTER TYPE station.weather_station_type OWNER TO postgres;

--
-- Name: _create_continuous_measure_over_altitude_table(text, text, text); Type: FUNCTION; Schema: measure; Owner: postgres
--

CREATE FUNCTION measure._create_continuous_measure_over_altitude_table(table_name text, title text, unit text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
  execute format($sql$
    create table measure.%s (
       id serial primary key
       , station_id bigint not null references station(id) on delete cascade
       , start_measure_altitude double precision not null
       -- interval between each measure point, in meters
       , altitude_interval double precision not null
       , measures double precision[]
       , campaign_id bigint references campaign(id) default 1
       , dataset_id int /*not null*/ references metadata.dataset(id) on delete cascade
       , unique (station_id, start_measure_altitude, campaign_id)
    )$sql$, table_name);
  execute format($sql$
    insert into measure_metadata (measure_table, name, unit_of_measure, x_axis_type) values ('%s', %s, %s, 'DepthAxis')
    $sql$, table_name, quote_literal(title), quote_literal(unit));
end;
$_$;


ALTER FUNCTION measure._create_continuous_measure_over_altitude_table(table_name text, title text, unit text) OWNER TO postgres;

--
-- Name: _create_continuous_measure_over_time_table(text, text, text); Type: FUNCTION; Schema: measure; Owner: postgres
--

CREATE FUNCTION measure._create_continuous_measure_over_time_table(table_name text, title text, unit text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
  execute format($sql$
    create table measure.%s (
       id serial primary key
       , station_id bigint not null references station(id) on delete cascade
       , start_measure_time timestamp not null
       -- interval between each measure point
       , time_interval interval not null
       , campaign_id bigint references campaign(id) default 1
       , dataset_id int /*not null*/ references metadata.dataset(id) on delete cascade
       , measures double precision[]
       , unique (station_id, start_measure_time, campaign_id)
    )$sql$, table_name);
  execute format($sql$
    insert into measure_metadata (measure_table, name, unit_of_measure, x_axis_type) values ('%s', %s, %s, 'TimeAxis')
    $sql$, table_name, quote_literal(title), quote_literal(unit));
end;
$_$;


ALTER FUNCTION measure._create_continuous_measure_over_time_table(table_name text, title text, unit text) OWNER TO postgres;

--
-- Name: _create_cumulative_measure_over_time_table(text, text, text); Type: FUNCTION; Schema: measure; Owner: postgres
--

CREATE FUNCTION measure._create_cumulative_measure_over_time_table(table_name text, title text, unit text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
  execute format($sql$
    create table measure.%s (
       id serial primary key
       , station_id bigint not null references station(id) on delete cascade
       , start_measure_time timestamp not null
       , end_measure_time timestamp not null
       , measure_value double precision
       , periodicity text
       , reference text -- original file
       , campaign_id bigint references campaign(id) default 1
       , dataset_id int /*not null*/ references metadata.dataset(id) on delete cascade
       , unique (station_id, start_measure_time, campaign_id)
    )$sql$, table_name);
  execute format($sql$
    insert into measure_metadata (measure_table, name, unit_of_measure, x_axis_type, storage_type) values ('%s', %s, %s, 'TimeAxis', 'Cumulative')
    $sql$, table_name, quote_literal(title), quote_literal(unit));
end;
$_$;


ALTER FUNCTION measure._create_cumulative_measure_over_time_table(table_name text, title text, unit text) OWNER TO postgres;

--
-- Name: _create_instantaneous_measure_over_time_table(text, text, text); Type: FUNCTION; Schema: measure; Owner: postgres
--

CREATE FUNCTION measure._create_instantaneous_measure_over_time_table(table_name text, title text, unit text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
  execute format($sql$
    create table measure.%s (
       id serial primary key
       , station_id bigint not null references station(id) on delete cascade
       , measure_time timestamp not null
       , measure_value double precision
       , campaign_id bigint references campaign(id) default 1
       , dataset_id int /*not null*/ references metadata.dataset(id) on delete cascade
       , unique (station_id, measure_time, campaign_id)
    )$sql$, table_name);
  execute format($sql$
    insert into measure_metadata (measure_table, name, unit_of_measure, x_axis_type, storage_type) values ('%s', %s, %s, 'TimeAxis', 'Instantaneous')
    $sql$, table_name, quote_literal(title), quote_literal(unit));
end;
$_$;


ALTER FUNCTION measure._create_instantaneous_measure_over_time_table(table_name text, title text, unit text) OWNER TO postgres;

--
-- Name: delete_children_ft(); Type: FUNCTION; Schema: metadata; Owner: postgres
--

CREATE FUNCTION metadata.delete_children_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  delete from metadata.dataset
  using (
    select id, unnest(parent_ids) as parent_id
    from metadata.dataset
  ) to_del
  where
    to_del.parent_id = old.id
    and dataset.id = to_del.id
  ;
  return old;
end;
$$;


ALTER FUNCTION metadata.delete_children_ft() OWNER TO postgres;

--
-- Name: borehole_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.borehole_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_borehole where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.borehole_delete_ft() OWNER TO postgres;

--
-- Name: borehole_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.borehole_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_borehole select
        currval('station.station_id_seq'::regclass)
        , new.total_depth,new.top_of_casing_altitude,new.casing_height,new.casing_internal_diameter,new.casing_external_diameter,new.driller,new.drilling_date,new.drilling_method,new.associated_barometer,new.location,new.num_bss,new.borehole_type,new.usage,new.condition
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.borehole_insert_ft() OWNER TO postgres;

--
-- Name: borehole_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.borehole_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_borehole set (total_depth,top_of_casing_altitude,casing_height,casing_internal_diameter,casing_external_diameter,driller,drilling_date,drilling_method,associated_barometer,location,num_bss,borehole_type,usage,condition) = (new.total_depth,new.top_of_casing_altitude,new.casing_height,new.casing_internal_diameter,new.casing_external_diameter,new.driller,new.drilling_date,new.drilling_method,new.associated_barometer,new.location,new.num_bss,new.borehole_type,new.usage,new.condition) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.borehole_update_ft() OWNER TO postgres;

--
-- Name: chimney_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.chimney_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_chimney where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.chimney_delete_ft() OWNER TO postgres;

--
-- Name: chimney_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.chimney_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_chimney select
        currval('station.station_id_seq'::regclass)
        , new.chimney_type,new.nuclear_facility_name,new.facility_name,new.building_name,new.height,new.flow_rate,new.surface
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.chimney_insert_ft() OWNER TO postgres;

--
-- Name: chimney_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.chimney_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_chimney set (chimney_type,nuclear_facility_name,facility_name,building_name,height,flow_rate,surface) = (new.chimney_type,new.nuclear_facility_name,new.facility_name,new.building_name,new.height,new.flow_rate,new.surface) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.chimney_update_ft() OWNER TO postgres;

--
-- Name: device_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.device_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_device where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.device_delete_ft() OWNER TO postgres;

--
-- Name: device_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.device_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_device select
        currval('station.station_id_seq'::regclass)
        , new.device_type
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.device_insert_ft() OWNER TO postgres;

--
-- Name: device_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.device_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_device set (device_type) = (new.device_type) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.device_update_ft() OWNER TO postgres;

--
-- Name: hydrology_station_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.hydrology_station_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_hydrology where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.hydrology_station_delete_ft() OWNER TO postgres;

--
-- Name: hydrology_station_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.hydrology_station_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_hydrology select
        currval('station.station_id_seq'::regclass)
        , new.hydrology_station_type,new.a,new.b
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.hydrology_station_insert_ft() OWNER TO postgres;

--
-- Name: hydrology_station_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.hydrology_station_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_hydrology set (hydrology_station_type,a,b) = (new.hydrology_station_type,new.a,new.b) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.hydrology_station_update_ft() OWNER TO postgres;

--
-- Name: sample_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.sample_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_sample where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.sample_delete_ft() OWNER TO postgres;

--
-- Name: sample_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.sample_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_sample select
        currval('station.station_id_seq'::regclass)
        , new.sample_family,new.sample_type
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.sample_insert_ft() OWNER TO postgres;

--
-- Name: sample_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.sample_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_sample set (sample_family,sample_type) = (new.sample_family,new.sample_type) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.sample_update_ft() OWNER TO postgres;

--
-- Name: weather_station_delete_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.weather_station_delete_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      delete from station.station_weather_station where id = old.id;
      delete from station.station where id = old.id;
      return old;
    end;
    $$;


ALTER FUNCTION station.weather_station_delete_ft() OWNER TO postgres;

--
-- Name: weather_station_insert_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.weather_station_insert_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      insert into station.station select
        nextval('station.station_id_seq'::regclass)
        , new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id
      ;
      insert into station.station_weather_station select
        currval('station.station_id_seq'::regclass)
        , new.weather_station_type,new.height
      ;
      return new;
    end;
    $$;


ALTER FUNCTION station.weather_station_insert_ft() OWNER TO postgres;

--
-- Name: weather_station_update_ft(); Type: FUNCTION; Schema: station; Owner: postgres
--

CREATE FUNCTION station.weather_station_update_ft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
      update station.station set (site_id,station_family,station_type,name,point,orig_srid,ground_altitude,dataset_id) = (new.site_id,new.station_family,new.station_type,new.name,new.point,new.orig_srid,new.ground_altitude,new.dataset_id) where id=old.id;
      update station.station_weather_station set (weather_station_type,height) = (new.weather_station_type,new.height) where id=old.id;
      return new;
    end;
    $$;


ALTER FUNCTION station.weather_station_update_ft() OWNER TO postgres;

--
-- Name: create_inheritance_view(text, text, regclass, regclass); Type: FUNCTION; Schema: utils; Owner: postgres
--

CREATE FUNCTION utils.create_inheritance_view(view_schema text, view_table text, child_rel regclass, parent_rel regclass) RETURNS void
    LANGUAGE plpgsql
    AS $_$
declare
  child_table text;
  child_schema text;
  parent_table text;
  parent_schema text;
  q text;
begin

  -- table and schema name from regclass
  select into child_table, child_schema
    relname, nspname from pg_class c join pg_namespace ns on ns.oid = c.relnamespace where c.oid = child_rel;
  select into parent_table, parent_schema
    relname, nspname from pg_class c join pg_namespace ns on ns.oid = c.relnamespace where c.oid = parent_rel;

  -- create the aggregate view
  q := format($sql$ create view %s as
  select
    %s
    , %s
  from
    %s c
    left join %s p on p.id = c.id$sql$
  , view_schema || '.' || view_table
  , array_to_string(utils.get_column_list(parent_rel, 'p.'), ',')
  , array_to_string(array_remove(utils.get_column_list(child_rel, 'c.'), 'c.id'), ',')
  , child_rel::text
  , parent_rel::text
  );
  execute q;

  -- create the insert trigger function
  q := format($sql$
    create function %s_insert_ft() returns trigger
    language plpgsql
    as $f$
    begin
      insert into %s select
        nextval('%s_id_seq'::regclass)
        , %s
      ;
      insert into %s select
        currval('%s_id_seq'::regclass)
        , %s
      ;
      return new;
    end;
    $f$;
    create trigger %s_insert_t instead of insert on %s
    for each row execute procedure %s_insert_ft();
  $sql$
  , view_table
  , parent_schema||'.'||parent_table
  , parent_schema||'.'||parent_table
  , array_to_string(array_remove(utils.get_column_list(parent_rel, 'new.'), 'new.id'), ',')
  , child_schema||'.'||child_table
  , parent_schema||'.'||parent_table
  , array_to_string(array_remove(utils.get_column_list(child_rel, 'new.'), 'new.id'), ',')
  , view_table
  , view_schema || '.' || view_table
  , view_table
  );
  execute q;

  -- create the delete trigger function
  q := format($sql$
    create function %s_delete_ft() returns trigger
    language plpgsql
    as $f$
    begin
      delete from %s where id = old.id;
      delete from %s where id = old.id;
      return old;
    end;
    $f$;
    create trigger %s_delete_t instead of delete on %s
    for each row execute procedure %s_delete_ft();
  $sql$
  , view_table
  , child_schema||'.'||child_table
  , parent_schema||'.'||parent_table
  , view_table
  , view_schema||'.'||view_table
  , view_table
  );
  execute q;

  -- create the update trigger function
  q := format($sql$
    create function %s_update_ft() returns trigger
    language plpgsql
    as $f$
    begin
      update %s set (%s) = (%s) where id=old.id;
      update %s set (%s) = (%s) where id=old.id;
      return new;
    end;
    $f$;
    create trigger %s_update_t instead of update on %s
    for each row execute procedure %s_update_ft();
  $sql$
  , view_table
  , parent_schema||'.'||parent_table
  , array_to_string(array_remove(utils.get_column_list(parent_rel), 'id'), ',')
  , array_to_string(array_remove(utils.get_column_list(parent_rel, 'new.'), 'new.id'), ',')
  , child_schema||'.'||child_table
  , array_to_string(array_remove(utils.get_column_list(child_rel), 'id'), ',')
  , array_to_string(array_remove(utils.get_column_list(child_rel, 'new.'), 'new.id'), ',')
  , view_table
  , view_schema||'.'||view_table
  , view_table
  );
  execute q;
end;
$_$;


ALTER FUNCTION utils.create_inheritance_view(view_schema text, view_table text, child_rel regclass, parent_rel regclass) OWNER TO postgres;

--
-- Name: get_column_list(regclass, text); Type: FUNCTION; Schema: utils; Owner: postgres
--

CREATE FUNCTION utils.get_column_list(l_relation regclass, l_col_prefix text DEFAULT ''::text) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  select array_agg(l_col_prefix||attname)
         from pg_attribute
        where attrelid = l_relation
          and attnum > 0;
$$;


ALTER FUNCTION utils.get_column_list(l_relation regclass, l_col_prefix text) OWNER TO postgres;

--
-- Name: stations_from_dataset(integer); Type: FUNCTION; Schema: utils; Owner: postgres
--

CREATE FUNCTION utils.stations_from_dataset(pdataset_id integer) RETURNS TABLE(station_id bigint)
    LANGUAGE plpgsql
    AS $$
declare
  r record;
  q text;
begin
  q := format('select distinct station_id from measure.stratigraphic_logvalue where dataset_id = %s', pdataset_id);
  q := q || format(' union select distinct station_id from measure.chemical_analysis_result where dataset_id = %s', pdataset_id);
  for r in select measure_table::text from measure.measure_metadata
  loop
    q := q || format(' union select distinct station_id from %s where dataset_id=%s', r.measure_table, pdataset_id); 
  end loop;
  return query execute q;
end;
$$;


ALTER FUNCTION utils.stations_from_dataset(pdataset_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: acoustic_imagery; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.acoustic_imagery (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    scan_date date NOT NULL,
    depth_range numrange NOT NULL,
    image_data bytea,
    image_format text,
    dataset_id integer
);


ALTER TABLE measure.acoustic_imagery OWNER TO postgres;

--
-- Name: acoustic_imagery_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.acoustic_imagery_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.acoustic_imagery_id_seq OWNER TO postgres;

--
-- Name: acoustic_imagery_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.acoustic_imagery_id_seq OWNED BY measure.acoustic_imagery.id;


--
-- Name: atmospheric_pressure; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.atmospheric_pressure (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.atmospheric_pressure OWNER TO postgres;

--
-- Name: atmospheric_pressure_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.atmospheric_pressure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.atmospheric_pressure_id_seq OWNER TO postgres;

--
-- Name: atmospheric_pressure_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.atmospheric_pressure_id_seq OWNED BY measure.atmospheric_pressure.id;


--
-- Name: campaign; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.campaign (
    id integer NOT NULL,
    instrument_id bigint,
    start_date date
);


ALTER TABLE measure.campaign OWNER TO postgres;

--
-- Name: campaign_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.campaign_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.campaign_id_seq OWNER TO postgres;

--
-- Name: campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.campaign_id_seq OWNED BY measure.campaign.id;


--
-- Name: chemical_analysis_result; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.chemical_analysis_result (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    chemical_element text NOT NULL,
    chemical_element_description text,
    measure_value double precision,
    measure_unit text,
    measure_uncertainty double precision,
    detection_limit double precision,
    quantification_limit double precision,
    analysis_method text,
    sampling_method text,
    sample_code text,
    sample_family station.sample_family,
    sample_type text,
    sample_name text,
    sample_report text,
    report_number text,
    da_number text,
    dataset_id integer
);


ALTER TABLE measure.chemical_analysis_result OWNER TO postgres;

--
-- Name: chemical_analysis_result_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.chemical_analysis_result_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.chemical_analysis_result_id_seq OWNER TO postgres;

--
-- Name: chemical_analysis_result_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.chemical_analysis_result_id_seq OWNED BY measure.chemical_analysis_result.id;


--
-- Name: chimney_release; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.chimney_release (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    chemical_element text NOT NULL,
    release_speed double precision,
    measure_value double precision,
    measure_uncertainty double precision,
    reference text,
    dataset_id integer
);


ALTER TABLE measure.chimney_release OWNER TO postgres;

--
-- Name: chimney_release_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.chimney_release_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.chimney_release_id_seq OWNER TO postgres;

--
-- Name: chimney_release_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.chimney_release_id_seq OWNED BY measure.chimney_release.id;


--
-- Name: continuous_atmospheric_pressure; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_atmospheric_pressure (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_atmospheric_pressure OWNER TO postgres;

--
-- Name: continuous_atmospheric_pressure_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_atmospheric_pressure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_atmospheric_pressure_id_seq OWNER TO postgres;

--
-- Name: continuous_atmospheric_pressure_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_atmospheric_pressure_id_seq OWNED BY measure.continuous_atmospheric_pressure.id;


--
-- Name: continuous_groundwater_conductivity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_groundwater_conductivity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_groundwater_conductivity OWNER TO postgres;

--
-- Name: continuous_groundwater_conductivity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_groundwater_conductivity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_groundwater_conductivity_id_seq OWNER TO postgres;

--
-- Name: continuous_groundwater_conductivity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_groundwater_conductivity_id_seq OWNED BY measure.continuous_groundwater_conductivity.id;


--
-- Name: continuous_groundwater_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_groundwater_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_groundwater_level OWNER TO postgres;

--
-- Name: continuous_groundwater_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_groundwater_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_groundwater_level_id_seq OWNER TO postgres;

--
-- Name: continuous_groundwater_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_groundwater_level_id_seq OWNED BY measure.continuous_groundwater_level.id;


--
-- Name: continuous_groundwater_pressure; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_groundwater_pressure (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_groundwater_pressure OWNER TO postgres;

--
-- Name: continuous_groundwater_pressure_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_groundwater_pressure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_groundwater_pressure_id_seq OWNER TO postgres;

--
-- Name: continuous_groundwater_pressure_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_groundwater_pressure_id_seq OWNED BY measure.continuous_groundwater_pressure.id;


--
-- Name: continuous_groundwater_temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_groundwater_temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_groundwater_temperature OWNER TO postgres;

--
-- Name: continuous_groundwater_temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_groundwater_temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_groundwater_temperature_id_seq OWNER TO postgres;

--
-- Name: continuous_groundwater_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_groundwater_temperature_id_seq OWNED BY measure.continuous_groundwater_temperature.id;


--
-- Name: continuous_humidity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_humidity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_humidity OWNER TO postgres;

--
-- Name: continuous_humidity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_humidity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_humidity_id_seq OWNER TO postgres;

--
-- Name: continuous_humidity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_humidity_id_seq OWNED BY measure.continuous_humidity.id;


--
-- Name: continuous_nebulosity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_nebulosity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_nebulosity OWNER TO postgres;

--
-- Name: continuous_nebulosity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_nebulosity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_nebulosity_id_seq OWNER TO postgres;

--
-- Name: continuous_nebulosity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_nebulosity_id_seq OWNED BY measure.continuous_nebulosity.id;


--
-- Name: continuous_pasquill_index; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_pasquill_index (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_pasquill_index OWNER TO postgres;

--
-- Name: continuous_pasquill_index_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_pasquill_index_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_pasquill_index_id_seq OWNER TO postgres;

--
-- Name: continuous_pasquill_index_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_pasquill_index_id_seq OWNED BY measure.continuous_pasquill_index.id;


--
-- Name: continuous_potential_evapotranspiration; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_potential_evapotranspiration (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_potential_evapotranspiration OWNER TO postgres;

--
-- Name: continuous_potential_evapotranspiration_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_potential_evapotranspiration_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_potential_evapotranspiration_id_seq OWNER TO postgres;

--
-- Name: continuous_potential_evapotranspiration_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_potential_evapotranspiration_id_seq OWNED BY measure.continuous_potential_evapotranspiration.id;


--
-- Name: continuous_rain; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_rain (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_rain OWNER TO postgres;

--
-- Name: continuous_rain_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_rain_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_rain_id_seq OWNER TO postgres;

--
-- Name: continuous_rain_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_rain_id_seq OWNED BY measure.continuous_rain.id;


--
-- Name: continuous_temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_temperature OWNER TO postgres;

--
-- Name: continuous_temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_temperature_id_seq OWNER TO postgres;

--
-- Name: continuous_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_temperature_id_seq OWNED BY measure.continuous_temperature.id;


--
-- Name: continuous_water_conductivity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_water_conductivity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_water_conductivity OWNER TO postgres;

--
-- Name: continuous_water_conductivity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_water_conductivity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_water_conductivity_id_seq OWNER TO postgres;

--
-- Name: continuous_water_conductivity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_water_conductivity_id_seq OWNED BY measure.continuous_water_conductivity.id;


--
-- Name: continuous_water_discharge; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_water_discharge (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_water_discharge OWNER TO postgres;

--
-- Name: continuous_water_discharge_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_water_discharge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_water_discharge_id_seq OWNER TO postgres;

--
-- Name: continuous_water_discharge_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_water_discharge_id_seq OWNED BY measure.continuous_water_discharge.id;


--
-- Name: continuous_water_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_water_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_water_level OWNER TO postgres;

--
-- Name: continuous_water_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_water_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_water_level_id_seq OWNER TO postgres;

--
-- Name: continuous_water_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_water_level_id_seq OWNED BY measure.continuous_water_level.id;


--
-- Name: continuous_water_ph; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_water_ph (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_water_ph OWNER TO postgres;

--
-- Name: continuous_water_ph_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_water_ph_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_water_ph_id_seq OWNER TO postgres;

--
-- Name: continuous_water_ph_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_water_ph_id_seq OWNED BY measure.continuous_water_ph.id;


--
-- Name: continuous_water_temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_water_temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_water_temperature OWNER TO postgres;

--
-- Name: continuous_water_temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_water_temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_water_temperature_id_seq OWNER TO postgres;

--
-- Name: continuous_water_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_water_temperature_id_seq OWNED BY measure.continuous_water_temperature.id;


--
-- Name: continuous_wind_direction; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_wind_direction (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_wind_direction OWNER TO postgres;

--
-- Name: continuous_wind_direction_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_wind_direction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_wind_direction_id_seq OWNER TO postgres;

--
-- Name: continuous_wind_direction_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_wind_direction_id_seq OWNED BY measure.continuous_wind_direction.id;


--
-- Name: continuous_wind_force; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.continuous_wind_force (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.continuous_wind_force OWNER TO postgres;

--
-- Name: continuous_wind_force_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.continuous_wind_force_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.continuous_wind_force_id_seq OWNER TO postgres;

--
-- Name: continuous_wind_force_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.continuous_wind_force_id_seq OWNED BY measure.continuous_wind_force.id;


--
-- Name: fracturing_rate; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.fracturing_rate (
    station_id bigint NOT NULL,
    depth numrange NOT NULL,
    value double precision,
    dataset_id integer
);


ALTER TABLE measure.fracturing_rate OWNER TO postgres;

--
-- Name: groundwater_conductivity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.groundwater_conductivity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.groundwater_conductivity OWNER TO postgres;

--
-- Name: groundwater_conductivity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.groundwater_conductivity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.groundwater_conductivity_id_seq OWNER TO postgres;

--
-- Name: groundwater_conductivity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.groundwater_conductivity_id_seq OWNED BY measure.groundwater_conductivity.id;


--
-- Name: groundwater_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.groundwater_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.groundwater_level OWNER TO postgres;

--
-- Name: groundwater_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.groundwater_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.groundwater_level_id_seq OWNER TO postgres;

--
-- Name: groundwater_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.groundwater_level_id_seq OWNED BY measure.groundwater_level.id;


--
-- Name: groundwater_temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.groundwater_temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.groundwater_temperature OWNER TO postgres;

--
-- Name: groundwater_temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.groundwater_temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.groundwater_temperature_id_seq OWNER TO postgres;

--
-- Name: groundwater_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.groundwater_temperature_id_seq OWNED BY measure.groundwater_temperature.id;


--
-- Name: humidity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.humidity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.humidity OWNER TO postgres;

--
-- Name: humidity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.humidity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.humidity_id_seq OWNER TO postgres;

--
-- Name: humidity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.humidity_id_seq OWNED BY measure.humidity.id;


--
-- Name: instrument; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.instrument (
    id integer NOT NULL,
    model text,
    serial_number text,
    sensor_range double precision
);


ALTER TABLE measure.instrument OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.instrument_id_seq OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.instrument_id_seq OWNED BY measure.instrument.id;


--
-- Name: manual_groundwater_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.manual_groundwater_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.manual_groundwater_level OWNER TO postgres;

--
-- Name: manual_groundwater_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.manual_groundwater_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.manual_groundwater_level_id_seq OWNER TO postgres;

--
-- Name: manual_groundwater_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.manual_groundwater_level_id_seq OWNED BY measure.manual_groundwater_level.id;


--
-- Name: manual_water_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.manual_water_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.manual_water_level OWNER TO postgres;

--
-- Name: manual_water_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.manual_water_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.manual_water_level_id_seq OWNER TO postgres;

--
-- Name: manual_water_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.manual_water_level_id_seq OWNED BY measure.manual_water_level.id;


--
-- Name: measure_metadata; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.measure_metadata (
    measure_table regclass NOT NULL,
    name text,
    unit_of_measure text,
    x_axis_type text,
    storage_type text DEFAULT 'Continuous'::text,
    CONSTRAINT measure_metadata_storage_type_check CHECK ((storage_type = ANY (ARRAY['Cumulative'::text, 'Continuous'::text, 'Instantaneous'::text, 'Image'::text]))),
    CONSTRAINT measure_metadata_x_axis_type_check CHECK ((x_axis_type = ANY (ARRAY['TimeAxis'::text, 'DepthAxis'::text])))
);


ALTER TABLE measure.measure_metadata OWNER TO postgres;

--
-- Name: COLUMN measure_metadata.measure_table; Type: COMMENT; Schema: measure; Owner: postgres
--

COMMENT ON COLUMN measure.measure_metadata.measure_table IS 'Link to the table that holds this measure';


--
-- Name: COLUMN measure_metadata.name; Type: COMMENT; Schema: measure; Owner: postgres
--

COMMENT ON COLUMN measure.measure_metadata.name IS 'Name of the measure';


--
-- Name: nebulosity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.nebulosity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.nebulosity OWNER TO postgres;

--
-- Name: nebulosity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.nebulosity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.nebulosity_id_seq OWNER TO postgres;

--
-- Name: nebulosity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.nebulosity_id_seq OWNED BY measure.nebulosity.id;


--
-- Name: optical_imagery; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.optical_imagery (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    scan_date date NOT NULL,
    depth_range numrange NOT NULL,
    image_data bytea,
    image_format text,
    dataset_id integer
);


ALTER TABLE measure.optical_imagery OWNER TO postgres;

--
-- Name: optical_imagery_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.optical_imagery_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.optical_imagery_id_seq OWNER TO postgres;

--
-- Name: optical_imagery_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.optical_imagery_id_seq OWNED BY measure.optical_imagery.id;


--
-- Name: pasquill_index; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.pasquill_index (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.pasquill_index OWNER TO postgres;

--
-- Name: pasquill_index_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.pasquill_index_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.pasquill_index_id_seq OWNER TO postgres;

--
-- Name: pasquill_index_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.pasquill_index_id_seq OWNED BY measure.pasquill_index.id;


--
-- Name: potential_evapotranspiration; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.potential_evapotranspiration (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.potential_evapotranspiration OWNER TO postgres;

--
-- Name: potential_evapotranspiration_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.potential_evapotranspiration_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.potential_evapotranspiration_id_seq OWNER TO postgres;

--
-- Name: potential_evapotranspiration_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.potential_evapotranspiration_id_seq OWNED BY measure.potential_evapotranspiration.id;


--
-- Name: rain; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.rain (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.rain OWNER TO postgres;

--
-- Name: rain_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.rain_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.rain_id_seq OWNER TO postgres;

--
-- Name: rain_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.rain_id_seq OWNED BY measure.rain.id;


--
-- Name: raw_groundwater_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.raw_groundwater_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    time_interval interval NOT NULL,
    campaign_id bigint DEFAULT 1,
    dataset_id integer,
    measures double precision[]
);


ALTER TABLE measure.raw_groundwater_level OWNER TO postgres;

--
-- Name: raw_groundwater_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.raw_groundwater_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.raw_groundwater_level_id_seq OWNER TO postgres;

--
-- Name: raw_groundwater_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.raw_groundwater_level_id_seq OWNED BY measure.raw_groundwater_level.id;


--
-- Name: stratigraphic_logvalue; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.stratigraphic_logvalue (
    station_id bigint NOT NULL,
    depth numrange NOT NULL,
    rock_code integer,
    rock_description text,
    formation_code text,
    formation_description text,
    dataset_id integer
);


ALTER TABLE measure.stratigraphic_logvalue OWNER TO postgres;

--
-- Name: temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.temperature OWNER TO postgres;

--
-- Name: temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.temperature_id_seq OWNER TO postgres;

--
-- Name: temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.temperature_id_seq OWNED BY measure.temperature.id;


--
-- Name: tool_injection_pressure; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.tool_injection_pressure (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_altitude double precision NOT NULL,
    altitude_interval double precision NOT NULL,
    measures double precision[],
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.tool_injection_pressure OWNER TO postgres;

--
-- Name: tool_injection_pressure_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.tool_injection_pressure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.tool_injection_pressure_id_seq OWNER TO postgres;

--
-- Name: tool_injection_pressure_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.tool_injection_pressure_id_seq OWNED BY measure.tool_injection_pressure.id;


--
-- Name: tool_instant_speed; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.tool_instant_speed (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_altitude double precision NOT NULL,
    altitude_interval double precision NOT NULL,
    measures double precision[],
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.tool_instant_speed OWNER TO postgres;

--
-- Name: tool_instant_speed_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.tool_instant_speed_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.tool_instant_speed_id_seq OWNER TO postgres;

--
-- Name: tool_instant_speed_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.tool_instant_speed_id_seq OWNED BY measure.tool_instant_speed.id;


--
-- Name: tool_rotation_couple; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.tool_rotation_couple (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_altitude double precision NOT NULL,
    altitude_interval double precision NOT NULL,
    measures double precision[],
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.tool_rotation_couple OWNER TO postgres;

--
-- Name: tool_rotation_couple_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.tool_rotation_couple_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.tool_rotation_couple_id_seq OWNER TO postgres;

--
-- Name: tool_rotation_couple_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.tool_rotation_couple_id_seq OWNED BY measure.tool_rotation_couple.id;


--
-- Name: water_conductivity; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.water_conductivity (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.water_conductivity OWNER TO postgres;

--
-- Name: water_conductivity_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.water_conductivity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.water_conductivity_id_seq OWNER TO postgres;

--
-- Name: water_conductivity_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.water_conductivity_id_seq OWNED BY measure.water_conductivity.id;


--
-- Name: water_discharge; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.water_discharge (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.water_discharge OWNER TO postgres;

--
-- Name: water_discharge_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.water_discharge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.water_discharge_id_seq OWNER TO postgres;

--
-- Name: water_discharge_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.water_discharge_id_seq OWNED BY measure.water_discharge.id;


--
-- Name: water_level; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.water_level (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.water_level OWNER TO postgres;

--
-- Name: water_level_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.water_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.water_level_id_seq OWNER TO postgres;

--
-- Name: water_level_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.water_level_id_seq OWNED BY measure.water_level.id;


--
-- Name: water_ph; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.water_ph (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.water_ph OWNER TO postgres;

--
-- Name: water_ph_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.water_ph_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.water_ph_id_seq OWNER TO postgres;

--
-- Name: water_ph_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.water_ph_id_seq OWNED BY measure.water_ph.id;


--
-- Name: water_temperature; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.water_temperature (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.water_temperature OWNER TO postgres;

--
-- Name: water_temperature_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.water_temperature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.water_temperature_id_seq OWNER TO postgres;

--
-- Name: water_temperature_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.water_temperature_id_seq OWNED BY measure.water_temperature.id;


--
-- Name: weight_on_tool; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.weight_on_tool (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_altitude double precision NOT NULL,
    altitude_interval double precision NOT NULL,
    measures double precision[],
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.weight_on_tool OWNER TO postgres;

--
-- Name: weight_on_tool_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.weight_on_tool_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.weight_on_tool_id_seq OWNER TO postgres;

--
-- Name: weight_on_tool_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.weight_on_tool_id_seq OWNED BY measure.weight_on_tool.id;


--
-- Name: wind_direction; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.wind_direction (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.wind_direction OWNER TO postgres;

--
-- Name: wind_direction_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.wind_direction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.wind_direction_id_seq OWNER TO postgres;

--
-- Name: wind_direction_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.wind_direction_id_seq OWNED BY measure.wind_direction.id;


--
-- Name: wind_force; Type: TABLE; Schema: measure; Owner: postgres
--

CREATE TABLE measure.wind_force (
    id integer NOT NULL,
    station_id bigint NOT NULL,
    start_measure_time timestamp without time zone NOT NULL,
    end_measure_time timestamp without time zone NOT NULL,
    measure_value double precision,
    periodicity text,
    reference text,
    campaign_id bigint DEFAULT 1,
    dataset_id integer
);


ALTER TABLE measure.wind_force OWNER TO postgres;

--
-- Name: wind_force_id_seq; Type: SEQUENCE; Schema: measure; Owner: postgres
--

CREATE SEQUENCE measure.wind_force_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE measure.wind_force_id_seq OWNER TO postgres;

--
-- Name: wind_force_id_seq; Type: SEQUENCE OWNED BY; Schema: measure; Owner: postgres
--

ALTER SEQUENCE measure.wind_force_id_seq OWNED BY measure.wind_force.id;


--
-- Name: dataset; Type: TABLE; Schema: metadata; Owner: postgres
--

CREATE TABLE metadata.dataset (
    id integer NOT NULL,
    data_name text NOT NULL,
    import_time timestamp without time zone NOT NULL,
    parent_ids bigint[]
);


ALTER TABLE metadata.dataset OWNER TO postgres;

--
-- Name: dataset_id_seq; Type: SEQUENCE; Schema: metadata; Owner: postgres
--

CREATE SEQUENCE metadata.dataset_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE metadata.dataset_id_seq OWNER TO postgres;

--
-- Name: dataset_id_seq; Type: SEQUENCE OWNED BY; Schema: metadata; Owner: postgres
--

ALTER SEQUENCE metadata.dataset_id_seq OWNED BY metadata.dataset.id;


--
-- Name: imported_data; Type: TABLE; Schema: metadata; Owner: postgres
--

CREATE TABLE metadata.imported_data (
    site_name text NOT NULL,
    data_name text NOT NULL,
    import_date timestamp without time zone NOT NULL
);


ALTER TABLE metadata.imported_data OWNER TO postgres;

--
-- Name: layer_styles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.layer_styles (
    id integer NOT NULL,
    f_table_catalog text,
    f_table_schema text,
    f_table_name text,
    f_geometry_column text,
    stylename text,
    styleqml xml,
    stylesld xml,
    useasdefault boolean,
    description text,
    owner text,
    ui xml,
    update_time timestamp without time zone
);


ALTER TABLE public.layer_styles OWNER TO postgres;

--
-- Name: layer_styles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.layer_styles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.layer_styles_id_seq OWNER TO postgres;

--
-- Name: layer_styles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.layer_styles_id_seq OWNED BY public.layer_styles.id;


--
-- Name: station; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station (
    id integer NOT NULL,
    site_id bigint,
    station_family station.station_family,
    station_type text,
    name text,
    point public.geometry(Point,4326) NOT NULL,
    orig_srid integer NOT NULL,
    ground_altitude double precision,
    dataset_id integer
);


ALTER TABLE station.station OWNER TO postgres;

--
-- Name: COLUMN station.point; Type: COMMENT; Schema: station; Owner: postgres
--

COMMENT ON COLUMN station.station.point IS 'Station point geometry, stored in EPSG:4326 (gives 1cm accuracy for most of the projected systems)';


--
-- Name: COLUMN station.orig_srid; Type: COMMENT; Schema: station; Owner: postgres
--

COMMENT ON COLUMN station.station.orig_srid IS 'Original SRID of the point geometry. Allows to filter data on local projection views';


--
-- Name: COLUMN station.ground_altitude; Type: COMMENT; Schema: station; Owner: postgres
--

COMMENT ON COLUMN station.station.ground_altitude IS 'Altitude of the ground at point location. Expressed in NGF IGN69 (gravity-related height in meters)';


--
-- Name: station_borehole; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_borehole (
    id bigint NOT NULL,
    total_depth double precision,
    top_of_casing_altitude double precision,
    casing_height double precision,
    casing_internal_diameter double precision,
    casing_external_diameter double precision,
    driller text,
    drilling_date date,
    drilling_method text,
    associated_barometer text,
    location text,
    num_bss text,
    borehole_type station.borehole_type,
    usage text,
    condition text
);


ALTER TABLE station.station_borehole OWNER TO postgres;

--
-- Name: COLUMN station_borehole.num_bss; Type: COMMENT; Schema: station; Owner: postgres
--

COMMENT ON COLUMN station.station_borehole.num_bss IS 'BRGM BSS number if available';


--
-- Name: borehole; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.borehole AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.total_depth,
    c.top_of_casing_altitude,
    c.casing_height,
    c.casing_internal_diameter,
    c.casing_external_diameter,
    c.driller,
    c.drilling_date,
    c.drilling_method,
    c.associated_barometer,
    c.location,
    c.num_bss,
    c.borehole_type,
    c.usage,
    c.condition
   FROM (station.station_borehole c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.borehole OWNER TO postgres;

--
-- Name: borehole; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.borehole AS
 SELECT borehole.id,
    borehole.site_id,
    borehole.station_family,
    borehole.station_type,
    borehole.name,
    borehole.point,
    borehole.orig_srid,
    borehole.ground_altitude,
    borehole.dataset_id,
    borehole.total_depth,
    borehole.top_of_casing_altitude,
    borehole.casing_height,
    borehole.casing_internal_diameter,
    borehole.casing_external_diameter,
    borehole.driller,
    borehole.drilling_date,
    borehole.drilling_method,
    borehole.associated_barometer,
    borehole.location,
    borehole.num_bss,
    borehole.borehole_type,
    borehole.usage,
    borehole.condition
   FROM station.borehole;


ALTER TABLE qgis.borehole OWNER TO postgres;

--
-- Name: measure_acoustic_imagery; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_acoustic_imagery AS
 SELECT m.id,
    m.station_id,
    m.scan_date,
    m.depth_range,
    m.image_data,
    m.image_format,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    lower(m.depth_range) AS depth_from,
    upper(m.depth_range) AS depth_to
   FROM (measure.acoustic_imagery m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_acoustic_imagery OWNER TO postgres;

--
-- Name: measure_atmospheric_pressure; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_atmospheric_pressure AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.atmospheric_pressure m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_atmospheric_pressure OWNER TO postgres;

--
-- Name: measure_chemical_analysis_result; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_chemical_analysis_result AS
 SELECT chemical_analysis_result.id,
    chemical_analysis_result.station_id,
    chemical_analysis_result.measure_time,
    chemical_analysis_result.chemical_element,
    chemical_analysis_result.chemical_element_description,
    chemical_analysis_result.measure_value,
    chemical_analysis_result.measure_unit,
    chemical_analysis_result.measure_uncertainty,
    chemical_analysis_result.detection_limit,
    chemical_analysis_result.quantification_limit,
    chemical_analysis_result.analysis_method,
    chemical_analysis_result.sampling_method,
    chemical_analysis_result.sample_code,
    chemical_analysis_result.sample_family,
    chemical_analysis_result.sample_type,
    chemical_analysis_result.sample_name,
    chemical_analysis_result.sample_report,
    chemical_analysis_result.report_number,
    chemical_analysis_result.da_number,
    chemical_analysis_result.dataset_id,
    date_part('epoch'::text, chemical_analysis_result.measure_time) AS measure_epoch
   FROM measure.chemical_analysis_result;


ALTER TABLE qgis.measure_chemical_analysis_result OWNER TO postgres;

--
-- Name: measure_continuous_atmospheric_pressure; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_atmospheric_pressure AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_atmospheric_pressure m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_atmospheric_pressure OWNER TO postgres;

--
-- Name: measure_continuous_groundwater_conductivity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_groundwater_conductivity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_groundwater_conductivity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_groundwater_conductivity OWNER TO postgres;

--
-- Name: measure_continuous_groundwater_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_groundwater_level AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_groundwater_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_groundwater_level OWNER TO postgres;

--
-- Name: measure_continuous_groundwater_pressure; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_groundwater_pressure AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_groundwater_pressure m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_groundwater_pressure OWNER TO postgres;

--
-- Name: measure_continuous_groundwater_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_groundwater_temperature AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_groundwater_temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_groundwater_temperature OWNER TO postgres;

--
-- Name: measure_continuous_humidity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_humidity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_humidity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_humidity OWNER TO postgres;

--
-- Name: measure_continuous_nebulosity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_nebulosity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_nebulosity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_nebulosity OWNER TO postgres;

--
-- Name: measure_continuous_pasquill_index; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_pasquill_index AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_pasquill_index m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_pasquill_index OWNER TO postgres;

--
-- Name: measure_continuous_potential_evapotranspiration; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_potential_evapotranspiration AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_potential_evapotranspiration m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_potential_evapotranspiration OWNER TO postgres;

--
-- Name: measure_continuous_rain; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_rain AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_rain m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_rain OWNER TO postgres;

--
-- Name: measure_continuous_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_temperature AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_temperature OWNER TO postgres;

--
-- Name: measure_continuous_water_conductivity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_water_conductivity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_water_conductivity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_water_conductivity OWNER TO postgres;

--
-- Name: measure_continuous_water_discharge; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_water_discharge AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_water_discharge m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_water_discharge OWNER TO postgres;

--
-- Name: measure_continuous_water_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_water_level AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_water_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_water_level OWNER TO postgres;

--
-- Name: measure_continuous_water_ph; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_water_ph AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_water_ph m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_water_ph OWNER TO postgres;

--
-- Name: measure_continuous_water_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_water_temperature AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_water_temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_water_temperature OWNER TO postgres;

--
-- Name: measure_continuous_wind_direction; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_wind_direction AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_wind_direction m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_wind_direction OWNER TO postgres;

--
-- Name: measure_continuous_wind_force; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_continuous_wind_force AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.continuous_wind_force m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_continuous_wind_force OWNER TO postgres;

--
-- Name: measure_fracturing_rate; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_fracturing_rate AS
 SELECT fracturing_rate.station_id,
    fracturing_rate.depth,
    fracturing_rate.value,
    fracturing_rate.dataset_id,
    lower(fracturing_rate.depth) AS altitude,
    NULL::public.geometry(Polygon,4326) AS geom
   FROM measure.fracturing_rate;


ALTER TABLE qgis.measure_fracturing_rate OWNER TO postgres;

--
-- Name: measure_groundwater_conductivity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_groundwater_conductivity AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.groundwater_conductivity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_groundwater_conductivity OWNER TO postgres;

--
-- Name: measure_groundwater_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_groundwater_level AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.groundwater_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_groundwater_level OWNER TO postgres;

--
-- Name: measure_groundwater_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_groundwater_temperature AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.groundwater_temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_groundwater_temperature OWNER TO postgres;

--
-- Name: measure_humidity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_humidity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.humidity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_humidity OWNER TO postgres;

--
-- Name: measure_manual_groundwater_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_manual_groundwater_level AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.manual_groundwater_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_manual_groundwater_level OWNER TO postgres;

--
-- Name: measure_manual_water_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_manual_water_level AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.manual_water_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_manual_water_level OWNER TO postgres;

--
-- Name: measure_metadata; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_metadata AS
 SELECT ('measure_'::text || (pg_class.relname)::text) AS measure_table,
    m.name,
    m.unit_of_measure,
    m.x_axis_type
   FROM (measure.measure_metadata m
     JOIN pg_class ON ((pg_class.oid = (m.measure_table)::oid)));


ALTER TABLE qgis.measure_metadata OWNER TO postgres;

--
-- Name: measure_nebulosity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_nebulosity AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.nebulosity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_nebulosity OWNER TO postgres;

--
-- Name: measure_optical_imagery; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_optical_imagery AS
 SELECT m.id,
    m.station_id,
    m.scan_date,
    m.depth_range,
    m.image_data,
    m.image_format,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    lower(m.depth_range) AS depth_from,
    upper(m.depth_range) AS depth_to
   FROM (measure.optical_imagery m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_optical_imagery OWNER TO postgres;

--
-- Name: measure_pasquill_index; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_pasquill_index AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.pasquill_index m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_pasquill_index OWNER TO postgres;

--
-- Name: measure_potential_evapotranspiration; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_potential_evapotranspiration AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.potential_evapotranspiration m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_potential_evapotranspiration OWNER TO postgres;

--
-- Name: measure_rain; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_rain AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.rain m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_rain OWNER TO postgres;

--
-- Name: measure_raw_groundwater_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_raw_groundwater_level AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.time_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.time_interval) AS interval_s,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.raw_groundwater_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_raw_groundwater_level OWNER TO postgres;

--
-- Name: measure_stratigraphic_logvalue; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_stratigraphic_logvalue AS
 SELECT stratigraphic_logvalue.station_id,
    stratigraphic_logvalue.depth,
    stratigraphic_logvalue.rock_code,
    stratigraphic_logvalue.rock_description,
    stratigraphic_logvalue.formation_code,
    stratigraphic_logvalue.formation_description,
    stratigraphic_logvalue.dataset_id,
    lower(stratigraphic_logvalue.depth) AS depth_from,
    upper(stratigraphic_logvalue.depth) AS depth_to,
    NULL::public.geometry(Polygon,4326) AS geom
   FROM measure.stratigraphic_logvalue;


ALTER TABLE qgis.measure_stratigraphic_logvalue OWNER TO postgres;

--
-- Name: measure_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_temperature AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_temperature OWNER TO postgres;

--
-- Name: measure_tool_injection_pressure; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_tool_injection_pressure AS
 SELECT m.id,
    m.station_id,
    m.start_measure_altitude,
    m.altitude_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom
   FROM (measure.tool_injection_pressure m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_tool_injection_pressure OWNER TO postgres;

--
-- Name: measure_tool_instant_speed; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_tool_instant_speed AS
 SELECT m.id,
    m.station_id,
    m.start_measure_altitude,
    m.altitude_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom
   FROM (measure.tool_instant_speed m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_tool_instant_speed OWNER TO postgres;

--
-- Name: measure_tool_rotation_couple; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_tool_rotation_couple AS
 SELECT m.id,
    m.station_id,
    m.start_measure_altitude,
    m.altitude_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom
   FROM (measure.tool_rotation_couple m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_tool_rotation_couple OWNER TO postgres;

--
-- Name: measure_water_conductivity; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_water_conductivity AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.water_conductivity m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_water_conductivity OWNER TO postgres;

--
-- Name: measure_water_discharge; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_water_discharge AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.water_discharge m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_water_discharge OWNER TO postgres;

--
-- Name: measure_water_level; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_water_level AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.water_level m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_water_level OWNER TO postgres;

--
-- Name: measure_water_ph; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_water_ph AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.water_ph m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_water_ph OWNER TO postgres;

--
-- Name: measure_water_temperature; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_water_temperature AS
 SELECT m.id,
    m.station_id,
    m.measure_time,
    m.measure_value,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.measure_time) AS measure_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.water_temperature m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_water_temperature OWNER TO postgres;

--
-- Name: measure_weight_on_tool; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_weight_on_tool AS
 SELECT m.id,
    m.station_id,
    m.start_measure_altitude,
    m.altitude_interval,
    array_to_string(m.measures, ','::text) AS measures,
    m.campaign_id,
    m.dataset_id,
    s.name AS station_name,
    s.point AS geom
   FROM (measure.weight_on_tool m
     JOIN station.station s ON ((s.id = m.station_id)));


ALTER TABLE qgis.measure_weight_on_tool OWNER TO postgres;

--
-- Name: measure_wind_direction; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_wind_direction AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.wind_direction m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_wind_direction OWNER TO postgres;

--
-- Name: measure_wind_force; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.measure_wind_force AS
 SELECT m.id,
    m.station_id,
    m.start_measure_time,
    m.end_measure_time,
    m.measure_value,
    m.periodicity,
    m.reference,
    m.campaign_id,
    m.dataset_id,
    date_part('epoch'::text, m.start_measure_time) AS start_epoch,
    date_part('epoch'::text, m.end_measure_time) AS end_epoch,
    s.name AS station_name,
    s.point AS geom,
    i.model AS instrument_model,
    i.serial_number AS instrument_serial_model
   FROM (((measure.wind_force m
     JOIN station.station s ON ((s.id = m.station_id)))
     LEFT JOIN measure.campaign c ON ((m.campaign_id = c.id)))
     LEFT JOIN measure.instrument i ON ((c.instrument_id = i.id)));


ALTER TABLE qgis.measure_wind_force OWNER TO postgres;

--
-- Name: site; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.site AS
SELECT
    NULL::integer AS id,
    NULL::text AS name,
    NULL::public.geometry(Polygon,4326) AS site_extent;


ALTER TABLE qgis.site OWNER TO postgres;

--
-- Name: station; Type: VIEW; Schema: qgis; Owner: postgres
--

CREATE VIEW qgis.station AS
 SELECT station.id,
    station.site_id,
    station.station_family,
    station.station_type,
    station.name,
    station.point,
    station.orig_srid,
    station.ground_altitude,
    station.dataset_id
   FROM station.station;


ALTER TABLE qgis.station OWNER TO postgres;

--
-- Name: geologic_code; Type: TABLE; Schema: ref; Owner: postgres
--

CREATE TABLE ref.geologic_code (
    id integer NOT NULL,
    parent_id bigint,
    name_en text,
    code text,
    color ref.rgb_hex
);


ALTER TABLE ref.geologic_code OWNER TO postgres;

--
-- Name: geologic_code_id_seq; Type: SEQUENCE; Schema: ref; Owner: postgres
--

CREATE SEQUENCE ref.geologic_code_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ref.geologic_code_id_seq OWNER TO postgres;

--
-- Name: geologic_code_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: postgres
--

ALTER SEQUENCE ref.geologic_code_id_seq OWNED BY ref.geologic_code.id;


--
-- Name: rock_code; Type: TABLE; Schema: ref; Owner: postgres
--

CREATE TABLE ref.rock_code (
    code integer NOT NULL,
    authority ref.roc_code_authority DEFAULT 'USGS'::ref.roc_code_authority,
    description text,
    svg_pattern text
);


ALTER TABLE ref.rock_code OWNER TO postgres;

--
-- Name: station_chimney; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_chimney (
    id bigint NOT NULL,
    chimney_type station.chimney_type,
    nuclear_facility_name text,
    facility_name text,
    building_name text,
    height double precision,
    flow_rate double precision,
    surface double precision
);


ALTER TABLE station.station_chimney OWNER TO postgres;

--
-- Name: chimney; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.chimney AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.chimney_type,
    c.nuclear_facility_name,
    c.facility_name,
    c.building_name,
    c.height,
    c.flow_rate,
    c.surface
   FROM (station.station_chimney c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.chimney OWNER TO postgres;

--
-- Name: station_device; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_device (
    id bigint NOT NULL,
    device_type station.device_type
);


ALTER TABLE station.station_device OWNER TO postgres;

--
-- Name: device; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.device AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.device_type
   FROM (station.station_device c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.device OWNER TO postgres;

--
-- Name: station_hydrology; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_hydrology (
    id bigint NOT NULL,
    hydrology_station_type station.hydrology_station_type,
    a double precision,
    b double precision
);


ALTER TABLE station.station_hydrology OWNER TO postgres;

--
-- Name: hydrology_station; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.hydrology_station AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.hydrology_station_type,
    c.a,
    c.b
   FROM (station.station_hydrology c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.hydrology_station OWNER TO postgres;

--
-- Name: station_sample; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_sample (
    id bigint NOT NULL,
    sample_family station.sample_family,
    sample_type text
);


ALTER TABLE station.station_sample OWNER TO postgres;

--
-- Name: sample; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.sample AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.sample_family,
    c.sample_type
   FROM (station.station_sample c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.sample OWNER TO postgres;

--
-- Name: site; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.site (
    id integer NOT NULL,
    name text
);


ALTER TABLE station.site OWNER TO postgres;

--
-- Name: site_id_seq; Type: SEQUENCE; Schema: station; Owner: postgres
--

CREATE SEQUENCE station.site_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE station.site_id_seq OWNER TO postgres;

--
-- Name: site_id_seq; Type: SEQUENCE OWNED BY; Schema: station; Owner: postgres
--

ALTER SEQUENCE station.site_id_seq OWNED BY station.site.id;


--
-- Name: station_id_seq; Type: SEQUENCE; Schema: station; Owner: postgres
--

CREATE SEQUENCE station.station_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE station.station_id_seq OWNER TO postgres;

--
-- Name: station_id_seq; Type: SEQUENCE OWNED BY; Schema: station; Owner: postgres
--

ALTER SEQUENCE station.station_id_seq OWNED BY station.station.id;


--
-- Name: station_weather_station; Type: TABLE; Schema: station; Owner: postgres
--

CREATE TABLE station.station_weather_station (
    id bigint NOT NULL,
    weather_station_type station.weather_station_type,
    height double precision
);


ALTER TABLE station.station_weather_station OWNER TO postgres;

--
-- Name: weather_station; Type: VIEW; Schema: station; Owner: postgres
--

CREATE VIEW station.weather_station AS
 SELECT p.id,
    p.site_id,
    p.station_family,
    p.station_type,
    p.name,
    p.point,
    p.orig_srid,
    p.ground_altitude,
    p.dataset_id,
    c.weather_station_type,
    c.height
   FROM (station.station_weather_station c
     LEFT JOIN station.station p ON ((p.id = c.id)));


ALTER TABLE station.weather_station OWNER TO postgres;

--
-- Name: borehole_type_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.borehole_type_fr (
    borehole_type station.borehole_type,
    description text
);


ALTER TABLE tr.borehole_type_fr OWNER TO postgres;

--
-- Name: chimney_type_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.chimney_type_fr (
    chimney_type station.chimney_type,
    description text
);


ALTER TABLE tr.chimney_type_fr OWNER TO postgres;

--
-- Name: device_type_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.device_type_fr (
    device_type station.device_type,
    description text
);


ALTER TABLE tr.device_type_fr OWNER TO postgres;

--
-- Name: hydrology_station_type_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.hydrology_station_type_fr (
    hydrology_station_type station.hydrology_station_type,
    description text
);


ALTER TABLE tr.hydrology_station_type_fr OWNER TO postgres;

--
-- Name: sample_family_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.sample_family_fr (
    sample_family station.sample_family,
    description text
);


ALTER TABLE tr.sample_family_fr OWNER TO postgres;

--
-- Name: station_family_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.station_family_fr (
    station_family station.station_family,
    description text
);


ALTER TABLE tr.station_family_fr OWNER TO postgres;

--
-- Name: weather_station_type_fr; Type: TABLE; Schema: tr; Owner: postgres
--

CREATE TABLE tr.weather_station_type_fr (
    weather_station_type station.weather_station_type,
    description text
);


ALTER TABLE tr.weather_station_type_fr OWNER TO postgres;

--
-- Name: acoustic_imagery id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.acoustic_imagery ALTER COLUMN id SET DEFAULT nextval('measure.acoustic_imagery_id_seq'::regclass);


--
-- Name: atmospheric_pressure id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure ALTER COLUMN id SET DEFAULT nextval('measure.atmospheric_pressure_id_seq'::regclass);


--
-- Name: campaign id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.campaign ALTER COLUMN id SET DEFAULT nextval('measure.campaign_id_seq'::regclass);


--
-- Name: chemical_analysis_result id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chemical_analysis_result ALTER COLUMN id SET DEFAULT nextval('measure.chemical_analysis_result_id_seq'::regclass);


--
-- Name: chimney_release id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chimney_release ALTER COLUMN id SET DEFAULT nextval('measure.chimney_release_id_seq'::regclass);


--
-- Name: continuous_atmospheric_pressure id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure ALTER COLUMN id SET DEFAULT nextval('measure.continuous_atmospheric_pressure_id_seq'::regclass);


--
-- Name: continuous_groundwater_conductivity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity ALTER COLUMN id SET DEFAULT nextval('measure.continuous_groundwater_conductivity_id_seq'::regclass);


--
-- Name: continuous_groundwater_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level ALTER COLUMN id SET DEFAULT nextval('measure.continuous_groundwater_level_id_seq'::regclass);


--
-- Name: continuous_groundwater_pressure id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure ALTER COLUMN id SET DEFAULT nextval('measure.continuous_groundwater_pressure_id_seq'::regclass);


--
-- Name: continuous_groundwater_temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature ALTER COLUMN id SET DEFAULT nextval('measure.continuous_groundwater_temperature_id_seq'::regclass);


--
-- Name: continuous_humidity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity ALTER COLUMN id SET DEFAULT nextval('measure.continuous_humidity_id_seq'::regclass);


--
-- Name: continuous_nebulosity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity ALTER COLUMN id SET DEFAULT nextval('measure.continuous_nebulosity_id_seq'::regclass);


--
-- Name: continuous_pasquill_index id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index ALTER COLUMN id SET DEFAULT nextval('measure.continuous_pasquill_index_id_seq'::regclass);


--
-- Name: continuous_potential_evapotranspiration id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration ALTER COLUMN id SET DEFAULT nextval('measure.continuous_potential_evapotranspiration_id_seq'::regclass);


--
-- Name: continuous_rain id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain ALTER COLUMN id SET DEFAULT nextval('measure.continuous_rain_id_seq'::regclass);


--
-- Name: continuous_temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature ALTER COLUMN id SET DEFAULT nextval('measure.continuous_temperature_id_seq'::regclass);


--
-- Name: continuous_water_conductivity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity ALTER COLUMN id SET DEFAULT nextval('measure.continuous_water_conductivity_id_seq'::regclass);


--
-- Name: continuous_water_discharge id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge ALTER COLUMN id SET DEFAULT nextval('measure.continuous_water_discharge_id_seq'::regclass);


--
-- Name: continuous_water_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level ALTER COLUMN id SET DEFAULT nextval('measure.continuous_water_level_id_seq'::regclass);


--
-- Name: continuous_water_ph id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph ALTER COLUMN id SET DEFAULT nextval('measure.continuous_water_ph_id_seq'::regclass);


--
-- Name: continuous_water_temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature ALTER COLUMN id SET DEFAULT nextval('measure.continuous_water_temperature_id_seq'::regclass);


--
-- Name: continuous_wind_direction id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction ALTER COLUMN id SET DEFAULT nextval('measure.continuous_wind_direction_id_seq'::regclass);


--
-- Name: continuous_wind_force id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force ALTER COLUMN id SET DEFAULT nextval('measure.continuous_wind_force_id_seq'::regclass);


--
-- Name: groundwater_conductivity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity ALTER COLUMN id SET DEFAULT nextval('measure.groundwater_conductivity_id_seq'::regclass);


--
-- Name: groundwater_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level ALTER COLUMN id SET DEFAULT nextval('measure.groundwater_level_id_seq'::regclass);


--
-- Name: groundwater_temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature ALTER COLUMN id SET DEFAULT nextval('measure.groundwater_temperature_id_seq'::regclass);


--
-- Name: humidity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity ALTER COLUMN id SET DEFAULT nextval('measure.humidity_id_seq'::regclass);


--
-- Name: instrument id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.instrument ALTER COLUMN id SET DEFAULT nextval('measure.instrument_id_seq'::regclass);


--
-- Name: manual_groundwater_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level ALTER COLUMN id SET DEFAULT nextval('measure.manual_groundwater_level_id_seq'::regclass);


--
-- Name: manual_water_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level ALTER COLUMN id SET DEFAULT nextval('measure.manual_water_level_id_seq'::regclass);


--
-- Name: nebulosity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity ALTER COLUMN id SET DEFAULT nextval('measure.nebulosity_id_seq'::regclass);


--
-- Name: optical_imagery id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.optical_imagery ALTER COLUMN id SET DEFAULT nextval('measure.optical_imagery_id_seq'::regclass);


--
-- Name: pasquill_index id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index ALTER COLUMN id SET DEFAULT nextval('measure.pasquill_index_id_seq'::regclass);


--
-- Name: potential_evapotranspiration id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration ALTER COLUMN id SET DEFAULT nextval('measure.potential_evapotranspiration_id_seq'::regclass);


--
-- Name: rain id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain ALTER COLUMN id SET DEFAULT nextval('measure.rain_id_seq'::regclass);


--
-- Name: raw_groundwater_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level ALTER COLUMN id SET DEFAULT nextval('measure.raw_groundwater_level_id_seq'::regclass);


--
-- Name: temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature ALTER COLUMN id SET DEFAULT nextval('measure.temperature_id_seq'::regclass);


--
-- Name: tool_injection_pressure id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure ALTER COLUMN id SET DEFAULT nextval('measure.tool_injection_pressure_id_seq'::regclass);


--
-- Name: tool_instant_speed id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed ALTER COLUMN id SET DEFAULT nextval('measure.tool_instant_speed_id_seq'::regclass);


--
-- Name: tool_rotation_couple id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple ALTER COLUMN id SET DEFAULT nextval('measure.tool_rotation_couple_id_seq'::regclass);


--
-- Name: water_conductivity id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity ALTER COLUMN id SET DEFAULT nextval('measure.water_conductivity_id_seq'::regclass);


--
-- Name: water_discharge id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge ALTER COLUMN id SET DEFAULT nextval('measure.water_discharge_id_seq'::regclass);


--
-- Name: water_level id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level ALTER COLUMN id SET DEFAULT nextval('measure.water_level_id_seq'::regclass);


--
-- Name: water_ph id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph ALTER COLUMN id SET DEFAULT nextval('measure.water_ph_id_seq'::regclass);


--
-- Name: water_temperature id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature ALTER COLUMN id SET DEFAULT nextval('measure.water_temperature_id_seq'::regclass);


--
-- Name: weight_on_tool id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool ALTER COLUMN id SET DEFAULT nextval('measure.weight_on_tool_id_seq'::regclass);


--
-- Name: wind_direction id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction ALTER COLUMN id SET DEFAULT nextval('measure.wind_direction_id_seq'::regclass);


--
-- Name: wind_force id; Type: DEFAULT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force ALTER COLUMN id SET DEFAULT nextval('measure.wind_force_id_seq'::regclass);


--
-- Name: dataset id; Type: DEFAULT; Schema: metadata; Owner: postgres
--

ALTER TABLE ONLY metadata.dataset ALTER COLUMN id SET DEFAULT nextval('metadata.dataset_id_seq'::regclass);


--
-- Name: layer_styles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.layer_styles ALTER COLUMN id SET DEFAULT nextval('public.layer_styles_id_seq'::regclass);


--
-- Name: geologic_code id; Type: DEFAULT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.geologic_code ALTER COLUMN id SET DEFAULT nextval('ref.geologic_code_id_seq'::regclass);


--
-- Name: site id; Type: DEFAULT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.site ALTER COLUMN id SET DEFAULT nextval('station.site_id_seq'::regclass);


--
-- Name: station id; Type: DEFAULT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station ALTER COLUMN id SET DEFAULT nextval('station.station_id_seq'::regclass);


--
-- Data for Name: acoustic_imagery; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.acoustic_imagery (id, station_id, scan_date, depth_range, image_data, image_format, dataset_id) FROM stdin;
\.


--
-- Data for Name: atmospheric_pressure; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.atmospheric_pressure (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: campaign; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.campaign (id, instrument_id, start_date) FROM stdin;
1	\N	\N
\.


--
-- Data for Name: chemical_analysis_result; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.chemical_analysis_result (id, station_id, measure_time, chemical_element, chemical_element_description, measure_value, measure_unit, measure_uncertainty, detection_limit, quantification_limit, analysis_method, sampling_method, sample_code, sample_family, sample_type, sample_name, sample_report, report_number, da_number, dataset_id) FROM stdin;
\.


--
-- Data for Name: chimney_release; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.chimney_release (id, station_id, start_measure_time, end_measure_time, chemical_element, release_speed, measure_value, measure_uncertainty, reference, dataset_id) FROM stdin;
\.


--
-- Data for Name: continuous_atmospheric_pressure; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_atmospheric_pressure (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_groundwater_conductivity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_groundwater_conductivity (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_groundwater_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_groundwater_level (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_groundwater_pressure; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_groundwater_pressure (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_groundwater_temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_groundwater_temperature (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_humidity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_humidity (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_nebulosity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_nebulosity (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_pasquill_index; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_pasquill_index (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_potential_evapotranspiration; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_potential_evapotranspiration (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_rain; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_rain (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_temperature (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_water_conductivity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_water_conductivity (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_water_discharge; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_water_discharge (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_water_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_water_level (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_water_ph; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_water_ph (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_water_temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_water_temperature (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_wind_direction; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_wind_direction (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: continuous_wind_force; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.continuous_wind_force (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: fracturing_rate; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.fracturing_rate (station_id, depth, value, dataset_id) FROM stdin;
\.


--
-- Data for Name: groundwater_conductivity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.groundwater_conductivity (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: groundwater_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.groundwater_level (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: groundwater_temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.groundwater_temperature (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
1	1	2020-01-01 00:00:00	10	1	4
2	1	2020-01-01 01:00:00	9.94999999999999929	1	4
3	1	2020-01-01 02:00:00	9.90000000000000036	1	4
4	1	2020-01-01 03:00:00	9.84999999999999964	1	4
5	1	2020-01-01 04:00:00	9.80000000000000071	1	4
6	1	2020-01-01 05:00:00	9.75	1	4
7	1	2020-01-01 06:00:00	9.69999999999999929	1	4
8	1	2020-01-01 07:00:00	9.65000000000000036	1	4
9	1	2020-01-01 08:00:00	9.59999999999999076	1	4
10	1	2020-01-01 09:00:00	9.69999999999999041	1	4
11	1	2020-01-01 10:00:00	9.79999999999999005	1	4
12	1	2020-01-01 11:00:00	9.8999999999999897	1	4
13	1	2020-01-01 12:00:00	10	1	4
14	1	2020-01-01 13:00:00	10.0999999999999996	1	4
15	1	2020-01-01 14:00:00	10.1999999999999993	1	4
16	1	2020-01-01 15:00:00	10.3000000000000007	1	4
17	1	2020-01-01 16:00:00	10.4000000000000004	1	4
18	1	2020-01-01 17:00:00	10.5	1	4
19	1	2020-01-01 18:00:00	10.5999999999999996	1	4
20	1	2020-01-01 19:00:00	10.5	1	4
21	1	2020-01-01 20:00:00	10.4000000000000004	1	4
22	1	2020-01-01 21:00:00	10.3000000000000007	1	4
23	1	2020-01-01 22:00:00	10.1999999999999993	1	4
24	1	2020-01-01 23:00:00	10.0999999999999996	1	4
25	1	2020-01-02 00:00:00	10	1	4
26	1	2020-01-02 01:00:00	9.94999999999999041	1	4
27	1	2020-01-02 02:00:00	9.8999999999999897	1	4
28	1	2020-01-02 03:00:00	9.84999999999999076	1	4
29	1	2020-01-02 04:00:00	9.79999999999999005	1	4
30	1	2020-01-02 05:00:00	9.74999999999999112	1	4
31	1	2020-01-02 06:00:00	9.69999999999999041	1	4
32	1	2020-01-02 07:00:00	9.6499999999999897	1	4
33	1	2020-01-02 08:00:00	9.59999999999999076	1	4
34	1	2020-01-02 09:00:00	9.69999999999999041	1	4
35	1	2020-01-02 10:00:00	9.79999999999999005	1	4
36	1	2020-01-02 11:00:00	9.8999999999999897	1	4
37	1	2020-01-02 12:00:00	9.99999999999999112	1	4
38	1	2020-01-02 13:00:00	10.0999999999999996	1	4
39	1	2020-01-02 14:00:00	10.1999999999999993	1	4
40	1	2020-01-02 15:00:00	10.3000000000000007	1	4
41	1	2020-01-02 16:00:00	10.4000000000000004	1	4
42	1	2020-01-02 17:00:00	10.5	1	4
43	1	2020-01-02 18:00:00	10.5999999999999996	1	4
44	1	2020-01-02 19:00:00	10.5	1	4
45	1	2020-01-02 20:00:00	10.4000000000000004	1	4
46	1	2020-01-02 21:00:00	10.3000000000000007	1	4
47	1	2020-01-02 22:00:00	10.1999999999999993	1	4
48	1	2020-01-02 23:00:00	10.0999999999999996	1	4
49	1	2020-01-03 00:00:00	9.99999999999999112	1	4
50	1	2020-01-03 01:00:00	9.94999999999999041	1	4
51	1	2020-01-03 02:00:00	9.89999999999998082	1	4
52	1	2020-01-03 03:00:00	9.8499999999999801	1	4
53	1	2020-01-03 04:00:00	9.79999999999998117	1	4
54	1	2020-01-03 05:00:00	9.74999999999998046	1	4
55	1	2020-01-03 06:00:00	9.69999999999998153	1	4
56	1	2020-01-03 07:00:00	9.64999999999998082	1	4
57	1	2020-01-03 08:00:00	9.5999999999999801	1	4
58	1	2020-01-03 09:00:00	9.69999999999998153	1	4
59	1	2020-01-03 10:00:00	9.79999999999998117	1	4
60	1	2020-01-03 11:00:00	9.89999999999998082	1	4
61	1	2020-01-03 12:00:00	9.99999999999998046	1	4
62	1	2020-01-03 13:00:00	10.0999999999999996	1	4
63	1	2020-01-03 14:00:00	10.1999999999999993	1	4
64	1	2020-01-03 15:00:00	10.3000000000000007	1	4
65	1	2020-01-03 16:00:00	10.4000000000000004	1	4
66	1	2020-01-03 17:00:00	10.5	1	4
67	1	2020-01-03 18:00:00	10.5999999999999996	1	4
68	1	2020-01-03 19:00:00	10.5	1	4
69	1	2020-01-03 20:00:00	10.4000000000000004	1	4
70	1	2020-01-03 21:00:00	10.3000000000000007	1	4
71	1	2020-01-03 22:00:00	10.1999999999999993	1	4
72	1	2020-01-03 23:00:00	10.0999999999999996	1	4
73	1	2020-01-04 00:00:00	9.99999999999998046	1	4
74	1	2020-01-04 01:00:00	9.94999999999998153	1	4
75	1	2020-01-04 02:00:00	9.89999999999998082	1	4
76	1	2020-01-04 03:00:00	9.8499999999999801	1	4
77	1	2020-01-04 04:00:00	9.79999999999998117	1	4
78	1	2020-01-04 05:00:00	9.74999999999998046	1	4
79	1	2020-01-04 06:00:00	9.69999999999997087	1	4
80	1	2020-01-04 07:00:00	9.64999999999997016	1	4
81	1	2020-01-04 08:00:00	9.59999999999996945	1	4
82	1	2020-01-04 09:00:00	9.69999999999997087	1	4
83	1	2020-01-04 10:00:00	9.79999999999997051	1	4
84	1	2020-01-04 11:00:00	9.89999999999997016	1	4
85	1	2020-01-04 12:00:00	9.9999999999999698	1	4
86	1	2020-01-04 13:00:00	10.0999999999999996	1	4
87	1	2020-01-04 14:00:00	10.1999999999999993	1	4
88	1	2020-01-04 15:00:00	10.3000000000000007	1	4
89	1	2020-01-04 16:00:00	10.4000000000000004	1	4
90	1	2020-01-04 17:00:00	10.5	1	4
91	1	2020-01-04 18:00:00	10.5999999999999996	1	4
92	1	2020-01-04 19:00:00	10.5	1	4
93	1	2020-01-04 20:00:00	10.4000000000000004	1	4
94	1	2020-01-04 21:00:00	10.3000000000000007	1	4
95	1	2020-01-04 22:00:00	10.1999999999999993	1	4
96	1	2020-01-04 23:00:00	10.0999999999999996	1	4
97	1	2020-01-05 00:00:00	9.9999999999999698	1	4
98	1	2020-01-05 01:00:00	9.94999999999997087	1	4
99	1	2020-01-05 02:00:00	9.89999999999997016	1	4
100	1	2020-01-05 03:00:00	9.84999999999996945	1	4
101	1	2020-01-05 04:00:00	9.79999999999997051	1	4
102	1	2020-01-05 05:00:00	9.7499999999999698	1	4
103	1	2020-01-05 06:00:00	9.69999999999997087	1	4
104	1	2020-01-05 07:00:00	9.64999999999997016	1	4
105	1	2020-01-05 08:00:00	9.59999999999996945	1	4
106	1	2020-01-05 09:00:00	9.69999999999997087	1	4
107	1	2020-01-05 10:00:00	9.79999999999997051	1	4
108	1	2020-01-05 11:00:00	9.89999999999997016	1	4
109	1	2020-01-05 12:00:00	9.99999999999996092	1	4
110	1	2020-01-05 13:00:00	10.0999999999999996	1	4
111	1	2020-01-05 14:00:00	10.1999999999999993	1	4
112	1	2020-01-05 15:00:00	10.3000000000000007	1	4
113	1	2020-01-05 16:00:00	10.4000000000000004	1	4
114	1	2020-01-05 17:00:00	10.5	1	4
115	1	2020-01-05 18:00:00	10.5999999999999996	1	4
116	1	2020-01-05 19:00:00	10.5	1	4
117	1	2020-01-05 20:00:00	10.4000000000000004	1	4
118	1	2020-01-05 21:00:00	10.3000000000000007	1	4
119	1	2020-01-05 22:00:00	10.1999999999999993	1	4
120	1	2020-01-05 23:00:00	10.0999999999999996	1	4
121	1	2020-01-06 00:00:00	9.99999999999996092	1	4
122	2	2020-01-01 00:00:00	11	1	5
123	2	2020-01-01 01:00:00	10.9499999999999993	1	5
124	2	2020-01-01 02:00:00	10.9000000000000004	1	5
125	2	2020-01-01 03:00:00	10.8499999999999996	1	5
126	2	2020-01-01 04:00:00	10.8000000000000007	1	5
127	2	2020-01-01 05:00:00	10.75	1	5
128	2	2020-01-01 06:00:00	10.6999999999999993	1	5
129	2	2020-01-01 07:00:00	10.6500000000000004	1	5
130	2	2020-01-01 08:00:00	10.5999999999999996	1	5
131	2	2020-01-01 09:00:00	10.6999999999999993	1	5
132	2	2020-01-01 10:00:00	10.8000000000000007	1	5
133	2	2020-01-01 11:00:00	10.9000000000000004	1	5
134	2	2020-01-01 12:00:00	11	1	5
135	2	2020-01-01 13:00:00	11.0999999999999996	1	5
136	2	2020-01-01 14:00:00	11.1999999999999993	1	5
137	2	2020-01-01 15:00:00	11.3000000000000007	1	5
138	2	2020-01-01 16:00:00	11.4000000000000004	1	5
139	2	2020-01-01 17:00:00	11.5	1	5
140	2	2020-01-01 18:00:00	11.5999999999999996	1	5
141	2	2020-01-01 19:00:00	11.5	1	5
142	2	2020-01-01 20:00:00	11.4000000000000004	1	5
143	2	2020-01-01 21:00:00	11.3000000000000007	1	5
144	2	2020-01-01 22:00:00	11.1999999999999993	1	5
145	2	2020-01-01 23:00:00	11.0999999999999996	1	5
146	2	2020-01-02 00:00:00	11	1	5
147	2	2020-01-02 01:00:00	10.9499999999999993	1	5
148	2	2020-01-02 02:00:00	10.9000000000000004	1	5
149	2	2020-01-02 03:00:00	10.8499999999999996	1	5
150	2	2020-01-02 04:00:00	10.8000000000000007	1	5
151	2	2020-01-02 05:00:00	10.75	1	5
152	2	2020-01-02 06:00:00	10.6999999999999993	1	5
153	2	2020-01-02 07:00:00	10.6500000000000004	1	5
154	2	2020-01-02 08:00:00	10.5999999999999996	1	5
155	2	2020-01-02 09:00:00	10.6999999999999993	1	5
156	2	2020-01-02 10:00:00	10.8000000000000007	1	5
157	2	2020-01-02 11:00:00	10.9000000000000004	1	5
158	2	2020-01-02 12:00:00	11	1	5
159	2	2020-01-02 13:00:00	11.0999999999999996	1	5
160	2	2020-01-02 14:00:00	11.1999999999999993	1	5
161	2	2020-01-02 15:00:00	11.3000000000000007	1	5
162	2	2020-01-02 16:00:00	11.4000000000000004	1	5
163	2	2020-01-02 17:00:00	11.5	1	5
164	2	2020-01-02 18:00:00	11.5999999999999996	1	5
165	2	2020-01-02 19:00:00	11.5	1	5
166	2	2020-01-02 20:00:00	11.4000000000000004	1	5
167	2	2020-01-02 21:00:00	11.3000000000000007	1	5
168	2	2020-01-02 22:00:00	11.1999999999999993	1	5
169	2	2020-01-02 23:00:00	11.0999999999999996	1	5
170	2	2020-01-03 00:00:00	11	1	5
171	2	2020-01-03 01:00:00	10.9499999999999993	1	5
172	2	2020-01-03 02:00:00	10.9000000000000004	1	5
173	2	2020-01-03 03:00:00	10.8499999999999996	1	5
174	2	2020-01-03 04:00:00	10.8000000000000007	1	5
175	2	2020-01-03 05:00:00	10.75	1	5
176	2	2020-01-03 06:00:00	10.6999999999999993	1	5
177	2	2020-01-03 07:00:00	10.6500000000000004	1	5
178	2	2020-01-03 08:00:00	10.5999999999999996	1	5
179	2	2020-01-03 09:00:00	10.6999999999999993	1	5
180	2	2020-01-03 10:00:00	10.8000000000000007	1	5
181	2	2020-01-03 11:00:00	10.9000000000000004	1	5
182	2	2020-01-03 12:00:00	11	1	5
183	2	2020-01-03 13:00:00	11.0999999999999996	1	5
184	2	2020-01-03 14:00:00	11.1999999999999993	1	5
185	2	2020-01-03 15:00:00	11.3000000000000007	1	5
186	2	2020-01-03 16:00:00	11.4000000000000004	1	5
187	2	2020-01-03 17:00:00	11.5	1	5
188	2	2020-01-03 18:00:00	11.5999999999999996	1	5
189	2	2020-01-03 19:00:00	11.5	1	5
190	2	2020-01-03 20:00:00	11.4000000000000004	1	5
191	2	2020-01-03 21:00:00	11.3000000000000007	1	5
192	2	2020-01-03 22:00:00	11.1999999999999993	1	5
193	2	2020-01-03 23:00:00	11.0999999999999996	1	5
194	2	2020-01-04 00:00:00	11	1	5
195	2	2020-01-04 01:00:00	10.9499999999999993	1	5
196	2	2020-01-04 02:00:00	10.9000000000000004	1	5
197	2	2020-01-04 03:00:00	10.8499999999999996	1	5
198	2	2020-01-04 04:00:00	10.8000000000000007	1	5
199	2	2020-01-04 05:00:00	10.75	1	5
200	2	2020-01-04 06:00:00	10.6999999999999993	1	5
201	2	2020-01-04 07:00:00	10.6500000000000004	1	5
202	2	2020-01-04 08:00:00	10.5999999999999996	1	5
203	2	2020-01-04 09:00:00	10.6999999999999993	1	5
204	2	2020-01-04 10:00:00	10.8000000000000007	1	5
205	2	2020-01-04 11:00:00	10.9000000000000004	1	5
206	2	2020-01-04 12:00:00	11	1	5
207	2	2020-01-04 13:00:00	11.0999999999999996	1	5
208	2	2020-01-04 14:00:00	11.1999999999999993	1	5
209	2	2020-01-04 15:00:00	11.3000000000000007	1	5
210	2	2020-01-04 16:00:00	11.4000000000000004	1	5
211	2	2020-01-04 17:00:00	11.5	1	5
212	2	2020-01-04 18:00:00	11.5999999999999996	1	5
213	2	2020-01-04 19:00:00	11.5	1	5
214	2	2020-01-04 20:00:00	11.4000000000000004	1	5
215	2	2020-01-04 21:00:00	11.3000000000000007	1	5
216	2	2020-01-04 22:00:00	11.1999999999999993	1	5
217	2	2020-01-04 23:00:00	11.0999999999999996	1	5
218	2	2020-01-05 00:00:00	11	1	5
219	2	2020-01-05 01:00:00	10.9499999999999993	1	5
220	2	2020-01-05 02:00:00	10.9000000000000004	1	5
221	2	2020-01-05 03:00:00	10.8499999999999996	1	5
222	2	2020-01-05 04:00:00	10.8000000000000007	1	5
223	2	2020-01-05 05:00:00	10.75	1	5
224	2	2020-01-05 06:00:00	10.6999999999999993	1	5
225	2	2020-01-05 07:00:00	10.6500000000000004	1	5
226	2	2020-01-05 08:00:00	10.5999999999999996	1	5
227	2	2020-01-05 09:00:00	10.6999999999999993	1	5
228	2	2020-01-05 10:00:00	10.8000000000000007	1	5
229	2	2020-01-05 11:00:00	10.9000000000000004	1	5
230	2	2020-01-05 12:00:00	11	1	5
231	2	2020-01-05 13:00:00	11.0999999999999996	1	5
232	2	2020-01-05 14:00:00	11.1999999999999993	1	5
233	2	2020-01-05 15:00:00	11.3000000000000007	1	5
234	2	2020-01-05 16:00:00	11.4000000000000004	1	5
235	2	2020-01-05 17:00:00	11.5	1	5
236	2	2020-01-05 18:00:00	11.5999999999999996	1	5
237	2	2020-01-05 19:00:00	11.5	1	5
238	2	2020-01-05 20:00:00	11.4000000000000004	1	5
239	2	2020-01-05 21:00:00	11.3000000000000007	1	5
240	2	2020-01-05 22:00:00	11.1999999999999993	1	5
241	2	2020-01-05 23:00:00	11.0999999999999996	1	5
242	2	2020-01-06 00:00:00	11	1	5
\.


--
-- Data for Name: humidity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.humidity (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: instrument; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.instrument (id, model, serial_number, sensor_range) FROM stdin;
\.


--
-- Data for Name: manual_groundwater_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.manual_groundwater_level (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: manual_water_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.manual_water_level (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: measure_metadata; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.measure_metadata (measure_table, name, unit_of_measure, x_axis_type, storage_type) FROM stdin;
measure.atmospheric_pressure	Pression atmosphérique	m	TimeAxis	Cumulative
measure.continuous_atmospheric_pressure	Pression atmosphérique (capteurs)	m	TimeAxis	Continuous
measure.continuous_groundwater_pressure	Pression d'eau (capteurs)	m	TimeAxis	Continuous
measure.groundwater_level	Cote de nappe	m	TimeAxis	Instantaneous
measure.manual_groundwater_level	Cote de nappe (mesures manuelles)	m	TimeAxis	Instantaneous
measure.raw_groundwater_level	Cote de nappe brute (capteurs)	m	TimeAxis	Continuous
measure.continuous_groundwater_level	Cote de nappe (capteurs)	m	TimeAxis	Continuous
measure.groundwater_temperature	Température nappe	°C	TimeAxis	Instantaneous
measure.continuous_groundwater_temperature	Température nappe (capteurs)	°C	TimeAxis	Continuous
measure.groundwater_conductivity	Conductivité nappe	S/m	TimeAxis	Instantaneous
measure.continuous_groundwater_conductivity	Conductivité nappe (capteurs)	S/m	TimeAxis	Continuous
measure.water_level	Hauteur d'eau	m	TimeAxis	Instantaneous
measure.manual_water_level	Hauteur d'eau (mesures manuelles)	m	TimeAxis	Instantaneous
measure.continuous_water_level	Hauteur d'eau (capteurs)	m	TimeAxis	Continuous
measure.water_discharge	Débit	m3/s	TimeAxis	Instantaneous
measure.continuous_water_discharge	Débit (capteurs)	m3/s	TimeAxis	Continuous
measure.water_ph	pH		TimeAxis	Instantaneous
measure.continuous_water_ph	pH (capteurs)		TimeAxis	Continuous
measure.water_temperature	Température eau	°C	TimeAxis	Instantaneous
measure.continuous_water_temperature	Température eau (capteurs)	°C	TimeAxis	Continuous
measure.water_conductivity	Conductivité eau	S/m	TimeAxis	Instantaneous
measure.continuous_water_conductivity	Conductivité eau (capteurs)	S/m	TimeAxis	Continuous
measure.rain	Pluie	m	TimeAxis	Cumulative
measure.continuous_rain	Pluie (capteurs)	m	TimeAxis	Continuous
measure.potential_evapotranspiration	ETP	m	TimeAxis	Cumulative
measure.continuous_potential_evapotranspiration	ETP (capteurs)	m	TimeAxis	Continuous
measure.temperature	Température	°C	TimeAxis	Cumulative
measure.continuous_temperature	Température (capteurs)	°C	TimeAxis	Continuous
measure.wind_direction	Direction du vent	°	TimeAxis	Cumulative
measure.continuous_wind_direction	Direction du vent (capteurs)	°	TimeAxis	Continuous
measure.wind_force	Force du vent	noeuds	TimeAxis	Cumulative
measure.continuous_wind_force	Force du vent (capteurs)	noeuds	TimeAxis	Continuous
measure.pasquill_index	Indice de stabilité de Pasquill		TimeAxis	Cumulative
measure.continuous_pasquill_index	Indice de stabilité de Pasquill (capteurs)		TimeAxis	Continuous
measure.nebulosity	Nébulosité		TimeAxis	Cumulative
measure.continuous_nebulosity	Nébulosité (capteurs)		TimeAxis	Continuous
measure.humidity	Humidité		TimeAxis	Cumulative
measure.continuous_humidity	Humidité (capteurs)		TimeAxis	Continuous
measure.tool_instant_speed	Vitesse instantanée d'avancement	m/s	DepthAxis	Continuous
measure.weight_on_tool	Poids sur l'outil	kg	DepthAxis	Continuous
measure.tool_injection_pressure	Pression d'injection	Pa	DepthAxis	Continuous
measure.tool_rotation_couple	Couple de rotation	N.m	DepthAxis	Continuous
measure.optical_imagery	Imagerie optique	\N	DepthAxis	Image
measure.acoustic_imagery	Imagerie acoustique	\N	DepthAxis	Image
\.


--
-- Data for Name: nebulosity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.nebulosity (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: optical_imagery; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.optical_imagery (id, station_id, scan_date, depth_range, image_data, image_format, dataset_id) FROM stdin;
\.


--
-- Data for Name: pasquill_index; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.pasquill_index (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: potential_evapotranspiration; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.potential_evapotranspiration (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: rain; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.rain (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: raw_groundwater_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.raw_groundwater_level (id, station_id, start_measure_time, time_interval, campaign_id, dataset_id, measures) FROM stdin;
\.


--
-- Data for Name: stratigraphic_logvalue; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.stratigraphic_logvalue (station_id, depth, rock_code, rock_description, formation_code, formation_description, dataset_id) FROM stdin;
1	[0.0,40.0)	627	Calcaire comblanchoide	J2b	Bathonien	7
1	[40.0,50.0)	635	Calcaire à oolithes	J2a-b	Bathonien	7
1	[50.0,80.0)	640	Calcaire à oncolithes et chailles	J2a	Bathonien	7
1	[80.0,85.0)	638	Calcaire marneux lumachellique	J1c2	Bajocien	7
1	[85.0,100.0)	675	Marne à Ostrea Acuminata	J1c1	Bajocien	7
1	[100.0,110.0)	627	Calcaire à entroques	J1a-b	Bajocien	7
\.


--
-- Data for Name: temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.temperature (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: tool_injection_pressure; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.tool_injection_pressure (id, station_id, start_measure_altitude, altitude_interval, measures, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: tool_instant_speed; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.tool_instant_speed (id, station_id, start_measure_altitude, altitude_interval, measures, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: tool_rotation_couple; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.tool_rotation_couple (id, station_id, start_measure_altitude, altitude_interval, measures, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: water_conductivity; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.water_conductivity (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: water_discharge; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.water_discharge (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: water_level; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.water_level (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: water_ph; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.water_ph (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: water_temperature; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.water_temperature (id, station_id, measure_time, measure_value, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: weight_on_tool; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.weight_on_tool (id, station_id, start_measure_altitude, altitude_interval, measures, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: wind_direction; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.wind_direction (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: wind_force; Type: TABLE DATA; Schema: measure; Owner: postgres
--

COPY measure.wind_force (id, station_id, start_measure_time, end_measure_time, measure_value, periodicity, reference, campaign_id, dataset_id) FROM stdin;
\.


--
-- Data for Name: dataset; Type: TABLE DATA; Schema: metadata; Owner: postgres
--

COPY metadata.dataset (id, data_name, import_time, parent_ids) FROM stdin;
1	bdlhes_qgis_plugin/QGeoloGIS/sample/data/DUMMYSITE/stations.csv	2020-03-18 11:31:43.618926	\N
2	hydrology_campaign_for_site_1	2020-03-18 11:31:43.635546	{}
3	bdlhes_qgis_plugin/QGeoloGIS/sample/data/DUMMYSITE/FORAGES/forages.csv	2020-03-18 11:31:43.640494	\N
4	bdlhes_qgis_plugin/QGeoloGIS/sample/data/DUMMYSITE/HYDROGEOLOGIE/SYNTHESE/S1/groundwater_temperature.csv	2020-03-18 11:31:43.651308	\N
5	bdlhes_qgis_plugin/QGeoloGIS/sample/data/DUMMYSITE/HYDROGEOLOGIE/SYNTHESE/S2/groundwater_temperature.csv	2020-03-18 11:31:43.651308	\N
6	hydrogeology_campaign_for_site_1	2020-03-18 11:31:43.709525	{}
7	bdlhes_qgis_plugin/QGeoloGIS/sample/data/DUMMYSITE/FORAGES/stratigraphie.csv	2020-03-18 11:31:43.715066	\N
\.


--
-- Data for Name: imported_data; Type: TABLE DATA; Schema: metadata; Owner: postgres
--

COPY metadata.imported_data (site_name, data_name, import_date) FROM stdin;
\.


--
-- Data for Name: layer_styles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.layer_styles (id, f_table_catalog, f_table_schema, f_table_name, f_geometry_column, stylename, styleqml, stylesld, useasdefault, description, owner, ui, update_time) FROM stdin;
1	qgeologistest	station	station	point	stations_bdlhes	<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>\n<qgis version="2.18.21" simplifyAlgorithm="0" minimumScale="0" maximumScale="1e+08" simplifyDrawingHints="0" minLabelScale="0" maxLabelScale="1e+08" simplifyDrawingTol="1" readOnly="0" simplifyMaxScale="1" hasScaleBasedVisibilityFlag="0" simplifyLocal="1" scaleBasedLabelVisibilityFlag="0">\n  <edittypes>\n    <edittype widgetv2type="TextEdit" name="id">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n    <edittype widgetv2type="TextEdit" name="site_id">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n    <edittype widgetv2type="TextEdit" name="station_type">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n    <edittype widgetv2type="TextEdit" name="name">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n    <edittype widgetv2type="TextEdit" name="orig_srid">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n    <edittype widgetv2type="TextEdit" name="ground_altitude">\n      <widgetv2config IsMultiline="0" fieldEditable="1" constraint="" UseHtml="0" labelOnTop="0" constraintDescription="" notNull="0"/>\n    </edittype>\n  </edittypes>\n  <renderer-v2 attr="station_type" forceraster="0" symbollevels="0" type="categorizedSymbol" enableorderby="0">\n    <categories>\n      <category render="true" symbol="0" value="Borehole" label="Borehole"/>\n      <category render="true" symbol="1" value="FilledUpDrill" label="FilledUpDrill"/>\n      <category render="true" symbol="2" value="GeotechnicDrill" label="GeotechnicDrill"/>\n      <category render="true" symbol="3" value="ObservationWell" label="ObservationWell"/>\n      <category render="true" symbol="4" value="Piezometer" label="Piezometer"/>\n      <category render="true" symbol="5" value="PumpingWell" label="PumpingWell"/>\n      <category render="true" symbol="6" value="River" label="River"/>\n      <category render="true" symbol="7" value="Sampling" label="Sampling"/>\n      <category render="true" symbol="8" value="Source" label="Source"/>\n      <category render="true" symbol="9" value="WeatherStation" label="WeatherStation"/>\n      <category render="true" symbol="10" value="" label=""/>\n    </categories>\n    <symbols>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="0">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="158,227,45,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="1">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="146,29,209,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="10">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="209,180,36,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="2">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="225,26,79,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="3">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="237,82,209,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="4">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="76,215,141,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="5">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="218,125,89,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="6">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="107,93,237,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="7">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="36,226,229,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="8">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="88,144,213,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="9">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="73,209,63,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n    </symbols>\n    <source-symbol>\n      <symbol alpha="1" clip_to_extent="1" type="marker" name="0">\n        <layer pass="0" class="SimpleMarker" locked="0">\n          <prop k="angle" v="0"/>\n          <prop k="color" v="34,42,132,255"/>\n          <prop k="horizontal_anchor_point" v="1"/>\n          <prop k="joinstyle" v="bevel"/>\n          <prop k="name" v="circle"/>\n          <prop k="offset" v="0,0"/>\n          <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="offset_unit" v="MM"/>\n          <prop k="outline_color" v="0,0,0,255"/>\n          <prop k="outline_style" v="solid"/>\n          <prop k="outline_width" v="0"/>\n          <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="outline_width_unit" v="MM"/>\n          <prop k="scale_method" v="diameter"/>\n          <prop k="size" v="2"/>\n          <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n          <prop k="size_unit" v="MM"/>\n          <prop k="vertical_anchor_point" v="1"/>\n        </layer>\n      </symbol>\n    </source-symbol>\n    <colorramp type="randomcolors" name="[source]"/>\n    <invertedcolorramp value="0"/>\n    <rotation/>\n    <sizescale scalemethod="diameter"/>\n  </renderer-v2>\n  <labeling type="simple"/>\n  <customproperties>\n    <property key="embeddedWidgets/count" value="0"/>\n    <property key="labeling" value="pal"/>\n    <property key="labeling/addDirectionSymbol" value="false"/>\n    <property key="labeling/angleOffset" value="0"/>\n    <property key="labeling/blendMode" value="0"/>\n    <property key="labeling/bufferBlendMode" value="0"/>\n    <property key="labeling/bufferColorA" value="255"/>\n    <property key="labeling/bufferColorB" value="255"/>\n    <property key="labeling/bufferColorG" value="255"/>\n    <property key="labeling/bufferColorR" value="255"/>\n    <property key="labeling/bufferDraw" value="false"/>\n    <property key="labeling/bufferJoinStyle" value="128"/>\n    <property key="labeling/bufferNoFill" value="false"/>\n    <property key="labeling/bufferSize" value="1"/>\n    <property key="labeling/bufferSizeInMapUnits" value="false"/>\n    <property key="labeling/bufferSizeMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/bufferTransp" value="0"/>\n    <property key="labeling/centroidInside" value="false"/>\n    <property key="labeling/centroidWhole" value="false"/>\n    <property key="labeling/decimals" value="3"/>\n    <property key="labeling/displayAll" value="false"/>\n    <property key="labeling/dist" value="0"/>\n    <property key="labeling/distInMapUnits" value="false"/>\n    <property key="labeling/distMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/drawLabels" value="true"/>\n    <property key="labeling/enabled" value="true"/>\n    <property key="labeling/fieldName" value="name"/>\n    <property key="labeling/fitInPolygonOnly" value="false"/>\n    <property key="labeling/fontCapitals" value="0"/>\n    <property key="labeling/fontFamily" value="Sans"/>\n    <property key="labeling/fontItalic" value="false"/>\n    <property key="labeling/fontLetterSpacing" value="0"/>\n    <property key="labeling/fontLimitPixelSize" value="false"/>\n    <property key="labeling/fontMaxPixelSize" value="10000"/>\n    <property key="labeling/fontMinPixelSize" value="3"/>\n    <property key="labeling/fontSize" value="9"/>\n    <property key="labeling/fontSizeInMapUnits" value="false"/>\n    <property key="labeling/fontSizeMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/fontStrikeout" value="false"/>\n    <property key="labeling/fontUnderline" value="false"/>\n    <property key="labeling/fontWeight" value="50"/>\n    <property key="labeling/fontWordSpacing" value="0"/>\n    <property key="labeling/formatNumbers" value="false"/>\n    <property key="labeling/isExpression" value="false"/>\n    <property key="labeling/labelOffsetInMapUnits" value="true"/>\n    <property key="labeling/labelOffsetMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/labelPerPart" value="false"/>\n    <property key="labeling/leftDirectionSymbol" value="&lt;"/>\n    <property key="labeling/limitNumLabels" value="false"/>\n    <property key="labeling/maxCurvedCharAngleIn" value="25"/>\n    <property key="labeling/maxCurvedCharAngleOut" value="-25"/>\n    <property key="labeling/maxNumLabels" value="2000"/>\n    <property key="labeling/mergeLines" value="false"/>\n    <property key="labeling/minFeatureSize" value="0"/>\n    <property key="labeling/multilineAlign" value="3"/>\n    <property key="labeling/multilineHeight" value="1"/>\n    <property key="labeling/namedStyle" value=""/>\n    <property key="labeling/obstacle" value="true"/>\n    <property key="labeling/obstacleFactor" value="1"/>\n    <property key="labeling/obstacleType" value="0"/>\n    <property key="labeling/offsetType" value="0"/>\n    <property key="labeling/placeDirectionSymbol" value="0"/>\n    <property key="labeling/placement" value="6"/>\n    <property key="labeling/placementFlags" value="10"/>\n    <property key="labeling/plussign" value="false"/>\n    <property key="labeling/predefinedPositionOrder" value="TR,TL,BR,BL,R,L,TSR,BSR"/>\n    <property key="labeling/preserveRotation" value="true"/>\n    <property key="labeling/previewBkgrdColor" value="#ffffff"/>\n    <property key="labeling/priority" value="5"/>\n    <property key="labeling/quadOffset" value="4"/>\n    <property key="labeling/repeatDistance" value="0"/>\n    <property key="labeling/repeatDistanceMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/repeatDistanceUnit" value="1"/>\n    <property key="labeling/reverseDirectionSymbol" value="false"/>\n    <property key="labeling/rightDirectionSymbol" value=">"/>\n    <property key="labeling/scaleMax" value="10000000"/>\n    <property key="labeling/scaleMin" value="1"/>\n    <property key="labeling/scaleVisibility" value="false"/>\n    <property key="labeling/shadowBlendMode" value="6"/>\n    <property key="labeling/shadowColorB" value="0"/>\n    <property key="labeling/shadowColorG" value="0"/>\n    <property key="labeling/shadowColorR" value="0"/>\n    <property key="labeling/shadowDraw" value="false"/>\n    <property key="labeling/shadowOffsetAngle" value="135"/>\n    <property key="labeling/shadowOffsetDist" value="1"/>\n    <property key="labeling/shadowOffsetGlobal" value="true"/>\n    <property key="labeling/shadowOffsetMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shadowOffsetUnits" value="1"/>\n    <property key="labeling/shadowRadius" value="1.5"/>\n    <property key="labeling/shadowRadiusAlphaOnly" value="false"/>\n    <property key="labeling/shadowRadiusMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shadowRadiusUnits" value="1"/>\n    <property key="labeling/shadowScale" value="100"/>\n    <property key="labeling/shadowTransparency" value="30"/>\n    <property key="labeling/shadowUnder" value="0"/>\n    <property key="labeling/shapeBlendMode" value="0"/>\n    <property key="labeling/shapeBorderColorA" value="255"/>\n    <property key="labeling/shapeBorderColorB" value="128"/>\n    <property key="labeling/shapeBorderColorG" value="128"/>\n    <property key="labeling/shapeBorderColorR" value="128"/>\n    <property key="labeling/shapeBorderWidth" value="0"/>\n    <property key="labeling/shapeBorderWidthMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shapeBorderWidthUnits" value="1"/>\n    <property key="labeling/shapeDraw" value="false"/>\n    <property key="labeling/shapeFillColorA" value="255"/>\n    <property key="labeling/shapeFillColorB" value="255"/>\n    <property key="labeling/shapeFillColorG" value="255"/>\n    <property key="labeling/shapeFillColorR" value="255"/>\n    <property key="labeling/shapeJoinStyle" value="64"/>\n    <property key="labeling/shapeOffsetMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shapeOffsetUnits" value="1"/>\n    <property key="labeling/shapeOffsetX" value="0"/>\n    <property key="labeling/shapeOffsetY" value="0"/>\n    <property key="labeling/shapeRadiiMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shapeRadiiUnits" value="1"/>\n    <property key="labeling/shapeRadiiX" value="0"/>\n    <property key="labeling/shapeRadiiY" value="0"/>\n    <property key="labeling/shapeRotation" value="0"/>\n    <property key="labeling/shapeRotationType" value="0"/>\n    <property key="labeling/shapeSVGFile" value=""/>\n    <property key="labeling/shapeSizeMapUnitScale" value="0,0,0,0,0,0"/>\n    <property key="labeling/shapeSizeType" value="0"/>\n    <property key="labeling/shapeSizeUnits" value="1"/>\n    <property key="labeling/shapeSizeX" value="0"/>\n    <property key="labeling/shapeSizeY" value="0"/>\n    <property key="labeling/shapeTransparency" value="0"/>\n    <property key="labeling/shapeType" value="0"/>\n    <property key="labeling/substitutions" value="&lt;substitutions/>"/>\n    <property key="labeling/textColorA" value="255"/>\n    <property key="labeling/textColorB" value="0"/>\n    <property key="labeling/textColorG" value="0"/>\n    <property key="labeling/textColorR" value="0"/>\n    <property key="labeling/textTransp" value="0"/>\n    <property key="labeling/upsidedownLabels" value="0"/>\n    <property key="labeling/useSubstitutions" value="false"/>\n    <property key="labeling/wrapChar" value=""/>\n    <property key="labeling/xOffset" value="0"/>\n    <property key="labeling/yOffset" value="0"/>\n    <property key="labeling/zIndex" value="0"/>\n    <property key="variableNames"/>\n    <property key="variableValues"/>\n  </customproperties>\n  <blendMode>0</blendMode>\n  <featureBlendMode>0</featureBlendMode>\n  <layerTransparency>0</layerTransparency>\n  <displayfield>name</displayfield>\n  <label>0</label>\n  <labelattributes>\n    <label fieldname="" text="Étiquette"/>\n    <family fieldname="" name="Sans"/>\n    <size fieldname="" units="pt" value="12"/>\n    <bold fieldname="" on="0"/>\n    <italic fieldname="" on="0"/>\n    <underline fieldname="" on="0"/>\n    <strikeout fieldname="" on="0"/>\n    <color fieldname="" red="0" blue="0" green="0"/>\n    <x fieldname=""/>\n    <y fieldname=""/>\n    <offset x="0" y="0" units="pt" yfieldname="" xfieldname=""/>\n    <angle fieldname="" value="0" auto="0"/>\n    <alignment fieldname="" value="center"/>\n    <buffercolor fieldname="" red="255" blue="255" green="255"/>\n    <buffersize fieldname="" units="pt" value="1"/>\n    <bufferenabled fieldname="" on=""/>\n    <multilineenabled fieldname="" on=""/>\n    <selectedonly on=""/>\n  </labelattributes>\n  <SingleCategoryDiagramRenderer diagramType="Histogram" sizeLegend="0" attributeLegend="1">\n    <DiagramCategory penColor="#000000" labelPlacementMethod="XHeight" penWidth="0" diagramOrientation="Up" sizeScale="0,0,0,0,0,0" minimumSize="0" barWidth="5" penAlpha="255" maxScaleDenominator="1e+08" backgroundColor="#ffffff" transparency="0" width="15" scaleDependency="Area" backgroundAlpha="255" angleOffset="1440" scaleBasedVisibility="0" enabled="0" height="15" lineSizeScale="0,0,0,0,0,0" sizeType="MM" lineSizeType="MM" minScaleDenominator="inf">\n      <fontProperties description="Sans,9,-1,0,50,0,0,0,0,0" style=""/>\n    </DiagramCategory>\n    <symbol alpha="1" clip_to_extent="1" type="marker" name="sizeSymbol">\n      <layer pass="0" class="SimpleMarker" locked="0">\n        <prop k="angle" v="0"/>\n        <prop k="color" v="255,0,0,255"/>\n        <prop k="horizontal_anchor_point" v="1"/>\n        <prop k="joinstyle" v="bevel"/>\n        <prop k="name" v="circle"/>\n        <prop k="offset" v="0,0"/>\n        <prop k="offset_map_unit_scale" v="0,0,0,0,0,0"/>\n        <prop k="offset_unit" v="MM"/>\n        <prop k="outline_color" v="0,0,0,255"/>\n        <prop k="outline_style" v="solid"/>\n        <prop k="outline_width" v="0"/>\n        <prop k="outline_width_map_unit_scale" v="0,0,0,0,0,0"/>\n        <prop k="outline_width_unit" v="MM"/>\n        <prop k="scale_method" v="diameter"/>\n        <prop k="size" v="2"/>\n        <prop k="size_map_unit_scale" v="0,0,0,0,0,0"/>\n        <prop k="size_unit" v="MM"/>\n        <prop k="vertical_anchor_point" v="1"/>\n      </layer>\n    </symbol>\n  </SingleCategoryDiagramRenderer>\n  <DiagramLayerSettings yPosColumn="-1" showColumn="-1" linePlacementFlags="10" placement="0" dist="0" xPosColumn="-1" priority="0" obstacle="0" zIndex="0" showAll="1"/>\n  <annotationform></annotationform>\n  <aliases>\n    <alias field="id" index="0" name=""/>\n    <alias field="site_id" index="1" name=""/>\n    <alias field="station_type" index="2" name=""/>\n    <alias field="name" index="3" name=""/>\n    <alias field="orig_srid" index="4" name=""/>\n    <alias field="ground_altitude" index="5" name=""/>\n  </aliases>\n  <excludeAttributesWMS/>\n  <excludeAttributesWFS/>\n  <attributeactions default="-1"/>\n  <attributetableconfig actionWidgetStyle="dropDown" sortExpression="" sortOrder="0">\n    <columns>\n      <column width="-1" hidden="0" type="field" name="id"/>\n      <column width="-1" hidden="0" type="field" name="site_id"/>\n      <column width="-1" hidden="0" type="field" name="station_type"/>\n      <column width="-1" hidden="0" type="field" name="name"/>\n      <column width="-1" hidden="0" type="field" name="orig_srid"/>\n      <column width="-1" hidden="0" type="field" name="ground_altitude"/>\n      <column width="-1" hidden="1" type="actions"/>\n    </columns>\n  </attributetableconfig>\n  <editform></editform>\n  <editforminit/>\n  <editforminitcodesource>0</editforminitcodesource>\n  <editforminitfilepath></editforminitfilepath>\n  <editforminitcode><![CDATA[# -*- coding: utf-8 -*-\n"""\nLes formulaires QGIS peuvent avoir une fonction Python qui sera appelée à l'ouverture du formulaire.\n\nUtilisez cette fonction pour ajouter plus de fonctionnalités à vos formulaires.\n\nEntrez le nom de la fonction dans le champ "Fonction d'initialisation Python".\nVoici un exemple à suivre:\n"""\nfrom qgis.PyQt.QtWidgets import QWidget\n\ndef my_form_open(dialog, layer, feature):\n    geom = feature.geometry()\n    control = dialog.findChild(QWidget, "MyLineEdit")\n\n]]></editforminitcode>\n  <featformsuppress>0</featformsuppress>\n  <editorlayout>generatedlayout</editorlayout>\n  <widgets/>\n  <conditionalstyles>\n    <rowstyles/>\n    <fieldstyles/>\n  </conditionalstyles>\n  <defaults>\n    <default field="id" expression=""/>\n    <default field="site_id" expression=""/>\n    <default field="station_type" expression=""/>\n    <default field="name" expression=""/>\n    <default field="orig_srid" expression=""/>\n    <default field="ground_altitude" expression=""/>\n  </defaults>\n  <previewExpression></previewExpression>\n  <layerGeometryType>0</layerGeometryType>\n</qgis>\n	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
927572	EPSG	927572	PROJCS["NTF (Paris) / Lambert zone II",GEOGCS["NTF (Paris)",DATUM["Nouvelle_Triangulation_Francaise_Paris",SPHEROID["Clarke 1880 (IGN)",6378249.2,293.4660212936269,AUTHORITY["EPSG","7011"]],TOWGS84[-168,-60,320,0,0,0,0],AUTHORITY["EPSG","6807"]],PRIMEM["Paris",2.33722917,AUTHORITY["EPSG","8903"]],UNIT["grad",0.01570796326794897,AUTHORITY["EPSG","9105"]],AUTHORITY["EPSG","4807"]],PROJECTION["Lambert_Conformal_Conic_1SP"],PARAMETER["latitude_of_origin",52],PARAMETER["central_meridian",0],PARAMETER["scale_factor",0.99987742],PARAMETER["false_easting",600000],PARAMETER["false_northing",2200000],UNIT["metre",1,AUTHORITY["EPSG","9001"]],AXIS["X",EAST],AXIS["Y",NORTH],AUTHORITY["EPSG","27572"]]	+proj=lcc +lat_1=46.8 +lat_0=46.8 +lon_0=0 +k_0=0.99987742 +x_0=600000 +y_0=2200000 +a=6378249.2 +b=6356515 +towgs84=-168,-60,320,0,0,0,0 +pm=paris +units=m +no_defs
\.


--
-- Data for Name: geologic_code; Type: TABLE DATA; Schema: ref; Owner: postgres
--

COPY ref.geologic_code (id, parent_id, name_en, code, color) FROM stdin;
\.


--
-- Data for Name: rock_code; Type: TABLE DATA; Schema: ref; Owner: postgres
--

COPY ref.rock_code (code, authority, description, svg_pattern) FROM stdin;
601	USGS	Gravel or conglomerate (1st option)	\N
602	USGS	Gravel or conglomerate (2nd option)	\N
603	USGS	Crossbedded gravel or conglomerate	\N
605	USGS	Breccia (1st option)	\N
606	USGS	Breccia (2nd option)	\N
607	USGS	Massive sand or sandstone	\N
608	USGS	Bedded sand or sandstone	\N
609	USGS	Crossbedded sand or sandstone (1st option)	\N
610	USGS	Crossbedded sand or sandstone (2nd option)	\N
611	USGS	Ripple-bedded sand or sandstone	\N
612	USGS	Argillaceous or shaly sandstone	\N
613	USGS	Calcareous sandstone	\N
614	USGS	Dolomitic sandstone	\N
616	USGS	Silt, siltstone, or shaly silt	\N
617	USGS	Calcareous siltstone	\N
618	USGS	Dolomitic siltstone	\N
619	USGS	Sandy or silty shale	\N
620	USGS	Clay or clay shale	\N
621	USGS	Cherty shale	\N
622	USGS	Dolomitic shale	\N
623	USGS	Calcareous shale or marl	\N
624	USGS	Carbonaceous shale	\N
625	USGS	Oil shale	\N
626	USGS	Chalk	\N
627	USGS	Limestone	\N
628	USGS	Clastic limestone	\N
629	USGS	Fossiliferous clastic limestone	\N
630	USGS	Nodular or irregularly bedded limestone	\N
631	USGS	Limestone, irregular (burrow?) fllings of saccharoidal dolomite	\N
632	USGS	Crossbedded limestone	\N
633	USGS	Cherty crossbedded limestone	\N
634	USGS	Cherty and sandy crossbedded clastic limestone	\N
635	USGS	Oolitic limestone	\N
636	USGS	Sandy limestone	\N
637	USGS	Silty limestone	\N
638	USGS	Argillaceous or shaly limestone	\N
639	USGS	Cherty limestone (1st option)	\N
640	USGS	Cherty limestone (2nd option)	\N
641	USGS	Dolomitic limestone, limy dolostone, or limy dolomite	\N
642	USGS	Dolostone or dolomite	\N
643	USGS	Crossbedded dolostone or dolomite	\N
644	USGS	Oolitic dolostone or dolomite	\N
652	USGS	Fossiliferous rock	\N
653	USGS	Diatomaceous rock	\N
654	USGS	Subgraywacke	\N
655	USGS	Crossbedded subgraywacke	\N
656	USGS	Ripple-bedded subgraywacke	\N
657	USGS	Peat	\N
658	USGS	Coal	\N
645	USGS	Sandy dolostone or dolomite	\N
646	USGS	Silty dolostone or dolomite	\N
647	USGS	Argillaceous or shaly dolostone or dolomite	\N
648	USGS	Cherty dolostone or dolomite	\N
649	USGS	Bedded chert (1st option)	\N
650	USGS	Bedded chert (2nd option)	\N
651	USGS	Fossiliferous bedded chert	\N
659	USGS	Bony coal or impure coal	\N
660	USGS	Underclay	\N
661	USGS	Flint clay	\N
662	USGS	Bentonite	\N
663	USGS	Glauconite	\N
664	USGS	Limonite	\N
665	USGS	Siderite	\N
666	USGS	Phosphatic-nodular rock	\N
667	USGS	Gypsum	\N
668	USGS	Salt	\N
669	USGS	Interbedded sandstone and siltstone	\N
670	USGS	Interbedded sandstone and shale	\N
671	USGS	Interbedded ripple- bedded sandstone and shale	\N
672	USGS	Interbedded shale and silty limestone (shale dominant)	\N
680	USGS	Interbedded limestone and calcareous shale	\N
681	USGS	Till or diamicton (1st option)	\N
682	USGS	Till or diamicton (2nd option)	\N
683	USGS	Till or diamicton (3rd option)	\N
684	USGS	Loess (1st option)	\N
685	USGS	Loess (2nd option)	\N
686	USGS	Loess (3rd option)	\N
673	USGS	Interbedded shale and limestone (shale dominant) (1st option)	\N
674	USGS	Interbedded shale and limestone (shale dominant) (2nd option)	\N
675	USGS	Interbedded calc- areous shale and limestone (shale dominant)	\N
676	USGS	Interbedded silty limestone and shale	\N
677	USGS	Interbedded limestone and shale (1st option)	\N
678	USGS	Interbedded limestone and shale (2nd option)	\N
679	USGS	Interbedded limestone and shale (limestone dominant)	\N
717	USGS	Basaltic fows	\N
718	USGS	Granite (1st option)	\N
719	USGS	Granite (2nd option)	\N
720	USGS	Banded igneous rock	\N
721	USGS	Igneous rock (1st option)	\N
723	USGS	Igneous rock (3rd option)	\N
724	USGS	Igneous rock (4th option)	\N
725	USGS	Igneous rock (5th option)	\N
726	USGS	Igneous rock (6th option)	\N
727	USGS	Igneous rock (7th option)	\N
728	USGS	Igneous rock (8th option)	\N
722	USGS	Igneous rock (2nd option)	\N
711	USGS	Tufaceous rock	\N
712	USGS	Crystal tuf	\N
713	USGS	Devitrifed tuf	\N
714	USGS	Volcanic breccia and tuf	\N
715	USGS	Volcanic breccia or agglomerate	\N
716	USGS	Zeolitic rock	\N
729	USGS	Porphyritic rock (1st option)	\N
730	USGS	Porphyritic rock (2nd option)	\N
731	USGS	Vitrophyre	\N
732	USGS	Quartz	\N
733	USGS	Ore	\N
707	USGS	Schist and gneiss	\N
708	USGS	Gneiss	\N
709	USGS	Contorted gneiss	\N
710	USGS	Soapstone, talc, or serpentinite	\N
701	USGS	Metamorphism	\N
702	USGS	Quartzite	\N
703	USGS	Slate	\N
704	USGS	Schistose or gneissoid granite	\N
705	USGS	Schist	\N
706	USGS	Contorted schist	\N
\.


--
-- Data for Name: site; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.site (id, name) FROM stdin;
1	dummysite
\.


--
-- Data for Name: station; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station (id, site_id, station_family, station_type, name, point, orig_srid, ground_altitude, dataset_id) FROM stdin;
1	1	Borehole	Piezometer	S1	0101000020E610000066666666666624406666666666662440	4326	200	3
2	1	Borehole	Piezometer	S2	0101000020E61000006666666666662440EC51B81E856B2440	4326	250	3
3	1	Borehole	Piezometer	S3	0101000020E6100000EC51B81E856B2440EC51B81E856B2440	4326	220	3
\.


--
-- Data for Name: station_borehole; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_borehole (id, total_depth, top_of_casing_altitude, casing_height, casing_internal_diameter, casing_external_diameter, driller, drilling_date, drilling_method, associated_barometer, location, num_bss, borehole_type, usage, condition) FROM stdin;
1	20.0199999999999996	200.800000000000011	0.800000000000000044	\N	\N	\N	\N	\N	\N	\N	\N	Piezometer	\N	\N
2	52	250.349999999999994	0.75	\N	\N	\N	\N	\N	\N	\N	\N	Piezometer	\N	\N
3	45.6000000000000014	221.050000000000011	0.200000000000000011	\N	\N	\N	\N	\N	\N	\N	\N	Piezometer	\N	\N
\.


--
-- Data for Name: station_chimney; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_chimney (id, chimney_type, nuclear_facility_name, facility_name, building_name, height, flow_rate, surface) FROM stdin;
\.


--
-- Data for Name: station_device; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_device (id, device_type) FROM stdin;
\.


--
-- Data for Name: station_hydrology; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_hydrology (id, hydrology_station_type, a, b) FROM stdin;
\.


--
-- Data for Name: station_sample; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_sample (id, sample_family, sample_type) FROM stdin;
\.


--
-- Data for Name: station_weather_station; Type: TABLE DATA; Schema: station; Owner: postgres
--

COPY station.station_weather_station (id, weather_station_type, height) FROM stdin;
\.


--
-- Data for Name: borehole_type_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.borehole_type_fr (borehole_type, description) FROM stdin;
Piezometer	Piézomètre
CoreDrill	Carottage
FilledUpDrill	Forage rebouché
GeotechnicDrill	Forage géotechnique
Borehole	Forage
Well	Puits
DrainWell	Puits de drainage
\.


--
-- Data for Name: chimney_type_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.chimney_type_fr (chimney_type, description) FROM stdin;
Chimney	Cheminée
\.


--
-- Data for Name: device_type_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.device_type_fr (device_type, description) FROM stdin;
MeasurementDevice	Instrument de mesure
DrainagePump	Pompe de relevage
\.


--
-- Data for Name: hydrology_station_type_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.hydrology_station_type_fr (hydrology_station_type, description) FROM stdin;
River	Rivière
Spring	Source
\.


--
-- Data for Name: sample_family_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.sample_family_fr (sample_family, description) FROM stdin;
Air	Air
Ground	Sol
Water	Eau
Animal	Animal
Plant	Végétal
\.


--
-- Data for Name: station_family_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.station_family_fr (station_family, description) FROM stdin;
Borehole	Forage
Chimney	Cheminée
Weather_Station	Station météo
Hydrology_Station	Station hydrologique
Sample	Échantillon
Device	Instrument
\.


--
-- Data for Name: weather_station_type_fr; Type: TABLE DATA; Schema: tr; Owner: postgres
--

COPY tr.weather_station_type_fr (weather_station_type, description) FROM stdin;
Pluviometer	Pluviomètre
WeatherStation	Station météo
\.


--
-- Name: acoustic_imagery_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.acoustic_imagery_id_seq', 1, false);


--
-- Name: atmospheric_pressure_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.atmospheric_pressure_id_seq', 1, false);


--
-- Name: campaign_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.campaign_id_seq', 1, true);


--
-- Name: chemical_analysis_result_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.chemical_analysis_result_id_seq', 1, false);


--
-- Name: chimney_release_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.chimney_release_id_seq', 1, false);


--
-- Name: continuous_atmospheric_pressure_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_atmospheric_pressure_id_seq', 1, false);


--
-- Name: continuous_groundwater_conductivity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_groundwater_conductivity_id_seq', 1, false);


--
-- Name: continuous_groundwater_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_groundwater_level_id_seq', 1, false);


--
-- Name: continuous_groundwater_pressure_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_groundwater_pressure_id_seq', 1, false);


--
-- Name: continuous_groundwater_temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_groundwater_temperature_id_seq', 1, false);


--
-- Name: continuous_humidity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_humidity_id_seq', 1, false);


--
-- Name: continuous_nebulosity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_nebulosity_id_seq', 1, false);


--
-- Name: continuous_pasquill_index_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_pasquill_index_id_seq', 1, false);


--
-- Name: continuous_potential_evapotranspiration_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_potential_evapotranspiration_id_seq', 1, false);


--
-- Name: continuous_rain_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_rain_id_seq', 1, false);


--
-- Name: continuous_temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_temperature_id_seq', 1, false);


--
-- Name: continuous_water_conductivity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_water_conductivity_id_seq', 1, false);


--
-- Name: continuous_water_discharge_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_water_discharge_id_seq', 1, false);


--
-- Name: continuous_water_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_water_level_id_seq', 1, false);


--
-- Name: continuous_water_ph_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_water_ph_id_seq', 1, false);


--
-- Name: continuous_water_temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_water_temperature_id_seq', 1, false);


--
-- Name: continuous_wind_direction_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_wind_direction_id_seq', 1, false);


--
-- Name: continuous_wind_force_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.continuous_wind_force_id_seq', 1, false);


--
-- Name: groundwater_conductivity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.groundwater_conductivity_id_seq', 1, false);


--
-- Name: groundwater_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.groundwater_level_id_seq', 1, false);


--
-- Name: groundwater_temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.groundwater_temperature_id_seq', 242, true);


--
-- Name: humidity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.humidity_id_seq', 1, false);


--
-- Name: instrument_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.instrument_id_seq', 1, false);


--
-- Name: manual_groundwater_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.manual_groundwater_level_id_seq', 1, false);


--
-- Name: manual_water_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.manual_water_level_id_seq', 1, false);


--
-- Name: nebulosity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.nebulosity_id_seq', 1, false);


--
-- Name: optical_imagery_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.optical_imagery_id_seq', 1, false);


--
-- Name: pasquill_index_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.pasquill_index_id_seq', 1, false);


--
-- Name: potential_evapotranspiration_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.potential_evapotranspiration_id_seq', 1, false);


--
-- Name: rain_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.rain_id_seq', 1, false);


--
-- Name: raw_groundwater_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.raw_groundwater_level_id_seq', 1, false);


--
-- Name: temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.temperature_id_seq', 1, false);


--
-- Name: tool_injection_pressure_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.tool_injection_pressure_id_seq', 1, false);


--
-- Name: tool_instant_speed_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.tool_instant_speed_id_seq', 1, false);


--
-- Name: tool_rotation_couple_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.tool_rotation_couple_id_seq', 1, false);


--
-- Name: water_conductivity_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.water_conductivity_id_seq', 1, false);


--
-- Name: water_discharge_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.water_discharge_id_seq', 1, false);


--
-- Name: water_level_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.water_level_id_seq', 1, false);


--
-- Name: water_ph_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.water_ph_id_seq', 1, false);


--
-- Name: water_temperature_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.water_temperature_id_seq', 1, false);


--
-- Name: weight_on_tool_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.weight_on_tool_id_seq', 1, false);


--
-- Name: wind_direction_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.wind_direction_id_seq', 1, false);


--
-- Name: wind_force_id_seq; Type: SEQUENCE SET; Schema: measure; Owner: postgres
--

SELECT pg_catalog.setval('measure.wind_force_id_seq', 1, false);


--
-- Name: dataset_id_seq; Type: SEQUENCE SET; Schema: metadata; Owner: postgres
--

SELECT pg_catalog.setval('metadata.dataset_id_seq', 7, true);


--
-- Name: layer_styles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.layer_styles_id_seq', 1, true);


--
-- Name: geologic_code_id_seq; Type: SEQUENCE SET; Schema: ref; Owner: postgres
--

SELECT pg_catalog.setval('ref.geologic_code_id_seq', 1, false);


--
-- Name: site_id_seq; Type: SEQUENCE SET; Schema: station; Owner: postgres
--

SELECT pg_catalog.setval('station.site_id_seq', 1, true);


--
-- Name: station_id_seq; Type: SEQUENCE SET; Schema: station; Owner: postgres
--

SELECT pg_catalog.setval('station.station_id_seq', 3, true);


--
-- Name: acoustic_imagery acoustic_imagery_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.acoustic_imagery
    ADD CONSTRAINT acoustic_imagery_pkey PRIMARY KEY (id);


--
-- Name: acoustic_imagery acoustic_imagery_station_id_scan_date_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.acoustic_imagery
    ADD CONSTRAINT acoustic_imagery_station_id_scan_date_key UNIQUE (station_id, scan_date);


--
-- Name: atmospheric_pressure atmospheric_pressure_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure
    ADD CONSTRAINT atmospheric_pressure_pkey PRIMARY KEY (id);


--
-- Name: atmospheric_pressure atmospheric_pressure_station_id_start_measure_time_campaign_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure
    ADD CONSTRAINT atmospheric_pressure_station_id_start_measure_time_campaign_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: campaign campaign_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.campaign
    ADD CONSTRAINT campaign_pkey PRIMARY KEY (id);


--
-- Name: chemical_analysis_result chemical_analysis_result_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chemical_analysis_result
    ADD CONSTRAINT chemical_analysis_result_pkey PRIMARY KEY (id);


--
-- Name: chemical_analysis_result chemical_analysis_result_station_id_measure_time_chemical_e_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chemical_analysis_result
    ADD CONSTRAINT chemical_analysis_result_station_id_measure_time_chemical_e_key UNIQUE (station_id, measure_time, chemical_element, sample_report, sample_code);


--
-- Name: chimney_release chimney_release_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chimney_release
    ADD CONSTRAINT chimney_release_pkey PRIMARY KEY (id);


--
-- Name: chimney_release chimney_release_station_id_start_measure_time_end_measure_t_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chimney_release
    ADD CONSTRAINT chimney_release_station_id_start_measure_time_end_measure_t_key UNIQUE (station_id, start_measure_time, end_measure_time, chemical_element);


--
-- Name: continuous_atmospheric_pressure continuous_atmospheric_pressu_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure
    ADD CONSTRAINT continuous_atmospheric_pressu_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_atmospheric_pressure continuous_atmospheric_pressure_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure
    ADD CONSTRAINT continuous_atmospheric_pressure_pkey PRIMARY KEY (id);


--
-- Name: continuous_groundwater_conductivity continuous_groundwater_conduc_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity
    ADD CONSTRAINT continuous_groundwater_conduc_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_groundwater_conductivity continuous_groundwater_conductivity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity
    ADD CONSTRAINT continuous_groundwater_conductivity_pkey PRIMARY KEY (id);


--
-- Name: continuous_groundwater_level continuous_groundwater_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level
    ADD CONSTRAINT continuous_groundwater_level_pkey PRIMARY KEY (id);


--
-- Name: continuous_groundwater_level continuous_groundwater_level_station_id_start_measure_time__key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level
    ADD CONSTRAINT continuous_groundwater_level_station_id_start_measure_time__key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_groundwater_pressure continuous_groundwater_pressu_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure
    ADD CONSTRAINT continuous_groundwater_pressu_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_groundwater_pressure continuous_groundwater_pressure_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure
    ADD CONSTRAINT continuous_groundwater_pressure_pkey PRIMARY KEY (id);


--
-- Name: continuous_groundwater_temperature continuous_groundwater_temper_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature
    ADD CONSTRAINT continuous_groundwater_temper_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_groundwater_temperature continuous_groundwater_temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature
    ADD CONSTRAINT continuous_groundwater_temperature_pkey PRIMARY KEY (id);


--
-- Name: continuous_humidity continuous_humidity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity
    ADD CONSTRAINT continuous_humidity_pkey PRIMARY KEY (id);


--
-- Name: continuous_humidity continuous_humidity_station_id_start_measure_time_campaign__key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity
    ADD CONSTRAINT continuous_humidity_station_id_start_measure_time_campaign__key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_nebulosity continuous_nebulosity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity
    ADD CONSTRAINT continuous_nebulosity_pkey PRIMARY KEY (id);


--
-- Name: continuous_nebulosity continuous_nebulosity_station_id_start_measure_time_campaig_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity
    ADD CONSTRAINT continuous_nebulosity_station_id_start_measure_time_campaig_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_pasquill_index continuous_pasquill_index_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index
    ADD CONSTRAINT continuous_pasquill_index_pkey PRIMARY KEY (id);


--
-- Name: continuous_pasquill_index continuous_pasquill_index_station_id_start_measure_time_cam_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index
    ADD CONSTRAINT continuous_pasquill_index_station_id_start_measure_time_cam_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_potential_evapotranspiration continuous_potential_evapotra_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration
    ADD CONSTRAINT continuous_potential_evapotra_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_potential_evapotranspiration continuous_potential_evapotranspiration_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration
    ADD CONSTRAINT continuous_potential_evapotranspiration_pkey PRIMARY KEY (id);


--
-- Name: continuous_rain continuous_rain_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain
    ADD CONSTRAINT continuous_rain_pkey PRIMARY KEY (id);


--
-- Name: continuous_rain continuous_rain_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain
    ADD CONSTRAINT continuous_rain_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_temperature continuous_temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature
    ADD CONSTRAINT continuous_temperature_pkey PRIMARY KEY (id);


--
-- Name: continuous_temperature continuous_temperature_station_id_start_measure_time_campai_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature
    ADD CONSTRAINT continuous_temperature_station_id_start_measure_time_campai_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_water_conductivity continuous_water_conductivity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity
    ADD CONSTRAINT continuous_water_conductivity_pkey PRIMARY KEY (id);


--
-- Name: continuous_water_conductivity continuous_water_conductivity_station_id_start_measure_time_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity
    ADD CONSTRAINT continuous_water_conductivity_station_id_start_measure_time_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_water_discharge continuous_water_discharge_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge
    ADD CONSTRAINT continuous_water_discharge_pkey PRIMARY KEY (id);


--
-- Name: continuous_water_discharge continuous_water_discharge_station_id_start_measure_time_ca_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge
    ADD CONSTRAINT continuous_water_discharge_station_id_start_measure_time_ca_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_water_level continuous_water_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level
    ADD CONSTRAINT continuous_water_level_pkey PRIMARY KEY (id);


--
-- Name: continuous_water_level continuous_water_level_station_id_start_measure_time_campai_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level
    ADD CONSTRAINT continuous_water_level_station_id_start_measure_time_campai_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_water_ph continuous_water_ph_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph
    ADD CONSTRAINT continuous_water_ph_pkey PRIMARY KEY (id);


--
-- Name: continuous_water_ph continuous_water_ph_station_id_start_measure_time_campaign__key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph
    ADD CONSTRAINT continuous_water_ph_station_id_start_measure_time_campaign__key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_water_temperature continuous_water_temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature
    ADD CONSTRAINT continuous_water_temperature_pkey PRIMARY KEY (id);


--
-- Name: continuous_water_temperature continuous_water_temperature_station_id_start_measure_time__key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature
    ADD CONSTRAINT continuous_water_temperature_station_id_start_measure_time__key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_wind_direction continuous_wind_direction_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction
    ADD CONSTRAINT continuous_wind_direction_pkey PRIMARY KEY (id);


--
-- Name: continuous_wind_direction continuous_wind_direction_station_id_start_measure_time_cam_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction
    ADD CONSTRAINT continuous_wind_direction_station_id_start_measure_time_cam_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: continuous_wind_force continuous_wind_force_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force
    ADD CONSTRAINT continuous_wind_force_pkey PRIMARY KEY (id);


--
-- Name: continuous_wind_force continuous_wind_force_station_id_start_measure_time_campaig_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force
    ADD CONSTRAINT continuous_wind_force_station_id_start_measure_time_campaig_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: fracturing_rate fracturing_rate_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.fracturing_rate
    ADD CONSTRAINT fracturing_rate_pkey PRIMARY KEY (station_id, depth);


--
-- Name: fracturing_rate fracturing_rate_station_id_depth_excl; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.fracturing_rate
    ADD CONSTRAINT fracturing_rate_station_id_depth_excl EXCLUDE USING gist (station_id WITH =, depth WITH &&);


--
-- Name: groundwater_conductivity groundwater_conductivity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity
    ADD CONSTRAINT groundwater_conductivity_pkey PRIMARY KEY (id);


--
-- Name: groundwater_conductivity groundwater_conductivity_station_id_measure_time_campaign_i_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity
    ADD CONSTRAINT groundwater_conductivity_station_id_measure_time_campaign_i_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: groundwater_level groundwater_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level
    ADD CONSTRAINT groundwater_level_pkey PRIMARY KEY (id);


--
-- Name: groundwater_level groundwater_level_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level
    ADD CONSTRAINT groundwater_level_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: groundwater_temperature groundwater_temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature
    ADD CONSTRAINT groundwater_temperature_pkey PRIMARY KEY (id);


--
-- Name: groundwater_temperature groundwater_temperature_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature
    ADD CONSTRAINT groundwater_temperature_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: humidity humidity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity
    ADD CONSTRAINT humidity_pkey PRIMARY KEY (id);


--
-- Name: humidity humidity_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity
    ADD CONSTRAINT humidity_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: instrument instrument_model_serial_number_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.instrument
    ADD CONSTRAINT instrument_model_serial_number_key UNIQUE (model, serial_number);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);


--
-- Name: manual_groundwater_level manual_groundwater_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level
    ADD CONSTRAINT manual_groundwater_level_pkey PRIMARY KEY (id);


--
-- Name: manual_groundwater_level manual_groundwater_level_station_id_measure_time_campaign_i_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level
    ADD CONSTRAINT manual_groundwater_level_station_id_measure_time_campaign_i_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: manual_water_level manual_water_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level
    ADD CONSTRAINT manual_water_level_pkey PRIMARY KEY (id);


--
-- Name: manual_water_level manual_water_level_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level
    ADD CONSTRAINT manual_water_level_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: measure_metadata measure_metadata_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.measure_metadata
    ADD CONSTRAINT measure_metadata_pkey PRIMARY KEY (measure_table);


--
-- Name: nebulosity nebulosity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity
    ADD CONSTRAINT nebulosity_pkey PRIMARY KEY (id);


--
-- Name: nebulosity nebulosity_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity
    ADD CONSTRAINT nebulosity_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: optical_imagery optical_imagery_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.optical_imagery
    ADD CONSTRAINT optical_imagery_pkey PRIMARY KEY (id);


--
-- Name: optical_imagery optical_imagery_station_id_scan_date_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.optical_imagery
    ADD CONSTRAINT optical_imagery_station_id_scan_date_key UNIQUE (station_id, scan_date);


--
-- Name: pasquill_index pasquill_index_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index
    ADD CONSTRAINT pasquill_index_pkey PRIMARY KEY (id);


--
-- Name: pasquill_index pasquill_index_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index
    ADD CONSTRAINT pasquill_index_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: potential_evapotranspiration potential_evapotranspiration_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration
    ADD CONSTRAINT potential_evapotranspiration_pkey PRIMARY KEY (id);


--
-- Name: potential_evapotranspiration potential_evapotranspiration_station_id_start_measure_time__key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration
    ADD CONSTRAINT potential_evapotranspiration_station_id_start_measure_time__key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: rain rain_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain
    ADD CONSTRAINT rain_pkey PRIMARY KEY (id);


--
-- Name: rain rain_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain
    ADD CONSTRAINT rain_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: raw_groundwater_level raw_groundwater_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level
    ADD CONSTRAINT raw_groundwater_level_pkey PRIMARY KEY (id);


--
-- Name: raw_groundwater_level raw_groundwater_level_station_id_start_measure_time_campaig_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level
    ADD CONSTRAINT raw_groundwater_level_station_id_start_measure_time_campaig_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: stratigraphic_logvalue stratigraphic_logvalue_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.stratigraphic_logvalue
    ADD CONSTRAINT stratigraphic_logvalue_pkey PRIMARY KEY (station_id, depth);


--
-- Name: stratigraphic_logvalue stratigraphic_logvalue_station_id_depth_excl; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.stratigraphic_logvalue
    ADD CONSTRAINT stratigraphic_logvalue_station_id_depth_excl EXCLUDE USING gist (station_id WITH =, depth WITH &&);


--
-- Name: temperature temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature
    ADD CONSTRAINT temperature_pkey PRIMARY KEY (id);


--
-- Name: temperature temperature_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature
    ADD CONSTRAINT temperature_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: tool_injection_pressure tool_injection_pressure_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure
    ADD CONSTRAINT tool_injection_pressure_pkey PRIMARY KEY (id);


--
-- Name: tool_injection_pressure tool_injection_pressure_station_id_start_measure_altitude_c_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure
    ADD CONSTRAINT tool_injection_pressure_station_id_start_measure_altitude_c_key UNIQUE (station_id, start_measure_altitude, campaign_id);


--
-- Name: tool_instant_speed tool_instant_speed_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed
    ADD CONSTRAINT tool_instant_speed_pkey PRIMARY KEY (id);


--
-- Name: tool_instant_speed tool_instant_speed_station_id_start_measure_altitude_campai_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed
    ADD CONSTRAINT tool_instant_speed_station_id_start_measure_altitude_campai_key UNIQUE (station_id, start_measure_altitude, campaign_id);


--
-- Name: tool_rotation_couple tool_rotation_couple_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple
    ADD CONSTRAINT tool_rotation_couple_pkey PRIMARY KEY (id);


--
-- Name: tool_rotation_couple tool_rotation_couple_station_id_start_measure_altitude_camp_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple
    ADD CONSTRAINT tool_rotation_couple_station_id_start_measure_altitude_camp_key UNIQUE (station_id, start_measure_altitude, campaign_id);


--
-- Name: water_conductivity water_conductivity_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity
    ADD CONSTRAINT water_conductivity_pkey PRIMARY KEY (id);


--
-- Name: water_conductivity water_conductivity_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity
    ADD CONSTRAINT water_conductivity_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: water_discharge water_discharge_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge
    ADD CONSTRAINT water_discharge_pkey PRIMARY KEY (id);


--
-- Name: water_discharge water_discharge_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge
    ADD CONSTRAINT water_discharge_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: water_level water_level_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level
    ADD CONSTRAINT water_level_pkey PRIMARY KEY (id);


--
-- Name: water_level water_level_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level
    ADD CONSTRAINT water_level_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: water_ph water_ph_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph
    ADD CONSTRAINT water_ph_pkey PRIMARY KEY (id);


--
-- Name: water_ph water_ph_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph
    ADD CONSTRAINT water_ph_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: water_temperature water_temperature_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature
    ADD CONSTRAINT water_temperature_pkey PRIMARY KEY (id);


--
-- Name: water_temperature water_temperature_station_id_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature
    ADD CONSTRAINT water_temperature_station_id_measure_time_campaign_id_key UNIQUE (station_id, measure_time, campaign_id);


--
-- Name: weight_on_tool weight_on_tool_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool
    ADD CONSTRAINT weight_on_tool_pkey PRIMARY KEY (id);


--
-- Name: weight_on_tool weight_on_tool_station_id_start_measure_altitude_campaign_i_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool
    ADD CONSTRAINT weight_on_tool_station_id_start_measure_altitude_campaign_i_key UNIQUE (station_id, start_measure_altitude, campaign_id);


--
-- Name: wind_direction wind_direction_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction
    ADD CONSTRAINT wind_direction_pkey PRIMARY KEY (id);


--
-- Name: wind_direction wind_direction_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction
    ADD CONSTRAINT wind_direction_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: wind_force wind_force_pkey; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force
    ADD CONSTRAINT wind_force_pkey PRIMARY KEY (id);


--
-- Name: wind_force wind_force_station_id_start_measure_time_campaign_id_key; Type: CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force
    ADD CONSTRAINT wind_force_station_id_start_measure_time_campaign_id_key UNIQUE (station_id, start_measure_time, campaign_id);


--
-- Name: dataset dataset_data_name_key; Type: CONSTRAINT; Schema: metadata; Owner: postgres
--

ALTER TABLE ONLY metadata.dataset
    ADD CONSTRAINT dataset_data_name_key UNIQUE (data_name);


--
-- Name: dataset dataset_pkey; Type: CONSTRAINT; Schema: metadata; Owner: postgres
--

ALTER TABLE ONLY metadata.dataset
    ADD CONSTRAINT dataset_pkey PRIMARY KEY (id);


--
-- Name: geologic_code geologic_code_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.geologic_code
    ADD CONSTRAINT geologic_code_pkey PRIMARY KEY (id);


--
-- Name: rock_code rock_code_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.rock_code
    ADD CONSTRAINT rock_code_pkey PRIMARY KEY (code);


--
-- Name: site site_name_key; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.site
    ADD CONSTRAINT site_name_key UNIQUE (name);


--
-- Name: site site_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (id);


--
-- Name: station_borehole station_borehole_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_borehole
    ADD CONSTRAINT station_borehole_pkey PRIMARY KEY (id);


--
-- Name: station_chimney station_chimney_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_chimney
    ADD CONSTRAINT station_chimney_pkey PRIMARY KEY (id);


--
-- Name: station_device station_device_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_device
    ADD CONSTRAINT station_device_pkey PRIMARY KEY (id);


--
-- Name: station_hydrology station_hydrology_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_hydrology
    ADD CONSTRAINT station_hydrology_pkey PRIMARY KEY (id);


--
-- Name: station station_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station
    ADD CONSTRAINT station_pkey PRIMARY KEY (id);


--
-- Name: station_sample station_sample_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_sample
    ADD CONSTRAINT station_sample_pkey PRIMARY KEY (id);


--
-- Name: station station_site_id_name_key; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station
    ADD CONSTRAINT station_site_id_name_key UNIQUE (site_id, name);


--
-- Name: station_weather_station station_weather_station_pkey; Type: CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_weather_station
    ADD CONSTRAINT station_weather_station_pkey PRIMARY KEY (id);


--
-- Name: site _RETURN; Type: RULE; Schema: qgis; Owner: postgres
--

CREATE OR REPLACE VIEW qgis.site AS
 SELECT site.id,
    site.name,
    (public.st_setsrid((public.st_expand(public.st_extent(station.point), (0.01)::double precision))::public.geometry, 4326))::public.geometry(Polygon,4326) AS site_extent
   FROM (station.station
     JOIN station.site ON ((site.id = station.site_id)))
  GROUP BY site.id;


--
-- Name: dataset delete_children_t; Type: TRIGGER; Schema: metadata; Owner: postgres
--

CREATE TRIGGER delete_children_t AFTER DELETE ON metadata.dataset FOR EACH ROW EXECUTE PROCEDURE metadata.delete_children_ft();


--
-- Name: borehole borehole_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER borehole_delete_t INSTEAD OF DELETE ON station.borehole FOR EACH ROW EXECUTE PROCEDURE station.borehole_delete_ft();


--
-- Name: borehole borehole_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER borehole_insert_t INSTEAD OF INSERT ON station.borehole FOR EACH ROW EXECUTE PROCEDURE station.borehole_insert_ft();


--
-- Name: borehole borehole_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER borehole_update_t INSTEAD OF UPDATE ON station.borehole FOR EACH ROW EXECUTE PROCEDURE station.borehole_update_ft();


--
-- Name: chimney chimney_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER chimney_delete_t INSTEAD OF DELETE ON station.chimney FOR EACH ROW EXECUTE PROCEDURE station.chimney_delete_ft();


--
-- Name: chimney chimney_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER chimney_insert_t INSTEAD OF INSERT ON station.chimney FOR EACH ROW EXECUTE PROCEDURE station.chimney_insert_ft();


--
-- Name: chimney chimney_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER chimney_update_t INSTEAD OF UPDATE ON station.chimney FOR EACH ROW EXECUTE PROCEDURE station.chimney_update_ft();


--
-- Name: device device_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER device_delete_t INSTEAD OF DELETE ON station.device FOR EACH ROW EXECUTE PROCEDURE station.device_delete_ft();


--
-- Name: device device_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER device_insert_t INSTEAD OF INSERT ON station.device FOR EACH ROW EXECUTE PROCEDURE station.device_insert_ft();


--
-- Name: device device_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER device_update_t INSTEAD OF UPDATE ON station.device FOR EACH ROW EXECUTE PROCEDURE station.device_update_ft();


--
-- Name: hydrology_station hydrology_station_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER hydrology_station_delete_t INSTEAD OF DELETE ON station.hydrology_station FOR EACH ROW EXECUTE PROCEDURE station.hydrology_station_delete_ft();


--
-- Name: hydrology_station hydrology_station_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER hydrology_station_insert_t INSTEAD OF INSERT ON station.hydrology_station FOR EACH ROW EXECUTE PROCEDURE station.hydrology_station_insert_ft();


--
-- Name: hydrology_station hydrology_station_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER hydrology_station_update_t INSTEAD OF UPDATE ON station.hydrology_station FOR EACH ROW EXECUTE PROCEDURE station.hydrology_station_update_ft();


--
-- Name: sample sample_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER sample_delete_t INSTEAD OF DELETE ON station.sample FOR EACH ROW EXECUTE PROCEDURE station.sample_delete_ft();


--
-- Name: sample sample_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER sample_insert_t INSTEAD OF INSERT ON station.sample FOR EACH ROW EXECUTE PROCEDURE station.sample_insert_ft();


--
-- Name: sample sample_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER sample_update_t INSTEAD OF UPDATE ON station.sample FOR EACH ROW EXECUTE PROCEDURE station.sample_update_ft();


--
-- Name: weather_station weather_station_delete_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER weather_station_delete_t INSTEAD OF DELETE ON station.weather_station FOR EACH ROW EXECUTE PROCEDURE station.weather_station_delete_ft();


--
-- Name: weather_station weather_station_insert_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER weather_station_insert_t INSTEAD OF INSERT ON station.weather_station FOR EACH ROW EXECUTE PROCEDURE station.weather_station_insert_ft();


--
-- Name: weather_station weather_station_update_t; Type: TRIGGER; Schema: station; Owner: postgres
--

CREATE TRIGGER weather_station_update_t INSTEAD OF UPDATE ON station.weather_station FOR EACH ROW EXECUTE PROCEDURE station.weather_station_update_ft();


--
-- Name: acoustic_imagery acoustic_imagery_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.acoustic_imagery
    ADD CONSTRAINT acoustic_imagery_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: acoustic_imagery acoustic_imagery_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.acoustic_imagery
    ADD CONSTRAINT acoustic_imagery_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: atmospheric_pressure atmospheric_pressure_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure
    ADD CONSTRAINT atmospheric_pressure_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: atmospheric_pressure atmospheric_pressure_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure
    ADD CONSTRAINT atmospheric_pressure_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: atmospheric_pressure atmospheric_pressure_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.atmospheric_pressure
    ADD CONSTRAINT atmospheric_pressure_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: campaign campaign_instrument_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.campaign
    ADD CONSTRAINT campaign_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES measure.instrument(id);


--
-- Name: chemical_analysis_result chemical_analysis_result_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chemical_analysis_result
    ADD CONSTRAINT chemical_analysis_result_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: chemical_analysis_result chemical_analysis_result_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chemical_analysis_result
    ADD CONSTRAINT chemical_analysis_result_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: chimney_release chimney_release_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chimney_release
    ADD CONSTRAINT chimney_release_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: chimney_release chimney_release_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.chimney_release
    ADD CONSTRAINT chimney_release_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_atmospheric_pressure continuous_atmospheric_pressure_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure
    ADD CONSTRAINT continuous_atmospheric_pressure_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_atmospheric_pressure continuous_atmospheric_pressure_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure
    ADD CONSTRAINT continuous_atmospheric_pressure_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_atmospheric_pressure continuous_atmospheric_pressure_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_atmospheric_pressure
    ADD CONSTRAINT continuous_atmospheric_pressure_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_conductivity continuous_groundwater_conductivity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity
    ADD CONSTRAINT continuous_groundwater_conductivity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_groundwater_conductivity continuous_groundwater_conductivity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity
    ADD CONSTRAINT continuous_groundwater_conductivity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_conductivity continuous_groundwater_conductivity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_conductivity
    ADD CONSTRAINT continuous_groundwater_conductivity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_level continuous_groundwater_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level
    ADD CONSTRAINT continuous_groundwater_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_groundwater_level continuous_groundwater_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level
    ADD CONSTRAINT continuous_groundwater_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_level continuous_groundwater_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_level
    ADD CONSTRAINT continuous_groundwater_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_pressure continuous_groundwater_pressure_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure
    ADD CONSTRAINT continuous_groundwater_pressure_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_groundwater_pressure continuous_groundwater_pressure_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure
    ADD CONSTRAINT continuous_groundwater_pressure_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_pressure continuous_groundwater_pressure_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_pressure
    ADD CONSTRAINT continuous_groundwater_pressure_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_temperature continuous_groundwater_temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature
    ADD CONSTRAINT continuous_groundwater_temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_groundwater_temperature continuous_groundwater_temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature
    ADD CONSTRAINT continuous_groundwater_temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_groundwater_temperature continuous_groundwater_temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_groundwater_temperature
    ADD CONSTRAINT continuous_groundwater_temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_humidity continuous_humidity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity
    ADD CONSTRAINT continuous_humidity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_humidity continuous_humidity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity
    ADD CONSTRAINT continuous_humidity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_humidity continuous_humidity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_humidity
    ADD CONSTRAINT continuous_humidity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_nebulosity continuous_nebulosity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity
    ADD CONSTRAINT continuous_nebulosity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_nebulosity continuous_nebulosity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity
    ADD CONSTRAINT continuous_nebulosity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_nebulosity continuous_nebulosity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_nebulosity
    ADD CONSTRAINT continuous_nebulosity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_pasquill_index continuous_pasquill_index_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index
    ADD CONSTRAINT continuous_pasquill_index_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_pasquill_index continuous_pasquill_index_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index
    ADD CONSTRAINT continuous_pasquill_index_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_pasquill_index continuous_pasquill_index_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_pasquill_index
    ADD CONSTRAINT continuous_pasquill_index_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_potential_evapotranspiration continuous_potential_evapotranspiration_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration
    ADD CONSTRAINT continuous_potential_evapotranspiration_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_potential_evapotranspiration continuous_potential_evapotranspiration_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration
    ADD CONSTRAINT continuous_potential_evapotranspiration_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_potential_evapotranspiration continuous_potential_evapotranspiration_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_potential_evapotranspiration
    ADD CONSTRAINT continuous_potential_evapotranspiration_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_rain continuous_rain_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain
    ADD CONSTRAINT continuous_rain_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_rain continuous_rain_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain
    ADD CONSTRAINT continuous_rain_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_rain continuous_rain_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_rain
    ADD CONSTRAINT continuous_rain_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_temperature continuous_temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature
    ADD CONSTRAINT continuous_temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_temperature continuous_temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature
    ADD CONSTRAINT continuous_temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_temperature continuous_temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_temperature
    ADD CONSTRAINT continuous_temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_water_conductivity continuous_water_conductivity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity
    ADD CONSTRAINT continuous_water_conductivity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_water_conductivity continuous_water_conductivity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity
    ADD CONSTRAINT continuous_water_conductivity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_water_conductivity continuous_water_conductivity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_conductivity
    ADD CONSTRAINT continuous_water_conductivity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_water_discharge continuous_water_discharge_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge
    ADD CONSTRAINT continuous_water_discharge_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_water_discharge continuous_water_discharge_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge
    ADD CONSTRAINT continuous_water_discharge_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_water_discharge continuous_water_discharge_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_discharge
    ADD CONSTRAINT continuous_water_discharge_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_water_level continuous_water_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level
    ADD CONSTRAINT continuous_water_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_water_level continuous_water_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level
    ADD CONSTRAINT continuous_water_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_water_level continuous_water_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_level
    ADD CONSTRAINT continuous_water_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_water_ph continuous_water_ph_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph
    ADD CONSTRAINT continuous_water_ph_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_water_ph continuous_water_ph_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph
    ADD CONSTRAINT continuous_water_ph_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_water_ph continuous_water_ph_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_ph
    ADD CONSTRAINT continuous_water_ph_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_water_temperature continuous_water_temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature
    ADD CONSTRAINT continuous_water_temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_water_temperature continuous_water_temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature
    ADD CONSTRAINT continuous_water_temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_water_temperature continuous_water_temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_water_temperature
    ADD CONSTRAINT continuous_water_temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_wind_direction continuous_wind_direction_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction
    ADD CONSTRAINT continuous_wind_direction_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_wind_direction continuous_wind_direction_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction
    ADD CONSTRAINT continuous_wind_direction_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_wind_direction continuous_wind_direction_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_direction
    ADD CONSTRAINT continuous_wind_direction_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: continuous_wind_force continuous_wind_force_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force
    ADD CONSTRAINT continuous_wind_force_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: continuous_wind_force continuous_wind_force_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force
    ADD CONSTRAINT continuous_wind_force_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: continuous_wind_force continuous_wind_force_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.continuous_wind_force
    ADD CONSTRAINT continuous_wind_force_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: fracturing_rate fracturing_rate_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.fracturing_rate
    ADD CONSTRAINT fracturing_rate_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: fracturing_rate fracturing_rate_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.fracturing_rate
    ADD CONSTRAINT fracturing_rate_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: groundwater_conductivity groundwater_conductivity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity
    ADD CONSTRAINT groundwater_conductivity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: groundwater_conductivity groundwater_conductivity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity
    ADD CONSTRAINT groundwater_conductivity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: groundwater_conductivity groundwater_conductivity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_conductivity
    ADD CONSTRAINT groundwater_conductivity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: groundwater_level groundwater_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level
    ADD CONSTRAINT groundwater_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: groundwater_level groundwater_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level
    ADD CONSTRAINT groundwater_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: groundwater_level groundwater_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_level
    ADD CONSTRAINT groundwater_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: groundwater_temperature groundwater_temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature
    ADD CONSTRAINT groundwater_temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: groundwater_temperature groundwater_temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature
    ADD CONSTRAINT groundwater_temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: groundwater_temperature groundwater_temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.groundwater_temperature
    ADD CONSTRAINT groundwater_temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: humidity humidity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity
    ADD CONSTRAINT humidity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: humidity humidity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity
    ADD CONSTRAINT humidity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: humidity humidity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.humidity
    ADD CONSTRAINT humidity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: manual_groundwater_level manual_groundwater_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level
    ADD CONSTRAINT manual_groundwater_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: manual_groundwater_level manual_groundwater_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level
    ADD CONSTRAINT manual_groundwater_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: manual_groundwater_level manual_groundwater_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_groundwater_level
    ADD CONSTRAINT manual_groundwater_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: manual_water_level manual_water_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level
    ADD CONSTRAINT manual_water_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: manual_water_level manual_water_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level
    ADD CONSTRAINT manual_water_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: manual_water_level manual_water_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.manual_water_level
    ADD CONSTRAINT manual_water_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: nebulosity nebulosity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity
    ADD CONSTRAINT nebulosity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: nebulosity nebulosity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity
    ADD CONSTRAINT nebulosity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: nebulosity nebulosity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.nebulosity
    ADD CONSTRAINT nebulosity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: optical_imagery optical_imagery_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.optical_imagery
    ADD CONSTRAINT optical_imagery_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: optical_imagery optical_imagery_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.optical_imagery
    ADD CONSTRAINT optical_imagery_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: pasquill_index pasquill_index_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index
    ADD CONSTRAINT pasquill_index_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: pasquill_index pasquill_index_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index
    ADD CONSTRAINT pasquill_index_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: pasquill_index pasquill_index_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.pasquill_index
    ADD CONSTRAINT pasquill_index_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: potential_evapotranspiration potential_evapotranspiration_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration
    ADD CONSTRAINT potential_evapotranspiration_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: potential_evapotranspiration potential_evapotranspiration_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration
    ADD CONSTRAINT potential_evapotranspiration_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: potential_evapotranspiration potential_evapotranspiration_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.potential_evapotranspiration
    ADD CONSTRAINT potential_evapotranspiration_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: rain rain_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain
    ADD CONSTRAINT rain_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: rain rain_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain
    ADD CONSTRAINT rain_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: rain rain_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.rain
    ADD CONSTRAINT rain_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: raw_groundwater_level raw_groundwater_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level
    ADD CONSTRAINT raw_groundwater_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: raw_groundwater_level raw_groundwater_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level
    ADD CONSTRAINT raw_groundwater_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: raw_groundwater_level raw_groundwater_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.raw_groundwater_level
    ADD CONSTRAINT raw_groundwater_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: stratigraphic_logvalue stratigraphic_logvalue_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.stratigraphic_logvalue
    ADD CONSTRAINT stratigraphic_logvalue_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: stratigraphic_logvalue stratigraphic_logvalue_rock_code_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.stratigraphic_logvalue
    ADD CONSTRAINT stratigraphic_logvalue_rock_code_fkey FOREIGN KEY (rock_code) REFERENCES ref.rock_code(code);


--
-- Name: stratigraphic_logvalue stratigraphic_logvalue_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.stratigraphic_logvalue
    ADD CONSTRAINT stratigraphic_logvalue_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: temperature temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature
    ADD CONSTRAINT temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: temperature temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature
    ADD CONSTRAINT temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: temperature temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.temperature
    ADD CONSTRAINT temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: tool_injection_pressure tool_injection_pressure_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure
    ADD CONSTRAINT tool_injection_pressure_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: tool_injection_pressure tool_injection_pressure_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure
    ADD CONSTRAINT tool_injection_pressure_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: tool_injection_pressure tool_injection_pressure_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_injection_pressure
    ADD CONSTRAINT tool_injection_pressure_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: tool_instant_speed tool_instant_speed_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed
    ADD CONSTRAINT tool_instant_speed_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: tool_instant_speed tool_instant_speed_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed
    ADD CONSTRAINT tool_instant_speed_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: tool_instant_speed tool_instant_speed_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_instant_speed
    ADD CONSTRAINT tool_instant_speed_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: tool_rotation_couple tool_rotation_couple_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple
    ADD CONSTRAINT tool_rotation_couple_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: tool_rotation_couple tool_rotation_couple_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple
    ADD CONSTRAINT tool_rotation_couple_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: tool_rotation_couple tool_rotation_couple_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.tool_rotation_couple
    ADD CONSTRAINT tool_rotation_couple_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: water_conductivity water_conductivity_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity
    ADD CONSTRAINT water_conductivity_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: water_conductivity water_conductivity_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity
    ADD CONSTRAINT water_conductivity_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: water_conductivity water_conductivity_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_conductivity
    ADD CONSTRAINT water_conductivity_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: water_discharge water_discharge_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge
    ADD CONSTRAINT water_discharge_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: water_discharge water_discharge_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge
    ADD CONSTRAINT water_discharge_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: water_discharge water_discharge_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_discharge
    ADD CONSTRAINT water_discharge_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: water_level water_level_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level
    ADD CONSTRAINT water_level_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: water_level water_level_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level
    ADD CONSTRAINT water_level_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: water_level water_level_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_level
    ADD CONSTRAINT water_level_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: water_ph water_ph_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph
    ADD CONSTRAINT water_ph_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: water_ph water_ph_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph
    ADD CONSTRAINT water_ph_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: water_ph water_ph_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_ph
    ADD CONSTRAINT water_ph_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: water_temperature water_temperature_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature
    ADD CONSTRAINT water_temperature_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: water_temperature water_temperature_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature
    ADD CONSTRAINT water_temperature_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: water_temperature water_temperature_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.water_temperature
    ADD CONSTRAINT water_temperature_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: weight_on_tool weight_on_tool_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool
    ADD CONSTRAINT weight_on_tool_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: weight_on_tool weight_on_tool_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool
    ADD CONSTRAINT weight_on_tool_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: weight_on_tool weight_on_tool_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.weight_on_tool
    ADD CONSTRAINT weight_on_tool_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: wind_direction wind_direction_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction
    ADD CONSTRAINT wind_direction_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: wind_direction wind_direction_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction
    ADD CONSTRAINT wind_direction_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: wind_direction wind_direction_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_direction
    ADD CONSTRAINT wind_direction_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: wind_force wind_force_campaign_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force
    ADD CONSTRAINT wind_force_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES measure.campaign(id);


--
-- Name: wind_force wind_force_dataset_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force
    ADD CONSTRAINT wind_force_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: wind_force wind_force_station_id_fkey; Type: FK CONSTRAINT; Schema: measure; Owner: postgres
--

ALTER TABLE ONLY measure.wind_force
    ADD CONSTRAINT wind_force_station_id_fkey FOREIGN KEY (station_id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: geologic_code geologic_code_parent_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.geologic_code
    ADD CONSTRAINT geologic_code_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES ref.geologic_code(id);


--
-- Name: station_borehole station_borehole_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_borehole
    ADD CONSTRAINT station_borehole_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: station_chimney station_chimney_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_chimney
    ADD CONSTRAINT station_chimney_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: station station_dataset_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station
    ADD CONSTRAINT station_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES metadata.dataset(id) ON DELETE CASCADE;


--
-- Name: station_device station_device_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_device
    ADD CONSTRAINT station_device_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: station_hydrology station_hydrology_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_hydrology
    ADD CONSTRAINT station_hydrology_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: station station_orig_srid_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station
    ADD CONSTRAINT station_orig_srid_fkey FOREIGN KEY (orig_srid) REFERENCES public.spatial_ref_sys(srid);


--
-- Name: station_sample station_sample_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_sample
    ADD CONSTRAINT station_sample_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- Name: station station_site_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station
    ADD CONSTRAINT station_site_id_fkey FOREIGN KEY (site_id) REFERENCES station.site(id);


--
-- Name: station_weather_station station_weather_station_id_fkey; Type: FK CONSTRAINT; Schema: station; Owner: postgres
--

ALTER TABLE ONLY station.station_weather_station
    ADD CONSTRAINT station_weather_station_id_fkey FOREIGN KEY (id) REFERENCES station.station(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

