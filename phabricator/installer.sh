#!/bin/sh

apt-get update

apt-get -y install \
  ssh git mercurial subversion php5-fpm nginx php5-cli php5-curl \
  php5-mysql php5-gd php5-apcu python-pygments

adduser --disabled-password --gecos "" scm
adduser --disabled-password --gecos "" phd-user
adduser --disabled-password --gecos "" phabricator

mkdir -p /opt/phacility
mkdir -p /data/storage
mkdir -p /data/repo

chown phabricator:phabricator /opt/phacility
chown phabricator:phabricator /data/storage
chown phd-user:phd-user /data/repo

su -c "cd /opt/phacility && \
git clone https://github.com/phacility/libphutil.git && \
git clone https://github.com/phacility/arcanist.git && \
git clone https://github.com/phacility/phabricator.git && \
cd libphutil && git checkout stable && cd .. && \
cd arcanist && git checkout stable && cd .. && \
cd phabricator && git checkout stable && cd .." - phabricator

su -c "/opt/phacility/phabricator/bin/config set mysql.host $MYSQL_HOST && \
/opt/phacility/phabricator/bin/config set mysql.user $MYSQL_USER && \
/opt/phacility/phabricator/bin/config set mysql.pass $MYSQL_PASSWORD && \
/opt/phacility/phabricator/bin/config set pygments.enabled true && \
/opt/phacility/phabricator/bin/config set storage.local-disk.path /data/storage && \
/opt/phacility/phabricator/bin/config set repository.default-local-path /data/repo && \
/opt/phacility/phabricator/bin/config set phd.user phd-user && \
/opt/phacility/phabricator/bin/config set set diffusion.ssh-user scm && \
/opt/phacility/phabricator/bin/storage upgrade --force" - phabricator

cat /etc/php5/fpm/php.ini | \
sed 's/;opcache\.validate_timestamps=1/opcache.validate_timestamps=0/g' | \
sed 's/post_max_size = 8M/post_max_size = 32M/g' \
  > /etc/php5/fpm/php.ini

cat /etc/php5/fpm/pool.d/www.conf | \
sed 's/\[www\]/[phabricator]/g' | \
sed 's/www-data/phabricator/g' | \
sed 's/listen = \/var\/run\/php5-fpm\.sock/listen = 127.0.0.1:9000/g' \
  > /etc/php5/fpm/pool.d/phabricator.conf

rm /etc/nginx/sites-enabled/default

cat << EOF | tee /etc/nginx/sites-available/phabricator
server {
  server_name localhost;
  root        /opt/phacility/phabricator/webroot;

  location / {
    index index.php;
    rewrite ^/(.*)$ /index.php?__path__=/\$1 last;
  }

  location = /favicon.ico {
    try_files \$uri =204;
  }

  location /index.php {
    fastcgi_pass   localhost:9000;
    fastcgi_index   index.php;

    #required if PHP was built with --enable-force-cgi-redirect
    fastcgi_param  REDIRECT_STATUS    200;

    #variables to make the $_SERVER populate in PHP
    fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
    fastcgi_param  QUERY_STRING       \$query_string;
    fastcgi_param  REQUEST_METHOD     \$request_method;
    fastcgi_param  CONTENT_TYPE       \$content_type;
    fastcgi_param  CONTENT_LENGTH     \$content_length;

    fastcgi_param  SCRIPT_NAME        \$fastcgi_script_name;

    fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
    fastcgi_param  SERVER_SOFTWARE    nginx/\$nginx_version;

    fastcgi_param  REMOTE_ADDR        \$remote_addr;
  }
}
EOF

ln -s /etc/nginx/sites-available/phabricator /etc/nginx/sites-enabled/

cat /opt/phacility/phabricator/resources/sshd/sshd_config.phabricator.example | \
sed 's/vcs-user/scm/g' | \
sed 's/\/usr\/libexec\/phabricator-ssh-hook\.sh/\/etc\/ssh\/phabricator-ssh-hook.sh/g' \
  > /etc/ssh/sshd_config

cat /opt/phacility/phabricator/resources/sshd/phabricator-ssh-hook.sh | \
sed 's/vcs-user/scm/g' | \
sed 's/\/path\/to\/phabricator/\/opt\/phacility\/phabricator/g' \
  > /etc/ssh/phabricator-ssh-hook.sh

chmod 755 /etc/ssh/phabricator-ssh-hook.sh

cat << EOF | tee /etc/sudoers.d/phabricator
scm ALL=(phd-user) SETENV: NOPASSWD: /usr/bin/git-upload-pack, /usr/bin/git-receive-pack, /usr/bin/hg, /usr/bin/svnserve
phabricator ALL=(phd-user) SETENV: NOPASSWD: /usr/lib/git-core/git-http-backend, /usr/bin/hg
EOF

chmod 440 /etc/sudoers.d/phabricator

