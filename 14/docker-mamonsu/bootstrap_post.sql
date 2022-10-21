select 'GRANT EXECUTE ON FUNCTION ' || proname || '() TO mamonsu;' from pg_proc where pronamespace = 'mamonsu'::regnamespace \gexec
