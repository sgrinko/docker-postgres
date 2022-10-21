# -*- coding: utf-8 -*-
import socket
import os
import logging
import sys
import glob

import mamonsu.lib.platform as platform
from mamonsu.lib.plugin import Plugin
from mamonsu.plugins.pgsql.driver.checks import is_conn_to_db
from mamonsu.lib.default_config import DefaultConfig

if platform.LINUX:
    import pwd

import configparser


class Config(DefaultConfig):

    def __init__(self, cfg_file=None, plugin_directories=None):

        if plugin_directories is None:
            plugin_directories = []
        config = configparser.ConfigParser()

        config.add_section('postgres')
        config.set('postgres', 'enabled', str(True))
        config.set('postgres', 'user', Config.default_user())
        config.set('postgres', 'password', str(Config.default_pgpassword()))
        config.set('postgres', 'database', Config.default_db())
        config.set('postgres', 'host', Config.default_host())
        config.set('postgres', 'port', str(Config.default_port()))
        config.set('postgres', 'application_name', str(Config.default_app()))
        config.set('postgres', 'query_timeout', '10')

        config.add_section('system')
        config.set('system', 'enabled', str(True))

        config.add_section('sender')
        config.set('sender', 'queue', str(2048))

        config.add_section('agent')
        config.set('agent', 'enabled', str(True))
        config.set('agent', 'host', '127.0.0.1')
        config.set('agent', 'port', str(10052))

        config.add_section('plugins')
        config.set('plugins', 'enabled', str(False))
        config.set('plugins', 'directory', '/etc/mamonsu/plugins')

        config.add_section('zabbix')
        config.set('zabbix', 'enabled', str(True))
        config.set('zabbix', 'client', socket.gethostname())
        config.set('zabbix', 'address', '127.0.0.1')
        config.set('zabbix', 'port', str(10051))
        config.set('zabbix', 'timeout', str(15))
        config.set('zabbix', 're_send', str(False))

        config.add_section('metric_log')
        config.set('metric_log', 'enabled', str(False))
        config.set('metric_log', 'directory', '/var/log/mamonsu')
        config.set('metric_log', 'max_size_mb', '1024')

        config.add_section('log')
        config.set('log', 'file', str(None))
        config.set('log', 'level', 'INFO')
        config.set(
            'log', 'format',
            '[%(levelname)s] %(asctime)s - %(name)s\t-\t%(message)s')

        self.config = config
        self._load_external_plugins(plugin_directories)
        self._apply_default_config()

        if cfg_file and not os.path.isfile(cfg_file):
            sys.stderr.write('Can\'t found file: {0}\n'.format(cfg_file))
            sys.exit(1)
        else:
            if os.path.getsize(cfg_file) == 0:
                sys.stderr.write('Config file is empty: {0}\n'.format(cfg_file))
                sys.exit(1)
            if cfg_file is not None:
                if platform.LINUX:
                    config_status = int(repr(oct(os.stat(cfg_file).st_mode))[:-1][-3:])
                    config_owner = pwd.getpwuid(os.stat(cfg_file).st_uid).pw_name
                    if not ((config_status == 600 or config_status == 644) and (config_owner == "mamonsu" or config_owner == "postgres" or config_owner == "root")):
                        logging.info(
                            "Shut down because of incorrect config file {0} permissions. It must be r/w for mamonsu user only (600).".format(
                                cfg_file))
                        sys.stderr.write(
                            "Please, check your config file {0} permissions. It must be r/w for mamonsu user only (600).\n".format(
                                cfg_file))
                        sys.exit(1)
                self.config.read_file(open(cfg_file))

        plugins = self.fetch('plugins', 'directory', str)
        if plugins is not None:
            self._load_external_plugins_from_directory(plugins)
        self._apply_default_config()
        self._check_interval()
        self._apply_log_setting()
        self._apply_environ()
        self._override_auto_variables()

    def has_plugin_config(self, name):
        return self.config.has_section(name)

    def plugin_options(self, name):
        return self.config.options(name)

    def fetch(self, sec, key, klass=None, raw=False):
        try:
            if klass == float:
                return self.config.getfloat(sec, key)
            if klass == int:
                return self.config.getint(sec, key)
            if klass == bool:
                return self.config.getboolean(sec, key)
            if self.config.get(sec, key, raw=raw) == 'None':
                return None
            return self.config.get(sec, key, raw=raw)
        except KeyError:
            return None

    def _apply_environ(self):
        os.environ['PGUSER'] = self.fetch('postgres', 'user')
        if self.fetch('postgres', 'password'):
            os.environ['PGPASSWORD'] = self.fetch('postgres', 'password')
        os.environ['PGHOST'] = self.fetch('postgres', 'host')
        os.environ['PGPORT'] = str(self.fetch('postgres', 'port'))
        os.environ['PGDATABASE'] = self.fetch('postgres', 'database')
        os.environ['PGTIMEOUT'] = self.fetch('postgres', 'query_timeout')
        os.environ['PGAPPNAME'] = self.fetch('postgres', 'application_name')

    def _apply_log_setting(self):
        logging.basicConfig(
            format=self.fetch('log', 'format', raw=True),
            filename=self.fetch('log', 'file'),
            level=self.get_logger_level(self.fetch('log', 'level')))

    def _load_external_plugins(self, directories):
        if directories is None:
            return
        for dir in directories:
            self._load_external_plugins_from_directory(dir)

    def _load_external_plugins_from_directory(self, directory):
        sys.path.append(directory)
        try:
            for filename in glob.glob(os.path.join(directory, '*.py')):
                if not os.path.isfile(filename):
                    continue
                # /dir/filename.py => filename.py
                filename = os.path.basename(filename)
                if filename.startswith('_'):
                    continue
                # filename.py => filename
                filename, _ = os.path.splitext(filename)
                __import__(filename)
        except Exception as e:
            sys.stderr.write('Can\'t load module: {0}'.format(e))
            sys.exit(3)

    def _override_auto_variables(self):
        self._override_auto_host()

    def _override_auto_host(self):

        def test_db(self, host_pre):
            if is_conn_to_db(
                host=host_pre,
                db=self.fetch('postgres', 'database'),
                port=str(self.fetch('postgres', 'port')),
                user=self.fetch('postgres', 'user'),
                    paswd=self.fetch('postgres', 'password')):
                self.config.set('postgres', 'host', host_pre)
                self._apply_environ()
                return True
            return False

        host = self.fetch('postgres', 'host')
        port = str(self.fetch('postgres', 'port'))
        if host == 'auto' and platform.UNIX:
            logging.debug('Host set to auto, test variables')
            if test_db(self, '/tmp/.s.PGSQL.{0}'.format(port)):
                return
            if test_db(self, '/var/run/postgresql/.s.PGSQL.{0}'.format(port)):
                return
            if test_db(self, '127.0.0.1'):
                return
            #  не выходим, так как ожидаем коннекта до localhost
            self.config.set('postgres', 'host', 'localhost')
            self._apply_environ()

    def _apply_default_config(self):
        if self.config.has_option('postgres', 'interval'):
            interval = self.fetch('postgres', 'interval')
        else:
            interval = None
        for plugin in Plugin.only_child_subclasses():
            plugin.set_default_config(self.config, interval)

    def _check_interval(self):
        for plugin in Plugin.only_child_subclasses():
            if not self.config.has_option(plugin.__name__.lower(), 'interval'):
                self.config.set(plugin.__name__.lower(), 'interval', '{0}'.format(plugin.Interval))

