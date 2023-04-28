--
-- код только для БД postgres
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset

GRANT USAGE ON SCHEMA pg_catalog to monitoring_group;
GRANT USAGE ON SCHEMA public TO monitoring_group;
GRANT EXECUTE ON FUNCTION public.pg_stat_statements_reset(oid, oid, bigint) TO monitoring_group;
GRANT SELECT ON TABLE pg_catalog.pg_proc TO monitoring_group;
--
-- Upgrade or install pg_cron
select setting ~ 'pg_cron' as is_pg_cron_loaded  from pg_settings where name ~ 'shared_preload_libraries' \gset
\if :is_pg_cron_loaded
   CREATE EXTENSION IF NOT EXISTS pg_cron;
   ALTER EXTENSION pg_cron UPDATE;
   GRANT USAGE ON SCHEMA cron TO mamonsu;
   --
   delete from cron.job where command ilike '%util.inf_long_running_requests()%';
   -- организуем контроль за долгими процедурами
   select cron.schedule('long query JOB all DB', '*/5 * * * *', 'select util.inf_long_running_requests();');
   --
   CREATE OR REPLACE FUNCTION cron.get_job_run_details(
      p_dbname    text,
      p_interval  interval DEFAULT '1 day'::interval
   ) RETURNS SETOF cron.job_run_details
      LANGUAGE sql SECURITY DEFINER
      AS $$
   select * from cron.job_run_details where start_time >= now()-p_interval and database=p_dbname;
   $$;
   COMMENT ON FUNCTION cron.get_job_run_details(text, interval) IS 'Returns the history of completed jobs for the specified database and the specified time period';
   --
   -- эта функция должна быть доступна для выполнения роли mamonsu
   GRANT EXECUTE ON FUNCTION cron.get_job_run_details(text, interval) TO mamonsu;
   --
   GRANT ALL ON SCHEMA cron TO :"role_deploy";
   GRANT ALL ON TABLE cron.job TO :"role_deploy";
   GRANT ALL ON SEQUENCE cron.jobid_seq TO :"role_deploy";
   GRANT ALL ON TABLE cron.job_run_details TO :"role_deploy";
   GRANT ALL ON SEQUENCE cron.runid_seq TO :"role_deploy";

   GRANT EXECUTE ON FUNCTION cron.schedule(text, text) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.schedule(text, text, text) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.schedule_in_database(text, text, text, text, text, boolean) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.unschedule(text) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean) TO :"role_deploy";
   GRANT EXECUTE ON FUNCTION cron.get_job_run_details(text, interval) TO :"role_deploy";
\endif
--
