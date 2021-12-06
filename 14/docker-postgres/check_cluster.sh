#!/bin/bash

# $1 - 'amcheck' Enable an additional cluster with an Amcheck extension
# $2 - 'heapallindexed' It will be additionally verified that in the index, all the cortices of the heaps that should get into it

if [ "$EMAILTO" = "" ]; then
    EMAILTO="DBA-PostgreSQL@interfax.ru"
fi

if [ "$EMAIL_SERVER" = "" ]; then
    EMAIL_SERVER=extra.devel.ifx
fi

if [ "$EMAIL_HOSTNAME" = "" ]; then
    EMAIL_HOSTNAME=`hostname`
    EMAIL_HOSTNAME="noreplay@${EMAIL_HOSTNAME}.ru"
fi

if [ "$EMAIL_SEND" = "" ]; then
    EMAIL_SEND="yes"
fi

if [ "$BACKUP_THREADS" = "" ]; then
    BACKUP_THREADS=4
fi

if [ "$BACKUP_PATH" = "" ]; then
    BACKUP_PATH="/mnt/pgbak"
fi

if [ "$PGUSER" = "" ]; then
    PGUSER=postgres
fi

if [ "$AMCHECK" = "" ]; then
    AMCHECK="false"
fi

if [ "$HEAPALLINDEXED" = "" ]; then
    HEAPALLINDEXED="false"
fi

if [ "$1" = "amcheck" ]; then
    AMCHECK="true"
fi

if [ "$2" = "heapallindexed" ]; then
    HEAPALLINDEXED="true"
fi

function send_email()
{
    # отправляем письмо о ошибочном выполнении скрипта, в параметре $1 указывается поясняющий текст, а в $2 заголовок письма
    echo "$2"
    echo "$1"
    cat $REPORT_PATH/${curr_date}_checkdb_result.txt
    # send mail to DBA
    if [ "$EMAIL_SEND" = "yes" ]; then
       (echo "<html><pre> $1 <br>" ; cat $REPORT_PATH/${curr_date}_checkdb_result.txt ; echo '</pre></html>';) | sendEmail -o message-content-type=html -o message-charset=utf-8 -f "$EMAIL_HOSTNAME" -t $EMAILTO -s $EMAIL_SERVER -u "$2"
    fi
}

# check paths...
PGLOG=/var/log/postgresql
SCRIPT_PATH=/var/lib/postgresql
REPORT_PATH=$PGLOG/report

su - postgres -c "mkdir -p $REPORT_PATH"

cd $REPORT_PATH

curr_date=`eval date +%F`
su - postgres -c "echo `date +%T` 'Старт checkdb проверки' > $REPORT_PATH/${curr_date}_checkdb_result.txt"

# дополнительные опции проверки
ADDOPTIONS=""
if [ $AMCHECK = "true" ] ; then
    ADDOPTIONS="--amcheck"
fi
if [ $HEAPALLINDEXED = "true" ] ; then
    ADDOPTIONS="--amcheck --heapallindexed"
fi
echo "Режим проверки: checkdb $ADDOPTIONS" >> $REPORT_PATH/${curr_date}_checkdb_result.txt
su - postgres -c "/usr/bin/pg_probackup-$PG_MAJOR checkdb $ADDOPTIONS --threads=$BACKUP_THREADS -B $BACKUP_PATH --instance=$PG_MAJOR -D $PGDATA -d postgres -w -h ${PGHOST:-127.0.0.1} -p ${PGPORT:-5432} >> $REPORT_PATH/${curr_date}_checkdb_result.txt 2>&1"

#########

echo `date +%T` 'Проверка checkdb завершена' >> $REPORT_PATH/${curr_date}_checkdb_result.txt

# проверяем наличие файла результатов проверки checkdb

# выполняем проверки лога checkdb
if grep -e "invalid file size" $REPORT_PATH/${curr_date}_checkdb_result.txt; then
    # если есть сообщение "invalid file size" - прерываем скрипт, как минимум один файл имеет некорректный размер
    send_email "обнаружен поврежденный файл с некорректным размером!" "Check cluster - Failed"
    exit 1
fi

if grep -e "page verification failed" $REPORT_PATH/${curr_date}_checkdb_result.txt; then
    # если есть сообщение "page verification failed" - прерываем скрипт, как минимум один файл имеет некорректную чексумму
    send_email "обнаружен поврежденный файл с некорректной чексуммой!" "Check cluster - Failed"
    exit 1
fi

# формируем счетчики ошибок которые можно игнорировать (не B-Tree индексы, итоговое сообщение об ошибке из-за этих индексов) (возможно потом нужно будет дополнить)
# считаем количество ошибок из-за не B-Tree индексов
ERROR_NOT_BTREE_INDEX=$(grep -i -e "Amcheck failed.*ERROR.*only B-Tree indexes" $REPORT_PATH/${curr_date}_checkdb_result.txt | wc -l)

# считаем финальное сообщение об ошибке из-за невалидности индексов (может указывать на наличие не B-Tree индексов)
ERROR_FINAL_VALID_INDEX_CHECK=$(grep -i -e "ERROR.*Not all checked indexes are valid" $REPORT_PATH/${curr_date}_checkdb_result.txt | wc -l)

# сообщение об ошибке которое бывает при проверке через --amcheck
ERROR_FINAL_AMCHECK=$(grep -i -e "ERROR: Some databases were not amchecked." $REPORT_PATH/${curr_date}_checkdb_result.txt | wc -l)

# суммируем ошибки которые можно игнорировать
ERROR_FOR_IGNOR=$(($ERROR_NOT_BTREE_INDEX + $ERROR_FINAL_VALID_INDEX_CHECK + $ERROR_FINAL_AMCHECK))

# формируем общий счетчик всех ошибок в логе checkdb
ERROR_ALL=$(grep -i -e "ERROR" $REPORT_PATH/${curr_date}_checkdb_result.txt | wc -l)

if (($ERROR_ALL > $ERROR_FOR_IGNOR)); then
    # общее число ERROR больше чем тех что можно игнорировать, значит checkdb выявил проблемы, прерываем работу скрипта
    send_email "Выявлены проблемы при проверке целостности бд, необходим анализ причины!" "Check cluster - Failed"
    exit 1
fi

########

# send mail to DBA
send_email "Результаты проверки кластера:" "Check cluster - OK"
