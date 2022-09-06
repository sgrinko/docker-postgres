-- ========================================================================== --
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_snowball_en_ru_sw;

DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_hunspell_en_ru;
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_aot_en_ru;

DROP TEXT SEARCH DICTIONARY IF EXISTS public.english_hunspell_shared;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_hunspell_shared;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_aot_shared;

DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_hunspell_en_ru_sw;
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.fts_aot_en_ru_sw;

DROP TEXT SEARCH DICTIONARY IF EXISTS public.english_hunspell_shared_sw;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_hunspell_shared_sw;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.russian_aot_shared_sw;
-- ========================================================================== --

-- DICTIONARY without stopwords
CREATE TEXT SEARCH DICTIONARY public.english_hunspell_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'en_us', afffile = 'en_us'
);
COMMENT ON TEXT SEARCH DICTIONARY public.english_hunspell_shared IS 'FTS hunspell dictionary for english language (shared without stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_hunspell_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru', afffile = 'ru_ru'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_hunspell_shared IS 'FTS hunspell Lebedev dictionary for russian language (shared without stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_aot_shared (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru_aot', afffile = 'ru_ru_aot'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_aot_shared IS 'FTS hunspell AOT dictionary for russian language (shared without stopwords)';

-- DICTIONARY with stopwords
CREATE TEXT SEARCH DICTIONARY public.english_hunspell_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'en_us', afffile = 'en_us', stopwords = 'english'
);
COMMENT ON TEXT SEARCH DICTIONARY public.english_hunspell_shared_sw IS 'FTS hunspell dictionary for english language (shared with stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_hunspell_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru', afffile = 'ru_ru', stopwords = 'russian'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_hunspell_shared_sw IS 'FTS hunspell Lebedev dictionary for russian language (shared with stopwords)';

CREATE TEXT SEARCH DICTIONARY public.russian_aot_shared_sw (
   TEMPLATE = public.shared_ispell,
   dictfile = 'ru_ru_aot', afffile = 'ru_ru_aot', stopwords = 'russian'
);
COMMENT ON TEXT SEARCH DICTIONARY public.russian_aot_shared_sw IS 'FTS hunspell AOT dictionary for russian language (shared with stopwords)';

-- ========================================================================== --

-- CONFIGURATION without stopwords
CREATE TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_hunspell_shared, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru IS 'FTS hunspell Lebedev configuration for russian language based on shared_ispell without stopwords';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_aot_en_ru (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_aot_shared, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_aot_en_ru IS 'FTS hunspell AOT configuration for russian language based on shared_ispell without stopwords';

-- ========================================================================== --

-- CONFIGURATION with stopwords
CREATE TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared_sw, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_hunspell_shared_sw, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_hunspell_en_ru_sw IS 'FTS hunspell Lebedev configuration for russian language based on shared_ispell with stopwords';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw 
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart 
    WITH english_hunspell_shared_sw, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_aot_shared_sw, russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_aot_en_ru_sw IS 'FTS hunspell AOT configuration for russian language based on shared_ispell with stopwords';

-- ========================================================================== --

CREATE TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw (parser=public.tsparser);

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ADD MAPPING FOR email, file, float, host, hword_numpart, int, numhword, numword, sfloat, uint, url, url_path, version
    WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ALTER MAPPING FOR asciiword, asciihword, hword_asciipart
    WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw
    ALTER MAPPING FOR hword, hword_part, word 
    WITH russian_stem;

COMMENT ON TEXT SEARCH CONFIGURATION public.fts_snowball_en_ru_sw IS 'FTS snowball configuration for russian language based on tsparser with stopwords';

-- ========================================================================== --
