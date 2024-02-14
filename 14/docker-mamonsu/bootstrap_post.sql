select 'GRANT EXECUTE ON FUNCTION mamonsu.' || oid::regprocedure || ' TO mamonsu;' from pg_proc where pronamespace = 'mamonsu'::regnamespace \gexec
