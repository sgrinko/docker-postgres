select 'GRANT EXECUTE ON FUNCTION mamonsu.' || proname || '() TO mamonsu;' from pg_proc where pronamespace = 'mamonsu'::regnamespace \gexec
