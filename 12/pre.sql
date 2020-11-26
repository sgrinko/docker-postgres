SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select not exists(select true FROM pg_catalog.pg_database where datname='template_extension') as is_check
\gset
\if :is_check
    CREATE DATABASE template_extension IS_TEMPLATE true;
\endif

select not exists(select true FROM pg_catalog.pg_roles where rolname='deploy') as is_check
\gset
\if :is_check
    CREATE ROLE deploy;
\endif
ALTER ROLE deploy WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD :'DEPLOY_PASSWORD';

select not exists(select true FROM pg_catalog.pg_roles where rolname='replicator') as is_check
\gset
\if :is_check
    CREATE ROLE replicator;
\endif
ALTER ROLE replicator WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN REPLICATION NOBYPASSRLS;

select not exists(select true FROM pg_catalog.pg_roles where rolname='readonly_group') as is_check
\gset
\if :is_check
    CREATE ROLE readonly_group;
\endif
ALTER ROLE readonly_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

select not exists(select true FROM pg_catalog.pg_roles where rolname='write_group') as is_check
\gset
\if :is_check
    CREATE ROLE write_group;
\endif
ALTER ROLE write_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

select not exists(select true FROM pg_catalog.pg_roles where rolname='execution_group') as is_check
\gset
\if :is_check
    CREATE ROLE execution_group;
\endif
ALTER ROLE execution_group WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB NOLOGIN NOREPLICATION NOBYPASSRLS;

GRANT CONNECT ON DATABASE postgres TO deploy;
GRANT CONNECT ON DATABASE postgres TO readonly_group;
GRANT CONNECT ON DATABASE postgres TO write_group;
GRANT CONNECT ON DATABASE postgres TO execution_group;
