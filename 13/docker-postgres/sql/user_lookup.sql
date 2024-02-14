CREATE OR REPLACE FUNCTION pgbouncer.user_lookup(p_username text, OUT uname text, OUT phash text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    SELECT usename, passwd FROM pg_catalog.pg_shadow
    WHERE usename = p_username INTO uname, phash;
    RETURN;
END;
$$;
