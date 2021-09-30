SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- create DB template_extension
select not exists(select true FROM pg_catalog.pg_database where datname='template_extension') as is_check
\gset
\if :is_check
    CREATE DATABASE template_extension IS_TEMPLATE true;
\endif

-- create role deploy
-- роль для деплоя, т.е. все объекты в БД должны быть созданы от нее, а не от пользователя postgres (sa)
select not exists(select true FROM pg_catalog.pg_roles where rolname ilike '%deploy%') as is_check
\gset
\if :is_check
    CREATE ROLE deploy;
    SET log_statement='none';
    ALTER ROLE deploy WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD :'DEPLOY_PASSWORD';
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

-- added rights
GRANT CONNECT ON DATABASE postgres TO :"role_deploy";
GRANT CONNECT ON DATABASE postgres TO readonly_group;
GRANT CONNECT ON DATABASE postgres TO write_group;
GRANT CONNECT ON DATABASE postgres TO execution_group;
GRANT CONNECT ON DATABASE postgres TO read_procedure_group;
