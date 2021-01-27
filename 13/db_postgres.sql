--
-- код только для БД postgres
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- Upgrade or install pg_cron
select setting ~ 'pg_cron' as is_pg_cron_loaded  from pg_settings where name ~ 'shared_preload_libraries' \gset
\if :is_pg_cron_loaded
   CREATE EXTENSION IF NOT EXISTS pg_cron;
   ALTER EXTENSION pg_cron UPDATE;
\endif

