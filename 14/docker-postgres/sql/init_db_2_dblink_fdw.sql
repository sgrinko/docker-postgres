select current_user as userconnect, current_user='postgres' as is_user_postgres \gset
select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset

CREATE EXTENSION IF NOT EXISTS dblink SCHEMA public;
CREATE EXTENSION IF NOT EXISTS postgres_fdw SCHEMA public;

-- DBLINK позволяет выполнять автономные запросы
-- DBLINK: в БД postgres
CREATE SERVER IF NOT EXISTS dblink_postgres
  FOREIGN DATA WRAPPER dblink_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');

-- FDW поддерживает транзакции
-- FDW: в БД postgres
CREATE SERVER IF NOT EXISTS fdw_postgres
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'localhost', port '5432', dbname 'postgres');

-- если задан POSTGRES_PASSWORD то создаём маппинги для пользователя postgres
\if :{?POSTGRES_PASSWORD}
  -- для fdw_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER fdw_postgres
    OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');
  -- для dblink_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER dblink_postgres
    OPTIONS (user 'postgres', password :'POSTGRES_PASSWORD');
\else
  -- для fdw_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER fdw_postgres
    OPTIONS (user 'postgres');
  -- для dblink_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER dblink_postgres
    OPTIONS (user 'postgres');
\endif

-- если задан deploy_password то создаём маппинги для пользователя развертывания приложений
\if :{?deploy_password}
  -- для fdw_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR :role_deploy
    SERVER fdw_postgres
    OPTIONS (user :'role_deploy', password :'deploy_password');
  -- для dblink_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR :role_deploy
    SERVER dblink_postgres
    OPTIONS (user :'role_deploy', password :'deploy_password');
\else
  -- для fdw_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR :role_deploy
    SERVER fdw_postgres
    OPTIONS (user :'role_deploy');
  -- для dblink_postgres
  CREATE USER MAPPING IF NOT EXISTS FOR :role_deploy
    SERVER dblink_postgres
    OPTIONS (user :'role_deploy');
\endif
