CREATE OR REPLACE FUNCTION util.background_start(p_command text) RETURNS void
    LANGUAGE plpgsql
    AS $$
/*
  Запускает указанную команду отдельным фоновым процессом без ожидания возврата результата
*/
declare v_pid integer = pg_background_launch(p_command);
begin
    perform pg_sleep(0.1);
    perform pg_background_detach(v_pid);
end;
$$;