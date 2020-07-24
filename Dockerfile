FROM centos:8
MAINTAINER  Daniel.Aboyewa info@lolubyte.com 

RUN dnf -y install epel-release
RUN dnf -y install httpd nagios nagios-plugins supervisor cronie-noanacron
RUN find /etc/httpd/conf.d/ -type f ! -name php.conf -a ! -name nagios.conf -delete
RUN find /etc/httpd/conf.modules.d/ -type f ! -name 00-base.conf -a ! -name 00-mpm.conf -a ! -name 01-cgi.conf -a ! -name 10-php.conf -delete

RUN chown apache: /var/log/httpd/ -R
RUN chown apache /run/httpd/
RUN usermod -G apache nagios
RUN sed -i "s/Listen 80/Listen 9090/" /etc/httpd/conf/httpd.conf

RUN echo $'[unix_http_server]\n\
file=/var/run/supervisor/supervisor.sock\n\
\n\
[supervisord]\n\
logfile=/var/log/supervisor/supervisord.log\n\
logfile_maxbytes=50MB\n\
logfile_backups=1\n\
loglevel=info\n\
pidfile=/var/run/supervisord.pid\n\
nodaemon=true\n\
minfds=1024\n\
minprocs=200\n\
user=root\n\
\n\
[rpcinterface:supervisor]\n\
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface\n\
\n\
[supervisorctl]\n\
serverurl=unix:///var/run/supervisor/supervisor.sock\n\
\n\
[program:nagios]\n\
command=/usr/sbin/nagios /etc/nagios/nagios.cfg\n\
numprocs=1\n\
autostart=true\n\
autorestart=true\n\
startsecs=10\n\
startretries=1\n\
user=nagios\n\
stdout_logfile=/var/log/supervisor/nagios.stdout.log\n\
stdout_logfile_maxbytes=1MB\n\
stdout_logfile_backups=10\n\
stderr_logfile=/var/log/supervisor/nagios.stderr.log\n\
stderr_logfile_maxbytes=1MB\n\
stderr_logfile_backups=10\n\
\n\
[program:httpd]\n\
command=/usr/sbin/httpd -DFOREGROUND\n\
numprocs=1\n\
autostart=true\n\
autorestart=true\n\
startsecs=10\n\
startretries=1\n\
user=apache\n\
stdout_logfile=/var/log/supervisor/httpd.stdout.log\n\
stdout_logfile_maxbytes=1MB\n\
stdout_logfile_backups=10\n\
stderr_logfile=/var/log/supervisor/httpd.stderr.log\n\
stderr_logfile_maxbytes=1MB\n\
stderr_logfile_backups=10\n\
\n\
[program:crond]\n\
command=/usr/sbin/crond -m off -n -s\n\
numprocs=1\n\
autostart=true\n\
autorestart=true\n\
startsecs=10\n\
startretries=1\n\
user=root\n\
stdout_logfile=/var/log/supervisor/crond.stdout.log\n\
stdout_logfile_maxbytes=1MB\n\
stdout_logfile_backups=10\n\
stderr_logfile=/var/log/supervisor/crond.stderr.log\n\
stderr_logfile_maxbytes=1MB\n\
stderr_logfile_backups=10\n\
' > /usr/local/etc/supervisord.conf

RUN /usr/bin/htpasswd -b -d /etc/nagios/passwd nagiosadmin admin && cp -rp /etc/nagios /usr/local/share/nagios
RUN echo $'#!/bin/bash\n\
[ -f /etc/nagios/pre_start.sh ] && /etc/nagios/pre_start.sh\n\
[ ! -f /etc/nagios/nagios.cfg ] && cp /usr/local/share/nagios/* /etc/nagios/ -rp && chown nagios: /etc/nagios -R\n\
find /var/run/ -iname *.pid -delete\n\
/usr/bin/supervisord -n -c /usr/local/etc/supervisord.conf\n\
' > /usr/local/bin/entrypoint.sh && chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 9090/tcp
VOLUME ["/etc/nagios", "/etc/cron.d"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
