# -*- coding: utf-8 -*-

from mamonsu.plugins.pgsql.plugin import PgsqlPlugin as Plugin
from mamonsu.plugins.pgsql.pool import Pooler

class PgPartitionDefRows(Plugin):
    Interval = 60*20
    query_agent_discovery = """WITH RECURSIVE inheritance_tree AS (
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
SELECT json_build_object ('data',json_agg(json_build_object('{#TABLE_PART}',it.table_parent_schema || '.' || it.table_parent_name)))
FROM inheritance_tree it
JOIN pg_class c ON c.oid = it.table_oid
LEFT JOIN pg_partitioned_table p ON p.partrelid = it.table_oid
WHERE pg_get_expr(c.relpartbound, c.oid, true) = 'DEFAULT';
"""
    # ищем все DEFAULT секции в которых есть данные
    query = """WITH RECURSIVE inheritance_tree AS (
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
SELECT c.reltuples::bigint, it.table_parent_schema, it.table_parent_name
FROM inheritance_tree it
JOIN pg_class c ON c.oid = it.table_oid
LEFT JOIN pg_partitioned_table p ON p.partrelid = it.table_oid
WHERE pg_get_expr(c.relpartbound, c.oid, true) = 'DEFAULT'
ORDER BY it.table_parent_schema, it.table_parent_name, c.reltuples;"""

    AgentPluginType = 'pg'
    key_rel_part = 'pgsql.partition.def.rows'
    key_rel_part_discovery = key_rel_part+'{0}'

    def run(self, zbx):
        tables = []
        for info_dbs in Pooler.query("select datname from pg_catalog.pg_database where datistemplate = false and datname not in ('mamonsu','postgres')"):
            for info_rows in Pooler.query(self.query, info_dbs[0]):
                table_name = '{0}.{1}.{2}'.format(info_dbs[0], info_rows[1], info_rows[2])
                tables.append({'{#TABLE_PART}': table_name})
                zbx.send(self.key_rel_part+'[{0}]'.format(table_name), info_rows[0])
        zbx.send(self.key_rel_part+'[]', zbx.json({'data': tables}))

    def discovery_rules(self, template, dashboard=False):
        rule = {
            'name': 'Rows in default partition discovery',
            'key': self.key_rel_part_discovery.format('[{0}]'.format(self.Macros[self.Type])),
            'filter': '{#TABLE_PART}:.*'
        }
        items = [
            {'key': self.right_type(self.key_rel_part_discovery, var_discovery="{#TABLE_PART},"),
             'name': 'Rows in default partition: {#TABLE_PART}',
             'units': Plugin.UNITS.none,
             'value_type': Plugin.VALUE_TYPE.numeric_unsigned,
             'delay': self.Interval},
        ]
        conditions = [
            {
                'condition': [
                    {'macro': '{#TABLE_PART}',
                        'value': '.*',
                        'formulaid': 'A'}
                ]
            }
        ]
        graphs = [
            {
                'name': 'PostgreSQL: Rows in default partition {#TABLE_PART}',
                'items': [
                    {'color': 'CC0000',
                     'key': self.right_type(self.key_rel_part_discovery, var_discovery="{#TABLE_PART},")}
                  ]
            }
        ]
        triggers = [{
                    'name': 'PostgreSQL: In the default partition {#TABLE_PART} there are rows on {HOSTNAME} (value={ITEM.LASTVALUE})',
                    'expression': '{#TEMPLATE:'+self.right_type(self.key_rel_part_discovery, var_discovery="{#TABLE_PART},")+'.last()}&gt;0'
                    }
        ]
        return template.discovery_rule(rule=rule, conditions=conditions, items=items, graphs=graphs, triggers=triggers)

    def keys_and_queries(self, template_zabbix):
        result = ['{0},$2 $1 -c "{1}"'.format(self.key_rel_part_discovery.format("[*]"), self.query_agent_discovery),
        ]
        return template_zabbix.key_and_query(result)
