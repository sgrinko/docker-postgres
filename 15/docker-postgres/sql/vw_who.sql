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
