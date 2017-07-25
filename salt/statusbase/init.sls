{% set app = pillar.statusbase %}

install-statusbase: 
    file.directory:
        - name: /srv/statusbase
        - user: {{ pillar.elife.webserver.username }}
        - group: {{ pillar.elife.webserver.username }}

    git.latest:
        - user: {{ pillar.elife.webserver.username }}
        - name: https://github.com/ep320/statusbase
        - rev: {{ salt['elife.cfg']('project.revision', 'project.branch', 'master') }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/statusbase/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - require:
            - file: install-statusbase


# create db


statusbase-db:
    mysql_database.present:
        - name: {{ app.db.name }}
        - connection_pass: {{ pillar.elife.db_root.password }}

statusbase-db-user:
    mysql_user.present:
        - name: {{ app.db.user }}
        - password: {{ app.db.pass }}
        - connection_pass: {{ pillar.elife.db_root.password }} # do it as the root user
        - host: {{ app.db.host }}
        - require:
            - service: mysql-server

statusbase-db-access:
    mysql_grants.present:
        - user: {{ app.db.user }}
        - database: {{ app.db.name }}.*
        - grant: all privileges
        - connection_pass: {{ pillar.elife.db_root.password }} # do it as the root user
        - require:
            - mysql_user: statusbase-db-user

# contains IP addresses so we can debug things under actual conditions
replacement-app-dev:
    file.managed:
        - name: /srv/statusbase/web/app_dev.php
        - source: salt://statusbase/config/srv-statusbase-web-app_dev.php
        - require:
            - git: install-statusbase
          
file-perms:
    cmd.run:
        - cwd: /srv/statusbase
        - name: chmod +w -R var/
        - require:
            - git: install-statusbase
            
configure-statusbase:
    file.managed:
        - user: {{ pillar.elife.webserver.username }}
        - name: /srv/statusbase/app/config/parameters.yml
        - source: salt://statusbase/config/srv-statusbase-app-config-parameters.yml
        - template: jinja
        - require:
            - git: install-statusbase

    cmd.run:
        - user: {{ pillar.elife.webserver.username }}
        - cwd: /srv/statusbase
        - name: |
            # re-generate any files and install the db
            set -e
            composer install 
            php bin/console doctrine:schema:update --force
        - require:
            - file: configure-statusbase
            - cmd: file-perms



statusbase-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/statusbase.conf
        - source: salt://statusbase/config/etc-nginx-sites-enabled-statusbase.conf
        - template: jinja
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm


