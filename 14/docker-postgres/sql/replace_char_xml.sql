CREATE OR REPLACE FUNCTION util.replace_char_xml(p_str2xml text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE COST 10.0
    AS $$
	select replace(replace(replace(replace(replace(p_str2xml,'&','&#38;'),'''','&#39;'),'"','&#34;'),'<','&lt;'),'>','&gt;');
$$;
