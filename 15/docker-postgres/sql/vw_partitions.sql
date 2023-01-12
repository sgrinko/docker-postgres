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