--
-- код для всех БД кроме postgres
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select current_database() as dbconnect \gset
-- ckeck exists roles
select rolname as role_write_group from pg_roles where rolname = 'write_group' limit 1 \gset
select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset
select rolname as role_execution_group from pg_roles where rolname = 'execution_group' limit 1 \gset

-- ========================================================================== --

-- Upgrade pg_dbo_timestamp;
CREATE EXTENSION IF NOT EXISTS pg_dbo_timestamp SCHEMA public;
ALTER EXTENSION pg_dbo_timestamp UPDATE;

ALTER EVENT TRIGGER dbots_tg_on_ddl_event DISABLE;
ALTER EVENT TRIGGER dbots_tg_on_drop_event DISABLE;

\if :IS_SETUPDB
  -- Upgrade PostGIS (includes raster)
  CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;
  ALTER EXTENSION postgis  UPDATE;

  -- Upgrade Topology
  CREATE EXTENSION IF NOT EXISTS postgis_topology;
  ALTER EXTENSION postgis_topology UPDATE;

  -- Install Tiger dependencies in case not already installed
  CREATE EXTENSION IF NOT EXISTS fuzzystrmatch SCHEMA public;

  -- Upgrade US Tiger Geocoder
  CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
  ALTER EXTENSION postgis_tiger_geocoder UPDATE;
\else
  -- Install PostGIS (includes raster)
  CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;

  -- Install Topology
  CREATE EXTENSION IF NOT EXISTS postgis_topology;

  -- Install Tiger dependencies in case not already installed
  CREATE EXTENSION IF NOT EXISTS fuzzystrmatch SCHEMA public;

  -- Install US Tiger Geocoder
  CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
\endif

-- Upgrade citext
CREATE EXTENSION IF NOT EXISTS citext SCHEMA public;
ALTER EXTENSION citext UPDATE;

-- Upgrade uuid-ossp
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;
ALTER EXTENSION "uuid-ossp" UPDATE;

-- Upgrade adminpack;
CREATE EXTENSION IF NOT EXISTS adminpack;
ALTER EXTENSION adminpack UPDATE;

-- Upgrade dblink
CREATE EXTENSION IF NOT EXISTS dblink SCHEMA public;
ALTER EXTENSION dblink UPDATE;

-- Upgrade pageinspect
CREATE EXTENSION IF NOT EXISTS pageinspect SCHEMA public;
ALTER EXTENSION pageinspect UPDATE;

-- Upgrade pg_buffercache
CREATE EXTENSION IF NOT EXISTS pg_buffercache SCHEMA public;
ALTER EXTENSION pg_buffercache UPDATE;

-- Upgrade pg_prewarm
CREATE EXTENSION IF NOT EXISTS pg_prewarm SCHEMA public;
ALTER EXTENSION pg_prewarm UPDATE;

-- Upgrade pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA public;
ALTER EXTENSION pg_stat_statements UPDATE;

-- Upgrade pg_trgm
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;
ALTER EXTENSION pg_trgm UPDATE;

-- Upgrade pgstattuple
CREATE EXTENSION IF NOT EXISTS pgstattuple SCHEMA public;
ALTER EXTENSION pgstattuple UPDATE;

-- Upgrade postgres_fdw
CREATE EXTENSION IF NOT EXISTS postgres_fdw SCHEMA public;
ALTER EXTENSION postgres_fdw UPDATE;

-- Upgrade file_fdw
CREATE EXTENSION IF NOT EXISTS file_fdw SCHEMA public;
ALTER EXTENSION file_fdw UPDATE;

-- Upgrade amcheck
CREATE EXTENSION IF NOT EXISTS amcheck SCHEMA public;
ALTER EXTENSION amcheck UPDATE;

-- Upgrade btree_gin
CREATE EXTENSION IF NOT EXISTS btree_gin SCHEMA public;
ALTER EXTENSION btree_gin UPDATE;

-- Upgrade pldbgapi
CREATE EXTENSION IF NOT EXISTS pldbgapi SCHEMA public;
ALTER EXTENSION pldbgapi UPDATE;

-- Upgrade pg_variables;
CREATE EXTENSION IF NOT EXISTS pg_variables SCHEMA public;
ALTER EXTENSION pg_variables UPDATE;

-- Upgrade rum
CREATE EXTENSION IF NOT EXISTS rum SCHEMA public;
ALTER EXTENSION rum UPDATE;

-- Upgrade hunspell_en_us
CREATE EXTENSION IF NOT EXISTS hunspell_en_us SCHEMA public;
ALTER EXTENSION hunspell_en_us UPDATE;

-- Upgrade hunspell_ru_ru
CREATE EXTENSION IF NOT EXISTS hunspell_ru_ru SCHEMA public;
ALTER EXTENSION hunspell_ru_ru UPDATE;

-- Upgrade hunspell_ru_ru_aou
CREATE EXTENSION IF NOT EXISTS hunspell_ru_ru_aot SCHEMA public;
ALTER EXTENSION hunspell_ru_ru_aot UPDATE;

-- Upgrade shared_ispell;
select setting ~ 'shared_ispell' as is_shared_ispell_loaded  from pg_settings where name ~ 'shared_preload_libraries' \gset
\if :is_shared_ispell_loaded
    CREATE EXTENSION IF NOT EXISTS shared_ispell SCHEMA public;
    ALTER EXTENSION shared_ispell UPDATE;
\endif

-- Upgrade plpython3u;
CREATE EXTENSION IF NOT EXISTS plpython3u;
ALTER EXTENSION plpython3u UPDATE;

-- Upgrade pg_tsparser
CREATE EXTENSION IF NOT EXISTS pg_tsparser SCHEMA public;
ALTER EXTENSION pg_tsparser UPDATE;

-- Upgrade pg_repack
DROP EXTENSION IF EXISTS pg_repack;
CREATE EXTENSION IF NOT EXISTS pg_repack SCHEMA public;

-- Upgrade plpgsql_check
DROP EXTENSION IF EXISTS plpgsql_check;
CREATE EXTENSION IF NOT EXISTS plpgsql_check SCHEMA public;

-- ========================================================================== --

\i init_db_2_dblink_fdw.sql

-- ========================================================================== --

GRANT SELECT ON public.dbots_object_timestamps TO write_group;
GRANT SELECT ON public.dbots_object_timestamps TO readonly_group;
GRANT SELECT ON public.dbots_object_timestamps TO :"role_deploy";
GRANT SELECT ON public.dbots_event_data TO readonly_group;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dbots_event_data TO write_group;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON public.dbots_event_data TO :"role_deploy";
GRANT SELECT ON public.dbots_event_data TO readonly_group;

-- ========================================================================== --

\i  init_db_3_cron.sql

-- ========================================================================== --

\if :is_shared_ispell_loaded

  \i init_db_4_fts.sql

\endif

GRANT CONNECT, CREATE ON DATABASE  :"dbconnect" TO :"role_deploy";
GRANT CONNECT ON DATABASE  :"dbconnect" TO readonly_group;
GRANT CONNECT ON DATABASE  :"dbconnect" TO write_group;
GRANT CONNECT ON DATABASE  :"dbconnect" TO execution_group;
GRANT CONNECT ON DATABASE  :"dbconnect" TO read_procedure_group;
GRANT CONNECT ON DATABASE  :"dbconnect" TO monitoring_group;

-- ========================================================================= --

-- ==== привелегии по умолчанию ====
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON TABLES    TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON SEQUENCES TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON TYPES     TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON SCHEMAS   TO write_group;
--
ALTER DEFAULT PRIVILEGES GRANT SELECT                         ON TABLES    TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT SELECT                         ON SEQUENCES TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON TYPES     TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON SCHEMAS   TO readonly_group;
--
ALTER DEFAULT PRIVILEGES GRANT EXECUTE                        ON FUNCTIONS TO execution_group;
ALTER DEFAULT PRIVILEGES GRANT EXECUTE                        ON ROUTINES  TO execution_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON SCHEMAS   TO read_procedure_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT ALL            ON TABLES    TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT ALL            ON SEQUENCES TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT ALL            ON TYPES     TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT ALL            ON SCHEMAS   TO write_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT SELECT         ON TABLES    TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT SELECT         ON SEQUENCES TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT USAGE          ON TYPES     TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT USAGE          ON SCHEMAS   TO readonly_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT EXECUTE        ON FUNCTIONS TO execution_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT EXECUTE        ON ROUTINES  TO execution_group;
ALTER DEFAULT PRIVILEGES FOR ROLE :"role_deploy" GRANT USAGE          ON SCHEMAS   TO read_procedure_group;
--

-- ==== права на схемы (временно для ORM) ====

-- создаем отдельную схему разработки
CREATE SCHEMA IF NOT EXISTS :"DEV_SCHEMA" ;
ALTER SCHEMA :"DEV_SCHEMA" OWNER TO :"role_deploy";
COMMENT ON SCHEMA :"DEV_SCHEMA" IS 'developer base schema';

-- выдаём USAGE права на все схемы для используемых групповых ролей
select 'GRANT USAGE ON SCHEMA ' || quote_ident(nspname) || ' TO ' || quote_ident(r) || ';'
from pg_namespace, unnest(ARRAY['write_group', 'readonly_group', 'execution_group', 'read_procedure_group', :'role_deploy']) as r 
where nspname not in ('pg_toast','repack','pgbouncer')
\gexec

-- и даем полные права  для роли деплоя
GRANT ALL   ON SCHEMA :"DEV_SCHEMA" TO :"role_deploy";
GRANT ALL   ON SCHEMA public TO :"role_deploy";

-- не даём читать текст функций поле prosrc
REVOKE SELECT ON pg_catalog.pg_proc FROM execution_group;
-- но даём читать все столбцы кроме prosrc
SELECT 'GRANT SELECT(' || string_agg(attname, ',') || ') ON pg_catalog.pg_proc TO execution_group;'
FROM pg_catalog.pg_attribute a
WHERE attrelid = 'pg_catalog.pg_proc'::regclass AND NOT attisdropped AND attname NOT IN ('tableoid','cmax','xmax','cmin','xmin', 'ctid', 'prosrc')
\gexec

-- роль для чтения исходных кодов имеет нужные права                                                                                                            
GRANT SELECT ON TABLE pg_catalog.pg_proc TO read_procedure_group;
GRANT SELECT ON TABLE information_schema.routines TO read_procedure_group;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_get_functiondef(oid) TO read_procedure_group;

-- права на получение статистических данных
GRANT USAGE ON SCHEMA pg_catalog to monitoring_group;
GRANT USAGE ON SCHEMA public TO monitoring_group;
GRANT EXECUTE ON FUNCTION public.pg_stat_statements_reset(oid, oid, bigint) TO monitoring_group;
GRANT SELECT ON TABLE pg_catalog.pg_proc TO monitoring_group;

-- роль деплоя также имеет права по чтению кода
GRANT SELECT ON TABLE pg_catalog.pg_proc TO :"role_deploy";
GRANT SELECT ON TABLE information_schema.routines TO :"role_deploy";
GRANT EXECUTE ON FUNCTION pg_catalog.pg_get_functiondef(oid) TO :"role_deploy";

-- ========================================================================= --

ALTER EVENT TRIGGER dbots_tg_on_ddl_event ENABLE;
ALTER EVENT TRIGGER dbots_tg_on_drop_event ENABLE;

-- ========================================================================= --

GRANT CONNECT ON DATABASE :"dbconnect" TO mamonsu;
GRANT USAGE ON SCHEMA pg_catalog TO mamonsu;
GRANT SELECT ON TABLE pg_proc TO mamonsu;
--

-- проверка существования переменной окружения в базе данных 
with _configs as (
    select r.rolname, unnest(s.setconfig) as config 
    from pg_db_role_setting s 
    left join pg_roles 		r on r.oid=s.setrole 
    where s.setdatabase = (select oid from pg_database where datname=current_database())
),
_get as (
	select rolname, split_part(config, '=', 1) as variable, replace(config, split_part(config, '=', 1) || '=', '') as value
	from _configs
)
SELECT NOT EXISTS(select 1 from _get where variable = 'adm.environment') as is_environment_db
\gset
\if :is_environment_db
    -- устанавливаем переменную окружения для БД только если в БД нет ещё такой настройки
    ALTER DATABASE :"dbconnect" SET adm.environment = :'environment_db_value';
\endif
