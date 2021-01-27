--
-- code only for the target (additionally specified) database
--

SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER DATABASE :"DB" OWNER TO deploy;
GRANT ALL ON DATABASE :"DB" TO deploy;
ALTER DATABASE :"DB" SET search_path = :DEV_SCHEMA, public, tiger;

-- in the 1st week of the month we freeze transaction identifiers, in the rest of the weeks we only collect statistics
with _cmd as (
    select '0 0 * * 0' as schedule, 'do $$ begin if date_part(''day'', now()) <= 7 then perform dblink(''dblink_localserver'', ''VACUUM (FREEZE,ANALYZE);''); else perform dblink(''dblink_localserver'', ''VACUUM (ANALYZE);''); end if; end $$;' as command
)
select cron.schedule('vacuum job', _cmd.schedule, _cmd.command)
from _cmd
   left join cron.job j on j.command = _cmd.command and j."database"=current_database()
where j.command is null
;
