--
-- code only for the target (additionally specified) database
--

SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

ALTER DATABASE :"DB" OWNER TO deploy;
GRANT ALL ON DATABASE :"DB" TO deploy;
ALTER DATABASE :"DB" SET search_path = :DEV_SCHEMA, public, tiger;

with _cmd as (
    -- в 1-ю неделю месяца замораживаем идентификаторы транзакций, в остальные недели только собираем статистику
    select 'vacuum JOB' as name, '0 0 * * 0' as schedule, 'do $$ begin if date_part(''day'', now()) <= 7 then perform dblink(''dblink_localserver'', ''VACUUM (FREEZE,ANALYZE);''); else perform dblink(''dblink_localserver'', ''VACUUM (ANALYZE);''); end if; end $$;' as command
)
select cron.schedule(_cmd.name, _cmd.schedule, _cmd.command)
from _cmd
   left join cron.job j on j.command = _cmd.command and j."database"=current_database()
where j.command is null
;

