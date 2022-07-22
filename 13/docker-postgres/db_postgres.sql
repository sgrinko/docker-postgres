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

GRANT USAGE ON SCHEMA pg_catalog to monitoring_group;
GRANT USAGE ON SCHEMA public TO monitoring_group;
GRANT EXECUTE ON FUNCTION public.pg_stat_statements_reset(oid, oid, bigint) TO monitoring_group;
GRANT SELECT ON TABLE pg_catalog.pg_proc TO monitoring_group;

--
delete from cron.job where command ilike '%util.inf_long_running_requests()%';
-- организуем контроль за долгими процедурами
select cron.schedule('long query JOB all DB', '*/5 * * * *', 'select util.inf_long_running_requests();');
