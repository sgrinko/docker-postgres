--
-- PostgreSQL database cluster dump
--

-- Started on 2018-02-19 09:09:23 MSK

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select current_database() as dbconnect \gset

--
CREATE SCHEMA IF NOT EXISTS cron;
--
CREATE FOREIGN TABLE IF NOT EXISTS cron.job
(
   jobid      bigint  OPTIONS (column_name 'jobid')    NOT NULL,
   schedule   text    OPTIONS (column_name 'schedule') NOT NULL,
   command    text    OPTIONS (column_name 'command')  NOT NULL,
   nodename   text    OPTIONS (column_name 'nodename') NOT NULL,
   nodeport   integer OPTIONS (column_name 'nodeport') NOT NULL,
   "database" text    OPTIONS (column_name 'database') NOT NULL,
   username   text    OPTIONS (column_name 'username') NOT NULL,
   active     boolean OPTIONS (column_name 'active')   NOT NULL,
   jobname    text    OPTIONS (column_name 'jobname')
)
  SERVER fdw_postgres
  OPTIONS (schema_name 'cron', table_name 'job');
--
CREATE FOREIGN TABLE IF NOT EXISTS cron.job_run_details
(
   jobid          bigint  OPTIONS (column_name 'jobid'),
   runid          bigint  OPTIONS (column_name 'runid') NOT NULL,
   job_pid        integer OPTIONS (column_name 'job_pid'),
   "database"     text    OPTIONS (column_name 'database'),
   username       text    OPTIONS (column_name 'username'),
   command        text    OPTIONS (column_name 'command'),
   status         text    OPTIONS (column_name 'status'),
   return_message text    OPTIONS (column_name 'return_message'),
   start_time     timestamp with time zone OPTIONS (column_name 'start_time'),
   end_time       timestamp with time zone OPTIONS (column_name 'end_time')
)
  SERVER fdw_postgres
  OPTIONS (schema_name 'cron', table_name 'job_run_details');
--
CREATE OR REPLACE FUNCTION cron.schedule(schedule text, command text)
  RETURNS bigint AS
$$
declare
	v_jobid bigint; 
begin
   select jobid into v_jobid  
   from public.dblink('dblink_postgres', format('select * from cron.schedule_in_database(%L, %L, %L, %L, %L)', 
                                                'JOB (DB ' || current_database() || ')', schedule, command, current_database(), current_user
                                              ) 
                     ) as (jobid bigint);
   --
   update cron.job set jobname = null where jobid = v_jobid;
   --
   return v_jobid;  
end;
$$
  LANGUAGE plpgsql VOLATILE STRICT
  COST 100;
  
COMMENT ON FUNCTION cron.schedule(text, text) IS 'schedule a pg_cron job without job name';

--

CREATE OR REPLACE FUNCTION cron.schedule(job_name text, schedule text, command text)
  RETURNS bigint AS
$$
   select jobid
   from public.dblink('dblink_postgres', format('select * from cron.schedule_in_database(%L, %L, %L, %L, %L)', 
                                                job_name ||' (DB ' || current_database() || ')', schedule, command, current_database(), current_user
                                              ) 
                     ) as (jobid bigint);
$$
  LANGUAGE sql VOLATILE STRICT
  COST 100;

COMMENT ON FUNCTION cron.schedule(text, text, text) IS 'schedule a pg_cron job with job name';
--
CREATE OR REPLACE FUNCTION cron.schedule_in_database(job_name text, schedule text, command text, database text, username text, active boolean) RETURNS bigint
    AS $$
declare
	v_jobid bigint; 
begin
   select jobid into v_jobid  
   from public.dblink('dblink_postgres', format('select * from cron.schedule_in_database(%L, %L, %L, %L, %L, %L)', 
                                                job_name, schedule, command, database, username, active
                                              ) 
                     ) as (jobid bigint);
   --
   update cron.job 
   set database = schedule_in_database.database,
       active = schedule_in_database.active
   where jobid = v_jobid;
   --
   return v_jobid;  
end;
$$
  LANGUAGE plpgsql VOLATILE STRICT
  COST 100;

COMMENT ON FUNCTION cron.schedule_in_database(job_name text, schedule text, command text, database text, username text, active boolean) IS 'schedule a pg_cron job with full parameters';
--
CREATE OR REPLACE FUNCTION cron.unschedule(job_id bigint)
  RETURNS boolean AS
$$
   with _del as (
     delete from cron.job where jobid = job_id 
     returning jobid
   )
   select count(*)=1 from _del;
$$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
  
COMMENT ON FUNCTION cron.unschedule(bigint) IS 'unschedule a pg_cron job as number job';

--

CREATE OR REPLACE FUNCTION cron.unschedule(job_name text)
  RETURNS boolean AS
$$
   with _del as (
     delete from cron.job where jobname = job_name and username = current_user
     returning jobid
   )
   select count(*)=1 from _del;
$$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
  
COMMENT ON FUNCTION cron.unschedule(text) IS 'unschedule a pg_cron job as job name';
--
CREATE OR REPLACE FUNCTION cron.alter_job(
	job_id bigint, 
	schedule text = NULL::text, 
	command text = NULL::text, 
	"database" text = NULL::text, 
	username text = NULL::text, 
	active boolean = NULL::boolean, 
	job_name text = NULL::text
) RETURNS void
    LANGUAGE sql
    AS $$
  update cron.job set schedule   = alter_job.schedule   where jobid=alter_job.job_id and alter_job.schedule is not null;
  update cron.job set command    = alter_job.command    where jobid=alter_job.job_id and alter_job.command is not null;
  update cron.job set "database" = alter_job."database" where jobid=alter_job.job_id and alter_job."database" is not null;
  update cron.job set username   = alter_job.username   where jobid=alter_job.job_id and alter_job.username is not null;
  update cron.job set active     = alter_job.active     where jobid=alter_job.job_id and alter_job.active is not null;
  update cron.job set jobname    = alter_job.job_name   where jobid=alter_job.job_id and alter_job.job_name is not null;
$$;

COMMENT ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, text) IS 'Alter the job identified by job_id. Any option left as NULL will not be modified.';
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


-- ckeck exists roles
select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset
select rolname as role_write_group from pg_roles where rolname = 'write_group' limit 1 \gset
select rolname as role_execution_group from pg_roles where rolname = 'execution_group' limit 1 \gset

GRANT ALL ON SCHEMA cron TO postgres;
\if :{?role_deploy}
  GRANT ALL ON SCHEMA cron TO :role_deploy;
\endif
\if :{?role_write_group}
  GRANT USAGE ON SCHEMA cron TO write_group;
  GRANT ALL ON TABLE cron.job TO write_group;
  GRANT ALL ON TABLE cron.job_run_details TO write_group;
  GRANT USAGE ON SCHEMA pg_catalog TO write_group;
  GRANT EXECUTE ON FUNCTION cron.schedule(text, text) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.schedule(text, text, text) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.schedule_in_database(text, text, text, text, text, boolean) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.unschedule(text) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, text) TO write_group;
  GRANT EXECUTE ON FUNCTION cron.get_job_run_details(text, interval) TO write_group;
\endif
--
\if :{?role_deploy}
  GRANT ALL ON SCHEMA cron TO :"role_deploy";
  GRANT ALL ON TABLE cron.job TO :"role_deploy";
  GRANT ALL ON TABLE cron.job_run_details TO :"role_deploy";
  GRANT USAGE ON SCHEMA pg_catalog TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.schedule(text, text) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.schedule(text, text, text) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.schedule_in_database(text, text, text, text, text, boolean) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.unschedule(text) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.alter_job(bigint, text, text, text, text, boolean, text) TO :"role_deploy";
  GRANT EXECUTE ON FUNCTION cron.get_job_run_details(text, interval) TO :"role_deploy";
\endif

-- в 1-ю неделю месяца замораживаем идентификаторы транзакций, в остальные недели только собираем статистику
\if :{?IS_SETUPDB}
  \if :IS_SETUPDB
    select cron.schedule('vacuum JOB freeze', '0 0 1-7 1,6 */7', 'vacuum (freeze,analyze);'); -- 1-я неделя каждого полугодия
    select cron.schedule('vacuum JOB', '0 0 8-31 * */7', 'vacuum (analyze);');       -- 2-4 неделя каждого месяца
  \endif
\else
    select cron.schedule('vacuum JOB freeze', '0 0 1-7 1,6 */7', 'vacuum (freeze,analyze);'); -- 1-я неделя каждого полугодия
    select cron.schedule('vacuum JOB', '0 0 8-31 * */7', 'vacuum (analyze);');       -- 2-4 неделя каждого месяца
\endif
