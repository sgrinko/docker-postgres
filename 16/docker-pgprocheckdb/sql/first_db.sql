select datname from pg_database where not datistemplate and datname not in ('postgres','mamonsu') limit 1;
