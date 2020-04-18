FROM alpine
MAINTAINER luckyv

ENV RAILS_ENV=production
RUN set -ex \
    && export BUNDLE_SILENCE_ROOT_WARNING=1 \
    && apk --update add --virtual .redmine-deps \
        ruby ruby-bundler ruby-bigdecimal ruby-json tzdata mysql mysql-client mysql-dev \
    && apk add --virtual .redmine-builddpes \
        subversion git build-base ruby-dev zlib-dev \
    && mkdir -p /run/mysqld \
    && sed -i '/\[mysqld\]/a\socket = \/run\/mysqld\/mysqld.sock' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\port = 3306' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\datadir = \/var\/lib\/mysql' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\user = root' /etc/my.cnf \
    && mysql_install_db --user=root \
    && cd /var/lib \
    && svn co http://svn.redmine.org/redmine/branches/4.1-stable/ /var/lib/redmine \
    && cd redmine \
    && rm files/delete.me log/delete.me \
    && echo "$RAILS_ENV:" > config/database.yml \
    && echo "  adapter: mysql2" >> config/database.yml \
    && echo "  database: redmine" >> config/database.yml \
    && echo "  host: localhost" >> config/database.yml \
    && echo "  username: root" >> config/database.yml \
    && echo "  password: redmine" >> config/database.yml \
    && git clone https://github.com/paginagmbh/redmine_lightbox2.git plugins/redmine_lightbox2 \
    && git clone https://github.com/peclik/clipboard_image_paste.git plugins/clipboard_image_paste \
    && echo "gem 'puma', '~> 3.7'" >> Gemfile.local \
    && gem install bundle 

ADD plugins /var/lib/redmine/plugins
ADD redmine/Makefile /var/lib/redmine/

RUN cd /var/lib/redmine \
    && bundle install --without development test \
    && make rake \
    && rm -rf ~/.bundle/ \
    && rm -rf /usr/lib/ruby/gems/*/cache/* \
    && apk --purge del .redmine-builddpes \
    && rm -rf /var/cache/apk/* \
    && adduser -h /redmine -s /sbin/nologin -D -H redmine \
    && chown -R redmine:redmine /var/lib/redmine /var/lib/mysql \
    && chown -R redmine:redmine /run/mysqld

RUN echo "#!/bin/sh" > /var/lib/redmine/entrypoint.sh \
    && echo "/usr/bin/mysqld_safe &" >> /var/lib/redmine/entrypoint.sh \
    && echo "sleep 10" >> /var/lib/redmine/entrypoint.sh \
    && echo "exec \"\$@\"" >> /var/lib/redmine/entrypoint.sh \
    && chmod +x /var/lib/redmine/entrypoint.sh

USER redmine:redmine

WORKDIR /var/lib/redmine

VOLUME ["/var/lib/redmine/files"]

ENTRYPOINT ["/var/lib/redmine/entrypoint.sh"]

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
