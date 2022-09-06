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
    if exists( select 1 from public.vw_who 
               where state <> 'idle' 
                 and datname not in ('mamonsu', 'postgres') 
                 and coalesce(ts_age, xact_age, query_age) > p_query_age 
                 and position('vacuum' in lower(query))=0 
                 and position('start_replication slot' in lower(query))=0 
             ) then
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
        perform util.send_email(p_to := p_recipients_list, p_subject := 'Длительные запросы'::text, p_message := v_html, 
        						p_attach_files_name := v_arrpids, p_attach_files_body := v_arrquery);
        -- фиксируем в логе отправку письма
        raise notice 'Письмо о длительных запросах отправлено';
        raise log 'util.inf_long_running_requests: Letter of lengthy requests sent';
    end if;
end
$$;
