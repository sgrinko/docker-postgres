# docker-postgres

Оригинальный код: https://github.com/sgrinko/docker-postgres

Докер основан на официальном образе postgres и postgis:

```
https://hub.docker.com/_/postgres
https://github.com/docker-library/postgres

https://hub.docker.com/r/postgis/postgis
https://github.com/postgis/docker-postgis
```

Контейнер ориентирован на работу с русской локалью. Внутри выполняются следующие команды для локализации:

```
RUN localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.utf8
```

Инициализация новой БД выполняется по умолчанию с параметрами к initdb: `--locale=ru_RU.UTF8 --data-checksums`

Дополнительно добавлены следующие компоненты:
* `pg_probackup` - утилита для работы с бэкапами от Postgres Professional
* `sendemail` - используется для отправки почты
* установлен пакет для коннекта к MSSQL через FDW расширение `tds_fdw` c использованием пакета `freetds`. 
  В файле конфигурации `/etc/freetds/freetds.conf` для параметра `text size` установлено значение: 1262485504 (1204Мб)
* В БД postgres добавлено расширение `pg_cron` для возможности выполнения заданий внутри каждой БД по расписанию. 
  В других БД создаётся обертка из схемы `pg_cron`, 2-х внешних таблиц и нескольких функций, что позволяет использовать простое управление заданиями локально для каждой БД.
* `htop` - удобная утилита для просмотра запущенных процессов внутри контейнера
* `mc` - всем известный файловый менеджер
* дополнительно к исходным 3-м БД создана шаблонная БД с именем `template_extension`

_В шаблонную БД установлены расширения:_

| Extension              | Description                                                                         |
| ---------------------- | ----------------------------------------------------------------------------------- |
| adminpack              | administrative functions for PostgreSQL                                             |
| amcheck                | functions for verifying relation integrity                                          |
| btree_gin              | support for indexing common datatypes in GIN                                        |
| citext                 | data type for case-insensitive character strings                                    |
| dblink                 | connect to other PostgreSQL databases from within a database                        |
| file_fdw               | foreign-data wrapper for flat file access                                           |
| fuzzystrmatch          | determine similarities and distance between strings                                 |
| hunspell_en_us         | en_US Hunspell Dictionary                                                           |
| hunspell_ru_ru         | Russian Hunspell Dictionary                                                         |
| hunspell_ru_ru_aot     | Russian Hunspell Dictionary (from AOT.ru group)                                     |
| pageinspect            | inspect the contents of database pages at a low level                               |
| pg_buffercache         | examine the shared buffer cache                                                     |
| pg_background          | Run SQL queries in the background                                                   |
| pg_dbo_timestamp       | PostgreSQL extension for storing time and author of database structure modification |
| pg_prewarm             | prewarm relation data                                                               |
| pg_repack              | Reorganize tables in PostgreSQL databases with minimal locks                        |
| pg_stat_statements     | track execution statistics of all SQL statements executed                           |
| pg_trgm                | text similarity measurement and index searching based on trigrams                   |
| pg_tsparser            | parser for text search                                                              |
| pg_variables           | session variables with various types                                                |
| pgstattuple            | show tuple-level statistics                                                         |
| pldbgapi               | server-side support for debugging PL/pgSQL functions                                |
| plpgsql                | PL/pgSQL procedural language                                                        |
| plpgsql_check          | extended check for plpgsql functions                                                |
| plpython3u             | PL/Python3U untrusted procedural language                                           |
| postgis                | PostGIS geometry, geography, and raster spatial types and functions                 |
| postgis_tiger_geocoder | PostGIS tiger geocoder and reverse geocoder                                         |
| postgis_topology       | PostGIS topology spatial types and functions                                        |
| postgres_fdw           | foreign-data wrapper for remote PostgreSQL servers                                  |
| rum                    | RUM index access method                                                             |
| shared_ispell          | Provides shared ispell dictionaries.                                                |
| uuid-ossp              | generate universally unique identifiers (UUIDs)                                     |

_Настроены 5 конфигураций полнотекстового поиска для русского и английского языка:_

| Name                  | Description                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| fts_aot_en_ru         | FTS hunspell AOT configuration for russian language based on shared_ispell without stopwords     |
| fts_aot_en_ru_sw      | FTS hunspell AOT configuration for russian language based on shared_ispell with stopwords        |
| fts_hunspell_en_ru    | FTS hunspell Lebedev configuration for russian language based on shared_ispell without stopwords |
| fts_hunspell_en_ru_sw | FTS hunspell Lebedev configuration for russian language based on shared_ispell with stopwords    |
| fts_snowball_en_ru_sw | FTS snowball configuration for russian language based on tsparser with stopwords                 |

_Особенность:_
* использование парсера `tsparser` и загрузки используемых словарей в общую память однократно при старте сервера. Используется расширение `shared_ispell`. Русские и английские словари взяты из расширения `hunspell_dicts`
* 3 конфигурации с использованием стоп-слов (постфикс "_sw") и 2 конфигурации без использования стоп-слов

# Старт контейнера

Контейнер рассчитан на 2 режима начального старта:

* Старт с пустым каталогом данных

При запуске контейнера с пустым каталогом данных выполняется его инициализация через вызов `initdb` и созданием шаблонной БД `template_extension`. Из-за особенностей старта официального образа при такой инициализации не выполняется создание расширений `pg_cron` и `ispell_shared`, а также не выполняется настройка конфигураций полнотекстового поиска.
Поэтому после такого первого старта очень желательно выполнить запуск скрипта обновления БД кластера через команду:

```
$ docker exec -it temp_postgres_1 update-extension.sh <доп.БД>
```

где имя `temp_postgres_1` - имя запущенного postgres-контейнера. В выводе команды docker ps это колонка `NAMES`.

<доп.БД> - можно передать имя пользовательской БД которую необходимо "дотянуть" до стандарта по расширениям и настройкам текущего контейнера. БД должна быть уже создана.

Если же в настройках docker-compose файла указать:

```
command: |
      -c shared_preload_libraries='plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
```

то проблему 1-го старта с последующей донастройкой можно избежать. Однако надо помнить, что указание такой строки в качестве параметра старта службы не позволит изменить эти значение через файл настроек.

* Старт с уже инициализированным каталогом

Когда контейнер запускается с уже присоединённым каталогом кластера БД, то никаких внутренних скриптов инициализации не применяется. Однако, если есть желание "дотянуть" до стандарта по расширениям и настройкам текущего контейнера, то необходимо иметь ввиду, что для полноценной работы внутренних скриптов необходимо в настройках кластера загружать следующие shared библиотеки:

```
shared_preload_libraries='plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
```

а также в файле настроек указать параметр: 
```
shared_ispell.max_size=70MB
```

Чтобы "дотянуть" БД до стандарта по расширениям и настройкам текущего контейнера выполните вызов скрипта: `update-extension.sh` как описано чуть выше.

В кластере БД, созданном с нуля, `pg_hba.conf` и `pg_ident.conf` имеют значения, рассчитанные на вход по паролю (на это оказывает влияние параметр POSTGRES_HOST_AUTH_METHOD), а `postgresql.conf` оптимизирован под 512 MБ ОЗУ и SSD диски. При необходимости, после первичной инициализации уточните параметры конфигурации.

# Пользовательская БД

Чтобы создать свою БД, рекомендуется использовать шаблон `template_extension`:

```
CREATE DATABASE my_db WITH TEMPLATE template_extension;
```

В созданной таким образом БД настроены все необходимые расширения и создана схема с именем `dbo` как схема для пользовательских таблиц.
Однако права и пути поиска нельзя перенести таким образом, поэтому для дотягивания БД до стандартов контейнера нужно выполнить скрипт: `update-extension.sh` как описано чуть выше и передать как параметр этому скрипту имя созданной БД.

```
$ docker exec -it temp_postgres_1 update-extension.sh my_db
```

Путь поиска после выполнения скрипта в указанной БД выглядит так: `search_path = dbo, public, tiger;`

# Работа с бэкапами

Контейнер рассчитан на работу с утилитой бэкапирования `pg_probackup` от компании Postgres Professional. В настройках `archive_command` и `restore_command` написана bash команда для вызова архивации/восстановления WAL файлов:

```
archive_command:
if [ -f archive_pause.trigger ]; then exit 1; else if [ -f archive_active.trigger ]; then pg_probackup-14 archive-push -B /mnt/pgbak --instance 14--wal-file-path %p --wal-file-name %f -j 4 --batch-size=50; else exit 0; fi; fi

restore_command:
if [ -f archive_active.trigger ]; then pg_probackup-14 archive-get -B /mnt/pgbak --instance 14 --wal-file-path %p --wal-file-name %f; else exit 0; fi
```

Чтобы WAL файлы начали сохраняться, нужно в каталоге данных создать файл с именем: `archive_active.trigger` (автоматически создаётся при первом вызове `backup.sh`)
При его наличии каждый WAL файл сохраняется в бэкап-каталог. 

> При его отсутствии WAL файлы не сохраняются!

Чтобы временно приостановить выгрузку WAL файлов в бэкап-каталог нужно создать файл: `archive_pause.trigger` (это может понадобиться для временных работ с бэкапным каталогом).

В контейнере есть 3 дополнительных скрипта:

`backup.sh` - создаёт новый бэкап

`show.sh` - показывает какие бэкапы есть

`check_cluster.sh` - выполняет проверку кластера на возможные ошибки в структуре БД

Для запуска можно использовать команды:

```
$ docker exec -it temp_postgres_1 backup.sh
$ docker exec -it temp_postgres_1 show.sh
$ docker exec -it temp_postgres_1 check_cluster.sh
```

Скрипт `backup.sh` может принимать до 3-х параметров:

```
$1 - количество потоков для выполнения бэкапа: 4 (по умолчанию) или указанное число
$2 - указывает режим создания инкрементального бэкапа: delta (по умолчанию) или page
$3 - признак создания автономного бэкапа типа stream: yes (по умолчанию) или любой другой текст для варианта "archive"
```

Скрипт `show.sh` может принимать до 2-х параметров:

```
$1 - yes/no (нужно ли отсылать письмо с отчетом по текущим бэкапам)
$2 - список email получателей письма (через пробел и обрамить двойными кавычками)
```

Скрипт check_cluster.sh может принимать до 2 -х параметров:

```
$1 - 'amcheck' включить доп.проверку кластера при помощи расширения amcheck
$2 - 'heapallindexed' будет дополнительно проверено, что в индексе действительно представлены все кортежи кучи, которые должны в него попасть
```

# Переменные окружения контейнера

Часть переменных имеет значения по умолчанию, это значит, что если их не указывать при старте контейнера, то они имеют указанные значения.

_Переменные использующиеся только при первичной инициализации:_

| Name                      | Default value                        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| POSTGRES_INITDB_ARGS      | --locale=ru_RU.UTF8 --data-checksums | Эту необязательную переменную среды можно использовать для отправки аргументов в postgres initdb. Значение представляет собой строку аргументов, разделенных пробелами, как того и ожидает postgres initdb.                                                                                                                                                                                                                                                                                                    |
| POSTGRES_HOST_AUTH_METHOD | md5                                  | Эту необязательную переменную можно использовать для управления методом аутентификации для соединений с хостом для всех баз данных, всех пользователей и всех адресов. Это значение используется только на этапе первичной инициализации.                                                                                                                                                                                                                                                                      |
| PGDATA                    | /var/lib/postgresql/data             | Эту необязательную переменную можно использовать для определения другого местоположения - например, подкаталога - для файлов базы данных. По умолчанию это /var/lib/postgresql/data. Если используемый вами том данных является точкой монтирования файловой системы (например, с постоянными дисками GCE) или удаленной папкой, которая не может быть подключена для пользователя postgres (например, некоторые точки монтирования в NFS), Postgres initdb рекомендует создать подкаталог для хранения данных |
| POSTGRES_INITDB_WALDIR    | PGDATA/pg_wal                        | Эту необязательную переменную среды можно использовать для определения другого места для журнала транзакций Postgres. Иногда может быть желательно хранить журнал транзакций в другом каталоге, который может поддерживаться хранилищем с другими характеристиками производительности или надежности.                                                                                                                                                                                                          |

Пример показывающий использование подкаталога для каталога данных:

```
$ docker run -d \
    --name some-postgres \
    -e POSTGRES_PASSWORD=qweasdzxc \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v /custom/mount:/var/lib/postgresql/data \
    postgres
```

Обратите внимание, что мы подключаемый каталог монтируем на 1 уровень выше, чем указали в переменной PGDATA. В этом и есть смысл использования переменной PGDATA

_Переменные с данными по подключению к БД:_

| Name              | Default value | Description                                                                                                                                                                                                                                                                       |
| ----------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| POSTGRES_USER     | postgres      | Эта переменная создаст указанного пользователя с полномочиями суперпользователя и базу данных с тем же именем. Не рекомендуется менять значение этой переменной.                                                                                                                  |
| POSTGRES_DB       | postgres      | Эту необязательную переменную среды можно использовать для определения другого имени для базы данных по умолчанию, которая создается при первом запуске образа. Если он не указан, будет использоваться значение POSTGRES_USER. Не рекомендуется менять значение этой переменной. |
| POSTGRES_PASSWORD |               | Определяет пароль пользователя POSTGRES_USER. Это значение указывается в настройках мапинга пользователя для FDW серверов.                                                                                                                                                        |
| DEV_SCHEMA        | dbo           | Имя схемы, выбираемая как схема по умолчанию для пользовательских объектов. Это имя включается в параметр search_path и эта схема создается если её нет.                                                                                                                          |
| DEPLOY_PASSWORD   |               | Пароль для создаваемого пользователя с именем deploy. Это пользователь с повышенными правами, но не superuser. Предполагается, что он будет владельцем всех создаваемх БД и объектов в них                                                                                        |

_Переменная указывающая на временную зону в которой работает контейнер:_

| Name | Default value | Description                                                                                       |
| ---- | ------------- | ------------------------------------------------------------------------------------------------- |
| TZ   |               | Указывает на временную зону в которой работает контейнер. Например: "Europe/Moscow" или "Etc/UTC" |

_Переменные для отправки писем:_

| Name           | Default value      | Description                                  |
| -------------- | ------------------ | -------------------------------------------- |
| EMAILTO        |                    | На какой адрес отправлять почтовые сообщения |
| EMAIL_SERVER   |                    | Имя почтового сервера для отправки писем     |
| EMAIL_HOSTNAME | noreply@my_host.ru | имя отправителя писем                        |
| EMAIL_SEND     | yes                | Отправку писем можно отменить указав `no`    |

_Переменные влияющие на работу скриптов по бэкапам:_

| Name           | Default value | Description                                                                                                             |
| -------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------- |
| BACKUP_MODE    | delta         | Режим инкрементального бэкапа. Альтернативное значение page                                                             |
| BACKUP_PATH    | /mnt/pgbak    | Каталог используемый утилитой pg_probackup для хранения всех бэкапов                                                    |
| BACKUP_THREADS | 4             | На сколько потоков можно параллелить бэкап/рестор процесс                                                               |
| BACKUP_STREAM  | yes           | `yes` - создавать автономные резервные копии. `no` - создавать резервные копии для которых обязательно нужны WAL файлы. |

# Предустановленные роли

_Контейнер поддерживает следующие предустановленные роли (используйте скрипт update-extension.sh)_

| роль            | описание                                                                                      | параметры                                                                |
| --------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| mamonsu         | специализированная роль для активного агента mamonsu                                          | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION          |
| deploy          | роль владелец для всех новых БД и их объектов                                                 | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD |
| replicator      | роль для использования с логической и потоковой репликацией                                   | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION          |
| readonly_group  | роль-группа выдающая права на чтение таблиц, использование последовательностей и типов        | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| write_group     | роль-группа выдающая права на чтение/запись таблиц, последовательностей и использование типов | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| execution_group | роль-группа выдающая права на запуск всех функций и процедур                                  | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |

# Каталоги для маппинга

_Контейнер ожидает следующие примапленные каталоги_

| Name                               | Description                       |
| ---------------------------------- | --------------------------------- |
| /var/lib/postgresql/data           | каталог с данными кластера        |
| /var/log/postgresql                | каталог с файлами логов           |
| /mnt/pgbak                         | каталог для бэкапов кластера      |
| /usr/share/postgresql/tsearch_data | каталог хранения словарей для FTS |

> Обратите внимание, что на подключаемые каталоги нужно заранее выдать права на запись пользователю с uid=999 (код пользователя postgres внутри контейнера)
# Пример старта контейнера через docker run

запуск без примапленных каталогов. Всё данные кластера будут храниться внутри докер контейнера. В данном примере postgres мапится на порт 5433.

```	
docker run -d --name dev-db -p 5433:5432/tcp --shm-size 2147483648 \
           -e POSTGRES_PASSWORD=qweasdzxc \
           -e POSTGRES_HOST_AUTH_METHOD=trust \
           -e DEPLOY_PASSWORD=cxzdsaewq \
           -e TZ="Etc/UTC" \
           grufos/postgres:14.2 \
           -c shared_preload_libraries="plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" \
           -c shared_ispell.max_size=70MB
```

запуск с указанием примапленных каталогов. Все данные кластера будут храниться вне контейнера в каталоге `/var/lib/pgsql/14/data`, а логи в каталоге `/var/log/postgresql`

```	
docker run -d --name dev-db -p 5433:5432/tcp --shm-size 2147483648 \
       -e POSTGRES_PASSWORD=qweasdzxc \
       -e POSTGRES_HOST_AUTH_METHOD=trust \
       -e DEPLOY_PASSWORD=cxzdsaewq \
       -e TZ="Etc/UTC" \
       -v "/var/lib/pgsql/14/data:/var/lib/postgresql/data" \
       -v "/var/log/postgresql:/var/log/postgresql" \
       -v "/mnt/pgbak2:/mnt/pgbak" \
       -v "/usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data" \
       grufos/postgres:14.2 \
       -c shared_preload_libraries="plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" \
       -c shared_ispell.max_size=70MB
```

остановка контейнера

```	
docker stop dev-db
```

запуск ранее остановленного контейнера

```	
docker start dev-db
```

# Пример docker-compose файла

Создаём файл postgres-service.yml

```
version: '3.5'
services:
 
  postgres:

#    image: grufos/postgres:14.2
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
    volumes:
      - "/var/lib/pgsql/14_1/data:/var/lib/postgresql/data"
      - "/var/log/postgresql1:/var/log/postgresql"
      - "/mnt/pgbak2/:/mnt/pgbak/"
      - "/usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data"
    ports:
      - "5433:5432"
    environment:
#      POSTGRES_INITDB_ARGS: "--locale=ru_RU.UTF8 --data-checksums"
      POSTGRES_PASSWORD: qweasdzxc
      POSTGRES_HOST_AUTH_METHOD: trust
      DEPLOY_PASSWORD: qweasdzxc
#      TZ: "Etc/UTC"
      TZ: "Europe/Moscow"
      EMAILTO: "DBA-PostgreSQL@my_name.ru"
      EMAIL_SERVER: "mail.name.ru"
      EMAIL_HOSTNAME: "noreplay@my_host.ru"
      BACKUP_THREADS: "4"
      BACKUP_MODE: "delta"
```

Этот управляющий файл рекомендуется запускать командами:

```
#!/bin/bash
clear
rm -rf /var/log/postgresql/*
docker-compose -f "postgres-service.yml" up --build "$@"
```

Пример файл для запуска нескольких сервисов сразу postgres-service-all.yml

```
version: '3.5'
services:

  postgres:

#    image: grufos/postgres:14.2
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
    volumes:
      - "/var/lib/pgsql/14_1/data:/var/lib/postgresql/data"
      - "/var/log/postgresql1:/var/log/postgresql"
      - "/mnt/pgbak2/:/mnt/pgbak/"
      - "/usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data"
    ports:
      - "5433:5432"
    environment:
#      POSTGRES_INITDB_ARGS: "--locale=ru_RU.UTF8 --data-checksums"
      POSTGRES_PASSWORD: qweasdzxc
      POSTGRES_HOST_AUTH_METHOD: trust
      DEPLOY_PASSWORD: qweasdzxc
#      TZ: "Etc/UTC"
      TZ: "Europe/Moscow"
      EMAILTO: "DBA-PostgreSQL@my_name.ru"
      EMAIL_SERVER: "mail.name.ru"
      EMAIL_HOSTNAME: "noreplay@my_host.ru"
      BACKUP_THREADS: "4"
      BACKUP_MODE: "delta"

  pgbouncer:
#    image: grufos/pgbouncer:1.17.0
    build:
      context: ./docker-pgbouncer
      dockerfile: Dockerfile
    volumes:
      - "/etc/pgbouncer1/:/etc/pgbouncer/"
      - "/var/log/pgbouncer1:/var/log/pgbouncer"
      - "/etc/localtime:/etc/localtime"
    ports:
      - "6433:6432"
    restart: always
    depends_on:
      - postgres
    environment:
# если в каталоге файлов есть файлы настройки то указанные ниже переменные не обрабатываются 
# если файлы настройки не указываются, то нужно передать в переменных параметры подключения.
# 1-й вариант - использование передачи через URI подключения к серверу
#      - DATABASE_URL=postgresql://postgres:qweasdzxc@127.0.0.1:5432
# 2-й вариант - отдельные переменные 
# Обязательно нужно указывать DB_PASSWORD
      - DB_PASSWORD=qweasdzxc
#      - DB_HOST=127.0.0.1
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=postgres

  mamonsu:
#    image: grufos/mamonsu:14_3.4.0
    build:
      context: ./docker-mamonsu
      dockerfile: Dockerfile

    volumes:
      - "/mnt/pgbak2/:/mnt/pgbak/"
      - "/var/log/mamonsu1:/var/log/mamonsu"
      - "/etc/mamonsu1/:/etc/mamonsu/"

    environment:
#      TZ: "Etc/UTC"
      TZ: "Europe/Moscow"
      PGPASSWORD: qweasdzxc
#      PGHOST: 127.0.0.1
      PGHOST: postgres
      PGPORT: 5432
      MAMONSU_PASSWORD: 1234512345
      ZABBIX_SERVER_IP: zbxprxy.server.ru
      ZABBIX_SERVER_PORT: 10051
      CLIENT_HOSTNAME: my_host.server.ru
      MAMONSU_AGENTHOST: 127.0.0.1
      INTERVAL_PGBUFFERCACHE: 1200
      PGPROBACKUP_ENABLED: "False"

    restart: always
    ports:
      - "10051:10051"
      - "10052:10052"

    depends_on:
      - postgres
```

# Подсказки

Как запустить контейнер в tmpfs - https://stackoverflow.com/questions/42226418/how-to-move-postresql-to-ram-disk-in-docker
