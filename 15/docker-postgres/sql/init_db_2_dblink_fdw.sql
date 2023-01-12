CREATE EXTENSION IF NOT EXISTS dblink SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgres_fdw SCHEMA public;

-- DBLINK позволяет выполнять автономные запросы
-- DBLINK: в БД postgres
CREATE SERVER IF NOT EXISTS dblink_postgres
  FOREIGN DATA WRAPPER dblink_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');
-- user
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER dblink_postgres
  OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');

-- FDW поддерживает транзакции
-- FDW: в БД postgres
CREATE SERVER IF NOT EXISTS fdw_postgres
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');
-- user
CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER fdw_postgres
  OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');
