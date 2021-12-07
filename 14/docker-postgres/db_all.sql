--
-- код для всех БД
--
SET default_transaction_read_only = off;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- создаём объекты для мониторинга
CREATE EXTENSION IF NOT EXISTS plpython3u;
-- Upgrade pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA public;
ALTER EXTENSION pg_stat_statements UPDATE;
--
CREATE SCHEMA IF NOT EXISTS util;
COMMENT ON SCHEMA util IS 'Схема для хранения различных функций и представлений общего назначения';
--
CREATE OR REPLACE FUNCTION util.replace_char_xml(p_str2xml text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE COST 10.0
    AS $$
	select replace(replace(replace(replace(replace(p_str2xml,'&','&#38;'),'''','&#39;'),'"','&#34;'),'<','&lt;'),'>','&gt;');
$$;
--
select current_setting('server_version_num')::integer >= 130000 as postgres_pgvers_13plus \gset
select current_setting('server_version_num')::integer >= 140000 as postgres_pgvers_14plus \gset
--
\if :postgres_pgvers_13plus
  CREATE OR REPLACE VIEW public.vw_who AS
      SELECT pa.pid,
      pg_blocking_pids(pa.pid) AS blocked_by,
      pa.leader_pid,
      pa.state,
      now() - pa.xact_start AS ts_age,
      clock_timestamp() - pa.xact_start AS xact_age,
      clock_timestamp() - pa.query_start AS query_age,
      clock_timestamp() - pa.state_change AS change_age,
      pa.datname,
      pa.usename,
      pa.wait_event_type,
      pa.wait_event,
      pa.client_addr,
      pa.client_port,
      pa.application_name,
      pa.backend_type,
      pa.query
  FROM pg_stat_activity pa
  WHERE pa.pid <> pg_backend_pid()
  ORDER BY pa.datname, pa.state, pa.xact_start, pa.leader_pid NULLS FIRST;
--
\if :postgres_pgvers_14plus
  CREATE OR REPLACE VIEW public.vw_who_tree AS
    WITH RECURSIVE activity AS (
          SELECT pg_blocking_pids(pg_stat_activity.pid) AS blocked_by,
              pg_stat_activity.datid,
              pg_stat_activity.datname,
              pg_stat_activity.pid,
              pg_stat_activity.leader_pid,
              pg_stat_activity.usesysid,
              pg_stat_activity.usename,
              pg_stat_activity.application_name,
              pg_stat_activity.client_addr,
              pg_stat_activity.client_hostname,
              pg_stat_activity.client_port,
              pg_stat_activity.backend_start,
              pg_stat_activity.xact_start,
              pg_stat_activity.query_start,
              pg_stat_activity.state_change,
              pg_stat_activity.wait_event_type,
              pg_stat_activity.wait_event,
              pg_stat_activity.state,
              pg_stat_activity.backend_xid,
              pg_stat_activity.backend_xmin,
              pg_stat_activity.query_id,
              pg_stat_activity.query,
              pg_stat_activity.backend_type,
              age(clock_timestamp(), pg_stat_activity.xact_start)::interval(0) AS tx_age,
              age(clock_timestamp(), pg_stat_activity.state_change)::interval(0) AS state_age
            FROM pg_stat_activity
            WHERE pg_stat_activity.state IS DISTINCT FROM 'idle'::text
          ), blockers AS (
          SELECT array_agg(DISTINCT dt.c ORDER BY dt.c) AS pids
            FROM ( SELECT unnest(activity.blocked_by) AS unnest
                    FROM activity) dt(c)
          ), tree AS (
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.leader_pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query_id,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              1 AS level,
              activity.pid AS top_blocker_pid,
              ARRAY[activity.pid] AS path,
              ARRAY[activity.pid] AS all_blockers_above
            FROM activity,
              blockers
            WHERE ARRAY[activity.pid] <@ blockers.pids AND activity.blocked_by = '{}'::integer[]
          UNION ALL
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.leader_pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query_id,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              tree_1.level + 1 AS level,
              tree_1.top_blocker_pid,
              tree_1.path || ARRAY[activity.pid] AS path,
              tree_1.all_blockers_above || array_agg(activity.pid) OVER () AS all_blockers_above
            FROM activity,
              tree tree_1
            WHERE NOT ARRAY[activity.pid] <@ tree_1.all_blockers_above AND activity.blocked_by <> '{}'::integer[] AND activity.blocked_by <@ tree_1.all_blockers_above
          )
  SELECT tree.pid,
      tree.blocked_by,
      tree.tx_age,
      tree.state_age,
      tree.backend_xid AS xid,
      tree.backend_xmin AS xmin,
      replace(tree.state, 'idle in transaction'::text, 'idletx'::text) AS state,
      tree.datname,
      tree.usename,
      (tree.wait_event_type || ':'::text) || tree.wait_event AS wait,
      ( SELECT count(DISTINCT t1.pid) AS count
            FROM tree t1
            WHERE ARRAY[tree.pid] <@ t1.path AND t1.pid <> tree.pid) AS blkd,
      format('%s %s%s'::text, lpad(('['::text || tree.pid::text) || ']'::text, 7, ' '::text), repeat('.'::text, tree.level - 1) ||
          CASE
              WHEN tree.level > 1 THEN ' '::text
              ELSE NULL::text
          END, "left"(tree.query, 1000)) AS query
    FROM tree
    ORDER BY tree.top_blocker_pid, tree.level, tree.pid;    
\else
  CREATE OR REPLACE VIEW public.vw_who_tree AS
    WITH RECURSIVE activity AS (
          SELECT pg_blocking_pids(pg_stat_activity.pid) AS blocked_by,
              pg_stat_activity.datid,
              pg_stat_activity.datname,
              pg_stat_activity.pid,
              pg_stat_activity.leader_pid,
              pg_stat_activity.usesysid,
              pg_stat_activity.usename,
              pg_stat_activity.application_name,
              pg_stat_activity.client_addr,
              pg_stat_activity.client_hostname,
              pg_stat_activity.client_port,
              pg_stat_activity.backend_start,
              pg_stat_activity.xact_start,
              pg_stat_activity.query_start,
              pg_stat_activity.state_change,
              pg_stat_activity.wait_event_type,
              pg_stat_activity.wait_event,
              pg_stat_activity.state,
              pg_stat_activity.backend_xid,
              pg_stat_activity.backend_xmin,
              pg_stat_activity.query,
              pg_stat_activity.backend_type,
              age(clock_timestamp(), pg_stat_activity.xact_start)::interval(0) AS tx_age,
              age(clock_timestamp(), pg_stat_activity.state_change)::interval(0) AS state_age
            FROM pg_stat_activity
            WHERE pg_stat_activity.state IS DISTINCT FROM 'idle'::text
          ), blockers AS (
          SELECT array_agg(DISTINCT dt.c ORDER BY dt.c) AS pids
            FROM ( SELECT unnest(activity.blocked_by) AS unnest
                    FROM activity) dt(c)
          ), tree AS (
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.leader_pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              1 AS level,
              activity.pid AS top_blocker_pid,
              ARRAY[activity.pid] AS path,
              ARRAY[activity.pid] AS all_blockers_above
            FROM activity,
              blockers
            WHERE ARRAY[activity.pid] <@ blockers.pids AND activity.blocked_by = '{}'::integer[]
          UNION ALL
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.leader_pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              tree_1.level + 1 AS level,
              tree_1.top_blocker_pid,
              tree_1.path || ARRAY[activity.pid] AS path,
              tree_1.all_blockers_above || array_agg(activity.pid) OVER () AS all_blockers_above
            FROM activity,
              tree tree_1
            WHERE NOT ARRAY[activity.pid] <@ tree_1.all_blockers_above AND activity.blocked_by <> '{}'::integer[] AND activity.blocked_by <@ tree_1.all_blockers_above
          )
  SELECT tree.pid,
      tree.blocked_by,
      tree.tx_age,
      tree.state_age,
      tree.backend_xid AS xid,
      tree.backend_xmin AS xmin,
      replace(tree.state, 'idle in transaction'::text, 'idletx'::text) AS state,
      tree.datname,
      tree.usename,
      (tree.wait_event_type || ':'::text) || tree.wait_event AS wait,
      ( SELECT count(DISTINCT t1.pid) AS count
            FROM tree t1
            WHERE ARRAY[tree.pid] <@ t1.path AND t1.pid <> tree.pid) AS blkd,
      format('%s %s%s'::text, lpad(('['::text || tree.pid::text) || ']'::text, 7, ' '::text), repeat('.'::text, tree.level - 1) ||
          CASE
              WHEN tree.level > 1 THEN ' '::text
              ELSE NULL::text
          END, "left"(tree.query, 1000)) AS query
    FROM tree
    ORDER BY tree.top_blocker_pid, tree.level, tree.pid;    
\endif
\else
    CREATE OR REPLACE VIEW public.vw_who AS
        SELECT pa.pid,
        pg_blocking_pids(pa.pid) AS blocked_by,
        pa.state,
        now() - pa.xact_start AS ts_age,
        clock_timestamp() - pa.xact_start AS xact_age,
        clock_timestamp() - pa.query_start AS query_age,
        clock_timestamp() - pa.state_change AS change_age,
        pa.datname,
        pa.usename,
        pa.wait_event_type,
        pa.wait_event,
        pa.client_addr,
        pa.client_port,
        pa.application_name,
        pa.backend_type,
        pa.query
    FROM pg_stat_activity pa
    WHERE pa.pid <> pg_backend_pid()
    ORDER BY pa.datname, pa.state, pa.xact_start;
--
    WITH RECURSIVE activity AS (
          SELECT pg_blocking_pids(pg_stat_activity.pid) AS blocked_by,
              pg_stat_activity.datid,
              pg_stat_activity.datname,
              pg_stat_activity.pid,
              pg_stat_activity.usesysid,
              pg_stat_activity.usename,
              pg_stat_activity.application_name,
              pg_stat_activity.client_addr,
              pg_stat_activity.client_hostname,
              pg_stat_activity.client_port,
              pg_stat_activity.backend_start,
              pg_stat_activity.xact_start,
              pg_stat_activity.query_start,
              pg_stat_activity.state_change,
              pg_stat_activity.wait_event_type,
              pg_stat_activity.wait_event,
              pg_stat_activity.state,
              pg_stat_activity.backend_xid,
              pg_stat_activity.backend_xmin,
              pg_stat_activity.query,
              pg_stat_activity.backend_type,
              age(clock_timestamp(), pg_stat_activity.xact_start)::interval(0) AS tx_age,
              age(clock_timestamp(), pg_stat_activity.state_change)::interval(0) AS state_age
            FROM pg_stat_activity
            WHERE pg_stat_activity.state IS DISTINCT FROM 'idle'::text
          ), blockers AS (
          SELECT array_agg(DISTINCT dt.c ORDER BY dt.c) AS pids
            FROM ( SELECT unnest(activity.blocked_by) AS unnest
                    FROM activity) dt(c)
          ), tree AS (
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              1 AS level,
              activity.pid AS top_blocker_pid,
              ARRAY[activity.pid] AS path,
              ARRAY[activity.pid] AS all_blockers_above
            FROM activity,
              blockers
            WHERE ARRAY[activity.pid] <@ blockers.pids AND activity.blocked_by = '{}'::integer[]
          UNION ALL
          SELECT activity.blocked_by,
              activity.datid,
              activity.datname,
              activity.pid,
              activity.usesysid,
              activity.usename,
              activity.application_name,
              activity.client_addr,
              activity.client_hostname,
              activity.client_port,
              activity.backend_start,
              activity.xact_start,
              activity.query_start,
              activity.state_change,
              activity.wait_event_type,
              activity.wait_event,
              activity.state,
              activity.backend_xid,
              activity.backend_xmin,
              activity.query,
              activity.backend_type,
              activity.tx_age,
              activity.state_age,
              tree_1.level + 1 AS level,
              tree_1.top_blocker_pid,
              tree_1.path || ARRAY[activity.pid] AS path,
              tree_1.all_blockers_above || array_agg(activity.pid) OVER () AS all_blockers_above
            FROM activity,
              tree tree_1
            WHERE NOT ARRAY[activity.pid] <@ tree_1.all_blockers_above AND activity.blocked_by <> '{}'::integer[] AND activity.blocked_by <@ tree_1.all_blockers_above
          )
  SELECT tree.pid,
      tree.blocked_by,
      tree.tx_age,
      tree.state_age,
      tree.backend_xid AS xid,
      tree.backend_xmin AS xmin,
      replace(tree.state, 'idle in transaction'::text, 'idletx'::text) AS state,
      tree.datname,
      tree.usename,
      (tree.wait_event_type || ':'::text) || tree.wait_event AS wait,
      ( SELECT count(DISTINCT t1.pid) AS count
            FROM tree t1
            WHERE ARRAY[tree.pid] <@ t1.path AND t1.pid <> tree.pid) AS blkd,
      format('%s %s%s'::text, lpad(('['::text || tree.pid::text) || ']'::text, 7, ' '::text), repeat('.'::text, tree.level - 1) ||
          CASE
              WHEN tree.level > 1 THEN ' '::text
              ELSE NULL::text
          END, "left"(tree.query, 1000)) AS query
    FROM tree
    ORDER BY tree.top_blocker_pid, tree.level, tree.pid;    
\endif
--
CREATE OR REPLACE VIEW public.vw_locks AS
	SELECT pg_locks.pid,
    pg_locks.virtualtransaction AS vxid,
    pg_locks.locktype AS lock_type,
    pg_locks.mode AS lock_mode,
    pg_locks.granted,
        CASE
            WHEN pg_locks.virtualxid IS NOT NULL AND pg_locks.transactionid IS NOT NULL THEN (pg_locks.virtualxid || ' '::text) || pg_locks.transactionid
            WHEN pg_locks.virtualxid IS NOT NULL THEN pg_locks.virtualxid
            ELSE pg_locks.transactionid::text
        END AS xid_lock,
    pg_class.relname,
    pg_locks.page,
    pg_locks.tuple,
    pg_locks.classid,
    pg_locks.objid,
    pg_locks.objsubid
   FROM pg_locks
     LEFT JOIN pg_class ON pg_locks.relation = pg_class.oid
  WHERE pg_locks.pid <> pg_backend_pid() AND pg_locks.virtualtransaction IS DISTINCT FROM pg_locks.virtualxid
  ORDER BY pg_locks.pid, pg_locks.virtualtransaction, pg_locks.granted DESC, (
        CASE
            WHEN pg_locks.virtualxid IS NOT NULL AND pg_locks.transactionid IS NOT NULL THEN (pg_locks.virtualxid || ' '::text) || pg_locks.transactionid
            WHEN pg_locks.virtualxid IS NOT NULL THEN pg_locks.virtualxid
            ELSE pg_locks.transactionid::text
        END), pg_locks.locktype, pg_locks.mode, pg_class.relname;
--
CREATE OR REPLACE VIEW public.vw_partitions AS
 WITH RECURSIVE inheritance_tree AS (
         SELECT c_1.oid AS table_oid,
            n.nspname AS table_schema,
            c_1.relname AS table_name,
            NULL::name AS table_parent_schema,
            NULL::name AS table_parent_name,
            c_1.relispartition AS is_partition
           FROM pg_class c_1
             JOIN pg_namespace n ON n.oid = c_1.relnamespace
          WHERE c_1.relkind = 'p'::"char" AND c_1.relispartition = false
        UNION ALL
         SELECT inh.inhrelid AS table_oid,
            n.nspname AS table_schema,
            c_1.relname AS table_name,
            nn.nspname AS table_parent_schema,
            cc.relname AS table_parent_name,
            c_1.relispartition AS is_partition
           FROM inheritance_tree it_1
             JOIN pg_inherits inh ON inh.inhparent = it_1.table_oid
             JOIN pg_class c_1 ON inh.inhrelid = c_1.oid
             JOIN pg_namespace n ON n.oid = c_1.relnamespace
             JOIN pg_class cc ON it_1.table_oid = cc.oid
             JOIN pg_namespace nn ON nn.oid = cc.relnamespace
        )
 SELECT it.table_schema,
    it.table_name,
    c.reltuples,
    c.relpages,
        CASE p.partstrat
            WHEN 'l'::"char" THEN 'BY LIST'::text
            WHEN 'r'::"char" THEN 'BY RANGE'::text
            WHEN 'h'::"char" THEN 'BY HASH'::text
            ELSE 'not partitioned'::text
        END AS partitionin_type,
    it.table_parent_schema,
    it.table_parent_name,
    pg_get_expr(c.relpartbound, c.oid, true) AS partitioning_values,
    pg_get_expr(p.partexprs, c.oid, true) AS sub_partitioning_values
   FROM inheritance_tree it
     JOIN pg_class c ON c.oid = it.table_oid
     LEFT JOIN pg_partitioned_table p ON p.partrelid = it.table_oid
  ORDER BY it.table_name, c.reltuples;
--
CREATE OR REPLACE FUNCTION util.send_email(
    p_to text, 
    p_subject text, 
    p_message text, 
    p_copy text = NULL::text, 
    p_blindcopy text = NULL::text, 
    p_attach_files_name text[] = NULL::text[], 
    p_attach_files_body bytea[] = NULL::bytea[], 
    p_attach_files_codec text[] = NULL::text[], 
    p_sender_address text = NULL::text, 
    p_smtp_server text = :'email_server'::text
    ) RETURNS text
    LANGUAGE plpython3u
    AS $$
# -*- coding: utf-8 -*-

#
# Отправка сообщений через функцию в базе данных.
#
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма','grufos@mail.ru','sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма','sergey.grinko@gmail.com','grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, 'grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, 'sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', 'grufos@mail.ru');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', 'sergey.grinko@gmail.com');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>');
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','Текст письма', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea]);
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea]);
# select util.send_email('sergey.grinko@company.ru','Проверка заголовка','<html><head></head><body><p>Hi!<br>How are you?<br>Here is the <a href="https://www.python.org">link</a> you wanted.</p></body></html>', NULL, NULL, ARRAY['file.txt'], ARRAY['содержимое файла file.txt'::bytea], ARRAY['zip']);

  import io
  import zipfile
  import socket
  import smtplib
  from smtplib                import SMTPException
  from email.mime.multipart   import MIMEMultipart
  from email.mime.text        import MIMEText
  from email.header           import Header
  from email.mime.base        import MIMEBase
  from email.mime.application import MIMEApplication
  from email                  import encoders
  from os.path                import basename

  _sender_address = p_sender_address
  if p_sender_address is None or p_sender_address == '' or p_sender_address.isspace():
    _sender_address = socket.gethostname() + " <" +socket.gethostname() + "@company.ru>"

  _recipients_list = [r.strip() for r in p_to.split(',')]

  _msg = MIMEMultipart('alternative')
  _msg['From'] = _sender_address
  _msg['To'] = p_to
  _msg['Subject'] = Header(p_subject, 'utf-8') 
  if not (p_copy is None or p_copy=='' or p_copy.isspace()):
    _msg['CC'] = p_copy
    _recipients_list = _recipients_list + [r.strip() for r in p_copy.split(',')]
  if not (p_blindcopy is None or p_blindcopy=='' or p_blindcopy.isspace()):
    _msg['BCC'] = p_blindcopy
    _recipients_list = _recipients_list + [r.strip() for r in p_blindcopy.split(',')]

  if p_message:
    if "<html>" in p_message or "<br>" in p_message or "<style>" in p_message or "<table>" in p_message or "<H1>" in p_message or "<head>" in p_message:
      _part = MIMEText(p_message, 'html', 'utf-8')
    else:
      _part = MIMEText(p_message, 'plain', 'utf-8')
    _msg.attach(_part)

  if p_attach_files_name and p_attach_files_body:
    for _i, _f in enumerate(p_attach_files_name):
      _part = MIMEBase('application', "octet-stream")
      if p_attach_files_codec is not None and len(p_attach_files_codec) >= _i and p_attach_files_codec[_i] is not None and p_attach_files_codec[_i]=="zip":
        # применяем архивацию для преобразования данных файла вложения
        mf = io.BytesIO()
        with zipfile.ZipFile(mf, mode='w', compression=zipfile.ZIP_DEFLATED) as zf:
          zf.writestr(_f, p_attach_files_body[_i])
        _part.set_payload(mf.getvalue())
        _f = _f + ".zip"
      else:
        # не нужно применять никакого кодека преобразования данных файла вложения
        _part.set_payload(p_attach_files_body[_i])
      # конвертируем вложение в base64
      encoders.encode_base64(_part)
      _part.add_header('Content-Disposition', 'attachment; filename="%s"' % basename(_f))
      _msg.attach(_part)

  server = smtplib.SMTP(p_smtp_server)
  server.sendmail(_sender_address, _recipients_list, _msg.as_string())
  server.quit()
  return "send mail"
$$;
--
\if :postgres_pgvers_13plus
CREATE OR REPLACE FUNCTION util.inf_long_running_requests(
    p_query_age interval = '00:02:00'::interval, 
    p_recipients_list text = 'dba-postgresql@company.ru;'::text
) RETURNS void
LANGUAGE plpgsql
AS $$
-- select util.inf_long_running_requests();
-- select util.inf_long_running_requests(p_query_age:='00:00:30'::interval);
-- select cron.schedule('*/5 * * * *','select util.inf_long_running_requests();')
declare
    v_html text;
    v_arrpids text[];
    v_arrquery bytea[];
    v_nn_master int;
    v_nn_parallel int;
begin
    if exists( select 1 from public.vw_who where state <> 'idle' and datname not in ('mamonsu', 'postgres') and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0 ) then
        -- есть, что отправлять...
        -- читаем данные по длительным запросам
        v_html = (
            select  '<tr>' || string_agg(   '<td>' || coalesce(r.rn::text, ' ')                                || '</td>' ||
                                            '<td>' || coalesce(r.query_age, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.pid::text, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.leader_pid::text, ' ')                        || '</td>' ||
                                            '<td>' || coalesce(r.blocked_by, ' ')                              || '</td>' ||
                                            '<td>' || coalesce(r.state, ' ')                                   || '</td>' ||
                                            '<td>' || case when r.open_tran_count then '1' else ' ' end        || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.query), ' ')            || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.usename), ' ')          || '</td>' ||
                                            '<td>' || coalesce(r.wait_info, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.datname, ' ')                                 || '</td>' ||
                                            '<td>' || coalesce(r.client_addr::text, ' ')                       || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.application_name), ' ') || '</td>' ||
                                            '<td>' || coalesce(r.backend_type, ' ')                            || '</td>'
                                         , '</tr><tr>')
                           || '</tr>'
            from (
                    select case when position('.' in coalesce(ts_age, xact_age, query_age)::text) > 0 
                                    then left(coalesce(ts_age, xact_age, query_age)::text, 
                                              position('.' in coalesce(ts_age, xact_age, query_age)::text)-1)
                                else coalesce(ts_age, xact_age, query_age)::text
                           end as query_age,
                           pid,
                           leader_pid,
                           case when blocked_by::text = '{}' then '' else blocked_by::text end blocked_by, 
                           state,
                           ts_age is not null as open_tran_count,
                           datname, 
                           usename, 
                           coalesce(wait_event_type || ' ', '') || coalesce('(' || wait_event || ')', '') as wait_info, 
                           client_addr, 
                           application_name, 
                           backend_type, 
                           left(query,255) as query,
                           row_number() over(order by query_age desc) as rn
                    from public.vw_who
                    where state <> 'idle' and datname not in ('mamonsu', 'postgres')
            ) r
        );
        -- собираем исходный код длительных запросов
        select array_agg(pid || ' ('
						|| replace(case when position('.' in coalesce(ts_age, xact_age, query_age)::text) > 0 
                                    then left(coalesce(ts_age, xact_age, query_age)::text, 
                                              position('.' in coalesce(ts_age, xact_age, query_age)::text)-1)
                                else coalesce(ts_age, xact_age, query_age)::text
                           end, ':', '-')
						|| ').sql') as pid,
               array_agg(query::bytea) as query,
               count(*) as cnt_master
               into v_arrpids, v_arrquery, v_nn_master
        from public.vw_who
        where state <> 'idle' and datname not in ('mamonsu', 'postgres') and leader_pid is null
          and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0;
        --
        select count(*) as cnt_parallel
               into v_nn_parallel
        from public.vw_who
        where state <> 'idle' and datname not in ('mamonsu', 'postgres') and leader_pid is not null
          and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0;
        --
        v_html = '<style>
                    table {border-style:solid;border-width:1;border-collapse:collapse;width:100%}
                    th {border-style:solid;border-width:2;background-color:#FFDDA9}
                    td {border-style:solid;border-width:1}
                </style>
                <H1>Активность на сервере с долгими запросами</H1>
                <p>Всего найдено долгих запросов - ' || v_nn_master + coalesce(v_nn_parallel, 0) || ' из них:<br>
                основных - ' || v_nn_master || ', паралельных - ' || coalesce(v_nn_parallel, 0) || '<br></p>
                <table>
                <col width="3%"><col width="9%"><col width="3%"><col width="3%"><col width="9%"><col width="3%"><col width="3%"><col width="15%"><col width="9%"><col width="9%"><col width="9%"><col width="9%"><col width="12%"><col width="9%">
                <th>N</th><th>duration</th><th>pid</th><th>leader_pid</th><th>blocked_by</th><th>state</th><th>open tran</th><th>sql text</th><th>user name</th><th>wait info</th><th>database name</th><th>client addr</th><th>program name</th><th>backend_type</th>'
                || v_html || '</table>';
        -- отправляем письмо
        perform util.send_email(p_to := p_recipients_list, p_subject := 'Длительные запросы', p_message := v_html, 
        						p_attach_files_name := v_arrpids, p_attach_files_body := v_arrquery);
        -- фиксируем в логе отправку письма
        raise notice 'Письмо о длительных запросах отправлено';
        raise log 'util.inf_long_running_requests: Letter of lengthy requests sent';
    end if;
end
$$;
\else
CREATE OR REPLACE FUNCTION util.inf_long_running_requests(
    p_query_age interval = '00:02:00'::interval, 
    p_recipients_list text = 'dba-postgresql@company.ru;'::text
) RETURNS void
LANGUAGE plpgsql
AS $$
-- select util.inf_long_running_requests();
-- select util.inf_long_running_requests(p_query_age:='00:00:30'::interval);
-- select cron.schedule('*/5 * * * *','select util.inf_long_running_requests();')
declare
    v_html text;
    v_arrpids text[];
    v_arrquery bytea[];
    v_nn_master int;
    v_nn_parallel int;
begin
    if exists( select 1 from public.vw_who where state <> 'idle' and datname not in ('mamonsu', 'postgres') and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0 ) then
        -- есть, что отправлять...
        -- читаем данные по длительным запросам
        v_html = (
            select  '<tr>' || string_agg(   '<td>' || coalesce(r.rn::text, ' ')                                || '</td>' ||
                                            '<td>' || coalesce(r.query_age, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.pid::text, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.blocked_by, ' ')                              || '</td>' ||
                                            '<td>' || coalesce(r.state, ' ')                                   || '</td>' ||
                                            '<td>' || case when r.open_tran_count then '1' else ' ' end        || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.query), ' ')            || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.usename), ' ')          || '</td>' ||
                                            '<td>' || coalesce(r.wait_info, ' ')                               || '</td>' ||
                                            '<td>' || coalesce(r.datname, ' ')                                 || '</td>' ||
                                            '<td>' || coalesce(r.client_addr::text, ' ')                       || '</td>' ||
                                            '<td>' || coalesce(util.replace_char_xml(r.application_name), ' ') || '</td>' ||
                                            '<td>' || coalesce(r.backend_type, ' ')                            || '</td>'
                                         , '</tr><tr>')
                           || '</tr>'
            from (
                    select case when position('.' in coalesce(ts_age, xact_age, query_age)::text) > 0 
                                    then left(coalesce(ts_age, xact_age, query_age)::text, 
                                              position('.' in coalesce(ts_age, xact_age, query_age)::text)-1)
                                else coalesce(ts_age, xact_age, query_age)::text
                           end as query_age,
                           pid,
                           case when blocked_by::text = '{}' then '' else blocked_by::text end blocked_by, 
                           state,
                           ts_age is not null as open_tran_count,
                           datname, 
                           usename, 
                           coalesce(wait_event_type || ' ', '') || coalesce('(' || wait_event || ')', '') as wait_info, 
                           client_addr, 
                           application_name, 
                           backend_type, 
                           left(query,255) as query,
                           row_number() over(order by query_age desc) as rn
                    from public.vw_who
                    where state <> 'idle' and datname not in ('mamonsu', 'postgres')
            ) r
        );
        -- собираем исходный код длительных запросов
        select array_agg(pid || ' ('
						|| replace(case when position('.' in coalesce(ts_age, xact_age, query_age)::text) > 0 
                                    then left(coalesce(ts_age, xact_age, query_age)::text, 
                                              position('.' in coalesce(ts_age, xact_age, query_age)::text)-1)
                                else coalesce(ts_age, xact_age, query_age)::text
                           end, ':', '-')
						|| ').sql') as pid,
               array_agg(query::bytea) as query,
               count(*) as cnt_master
               into v_arrpids, v_arrquery, v_nn_master
        from public.vw_who
        where state <> 'idle' and datname not in ('mamonsu', 'postgres')
          and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0;
        --
        select count(*) as cnt_parallel
               into v_nn_parallel
        from public.vw_who
        where state <> 'idle' and datname not in ('mamonsu', 'postgres') 
          and coalesce(ts_age, xact_age, query_age) > p_query_age and position('vacuum' in lower(query))=0;
        --
        v_html = '<style>
                    table {border-style:solid;border-width:1;border-collapse:collapse;width:100%}
                    th {border-style:solid;border-width:2;background-color:#FFDDA9}
                    td {border-style:solid;border-width:1}
                </style>
                <H1>Активность на сервере с долгими запросами</H1>
                <p>Всего найдено долгих запросов - ' || v_nn_master + coalesce(v_nn_parallel, 0) || ' из них:<br>
                основных - ' || v_nn_master || ', паралельных - ' || coalesce(v_nn_parallel, 0) || '<br></p>
                <table>
                <col width="3%"><col width="9%"><col width="3%"><col width="9%"><col width="3%"><col width="3%"><col width="15%"><col width="9%"><col width="9%"><col width="9%"><col width="9%"><col width="12%"><col width="9%">
                <th>N</th><th>duration</th><th>pid</th><th>blocked_by</th><th>state</th><th>open tran</th><th>sql text</th><th>user name</th><th>wait info</th><th>database name</th><th>client addr</th><th>program name</th><th>backend_type</th>'
                || v_html || '</table>';
        -- отправляем письмо
        perform util.send_email(p_to := p_recipients_list, p_subject := 'Длительные запросы', p_message := v_html, 
        						p_attach_files_name := v_arrpids, p_attach_files_body := v_arrquery);
        -- фиксируем в логе отправку письма
        raise notice 'Письмо о длительных запросах отправлено';
        raise log 'util.inf_long_running_requests: Letter of lengthy requests sent';
    end if;
end
$$;
\endif
