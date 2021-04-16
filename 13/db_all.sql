--
-- код для всех БД
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

CREATE OR REPLACE VIEW public.who AS
 SELECT pa.pid,
    pg_blocking_pids(pa.pid) AS blocked_by,
    pa.leader_pid,
    pa.state,
    now() - pa.xact_start AS ts_age,
    clock_timestamp() - pa.xact_start AS xact_age,
    clock_timestamp() - pa.query_start AS query_age,
    clock_timestamp() - pa.state_change AS change_age,
    pa.datname,
    pa.usename,
    pa.wait_event_type,
    pa.wait_event,
    pa.client_addr,
    pa.client_port,
    pa.application_name,
    pa.backend_type,
    pa.query
   FROM pg_stat_activity pa
  WHERE pa.pid <> pg_backend_pid()
  ORDER BY pa.datname, pa.state, pa.xact_start, pa.leader_pid NULLS FIRST;

CREATE OR REPLACE VIEW public.vw_lock AS
    SELECT pg_locks.pid,
           pg_locks.virtualtransaction AS vxid,
           pg_locks.locktype AS lock_type,
           pg_locks.mode AS lock_mode,
           pg_locks.granted,
           CASE
               WHEN pg_locks.virtualxid IS NOT NULL AND pg_locks.transactionid IS NOT NULL THEN (pg_locks.virtualxid || ' '::text) || pg_locks.transactionid
               WHEN pg_locks.virtualxid IS NOT NULL THEN pg_locks.virtualxid
               ELSE pg_locks.transactionid::text
           END AS xid_lock,
           pg_class.relname,
           pg_locks.page,
           pg_locks.tuple,
           pg_locks.classid,
           pg_locks.objid,
           pg_locks.objsubid
    FROM pg_locks
        LEFT JOIN pg_class ON pg_locks.relation = pg_class.oid
    WHERE pg_locks.pid <> pg_backend_pid() AND pg_locks.virtualtransaction IS DISTINCT FROM pg_locks.virtualxid
    ORDER BY pg_locks.pid, pg_locks.virtualtransaction, pg_locks.granted DESC, (
             CASE
                 WHEN pg_locks.virtualxid IS NOT NULL AND pg_locks.transactionid IS NOT NULL THEN (pg_locks.virtualxid || ' '::text) || pg_locks.transactionid
                 WHEN pg_locks.virtualxid IS NOT NULL THEN pg_locks.virtualxid
                 ELSE pg_locks.transactionid::text
             END),
             pg_locks.locktype, pg_locks.mode, pg_class.relname;
