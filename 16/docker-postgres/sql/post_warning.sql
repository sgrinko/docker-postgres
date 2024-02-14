SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

select not (setting ~ 'shared_ispell') as is_shared_ispell_notloaded  from pg_settings where name ~ 'shared_preload_libraries' \gset
\if :is_shared_ispell_notloaded
    \echo ""
    \echo "-- ================================================================================================================ --"
    \echo "Please, after the 1st start of the container with an empty database directory, сorrect in the postgreSQL.conf file,"
    \echo "the 'shared_preload_libraries' parameter it must include the download of the 'shared_ispell' library "
    \echo "and re-run the script: update-extension.sh"
    \echo "-- ================================================================================================================ --"
\endif
