--
-- код для всех БД
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

CREATE OR REPLACE VIEW public.vw_who AS
 SELECT pa.pid,
    pg_blocking_pids(pa.pid) AS blocked_by,
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
  ORDER BY pa.datname, pa.state, pa.xact_start;

CREATE OR REPLACE VIEW public.vw_locks AS
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

CREATE OR REPLACE VIEW public.vw_partitions AS 
 WITH RECURSIVE inheritance_tree AS (
         SELECT c_1.oid AS table_oid,
            n.nspname as table_schema,
            c_1.relname AS table_name,
            NULL::name AS table_parent_schema,
            NULL::name AS table_parent_name,
            c_1.relispartition AS is_partition
           FROM pg_class c_1
             JOIN pg_namespace n ON n.oid = c_1.relnamespace
          WHERE c_1.relkind = 'p'::"char" AND c_1.relispartition = false
        UNION ALL
         SELECT inh.inhrelid AS table_oid,
            n.nspname as table_schema,
            c_1.relname AS table_name,
            nn.nspname as table_parent_schema,
            cc.relname AS table_parent_name,
            c_1.relispartition AS is_partition
           FROM inheritance_tree it_1
             JOIN pg_inherits inh ON inh.inhparent = it_1.table_oid
             JOIN pg_class c_1 ON inh.inhrelid = c_1.oid
             JOIN pg_namespace n ON n.oid = c_1.relnamespace
             JOIN pg_class cc ON it_1.table_oid = cc.oid
             JOIN pg_namespace nn ON nn.oid = cc.relnamespace
        )
 SELECT it.table_schema,
    it.table_name,
    c.reltuples,
    c.relpages,
        CASE p.partstrat
            WHEN 'l'::"char" THEN 'BY LIST'::text
            WHEN 'r'::"char" THEN 'BY RANGE'::text
            WHEN 'h'::"char" THEN 'BY HASH'::text
            ELSE 'not partitioned'::text
        END AS partitionin_type,
    it.table_parent_schema,
    it.table_parent_name,
    pg_get_expr(c.relpartbound, c.oid, true) AS partitioning_values,
    pg_get_expr(p.partexprs, c.oid, true) AS sub_partitioning_values
   FROM inheritance_tree it
     JOIN pg_class c ON c.oid = it.table_oid
     LEFT JOIN pg_partitioned_table p ON p.partrelid = it.table_oid
  ORDER BY it.table_name, c.reltuples;
