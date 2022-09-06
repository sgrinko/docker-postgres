--
-- код для всех БД
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select current_database() as dbconnect \gset

-- создаём объекты для мониторинга
CREATE EXTENSION IF NOT EXISTS plpython3u;
-- Upgrade pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA public;
ALTER EXTENSION pg_stat_statements UPDATE;
--
CREATE EXTENSION IF NOT EXISTS pg_background SCHEMA public;
ALTER EXTENSION pg_background UPDATE;
--
CREATE SCHEMA IF NOT EXISTS util;
COMMENT ON SCHEMA util IS 'Схема для хранения различных функций и представлений общего назначения';
--
CREATE SCHEMA IF NOT EXISTS pgbouncer;
COMMENT ON SCHEMA pgbouncer IS 'Схема для хранения функций пула коннектов';
GRANT CONNECT ON DATABASE :"dbconnect" TO pgbouncer;
GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;

\i user_lookup.sql

GRANT EXECUTE ON FUNCTION pgbouncer.user_lookup(text) TO pgbouncer;
REVOKE EXECUTE ON FUNCTION pgbouncer.user_lookup(text) FROM public;
REVOKE EXECUTE ON FUNCTION pgbouncer.user_lookup(text) FROM execution_group;
--
\i replace_char_xml.sql
--
select current_setting('server_version_num')::integer >= 130000 as postgres_pgvers_13plus \gset
select current_setting('server_version_num')::integer >= 140000 as postgres_pgvers_14plus \gset
--
\if :postgres_pgvers_13plus
  \i vw_who_13plus.sql
  --
  \if :postgres_pgvers_14plus
    \i vw_who_tree_14plus.sql
  \else
    \i vw_who_tree.sql
  \endif
\else
  \i vw_who.sql
  \i vw_who_tree.sql
\endif
--
\i vw_locks.sql
--
\i vw_partitions.sql
--
\i send_email.sql
--
\if :postgres_pgvers_13plus
  \i inf_long_running_requests_13plus.sql
\else
  \i inf_long_running_requests.sql
\endif

\i background_start.sql
