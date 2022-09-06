SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- ==== убирание public доступов ====

-- убираем все права для роли public
-- запрещаем кому бы то ни было создавать временные объекты для роли public
-- запрещаем кому бы то ни было подключаться к БД для роли public
select '\c '||datname||chr(13)||chr(10)||'REVOKE ALL ON DATABASE "' || datname || '"  FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для таблиц
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES REVOKE ALL PRIVILEGES ON TABLES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для последовательностей
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES REVOKE ALL PRIVILEGES ON SEQUENCES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для типов
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES REVOKE ALL PRIVILEGES ON TYPES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public на функции
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES REVOKE ALL PRIVILEGES ON FUNCTIONS FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для таблиц
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES FOR ROLE deploy REVOKE ALL PRIVILEGES ON TABLES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для последовательностей
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES FOR ROLE deploy REVOKE ALL PRIVILEGES ON SEQUENCES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public на функции
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES FOR ROLE deploy REVOKE ALL PRIVILEGES ON FUNCTIONS FROM public;'
from pg_database
where datname not in ('template1','template0');

-- запрещаем вновь создаваемым объектам получать любое право для роли public для типов
select '\c '||datname||chr(13)||chr(10)||'ALTER DEFAULT PRIVILEGES FOR ROLE deploy REVOKE ALL PRIVILEGES ON TYPES FROM public;'
from pg_database
where datname not in ('template1','template0');

-- Запрещаем кому бы то ни было читать код процедур для роли public
select '\c '||datname||chr(13)||chr(10)||'REVOKE ALL PRIVILEGES ON pg_catalog.pg_proc, information_schema.routines FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION pg_catalog.pg_get_functiondef(oid) FROM PUBLIC;'
from pg_database
where datname not in ('template1','template0');

-- видеть код и структуру данных для роли public
select '\c '||datname||chr(13)||chr(10)||'REVOKE ALL PRIVILEGES ON SCHEMA pg_catalog, information_schema, public FROM PUBLIC;'
from pg_database
where datname not in ('template1','template0');

-- разрешаем подключаться логинам мониторинга ко всем БД
select 'GRANT CONNECT ON DATABASE "'||datname||'" TO monitoring_group;'
from pg_database
where datname not in ('template1','template0');
