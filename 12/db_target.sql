--
-- code only for the target (additionally specified) database
--

SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select current_database() as dbconnect \gset
select rolname as role_deploy from pg_roles where rolname ilike '%deploy%' limit 1 \gset

ALTER DATABASE  :"dbconnect" OWNER TO :"role_deploy";
GRANT ALL ON DATABASE  :"dbconnect" TO :"role_deploy";
ALTER DATABASE  :"dbconnect" SET search_path = :DEV_SCHEMA, public, tiger;
