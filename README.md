# docker-postgres

Докер основан на официальном образе postgres и postgis:

```
https://hub.docker.com/_/postgres
https://hub.docker.com/r/postgis/postgis
```

Контейнер ориентирован на работу с русской локалью. Выполняются внутри следующие команды:

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

Дополнительно к исходным 3-м БД создана шаблонная БД с именем `template_extension`

_В шаблонную БД установлены расширения:_

| Extension | Description |
|--------------|--------------|
|adminpack|administrative functions for PostgreSQL|
|amcheck|functions for verifying relation integrity|
|btree_gin|support  for indexing common datatypes in GIN|
|citext|data type for case-insensitive character strings|
|dblink|connect to other PostgreSQL databases from within a database|
|file_fdw|foreign-data wrapper for flat file access|
|fuzzystrmatch|determine similarities and distance between strings|
|hunspell_en_us|en_US Hunspell Dictionary|
|hunspell_ru_ru|Russian Hunspell Dictionary|
|hunspell_ru_ru_aot|Russian Hunspell Dictionary (from AOT.ru group)|
|pageinspect|inspect the contents of database pages at a low level|
|pg_buffercache|examine the shared buffer cache|
|pg_dbo_timestamp|PostgreSQL extension for storing time and author of database structure modification.|
|pg_prewarm|prewarm relation data|
|pg_repack|Reorganize tables in PostgreSQL databases with minimal locks|
|pg_stat_statements|track execution statistics of all SQL statements executed|
|pg_trgm|text similarity measurement and index searching based on trigrams|
|pg_tsparser|parser for text search|
|pg_variables|session variables with various types|
|pgstattuple|show tuple-level statistics|
|pldbgapi|server-side support for debugging PL/pgSQL functions|
|plpgsql|PL/pgSQL procedural language|
|plpgsql_check|extended check for plpgsql functions|
|plpython3u|PL/Python3U untrusted procedural language|
|postgis|PostGIS geometry, geography, and raster spatial types and functions|
|postgis_tiger_geocoder|PostGIS tiger geocoder and reverse geocoder|
|postgis_topology|PostGIS topology spatial types and functions|
|postgres_fdw|foreign-data wrapper for remote PostgreSQL servers|
|rum|RUM index access method|
|shared_ispell|Provides shared ispell dictionaries.|
|uuid-ossp|generate universally unique identifiers (UUIDs)|

_Настроены 5 конфигураций полнотекстового поиска для русского и английского языка:_

| Name | Description |
|--------------|--------------|
|fts_aot_en_ru|FTS hunspell AOT configuration for russian language based on shared_ispell without stopwords|
|fts_hunspell_en_ru|FTS hunspell Lebedev configuration for russian language based on shared_ispell without stopwords|
|fts_aot_en_ru_sw|FTS hunspell AOT configuration for russian language based on shared_ispell with stopwords|
|fts_hunspell_en_ru_sw|FTS hunspell Lebedev configuration for russian language based on shared_ispell with stopwords|
|fts_snowball_en_ru_sw|FTS snowball configuration for russian language based on tsparser with stopwords|

_Особенность:_
* использование парсера `tsparser` и загрузки используемых словарей в общую память однократно при старте сервера. Используется расширение `shared_ispell`. Русские и английские словари взяты из расширения `hunspell_dicts`
* 3 конфигурации с использованием стоп-слов (постфикс "_sw") и 2 конфигурации без использования стоп слов

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
      -c shared_preload_libraries='plugin_debugger, pg_stat_statements, auto_explain, pg_buffercache, pg_cron, shared_ispell, pg_prewarm'
```

то проблему 1-го старта с последующей донастройкой можно избежать. Однако надо помнить, что указание такой строки в качестве параметра старта службы не позволит изменить это значение через файл настроек.

* Старт с уже инициализированным каталогом

Когда контейнер запускается с уже присоединённым каталогом кластера БД, то никаких внутренних скриптов инициализации не применяется. Однако, если есть желание "дотянуть" до стандарта по расширениям и настройкам текущего контейнера, то необходимо иметь ввиду, что для полноценной работы внутренних скриптов необходимо в настройках кластера загружать следующие shared библиотеки:

```
plugin_debugger, pg_stat_statements, auto_explain, pg_buffercache, pg_cron, shared_ispell, pg_prewarm
```

Чтобы "дотянуть" БД до стандарта по расширениям и настройкам текущего контейнера выполните вызов скрипта: `update-extension.sh` как описано чуть выше.

В кластере БД созданном с нуля `pg_hba.conf` и `pg_ident.conf` имеют значения расcчитанные на вход по паролю, а `postgresql.conf` оптимизирован под 2 ГБ ОЗУ и SSD диски. При необходимости, после первичной инициализации, уточните параметры конфигурации.

# Пользовательская БД

Чтобы создать свою БД, рекомендуется использовать шаблон `template_extension`:

```
CREATE DATABASE my_db WITH TEMPLATE template_extension;
```

В созданной таким образом БД настроены все необходимые расширения и создана схема с именем `dbo` как схема для пользовательских таблиц.
Однако права и пути поиска нельзя перенести таким образом, поэтому для дотягивания БД до стандартов контейнера нужно выполнить скрипт: `update-extension.sh` как описано чуть выше и передать как параметр этому скрипту имя созданнй БД.

```
$ docker exec -it temp_postgres_1 update-extension.sh my_db
```

Путь поиска после выполнения скрипта в указанной БД выглядит так: `search_path = dbo, public, tiger;`

# Работа с бэкапами

Контейнер рассчитан на работу с утилитой бэкапирования `pg_probackup` от компании PostgresProfessional. В настройках `archive_command` и `restore_command` написана bash команда для вызова архивации/восстановления WAL файлов:

```
archive_command:
if [ -f archive_pause.trigger ]; then exit 1; else if [ -f archive_active.trigger ]; then pg_probackup-12 archive-push -B /mnt/pgbak --instance 12 --wal-file-path %p --wal-file-name %f; else exit 0; fi; fi

restore_command:
if [ -f archive_active.trigger ]; then pg_probackup-12 archive-get -B /mnt/pgbak --instance 12 --wal-file-path %p --wal-file-name %f; else exit 0; fi
```

Чтобы WAL файлы начали сохраняться, нужно в каталоге данных создать файл с именем: `archive_active.trigger` (автоматически создается при первом вызове `backup.sh`)
При его наличии каждый WAL файл сохраняется в бэкап-каталог. 

> При его отсутствии WAL файлы не сохраняются!

Чтобы временно приостановить выгрузку WAL файлов в бэкап-каталог нужно создать файл: `archive_pause.trigger` (это может понадобиться для временных работ с бэкапным каталогом).

В контейнере есть 2 дополнительных скрипта:

`backup.sh` - создаёт новый бэкап

`show.sh`    - показывает какие бэкапы есть.

Для запуска можно использовать команды:

```
$ docker exec -it temp_postgres_1 backup.sh
$ docker exec -it temp_postgres_1 show.sh
```

Скрипт `backup.sh` может принимать до 3 -х параметров:

```
$1 - кол-во потоков для выполнения бэкапа: 4 (по умолчанию) или указанное число
$2 - указывает режим создания инкрементального бэкапа: delta (по умолчанию) или page
$3 - признак создания автономного бэкапа типа stream: yes (по умолчанию) или любой другой текст для варианта "archive"
```

Скрипт `show.sh` может принимать до 2 -х параметров:

```
$1 - yes/no (нужно ли отсылать письмо с отчетом по текущим бэкапам)
$2 - список email получателей письма (через пробел и обрамить двойными кавычками)
```

# Переменные окружения контейнера

Часть переменных имеет значения по умолчанию, это значит, что если их не указывать при старте контейнера, то они имеют указанные значения.

_Каталог данных:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|PGDATA|/var/lib/postgresql/data|Эту необязательную переменную можно использовать для определения другого местоположения - например, подкаталога - для файлов базы данных. Если используемый вами том данных является точкой монтирования файловой системы или удаленной папкой, которая не может быть подключена для пользователя postgres (например, некоторые монтируемые NFS), Postgres initdb рекомендует создать подкаталог для хранения данных.|

_Переменные использующиеся только при первичной инициализации:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|POSTGRES_INITDB_ARGS|--locale=ru_RU.UTF8 --data-checksums|Эту необязательную переменную среды можно использовать для отправки аргументов в postgres initdb. Значение представляет собой строку аргументов, разделенных пробелами, как того и ожидает postgres initdb.|
|POSTGRES_HOST_AUTH_METHOD|md5|Эту необязательную переменную можно использовать для управления методом аутентификации для соединений с хостом для всех баз данных, всех пользователей и всех адресов. Это значение используется только на этапе первичной инициализации.|
|POSTGRES_INITDB_WALDIR|PGDATA/pg_wal|Эту необязательную переменную среды можно использовать для определения другого места для журнала транзакций Postgres. Иногда может быть желательно хранить журнал транзакций в другом каталоге, который может поддерживаться хранилищем с другими характеристиками производительности или надежности.|

_Переменные с данными по подключению к БД:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|POSTGRES_USER|postgres|Эта переменная создаст указанного пользователя с полномочиями суперпользователя и базу данных с тем же именем. Не рекомендуется менять значение этой переменной.|
|POSTGRES_DB|postgres|Эту необязательную переменную среды можно использовать для определения другого имени для базы данных по умолчанию, которая создается при первом запуске образа. Если он не указан, будет использоваться значение POSTGRES_USER. Не рекомендуется менять значение этой переменной.|
|POSTGRES_PASSWORD| |Определяет пароль пользователя POSTGRES_USER. Это значение указывается в настройках мапинга пользователя для FDW серверов.|
|DEV_SCHEMA|dbo|Имя схемы, выбираемая как схема по умолчанию для пользовательских объектов. Это имя включается в параметр search_path и эта схема создается если её нет.|

_Переменная указывающая на временную зону в которой работает контейнер:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|TZ| |Указывает на временную зону в которой работает контейнер. Например: "Europe/Moscow" или "Etc/UTC"|

_Переменные для отправки писем:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|EMAILTO|PostgreSQL@my_company.ru|На какой адрес отправлять почтовые сообщения|
|EMAIL_SERVER|mail.my_company.ru|Имя почтового сервера для отправки писем|
|EMAIL_HOSTNAME|myhost@noreplay.ru|имя отправителя писем|
|EMAIL_SEND|yes|Отправку писем можно отменить указав no|

_Переменные влияющие на работу скриптов по бэкапам:_

| Name | Default value | Description |
|--------------|--------------|--------------|
|BACKUP_MODE|delta|Режим инкрементального бэкапа. Альтернативное значение page|
|BACKUP_PATH|/mnt/pgbak|Каталог используемый утилитой pg_probackup для хранения всех бэкапов|
|BACKUP_THREADS|4|На сколько потоко можно параллелить бэкап/рестор процесс|
|BACKUP_STREAM|yes|`yes` - создавать автономные резервные копии. `no` - создавать резервные копии для которых обязательно нужны WAL файлы.|

# Пример docker-compose файла

```
version: '3.5'
services:
 
  postgres:
 
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger, pg_stat_statements, auto_explain, pg_buffercache, pg_cron, shared_ispell, pg_prewarm'
    volumes:
      - "/var/lib/pgsql/12/data:/var/lib/postgresql/data"
      - "/var/log/postgresql:/var/log/postgresql"
      - "/var/run/postgresql/:/var/run/postgresql/"
      - "/mnt/pgbak/:/mnt/pgbak/"
    ports:
      - "5432:5432"
    restart: always
    environment:
      POSTGRES_PASSWORD: qweasdzxc
      POSTGRES_HOST_AUTH_METHOD: trust
      DEPLOY_PASSWORD: qweasdzxc
      TZ: "Europe/Moscow"
      EMAILTO: "PostgreSQL@my_company.ru"
      EMAIL_SERVER: "mail.my_company.ru"
      EMAIL_HOSTNAME: "myhost@noreplay.ru"
      BACKUP_THREADS: "4"
      BACKUP_MODE: "delta"
```

Этот управляющий файл рекомендуется запускать командами:

```
#!/bin/bash
clear
rm -rf /var/log/pgbouncer/*
rm -rf /var/log/postgresql/*
rm -rf /var/log/mamonsu/*
docker-compose -f "postgres-service.yml" up --build "$@"
```
