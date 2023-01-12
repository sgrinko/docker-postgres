select not pg_is_in_recovery() as is_master \gset
\if :is_master
  CREATE EXTENSION IF NOT EXISTS pg_buffercache;
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  GRANT USAGE ON SCHEMA pg_catalog TO mamonsu;
  GRANT SELECT ON TABLE pg_proc TO mamonsu;
  select current_database() = 'mamonsu' as is_mamonsu_db \gset
  \if :is_mamonsu_db
    select '''' || case when current_setting('shared_buffers') like '%GB'
                        then (replace(current_setting('shared_buffers'), 'GB', '')::int)*1024
                        else replace(current_setting('shared_buffers'), 'MB', '')::int
                   end * 0.0117 || ' MB''' as highpage_mb \gset
    ALTER FUNCTION mamonsu.buffer_cache() SET WORK_MEM = :highpage_mb; -- for shared_buffers 16 Гб 200 Мб
    GRANT USAGE ON SCHEMA public TO mamonsu;
  \endif
  -- we give the right to connect for the role of mamonsu
  do $$ begin execute 'GRANT CONNECT ON DATABASE "' || current_database() || '" TO mamonsu; '; end $$;
  --
  CREATE SCHEMA IF NOT EXISTS pgbouncer;
  GRANT CONNECT ON DATABASE mamonsu TO pgbouncer;
  GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;
CREATE OR REPLACE FUNCTION pgbouncer.user_lookup(p_username text, OUT uname text, OUT phash text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    SELECT usename, passwd FROM pg_catalog.pg_shadow
    WHERE usename = p_username INTO uname, phash;
    RETURN;
END;
$$;
\endif
