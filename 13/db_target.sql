--
-- code only for the target (additionally specified) database
--

SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER DATABASE :"DB" OWNER TO deploy;
GRANT ALL ON DATABASE :"DB" TO deploy;
ALTER DATABASE :"DB" SET search_path = :DEV_SCHEMA, public, tiger;
