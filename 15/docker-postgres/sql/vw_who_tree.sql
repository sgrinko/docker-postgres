  CREATE OR REPLACE VIEW public.vw_who_tree AS
    WITH RECURSIVE activity AS (
          SELECT pg_blocking_pids(pg_stat_activity.pid) AS blocked_by,
              pg_stat_activity.datid,
              pg_stat_activity.datname,
              pg_stat_activity.pid,
              pg_stat_activity.usesysid,
              pg_stat_activity.usename,
              pg_stat_activity.application_name,
              pg_stat_activity.client_addr,
              pg_stat_activity.client_hostname,
              pg_stat_activity.client_port,
              pg_stat_activity.backend_start,
              pg_stat_activity.xact_start,
              pg_stat_activity.query_start,
              pg_stat_activity.state_change,
              pg_stat_activity.wait_event_type,
              pg_stat_activity.wait_event,
              pg_stat_activity.state,
              pg_stat_activity.backend_xid,
              pg_stat_activity.backend_xmin,
              pg_stat_activity.query,
              pg_stat_activity.backend_type,
              age(clock_timestamp(), pg_stat_activity.xact_start)::interval(0) AS tx_age,
              age(clock_timestamp(), pg_stat_activity.state_change)::interval(0) AS state_age
            FROM pg_stat_activity
            WHERE pg_stat_activity.state IS DISTINCT FROM 'idle'::text
          ), blockers AS (
          SELECT array_agg(DISTINCT dt.c ORDER BY dt.c) AS pids
            FROM ( SELECT unnest(activity.blocked_by) AS unnest
                    FROM activity) dt(c)
          ), tree AS (
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              1 AS level,
              activity.pid AS top_blocker_pid,
              ARRAY[activity.pid] AS path,
              ARRAY[activity.pid] AS all_blockers_above
            FROM activity,
              blockers
            WHERE ARRAY[activity.pid] <@ blockers.pids AND activity.blocked_by = '{}'::integer[]
          UNION ALL
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              tree_1.level + 1 AS level,
              tree_1.top_blocker_pid,
              tree_1.path || ARRAY[activity.pid] AS path,
              tree_1.all_blockers_above || array_agg(activity.pid) OVER () AS all_blockers_above
            FROM activity,
              tree tree_1
            WHERE NOT ARRAY[activity.pid] <@ tree_1.all_blockers_above AND activity.blocked_by <> '{}'::integer[] AND activity.blocked_by <@ tree_1.all_blockers_above
          )
  SELECT tree.pid,
      tree.blocked_by,
      tree.tx_age,
      tree.state_age,
      tree.backend_xid AS xid,
      tree.backend_xmin AS xmin,
      replace(tree.state, 'idle in transaction'::text, 'idletx'::text) AS state,
      tree.datname,
      tree.usename,
      (tree.wait_event_type || ':'::text) || tree.wait_event AS wait,
      ( SELECT count(DISTINCT t1.pid) AS count
            FROM tree t1
            WHERE ARRAY[tree.pid] <@ t1.path AND t1.pid <> tree.pid) AS blkd,
      format('%s %s%s'::text, lpad(('['::text || tree.pid::text) || ']'::text, 7, ' '::text), repeat('.'::text, tree.level - 1) ||
          CASE
              WHEN tree.level > 1 THEN ' '::text
              ELSE NULL::text
          END, "left"(tree.query, 1000)) AS query
    FROM tree
    ORDER BY tree.top_blocker_pid, tree.level, tree.pid;    
