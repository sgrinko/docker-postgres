# -*- coding: utf-8 -*-

from mamonsu.plugins.pgsql.plugin import PgsqlPlugin as Plugin
from mamonsu.plugins.pgsql.pool import Pooler

class PgJobsCheck(Plugin):
    Interval = 60

    DEFAULT_CONFIG = {
        "interval_check": "1 day"   # На какой промежуток времени в прошлом искать ошибки
    }

    # получаем список всех БД
    query_agent_discovery = "select datname from pg_catalog.pg_database where datistemplate = false"
    # контролируем ошибки для конкретной БД
    query = "select count(*) from cron.get_job_run_details('{1}','{0}'::interval) where status = 'failed' and not pg_is_in_recovery()"
    query_table_exists = "select 1 from pg_class where relname='job_run_details' and relnamespace=(select oid from pg_namespace where nspname='cron')"

    AgentPluginType = 'pg'
    key_db = 'pgsql.jobs.error'
    key_db_discovery = key_db+'{0}'

    def run(self, zbx):
        dbs = []
        test_table = 0
        for row in Pooler.query(self.query_table_exists, 'postgres'):
            test_table = row[0]
        if test_table > 0 :
            for info_dbs in Pooler.query(self.query_agent_discovery):
                dbs.append({"{#DATABASE}": info_dbs[0]})
                # проверяем наличие ошибок в каждой БД
                err_count = 0   # пока ошибок нет
                # self.log.info('jobs[sql]='+ self.query.format(self.plugin_config("interval_check"), info_dbs[0]))
                for info_rows in Pooler.query(self.query.format(self.plugin_config("interval_check"), info_dbs[0]), 'postgres'):
                    err_count = int(info_rows[0])   # есть ошибки, фиксируем
                    # self.log.info('info_rows[{0}]={1} '.format(info_dbs[0], info_rows))
                zbx.send(self.key_db+"[{0}]".format(info_dbs[0]), err_count)
            zbx.send(self.key_db+'[]', zbx.json({'data': dbs}))

    def discovery_rules(self, template, dashboard=False):
        rule = {
            "name": "PostgreSQL JOBs error Discovery",
            "key": self.key_db_discovery.format("[{0}]".format(self.Macros[self.Type])),

        }
        if Plugin.old_zabbix:
            conditions = []
            rule["filter"] = "{#DATABASE}:.*"
        else:
            conditions = [{
                "condition": [
                    {"macro": "{#DATABASE}",
                     "value": ".*",
                     "operator": 8,
                     "formulaid": "A"}
                ]
            }]
        items = [
            {"key": self.right_type(self.key_db_discovery, var_discovery="{#DATABASE},"),
             "name": "PostgreSQL JOBs in {#DATABASE}: error count",
             'units': Plugin.UNITS.none,
             'value_type': Plugin.VALUE_TYPE.numeric_unsigned,
             'delay': self.Interval}
        ]
        triggers = [{
                    'name': 'PostgreSQL: In Database {#DATABASE} on {HOSTNAME} JOBs error (value={ITEM.LASTVALUE})',
                    'expression': '{#TEMPLATE:'+self.right_type(self.key_db_discovery, var_discovery="{#DATABASE},")+'.last()}&gt;0'
                    }
        ]
        return template.discovery_rule(rule=rule, conditions=conditions, items=items, triggers=triggers)

    def keys_and_queries(self, template_zabbix):
        result = ['{0},$2 $1 -c "{1}"'.format(self.key_db_discovery.format("[*]"), self.query_agent_discovery),
        ]
        return template_zabbix.key_and_query(result)
