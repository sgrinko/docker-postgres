#!/bin/bash


# Set variable

HOMEDIR=/var/lib/postgresql
OLD_VERSION=$PG_MAJOR_OLD
NEW_VERSION=$PG_MAJOR
OLD_CONF_FILE=$PGDATAOLD
NEW_CONF_FILE=$PGDATANEW
OLD_BIN=$PGBINOLD/
NEW_BIN=$PGBINNEW/
OLD_DB=$PGDATAOLD
NEW_DB=$PGDATANEW
OLD_PGLOG=/var/log/postgresql
NEW_PGLOG=/var/log/postgresql
OLD_TSEARCH=$TSEARCHDATAOLD
NEW_TSEARCH=$TSEARCHDATANEW

function parameter_copy()
{
    # $1 - имя параметра для копирования из старого конфига в новый
    OLD_PARAM=`grep "^$1 = " $OLD_CONF_FILE/postgresql.conf | awk -F= '{print $2}' | awk '{print $1}'`
    NEW_PARAM=`grep "^$1 = " $NEW_CONF_FILE/postgresql.conf | awk -F= '{print $2}' | awk '{print $1}'`
    if [ "$OLD_PARAM" != "" ]; then
        # для случая когда в тексте значения параметра есть символ / то экранируем его
        OLD_PARAM_R=${OLD_PARAM/'/'/'\/'}
        NEW_PARAM_R=${NEW_PARAM/'/'/'\/'}
        sed -i.bak "s/$1 = ${NEW_PARAM_R}/$1 = ${OLD_PARAM_R}/g" $NEW_CONF_FILE/postgresql.conf > /dev/null
        echo "Копируем параметр $1 = $OLD_PARAM"
    fi
}

if [ "$(id -u)" = '0' ]; then
    # запуск от root... исправляем права доступа и перезапускаемся как postgres
    mkdir -p "$PGDATAOLD" "$PGDATANEW" $TSEARCHDATANEW
    chmod 700 "$PGDATAOLD" "$PGDATANEW" $TSEARCHDATANEW
    chown postgres .
    chown -R postgres "$PGDATAOLD" "$PGDATANEW" $TSEARCHDATANEW
    exec gosu postgres "$BASH_SOURCE" "$@"
fi

# тестируем возможность работы с hard link на подключенных томах
LINK_OPTIONS="--link"
if ! ln "$PGDATAOLD/global/1213" "$PGDATANEW/1213" > /dev/null 2>&1 ; then
    # нет возможности делать HardLink между томами, поэтому опцию --link отключаем
    LINK_OPTIONS=""
else
    rm -f "$PGDATANEW/1213"
fi

if [ ! -s "$PGDATANEW/PG_VERSION" ]; then
    # если каталог новой версии ещё не подготовлен, то создаём его
    echo "------------"
    echo "-- initdb --"
    echo "------------"
    PGDATA="$PGDATANEW" eval "initdb $POSTGRES_INITDB_ARGS"
    cp -f /usr/local/bin/postgresql.conf $PGDATANEW
    cp -f /usr/local/bin/pg_ident.conf $PGDATANEW
    cp -f /usr/local/bin/pg_hba.conf $PGDATANEW
    # создаём начальную версию каталога FTS
    tar -xzkf /usr/share/postgresql/$PG_MAJOR/tsearch_data.tar.gz -C /usr/share/postgresql/tsearch_data/ > /dev/null 2>&1
fi

echo
echo "-- =================== версии для обновления =================== --"
echo "Старая: $PG_MAJOR_OLD"
echo "Новая:  $PG_MAJOR"
echo '-- ============================================================= --'
echo
echo "-- ================= файлы конфигурации ======================== --"
echo "Старый: $OLD_CONF_FILE/postgresql.conf"
echo "Новый:  $NEW_CONF_FILE/postgresql.conf"
echo '-- ============================================================= --'
echo
echo "-- ================= каталоги кластеров ======================== --"
echo "Старый: $OLD_DB"
echo "Новый:  $NEW_DB"
echo '-- ============================================================= --'
echo
echo '-- ============================================================= --'
if [ "$LINK_OPTIONS" = "" ] ; then
echo '--             Режим полного копирования кластера!               --'
echo '--                    HardLink недоступен!                       --'
else
echo '--                      HardLink включен                         --'
fi
echo '-- ============================================================= --'
echo
echo '-- ============================================================= --'
echo '--                       CHECK upgrade                           --'
echo '-- ============================================================= --'

cd $HOMEDIR

echo "Время старта проверки кластера на совместимость ..." > $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
date >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt

# для нового сервера берём некоторые параметры такие же как и у прежнего
parameter_copy "max_connections"
parameter_copy "shared_buffers"
parameter_copy "huge_pages"
parameter_copy "work_mem"
parameter_copy "timezone"
parameter_copy "wal_level"
parameter_copy "effective_cache_size"
parameter_copy "maintenance_work_mem"
parameter_copy "autovacuum_work_mem"
parameter_copy "max_worker_processes"
parameter_copy "max_parallel_maintenance_workers"
parameter_copy "max_parallel_workers_per_gather"
parameter_copy "max_parallel_workers"

echo
echo 'старт check...'
echo
if ! ${NEW_BIN}pg_upgrade --check $LINK_OPTIONS --jobs=4 -d ${OLD_DB} -D ${NEW_DB} -b ${OLD_BIN} -B ${NEW_BIN} \
						-o "-c shared_buffers=100MB" \
						-o "-c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'" \
						-o "-c shared_ispell.max_size=70MB" \
						-o "-c huge_pages=off" \
						-o "-c config_file=$OLD_CONF_FILE/postgresql.conf" \
						-O "-c shared_buffers=100MB" \
						-O "-c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'" \
						-O "-c shared_ispell.max_size=70MB" \
						-O "-c huge_pages=off" \
						-O "-c config_file=$NEW_CONF_FILE/postgresql.conf" \
						-O "-c log_directory=$NEW_PGLOG" \
						-O "-c log_filename=pg_upgrade.log"; then

    echo
    echo '-- ============================================================= --'
    echo '--    ! Проверка на совместимость кластеров не выполнена !       --'
    echo '-- ============================================================= --'
    echo

    exit 1
fi

echo
echo '-- ============================================================= --'
echo '--                       Process upgrade!                        --'
echo '-- ============================================================= --'
echo

echo "" >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
echo "Время старта операции upgrade кластера ..." >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
date >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt

echo
echo "копируем из исходного сервера в новый сервер файл конфигурации pg_hba.conf"
echo
cp -f $OLD_CONF_FILE/pg_hba.conf $NEW_CONF_FILE/pg_hba.conf

echo
echo "копируем из исходного сервера в новый сервер файл конфигурации pg_ident.conf"
echo
cp -f $OLD_CONF_FILE/pg_ident.conf $NEW_CONF_FILE/pg_ident.conf

echo
echo "копируем из исходного сервера в новый сервер все кастомные определения синонимов и тезаурусов"
echo
cd ${OLD_TSEARCH}
# копируем из исходного сервера в новый сервер все кастомные определения синонимов
for fts in $(ls *.syn)
do
  if [ "${fts}" != "synonym_sample.syn" ] ; then
    cp -f "${OLD_TSEARCH}/${fts}" "${NEW_TSEARCH}/${fts}"
    chmod 0644 "${NEW_TSEARCH}/${fts}"
    echo "cp -f \"${OLD_TSEARCH}/${fts}\" \"${NEW_TSEARCH}/${fts}\"" >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
  fi
done
# копируем из исходного сервера в новый сервер все кастомные определения тезаурусов
for fts in $(ls *.ths)
do
  if [ "${fts}" != "thesaurus_sample.ths" ] ; then
    cp -f "${OLD_TSEARCH}/${fts}" "${NEW_TSEARCH}/${fts}"
    chmod 0644 "${NEW_TSEARCH}/${fts}"
    echo "cp -f \"${OLD_TSEARCH}/${fts}\" \"${NEW_TSEARCH}/${fts}\"" >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
  fi
done

cd $HOMEDIR

echo
echo 'старт upgrade...'
echo

if ! ${NEW_BIN}pg_upgrade $LINK_OPTIONS --jobs=4 -d ${OLD_DB} -D ${NEW_DB} -b ${OLD_BIN} -B ${NEW_BIN} \
						-o "-c shared_buffers=100MB" \
						-o "-c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'" \
						-o "-c shared_ispell.max_size=70MB" \
						-o "-c huge_pages=off" \
						-o "-c config_file=$OLD_CONF_FILE/postgresql.conf" \
						-O "-c shared_buffers=100MB" \
						-O "-c shared_preload_libraries='plugin_debugger,plpgsql_check,pg_stat_statements,auto_explain,pg_buffercache,pg_cron,shared_ispell,pg_prewarm'" \
						-O "-c shared_ispell.max_size=70MB" \
						-O "-c huge_pages=off" \
						-O "-c config_file=$NEW_CONF_FILE/postgresql.conf" \
						-O "-c log_directory=$NEW_PGLOG" \
						-O "-c log_filename=pg_upgrade.log"; then
    # восстанавливаем pg_control файл для прежнего сервера.
    if [ -f ${OLD_DB}/global/pg_control.old ] ; then
        echo
        echo "Файл pg_control был восстановлен на старом сервере"
        mv ${OLD_DB}/global/pg_control.old  ${OLD_DB}/global/pg_control
    fi

    echo "Ошибки при мажорном обновлении"
    exit 1
fi

echo "" >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
echo "Время завершения upgrade кластера ..." >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt
date >> $NEW_PGLOG/upgrade_to_${NEW_VERSION}.txt

echo "==========================================="
echo "Мажорное обновление выполнено успешно."
echo "Данные старого сервера могут быть удалены."
echo "==========================================="

