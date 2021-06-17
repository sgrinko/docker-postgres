--
-- код для всех БД кроме postgres
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- ========================================================================== --

-- Upgrade pg_dbo_timestamp;
CREATE EXTENSION IF NOT EXISTS pg_dbo_timestamp SCHEMA public;
ALTER EXTENSION pg_dbo_timestamp UPDATE;

ALTER EVENT TRIGGER dbots_tg_on_ddl_event DISABLE;
ALTER EVENT TRIGGER dbots_tg_on_drop_event DISABLE;

\if :IS_POSTGIS_VERSION
  -- Upgrade PostGIS (includes raster)
  CREATE EXTENSION IF NOT EXISTS postgis VERSION :'POSTGIS_VERSION';
  ALTER EXTENSION postgis  UPDATE TO :'POSTGIS_VERSION';

  -- Upgrade Topology
  CREATE EXTENSION IF NOT EXISTS postgis_topology VERSION :'POSTGIS_VERSION';
  ALTER EXTENSION postgis_topology UPDATE TO :'POSTGIS_VERSION';

  -- Install Tiger dependencies in case not already installed
  CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

  -- Upgrade US Tiger Geocoder
  CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder VERSION :'POSTGIS_VERSION';
  ALTER EXTENSION postgis_tiger_geocoder UPDATE TO :'POSTGIS_VERSION';
\else
  -- Install PostGIS (includes raster)
  CREATE EXTENSION IF NOT EXISTS postgis;

  -- Install Topology
  CREATE EXTENSION IF NOT EXISTS postgis_topology;

  -- Install Tiger dependencies in case not already installed
  CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

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
CREATE EXTENSION IF NOT EXISTS pg_repack;

-- Upgrade plpgsql_check
DROP EXTENSION IF EXISTS plpgsql_check;
CREATE EXTENSION IF NOT EXISTS plpgsql_check SCHEMA public;

-- ========================================================================== --

DROP SERVER IF EXISTS dblink_postgres cascade;
DROP SERVER IF EXISTS fdw_postgres cascade;

-- DBLINK: в БД postgres
CREATE SERVER IF NOT EXISTS dblink_postgres
  FOREIGN DATA WRAPPER dblink_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');
-- user
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER dblink_postgres
  OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');

-- FDW: в БД postgres
CREATE SERVER IF NOT EXISTS fdw_postgres
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');
-- user
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER fdw_postgres
  OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');

-- ========================================================================== --

ALTER EVENT TRIGGER dbots_tg_on_ddl_event ENABLE;
GRANT SELECT ON public.dbots_object_timestamps TO write_group;
GRANT SELECT ON public.dbots_object_timestamps TO readonly_group;
GRANT SELECT ON public.dbots_object_timestamps TO deploy;
GRANT SELECT ON public.dbots_event_data TO readonly_group;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dbots_event_data TO write_group;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON public.dbots_event_data TO deploy;
GRANT SELECT ON public.dbots_event_data TO readonly_group;

-- ========================================================================== --

CREATE SCHEMA IF NOT EXISTS cron;
--
CREATE FOREIGN TABLE IF NOT EXISTS cron.job
(
   jobid bigint NOT NULL,
   schedule text NOT NULL,
   command text NOT NULL,
   nodename text NOT NULL,
   nodeport integer NOT NULL,
   "database" text NOT NULL,
   username text NOT NULL,
   active boolean NOT NULL,
   jobname name
)
  SERVER fdw_postgres
  OPTIONS (schema_name 'cron', table_name 'job');

CREATE FOREIGN TABLE IF NOT EXISTS cron.job_run_details
(
   jobid bigint ,
   runid bigint NOT NULL,
   job_pid integer ,
   "database" text ,
   username text ,
   command text ,
   status text ,
   return_message text ,
   start_time timestamp with time zone ,
   end_time timestamp with time zone
)
  SERVER fdw_postgres
  OPTIONS (schema_name 'cron', table_name 'job_run_details');
--
CREATE OR REPLACE FUNCTION cron.schedule(schedule text, command text)
  RETURNS bigint AS
$BODY$
   insert into cron.job (jobid, schedule, command, "database", username, nodename, nodeport, active) 
                  values((select coalesce(max(jobid)+1, 1) from cron.job),
                          schedule, command, current_database(), current_user, 'localhost', inet_server_port(), true)
   returning jobid;
$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
COMMENT ON FUNCTION cron.schedule(text,text) IS 'schedule a pg_cron job without job name';
--
CREATE OR REPLACE FUNCTION cron.schedule(job_name name, schedule text, command text)
  RETURNS bigint AS
$BODY$
   insert into cron.job (jobid, schedule, command, "database", username, jobname, nodename, nodeport, active)
                  values((select coalesce(max(jobid)+1, 1) from cron.job), 
                          schedule, command, current_database(), current_user, job_name, 'localhost', inet_server_port(), true)
   returning jobid;
$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
COMMENT ON FUNCTION cron.schedule(name,text,text) IS 'schedule a pg_cron job with job name';
--
CREATE OR REPLACE FUNCTION cron.schedule(job_name name, schedule text, command text, "database" text, username text, active boolean)
  RETURNS bigint AS
$BODY$
   insert into cron.job (jobid, schedule, command, "database", username, jobname, active, nodename, nodeport)
                  values((select coalesce(max(jobid)+1, 1) from cron.job), 
                          schedule, command, "database", username, job_name, active, 'localhost', inet_server_port())
   returning jobid;
$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
COMMENT ON FUNCTION cron.schedule(name,text,text,text,text,boolean) IS 'schedule a pg_cron job with full parameters';
--
CREATE OR REPLACE FUNCTION cron.unschedule(job_id bigint)
  RETURNS boolean AS
$BODY$
   with _del as (delete from cron.job where jobid = job_id returning jobid)
   select count(*)=1 from _del;
$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
COMMENT ON FUNCTION cron.unschedule(int8) IS 'unschedule a pg_cron job as number job';
--
CREATE OR REPLACE FUNCTION cron.unschedule(job_name name)
  RETURNS boolean AS
$BODY$
   with _del as (delete from cron.job where jobname = job_name returning jobid)
   select count(*)=1 from _del;
$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
COMMENT ON FUNCTION cron.unschedule(name) IS 'unschedule a pg_cron job as job name';
--
CREATE OR REPLACE FUNCTION cron.alter_job(
    job_id bigint,
    schedule text DEFAULT NULL::text,
    command text DEFAULT NULL::text,
    "database" text DEFAULT NULL::text,
    username text DEFAULT NULL::text,
    active boolean DEFAULT NULL::boolean,
    job_name name DEFAULT NULL::name
    )
RETURNS void AS
$BODY$
  update cron.job set schedule   = alter_job.schedule   where jobid=alter_job.job_id and alter_job.schedule is not null;
  update cron.job set command    = alter_job.command    where jobid=alter_job.job_id and alter_job.command is not null;
  update cron.job set "database" = alter_job."database" where jobid=alter_job.job_id and alter_job."database" is not null;
  update cron.job set username   = alter_job.username   where jobid=alter_job.job_id and alter_job.username is not null;
  update cron.job set active     = alter_job.active     where jobid=alter_job.job_id and alter_job.active is not null;
  update cron.job set jobname    = alter_job.job_name   where jobid=alter_job.job_id and alter_job.job_name is not null;
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
COMMENT ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, name) IS 'Alter the job identified by job_id. Any option left as NULL will not be modified.';
--
GRANT ALL ON SCHEMA cron TO deploy;
GRANT USAGE ON SCHEMA cron TO write_group;
--
GRANT ALL ON TABLE cron.job TO deploy;
GRANT ALL ON TABLE cron.job TO write_group;
--
GRANT ALL ON TABLE cron.job_run_details TO deploy;
GRANT ALL ON TABLE cron.job_run_details TO write_group;
--
GRANT USAGE ON SCHEMA pg_catalog TO deploy;
GRANT USAGE ON SCHEMA pg_catalog TO write_group;
--
GRANT EXECUTE ON FUNCTION cron.schedule(text,text) TO write_group;
GRANT EXECUTE ON FUNCTION cron.schedule(text,text) TO deploy;
--
GRANT EXECUTE ON FUNCTION cron.schedule(name,text,text) TO write_group;
GRANT EXECUTE ON FUNCTION cron.schedule(name,text,text) TO deploy;
--
GRANT EXECUTE ON FUNCTION cron.schedule(name,text,text,text,text,boolean) TO write_group;
GRANT EXECUTE ON FUNCTION cron.schedule(name,text,text,text,text,boolean) TO deploy;
--
GRANT EXECUTE ON FUNCTION cron.unschedule(name) TO write_group;
GRANT EXECUTE ON FUNCTION cron.unschedule(name) TO deploy;
--
GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO write_group;
GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO deploy;
--
GRANT EXECUTE ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, name) TO write_group;
GRANT EXECUTE ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, name) TO deploy;

-- ========================================================================== --

DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_snowball_en_ru_sw;
--
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_hunspell_en_ru;
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_aot_en_ru;
--
DROP TEXT SEARCH DICTIONARY IF EXISTS public.english_hunspell_shared;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_hunspell_shared;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_aot_shared;
--
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_hunspell_en_ru_sw;
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_aot_en_ru_sw;
--
DROP TEXT SEARCH DICTIONARY IF EXISTS public.english_hunspell_shared_sw;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_hunspell_shared_sw;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_aot_shared_sw;

-- ========================================================================== --

\if :is_shared_ispell_loaded

-- DICTIONARY without stopwords
CREATE TEXT SEARCH DICTIONARY public.english_hunspell_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'en_us', afffile = 'en_us'
);
COMMENT ON TEXT SEARCH DICTIONARY public.english_hunspell_shared IS 'FTS hunspell dictionary for english language (shared without stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_hunspell_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru', afffile = 'ru_ru'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_hunspell_shared IS 'FTS hunspell Lebedev dictionary for russian language (shared without stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_aot_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru_aot', afffile = 'ru_ru_aot'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_aot_shared IS 'FTS hunspell AOT dictionary for russian language (shared without stopwords)';

-- DICTIONARY with stopwords
CREATE TEXT SEARCH DICTIONARY public.english_hunspell_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'en_us', afffile = 'en_us', stopwords = 'english'
);
COMMENT ON TEXT SEARCH DICTIONARY public.english_hunspell_shared_sw IS 'FTS hunspell dictionary for english language (shared with stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_hunspell_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru', afffile = 'ru_ru', stopwords = 'russian'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_hunspell_shared_sw IS 'FTS hunspell Lebedev dictionary for russian language (shared with stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_aot_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru_aot', afffile = 'ru_ru_aot', stopwords = 'russian'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_aot_shared_sw IS 'FTS hunspell AOT dictionary for russian language (shared with stopwords)';

-- ========================================================================== --

-- CONFIGURATION without stopwords
CREATE TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_hunspell_shared, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru IS 'FTS hunspell Lebedev configuration for russian language based on shared_ispell';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_aot_en_ru (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_aot_shared, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_aot_en_ru IS 'FTS hunspell AOT configuration for russian language based on shared_ispell';

-- ========================================================================== --

-- CONFIGURATION with stopwords
CREATE TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared_sw, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_hunspell_shared_sw, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw IS 'FTS hunspell Lebedev configuration for russian language based on shared_ispell without stopwords';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared_sw, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_aot_shared_sw, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw IS 'FTS hunspell AOT configuration for russian language based on shared_ispell without stopwords';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart
    WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw IS 'FTS snowball configuration for russian language based on tsparser with stopwords';

-- ========================================================================== --

\endif

GRANT CONNECT, CREATE ON DATABASE :"DB" TO deploy;
GRANT CONNECT ON DATABASE :"DB" TO readonly_group;
GRANT CONNECT ON DATABASE :"DB" TO write_group;
GRANT CONNECT ON DATABASE :"DB" TO execution_group;

-- ========================================================================= --

-- ==== привелегии по умолчанию ====
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON TABLES    TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON SEQUENCES TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON TYPES     TO write_group;
ALTER DEFAULT PRIVILEGES GRANT ALL                            ON SCHEMAS   TO write_group;
--
ALTER DEFAULT PRIVILEGES GRANT SELECT                         ON TABLES    TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON SEQUENCES TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON TYPES     TO readonly_group;
ALTER DEFAULT PRIVILEGES GRANT USAGE                          ON SCHEMAS   TO readonly_group;
--
ALTER DEFAULT PRIVILEGES GRANT EXECUTE                        ON FUNCTIONS TO execution_group;
ALTER DEFAULT PRIVILEGES GRANT EXECUTE                        ON ROUTINES  TO execution_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT ALL            ON TABLES    TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT ALL            ON SEQUENCES TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT ALL            ON TYPES     TO write_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT ALL            ON SCHEMAS   TO write_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT SELECT         ON TABLES    TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT USAGE          ON SEQUENCES TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT USAGE          ON TYPES     TO readonly_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT USAGE          ON SCHEMAS   TO readonly_group;
--
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT EXECUTE        ON FUNCTIONS TO execution_group;
ALTER DEFAULT PRIVILEGES FOR ROLE deploy GRANT EXECUTE        ON ROUTINES  TO execution_group;
--

-- ==== права на схемы (временно для ORM) ====
-- не даём читать текст функций поле prosrc
REVOKE SELECT ON pg_catalog.pg_proc FROM execution_group;
-- но даём читать все столбцы кроме prosrc
SELECT 'GRANT SELECT(' || string_agg(attname, ',') || ') ON pg_catalog.pg_proc TO execution_group;'
FROM pg_catalog.pg_attribute a
WHERE attrelid = 'pg_catalog.pg_proc'::regclass AND NOT attisdropped AND attname NOT IN ('tableoid','cmax','xmax','cmin','xmin', 'ctid', 'prosrc')
\gexec
-- роль deploy может читать эту таблицу
GRANT SELECT ON TABLE pg_catalog.pg_proc TO deploy;

-- создаем отдельную схему разработки
CREATE SCHEMA IF NOT EXISTS :"DEV_SCHEMA" ;
ALTER SCHEMA :"DEV_SCHEMA" OWNER TO deploy;
-- и даем в неё права
GRANT ALL ON SCHEMA :"DEV_SCHEMA" TO deploy;
GRANT USAGE ON SCHEMA :"DEV_SCHEMA" TO write_group;
GRANT USAGE ON SCHEMA :"DEV_SCHEMA" TO execution_group;
GRANT USAGE ON SCHEMA :"DEV_SCHEMA" TO readonly_group;
COMMENT ON SCHEMA :"DEV_SCHEMA" IS 'developer base schema';

GRANT ALL   ON SCHEMA public TO deploy;
GRANT USAGE ON SCHEMA public TO write_group;
GRANT USAGE ON SCHEMA public TO execution_group;
GRANT USAGE ON SCHEMA public TO readonly_group;

GRANT USAGE ON SCHEMA information_schema TO deploy;
GRANT USAGE ON SCHEMA information_schema TO write_group;
GRANT USAGE ON SCHEMA information_schema TO execution_group;
GRANT USAGE ON SCHEMA information_schema TO readonly_group;

GRANT USAGE ON SCHEMA pg_catalog TO deploy;
GRANT USAGE ON SCHEMA pg_catalog TO write_group;
GRANT USAGE ON SCHEMA pg_catalog TO execution_group;
GRANT USAGE ON SCHEMA pg_catalog TO readonly_group;

-- ========================================================================= --

ALTER EVENT TRIGGER dbots_tg_on_ddl_event ENABLE;
ALTER EVENT TRIGGER dbots_tg_on_drop_event ENABLE;

-- ========================================================================= --

GRANT CONNECT ON DATABASE :"DB" TO mamonsu;
