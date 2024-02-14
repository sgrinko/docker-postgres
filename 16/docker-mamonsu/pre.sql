SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select not pg_is_in_recovery() as is_master \gset
\if :is_master
  select not exists(select true FROM pg_catalog.pg_database where datname='mamonsu') as is_db_mamonsu \gset
  \if :is_db_mamonsu
      CREATE DATABASE mamonsu;
  \endif
  \c mamonsu
  CREATE EXTENSION IF NOT EXISTS pg_buffercache;
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  -- check role mamonsu ...
  select not exists(select * from pg_roles where rolname = 'mamonsu') as is_role_mamonsu \gset
  \if :is_role_mamonsu
      select :'MAMONSU_PASSWORD' = '' as is_mamonsu_password_exists \gset
      \if :is_mamonsu_password_exists
          CREATE ROLE mamonsu LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
      \else
          CREATE ROLE mamonsu LOGIN PASSWORD :'MAMONSU_PASSWORD' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
      \endif
  \else
      select :'MAMONSU_PASSWORD' <> '' as is_mamonsu_password_notexists \gset
      \if :is_mamonsu_password_notexists
          ALTER ROLE mamonsu WITH PASSWORD :'MAMONSU_PASSWORD' ;
      \endif
  \endif
  GRANT USAGE ON SCHEMA pg_catalog TO mamonsu;
  GRANT SELECT ON TABLE pg_proc TO mamonsu;
\endif

-- get list all current DBs
select string_agg(datname,' ') from pg_catalog.pg_database where not datistemplate;
