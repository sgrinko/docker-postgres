SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- create DB template_extension
select not exists(select true FROM pg_catalog.pg_database where datname='template_extension') as is_check
\gset
\if :is_check
    CREATE DATABASE template_extension IS_TEMPLATE true;
\endif

\if :{?APP_DB}
  select not exists(select true FROM pg_catalog.pg_database where datname = :'APP_DB') as is_check
  \gset
  \if :is_check
    CREATE DATABASE :"APP_DB";
  \endif

  -- роль для приложения
  select not exists(select true FROM pg_catalog.pg_roles where rolname=:'APP_DB') as is_check
  \gset
  \if :is_check
      CREATE ROLE :"APP_DB" ;
      SET log_statement='none';
      ALTER ROLE :"APP_DB" WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD :'APP_DB_PASSWORD'; 
      SET log_statement='ddl';
      ALTER DATABASE :"APP_DB" OWNER TO :"APP_DB";
  \endif
\endif

-- create role deploy
-- роль для деплоя, т.е. все объекты в БД должны быть созданы от нее, а не от пользователя postgres (sa)
select not exists(select true FROM pg_catalog.pg_roles where rolname ilike '%deploy%') as is_check
\gset
\if :is_check
    CREATE ROLE deploy;
    SET log_statement='none';
    ALTER ROLE deploy WITH NOSUPERUSER INHERIT CREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD :'DEPLOY_PASSWORD';
	GRANT pg_signal_backend TO deploy;
    SET log_statement='ddl';
\endif
select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset

-- create role replicator
select not exists(select true FROM pg_catalog.pg_roles where rolname='replicator') as is_check
\gset
\if :is_check
    CREATE ROLE replicator;
\endif
ALTER ROLE replicator WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN REPLICATION NOBYPASSRLS;
GRANT CONNECT ON DATABASE postgres TO replicator; -- с версии 2.1.3 patroni требуется право CONNECT для выполнения проверок кластера

-- create group readonly_group
select not exists(select true FROM pg_catalog.pg_roles where rolname='readonly_group') as is_check
\gset
\if :is_check
    CREATE ROLE readonly_group;
\endif
ALTER ROLE readonly_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

-- create group write_group
select not exists(select true FROM pg_catalog.pg_roles where rolname='write_group') as is_check
\gset
\if :is_check
    CREATE ROLE write_group;
\endif
ALTER ROLE write_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

-- create group execution_group
select not exists(select true FROM pg_catalog.pg_roles where rolname='execution_group') as is_check
\gset
\if :is_check
    CREATE ROLE execution_group;
\endif
ALTER ROLE execution_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

-- create group read_procedure_group
select not exists(select true FROM pg_catalog.pg_roles where rolname='read_procedure_group') as is_check
\gset
\if :is_check
    CREATE ROLE read_procedure_group;
\endif
ALTER ROLE read_procedure_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

-- added role mamonsu
select not exists(select * from pg_roles where rolname = 'mamonsu') as is_check
\gset
\if :is_check
    CREATE ROLE mamonsu LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
\endif

-- группа мониторинга
select not exists(select true FROM pg_catalog.pg_roles where rolname='monitoring_group') as is_check
\gset
\if :is_check
    CREATE ROLE monitoring_group;
\endif
ALTER ROLE monitoring_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;
GRANT pg_monitor TO monitoring_group;

-- роль для коннекта
select not exists(select true FROM pg_catalog.pg_roles where rolname='pgbouncer') as is_check
\gset
\if :is_check
    -- пользователь pgbouncer должен иметь только md5 аутентификацию
    CREATE ROLE pgbouncer;
    SET log_statement='none';
    select setting as pswd_enc from pg_settings where name = 'password_encryption' \gset
    SET password_encryption = 'md5';
    ALTER ROLE pgbouncer WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD :'PGBOUNCER_PASSWORD';
    set password_encryption = :'pswd_enc';
    SET log_statement='ddl';
\endif

-- added rights
GRANT CONNECT ON DATABASE postgres TO :"role_deploy";
GRANT CONNECT ON DATABASE postgres TO readonly_group;
GRANT CONNECT ON DATABASE postgres TO write_group;
GRANT CONNECT ON DATABASE postgres TO execution_group;
GRANT CONNECT ON DATABASE postgres TO read_procedure_group;
GRANT CONNECT ON DATABASE postgres TO monitoring_group;
GRANT ALL PRIVILEGES ON TABLESPACE pg_global TO monitoring_group;

-- на пока даём права как для ORM роли приложения
\if :{?APP_DB}
  GRANT write_group TO :"APP_DB" ;
  GRANT execution_group TO :"APP_DB" ;
  GRANT readonly_group TO :"APP_DB" ;
\endif
