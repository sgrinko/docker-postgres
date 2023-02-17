# Репозитарий docker-postgres

Оригинальный код: https://github.com/sgrinko/docker-postgres

Докер основан на официальном образе postgres и postgis:

```
https://hub.docker.com/_/postgres
https://github.com/docker-library/postgres

https://hub.docker.com/r/postgis/postgis
https://github.com/postgis/docker-postgis
```
## Введение

Разработан набор контейнеров, обеспечивающих полную поддержку всех компонентов для развертывания на DEV, TEST и PROD в единой конфигурации

Докеры для работы с постгрес находятся в подкаталоге docker-postgres
Для каждой версии Postgres создан свой подкаталог по номеру мажорной версии.
Докер docker-pgbouncer не зависит от версии PostgreSQL, поэтому в github он находится в отдельном репозитарии https://github.com/sgrinko/docker-pgbouncer
Для того чтобы использовать докеры в работе (и в разработке) рекомендуется в произвольном каталоге расположить в таком виде докеры;

Общая структура каталогов:
```
├── bin
├── docker-analyze
├── docker-mamonsu
├── docker-pgbouncer
├── docker-pgprobackup
├── docker-pgprorestore
├── docker-pgupgrade
└── docker-postgres
```
Для более удобного управления стартом/разработкой контейнеров используется docker-compose. Для этого разработаны следующие compose yml файлы, которые лежат в корне каталога:
| Скрипт                    | Описание                                                                                                                                                  |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| analyze-service.yml       | настройки запуска контейнера docker-analyze для выполнения процедуры сбора статистики выполняемых запросов в Postgres и ротации логов                     |
| backup-service.yml        | настройки запуска контейнера docker-pgprobackup для выполнения процедуры создания бэкапа кластера БД                                                      |
| check_cluster_service.yml | настройки запуска контейнера docker-pgprobackup для выполнения процедуры проверки кластера                                                                |
| postgres-pgupgrade.yml    | настройки запуска контейнера docker-pgupgrade (контейнер обновления мажорной версии)                                                                      |
| postgres-service_all.yml  | настройки запуска 3-х контейнеров: docker-postgres, docker-pgbouncer и docker-mamonsu                                                                     |
| postgres-service_pgb.yml  | настройки запуска контейнера docker-postgres, docker-pgbouncer                                                                                            |
| postgres-service.yml      | настройки запуска контейнера docker-postgres                                                                                                              |
| restore-service.yml       | настройки запуска контейнера docker-pgprorestore для выполнения процедуры восстановления кластера из бэкапа                                               |
| show_backup-service.yml   | настройки запуска контейнера docker-pgprobackup. Выполняет процедуру показа содержимого каталога бэкапов с возможностью отправки этой информации на почту |

Эти скрипты лежат в корне каталога соотвествующей версии контейнеров.

В каталоге bin находятся sh файлы для старта/сборки контейнеров:
| Скрипт                 | Описание                                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| analyze_start.sh       | сбор статистики выполнения запросов в Postgres и выполнения ротации логов. Логи Postgres хранятся в течение 30 дней, а логи mamonsu и pgbouncer в течение 1 недели |
| backup_start.sh        | запуск создания бэкапа (FULL или DELTA/PAGE)                                                                                                                       |
| check_cluster_start.sh | полная очистка каталога контейнеров. При множественной корректировке контейнеров накапливается много "старых" контейнеров и выполнять их чистку иногда полезно     |
| clear_all_docker.sh    | удаление всех загруженных image контейнеров и их производных, чтобы полностью очистить рабочее пространство                                                        |
| docker_start.sh        | запуск контейнера postgres используя команду docker run ...                                                                                                        |
| hub_push.sh            | скрипт загрузки образов докер на hub.docker.com                                                                                                                    |
| postgres_start_all.sh  | запуск комплекса контейнеров (postgres + pgbouncer + mamonsu) работающих не в фоне и выводящих свои сообщения в терминал                                           |
| postgres_start_pgb.sh  | запуск комплекса контейнеров (postgres + pgbouncer) работающих не в фоне и выводящих свои сообщения в терминал                                                     |
| postgres_start.sh      | запуск контейнера postgres работающего не в фоне и выводящего свои сообщения в терминал                                                                            |
| restore_start.sh       | запуск восстановления кластера из бэкапа. При этом контейнер postgres не должен работать                                                                           |
| show_start.sh          | запуск вывода информации о текущих созданных бэкапах. Есть возможность отправки на почту результатов                                                               |
| upgrade_start.sh       | запуск контейнера pgupgrade для мажорного обновления кластера                                                                                                      |

# Контейнер docker-postgres
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

## Старт контейнера

Контейнер рассчитан на 2 режима начального старта:

* Старт с пустым каталогом данных

При запуске контейнера с пустым каталогом данных выполняется его инициализация через вызов `initdb` и созданием шаблонной БД `template_extension`. Из-за особенностей старта официального образа при такой инициализации не выполняется создание расширений `pg_cron` и `ispell_shared`, а также не выполняется настройка конфигураций полнотекстового поиска.
Поэтому после такого первого старта очень желательно выполнить запуск скрипта обновления БД кластера через команду:

```
$ docker exec temp_postgres_1 update-extension.sh <доп.БД>
```

где имя `temp_postgres_1` - имя запущенного postgres-контейнера. В выводе команды docker ps это колонка `NAMES`.

<доп.БД> - можно передать имя пользовательской БД которую необходимо "дотянуть" до стандарта по расширениям и настройкам текущего контейнера. БД должна быть уже создана.

Если же в настройках docker-compose файла указать:

```
command: |
      -c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
```

то проблему 1-го старта с последующей донастройкой можно избежать. Однако надо помнить, что указание такой строки в качестве параметра старта службы не позволит изменить эти значение через файл настроек.

* Старт с уже инициализированным каталогом

Когда контейнер запускается с уже присоединённым каталогом кластера БД, то никаких внутренних скриптов инициализации не применяется. Однако, если есть желание "дотянуть" до стандарта по расширениям и настройкам текущего контейнера, то необходимо иметь ввиду, что для полноценной работы внутренних скриптов необходимо в настройках кластера загружать следующие shared библиотеки:

```
shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
```

а также в файле настроек указать параметр: 
```
shared_ispell.max_size=70MB
```

Чтобы "дотянуть" БД до стандарта по расширениям и настройкам текущего контейнера выполните вызов скрипта: `update-extension.sh` как описано чуть выше.

В кластере БД, созданном с нуля, `pg_hba.conf` и `pg_ident.conf` имеют значения, рассчитанные на вход по паролю (на это оказывает влияние параметр POSTGRES_HOST_AUTH_METHOD), а `postgresql.conf` оптимизирован под 512 MБ ОЗУ и SSD диски. При необходимости, после первичной инициализации уточните параметры конфигурации.

## Пользовательская БД

Чтобы создать свою БД, рекомендуется использовать шаблон `template_extension`:

```
CREATE DATABASE my_db WITH TEMPLATE template_extension;
```

В созданной таким образом БД настроены все необходимые расширения и создана схема с именем `dbo` как схема для пользовательских таблиц.
Однако права и пути поиска нельзя перенести таким образом, поэтому для дотягивания БД до стандартов контейнера нужно выполнить скрипт: `update-extension.sh` как описано чуть выше и передать как параметр этому скрипту имя созданной БД.

```
$ docker exec temp_postgres_1 update-extension.sh my_db
```

Путь поиска после выполнения скрипта в указанной БД выглядит так: `search_path = dbo, public, tiger;`

## Работа с бэкапами

Контейнер рассчитан на работу с утилитой бэкапирования `pg_probackup` от компании Postgres Professional. В настройках `archive_command` и `restore_command` написана bash команда для вызова архивации/восстановления WAL файлов:

```
archive_command:
if [ -f archive_pause.trigger ]; then exit 1; else if [ -f archive_active.trigger ]; then pg_probackup-15 archive-push -B /mnt/pgbak --instance 15 --wal-file-path %p --wal-file-name %f -j 4 --batch-size=50; else exit 0; fi; fi

restore_command:
if [ -f archive_active.trigger ]; then pg_probackup-15 archive-get -B /mnt/pgbak --instance 15 --wal-file-path %p --wal-file-name %f; else exit 0; fi
```

Чтобы WAL файлы начали сохраняться, нужно в каталоге данных создать файл с именем: `archive_active.trigger` (автоматически создаётся при первом вызове `backup.sh`)
При его наличии каждый WAL файл сохраняется в бэкап-каталог. 

> При его отсутствии WAL файлы не сохраняются!

Чтобы временно приостановить выгрузку WAL файлов в бэкап-каталог нужно создать файл: `archive_pause.trigger` (это может понадобиться для временных работ с бэкапным каталогом).

В контейнере есть 2 дополнительных скрипта:

`backup.sh` - создаёт новый бэкап

`show.sh` - показывает какие бэкапы есть

Для запуска можно использовать команды:

```
$ docker exec temp_postgres_1 backup.sh
$ docker exec temp_postgres_1 show.sh
```

Скрипт `backup.sh` может принимать до 3-х параметров:

```
$1 - указывает режим создания инкрементального бэкапа: delta (по умолчанию) или page или full
$2 - признак создания автономного бэкапа типа stream: yes или stream (по умолчанию) или любой другой текст для варианта "archive"
$3 - количество потоков для выполнения бэкапа: 4 (по умолчанию) или указанное число
```

Скрипт `show.sh` может принимать до 2-х параметров:

```
$1 - yes/no (по умолчанию yes) нужно ли отсылать письмо с отчетом по текущим бэкапам
$2 - список email получателей письма (через пробел и обрамить двойными кавычками)
```

## Переменные окружения контейнера

Часть переменных имеет значения по умолчанию, это значит, что если их не указывать при старте контейнера, то они имеют указанные значения.

_Переменные использующиеся только при первичной инициализации:_

| Name                      | Default value                        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| POSTGRES_INITDB_ARGS      | --locale=ru_RU.UTF8 --data-checksums | Эту необязательную переменную среды можно использовать для отправки аргументов в postgres initdb. Значение представляет собой строку аргументов, разделенных пробелами, как того и ожидает postgres initdb.                                                                                                                                                                                                                                                                                                    |
| POSTGRES_HOST_AUTH_METHOD | md5                                  | Эту необязательную переменную можно использовать для управления методом аутентификации для соединений с хостом для всех баз данных, всех пользователей и всех адресов. Это значение используется только на этапе первичной инициализации.                                                                                                                                                                                                                                                                      |
| PGDATA                    | /var/lib/postgresql/data             | Эту необязательную переменную можно использовать для определения другого местоположения - например, подкаталога - для файлов базы данных. По умолчанию это /var/lib/postgresql/data. Если используемый вами том данных является точкой монтирования файловой системы (например, с постоянными дисками GCE) или удаленной папкой, которая не может быть подключена для пользователя postgres (например, некоторые точки монтирования в NFS), Postgres initdb рекомендует создать подкаталог для хранения данных |
| POSTGRES_INITDB_WALDIR    | PGDATA/pg_wal                        | Эту необязательную переменную среды можно использовать для определения другого места для журнала транзакций Postgres. Иногда может быть желательно хранить журнал транзакций в другом каталоге, который может поддерживаться хранилищем с другими характеристиками производительности или надежности.                                                                                                                                                                                                          |
| APP_DB                    |                                      | Эту необязательную переменную среды можно использовать для определения имени БД которую нужно создать сразу при старте контейнера. БД будет создана только если кластер БД не существует. БД создается также как если вручную создать БД на основе шаблонной БД template_extension и по ней пргонать скрипт update-extension.sh                                                                                                                                                                                |

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

В конфигурационном файле postgresql.conf есть параметр, в котором указывается значение указанное из переменной окружения EMAIL_SERVER. 
Значение переносится в файл во время первичной иннициализации кластера или же при вызове скрипта обновления update-extension.sh
Например:
adm.email_smtp_server = 'mail.company.ru'

Это значение используется функцией отправки почты: util.send_email()

_Переменные влияющие на работу скриптов по бэкапам:_

| Name           | Default value | Description                                                                                                             |
| -------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------- |
| BACKUP_MODE    | delta         | Режим инкрементального бэкапа. Альтернативное значение page                                                             |
| BACKUP_PATH    | /mnt/pgbak    | Каталог используемый утилитой pg_probackup для хранения всех бэкапов                                                    |
| BACKUP_THREADS | 4             | На сколько потоков можно параллелить бэкап/рестор процесс                                                               |
| BACKUP_STREAM  | yes           | `yes` - создавать автономные резервные копии. `no` - создавать резервные копии для которых обязательно нужны WAL файлы. |

## Предустановленные роли

_Контейнер поддерживает следующие предустановленные роли (используйте скрипт update-extension.sh)_

| роль                 | описание                                                                                      | параметры                                                                |
| -------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| mamonsu              | специализированная роль для активного агента mamonsu                                          | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION          |
| deploy               | роль владелец для всех новых БД и их объектов                                                 | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD |
| replicator           | роль для использования с логической и потоковой репликацией                                   | LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION          |
| readonly_group       | роль-группа выдающая права на чтение таблиц, использование последовательностей и типов        | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| write_group          | роль-группа выдающая права на чтение/запись таблиц, последовательностей и использование типов | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| execution_group      | роль-группа выдающая права на запуск всех функций и процедур                                  | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| read_procedure_group | роль-группа выдающая права на чтение текста процедур/функций                                  | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |
| monitoring_group     | роль-группа выдающая права на обращение к статистическим функциям, таблицам, представлениям   | NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION                |

## Каталоги для маппинга

_Контейнер ожидает следующие примапленные каталоги_

| Name                               | Description                       |
| ---------------------------------- | --------------------------------- |
| /var/lib/postgresql/data           | каталог с данными кластера        |
| /var/log/postgresql                | каталог с файлами логов           |
| /mnt/pgbak                         | каталог для бэкапов кластера      |
| /usr/share/postgresql/tsearch_data | каталог хранения словарей для FTS |

> Обратите внимание, что на подключаемые каталоги нужно заранее выдать права на запись пользователю с uid=999 (код пользователя postgres внутри контейнера)
## Пример старта контейнера через docker run

запуск без примапленных каталогов. Всё данные кластера будут храниться внутри докер контейнера. В данном примере postgres мапится на порт 5433.

```	
docker run -d --name dev-db -p 5433:5432/tcp --shm-size 2147483648 \
           -e POSTGRES_PASSWORD=qweasdzxc \
           -e POSTGRES_HOST_AUTH_METHOD=trust \
           -e DEPLOY_PASSWORD=cxzdsaewq \
           -e TZ="Etc/UTC" \
           grufos/postgres:15.2 \
           -c shared_preload_libraries="plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" \
           -c shared_ispell.max_size=70MB
```

запуск с указанием примапленных каталогов. Все данные кластера будут храниться вне контейнера в каталоге `/var/lib/pgsql/15/data`, а логи в каталоге `/var/log/postgresql`

```	
docker run -d --name dev-db -p 5433:5432/tcp --shm-size 2147483648 \
       -e POSTGRES_PASSWORD=qweasdzxc \
       -e POSTGRES_HOST_AUTH_METHOD=trust \
       -e DEPLOY_PASSWORD=cxzdsaewq \
       -e TZ="Etc/UTC" \
       -v "/var/lib/pgsql/15/data:/var/lib/postgresql/data" \
       -v "/var/log/postgresql:/var/log/postgresql" \
       -v "/mnt/pgbak2:/mnt/pgbak" \
       -v "/usr/share/postgres/tsearch_data:/usr/share/postgresql/tsearch_data" \
       grufos/postgres:15.2 \
       -c shared_preload_libraries="plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm" \
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

## Пример docker-compose файла

Создаём файл postgres-service.yml

```
version: '3.5'
services:
 
  postgres:

#    image: grufos/postgres:15.2
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
    volumes:
      - "/var/lib/pgsql/15_1/data:/var/lib/postgresql/data"
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

#    image: grufos/postgres:15.2
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'
      -c shared_ispell.max_size=70MB
    volumes:
      - "/var/lib/pgsql/15_1/data:/var/lib/postgresql/data"
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
#    image: grufos/mamonsu:15_3.5.2
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
      ZABBIX_SERVER_IP: name.server.ru
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

## Подсказки

Как запустить контейнер в tmpfs - https://stackoverflow.com/questions/42226418/how-to-move-postresql-to-ram-disk-in-docker

# Контейнер docker-pgupgrade

Контейнер предназначен для выполнения мажорного обновления Postgres. Для каждой версии существует своя редакция такого контейнера. Контейнер в каталоге 15-й версии выполняет обновление с 14-й версии на 15-ю версию. Необходимость разработки такого контейнера обусловлена тем, что в моих контейнерах используется много разных расширений и многие из них должны быть предварительно загружены в виде библиотек. В противном случае утилита pg_upgrade выдаст сообщение о несовместимости кластеров. 

Внимание:
- для корректной работы рекомендуется все же небольшое количество HugePages иметь доступными. Рекомендуется 150 страниц иметь свободными в запасе.

Файлы контейнера:
```
Dockerfile - скрипт создания контейнера
upgrade.sh - основной скрипт выполняющий всю процедуру мажорного обновления
pg_hba.conf     - файл доступов к серверу
pg_ident.conf   - файл маппинга пользователей
postgresql.conf - настройки postgres текущей версии 
```
Файлы конфигураций используются те же, что и в контейнере Postgres текущей версии. Дополнительно в процессе обновления часть настроек берётся из предыдущей обновляемой версии. Это необходимо делать, так как некоторые настройки могут быть критичными для работы контура и зависящие от параметров железа на котором мы работаем. На сейчас выполняется перенос следующих параметров:

- max_connections
- shared_buffers
- huge_pages
- work_mem
- timezone
- wal_level
- effective_cache_size
- maintenance_work_mem
- autovacuum_work_mem
- max_prepared_transactions
- logical_decoding_work_mem
- max_worker_processes
- max_parallel_maintenance_workers
- max_parallel_workers_per_gather
- max_parallel_workers
- cron.timezone


## Каталоги для маппинга
далее по тексту будет использование указание в виде:
`PREV` - номер версии текущей обновляемой версии Postgres, к примеру 14
`NEW` - номер версии новой версии Postgres, к примеру 15

_Контейнер ожидает следующие примапленные каталоги_

| Name                                      | Description                                                       |
| ----------------------------------------- | ----------------------------------------------------------------- |
| /var/lib/postgresql/                      | каталог с данными кластеров.                                      |
| /var/log/postgresql                       | каталог с файлами логов                                           |
| /usr/share/postgresql/PREV/tsearch_data | каталог хранения словарей для FTS обновляемой версии              |
| /usr/share/postgresql/NEW/tsearch_data  | каталог хранения словарей для FTS новой версии (должен быть пуст) |

Подробности по каталогу данных контейнера `/var/lib/postgresql/`:
Внутри ожидается следующая структура каталогов:
```
PREV/data - каталог с данными для обновляемой версии
NEW/data - каталог с данными для новой версии. Важно, этот каталог должен быть пуст на момент старта контейнера
```
Итак, получается, что когда мы мапим каталог верхнего уровня в контейнер:
```
-v /mnt/bigdrive/postgresql:/var/lib/postgresql/
```
То, контейнер ожидает, что данные обновляемого кластера находятся по пути: `/mnt/bigdrive/postgresql/PREV/data`.
Данные нового кластера будут созданы по пути: `/mnt/bigdrive/postgresql/NEW/data`.
При таком варианте маппинга контейнер может реализовать поддержку опции `--link`

Если по каким-то причинам нет возможности в таком маппинге каталогов, то можно использовать и вот такой подход:

| Name                            | Description                             |
| ------------------------------- | --------------------------------------- |
| /var/lib/postgresql/PREV/data | каталог с данными обновляемого кластера |
| /var/lib/postgresql/NEW/data  | каталог с данными нового кластера       |

как пример:
```
-v /mnt/bigdrive/postgresql-14/data:/var/lib/postgresql/14/data\
-v /mnt/bigdrive/postgresql-15/data:/var/lib/postgresql/15/data\
```

Внимание: каталог для новой версии кластера (`/mnt/bigdrive/postgresql-15`) должен быть пустым!

В этом случае предполагается, что данные нового кластера находятся на другом физическом устройстве, поэтому возможности использовать опцию `--link` не будет.

Опция `--link` позволяет создать физические ссылки на файлы и таким образом избежать их копирования. Это позволяет очень сильно сократить время выполнения обновления.

Контейнер выполняет простейшие проверки входных каталогов на предмет их ожидаемого содержимого.

В каталогах полнотекстового поиска не содержится никаких очень объемных данных, поэтому для них всегда используется обычное копирование файлов.
При старте контейнера в указанном каталоге полнотекстового поиска новой версии (должен быть пуст изначально) создаются все необходимые файлы новой версии и потом туда копируются только лишь пользовательские файлы синонимов (`*.syn`) и тезаурусов (`*.ths`)

Контейнер выполняет сначала проверку совместимости каталогов данных с новой версией и если всё в порядке выполняет обновление.

После выполнения обновления и старта нового контейнера postgres, необходимо выполнить команды:
```
vacuumdb --all --analyze-in-stages
```
Также рекомендуется сразу сделать полный бэкап кластера.

В зависимости от Release Notes могут потребоваться некие дополнительные работы над кластером.

Каталог данных старого кластера можно теперь удалить.

## Пример описания docker-compose файла для старта контейнера:
```
version: '3.5'
services:

  pgupgrade:

#    image: grufos/pgupgrade:15.2
    build:
      context: ./docker-pgupgrade
      dockerfile: Dockerfile
    stop_grace_period: 60s
    shm_size: '2gb'
    volumes:
      - "/var/lib/pgsql/15_1:/var/lib/postgresql"
      - "/var/log/postgresql1:/var/log/postgresql"
      - "/usr/share/postgres/14_1/tsearch_data:/usr/share/postgresql/14/tsearch_data"
      - "/usr/share/postgres/15_1/tsearch_data:/usr/share/postgresql/15/tsearch_data"
```

## Пример запуска контейнера через команду docker run
```	
docker run --rm --name upgrade-db --shm-size 2147483648 \
       -v "/var/lib/pgsql/15_1:/var/lib/postgresql" \
       -v "/var/log/postgresql1:/var/log/postgresql" \
       -v "/usr/share/postgres/14/tsearch_data:/usr/share/postgresql/14/tsearch_data" \
       -v "/usr/share/postgres/15/tsearch_data:/usr/share/postgresql/15/tsearch_data" \
       grufos/pgpostgres:15.2
#      15_pgupgrade
```
