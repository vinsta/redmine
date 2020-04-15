FROM alpine
MAINTAINER luckyv

ENV RAILS_ENV=production
RUN set -ex \
    && export BUNDLE_SILENCE_ROOT_WARNING=1 \
    && apk --update add --virtual .redmine-deps \
         ruby ruby-bundler ruby-bigdecimal ruby-json tzdata mysql mysql-client \
    && apk add --virtual .redmine-builddpes \
         subversion git mercurial build-base ruby-dev zlib-dev mysql-dev \
    && mkdir -p /run/mysqld \
    && sed -i '/\[mysqld\]/a\socket = \/run\/mysqld\/mysqld.sock' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\port = 3306' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\datadir = \/var\/lib\/mysql' /etc/my.cnf \
    && sed -i '/\[mysqld\]/a\user = root' /etc/my.cnf \
    && mysql_install_db --user=root 

RUN cd /var/lib \
    && svn co http://svn.redmine.org/redmine/branches/4.1-stable/ /var/lib/redmine \
    && cd redmine \
        && rm files/delete.me log/delete.me \
        && echo "$RAILS_ENV:" > config/database.yml \
        && echo "  adapter: mysql2" >> config/database.yml \
        && echo "  database: redmine" >> config/database.yml \
        && echo "  host: localhost" >> config/database.yml \
        && echo "  username: root" >> config/database.yml \
        && echo "  password: redmine" >> config/database.yml \
        # && echo 'config.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))' > config/additional_environment.rb \
        && gem install bundle \
        && bundle install --without development test 

RUN git clone -b feature/redmine3 https://github.com/backlogs/redmine_backlogs.git /var/lib/redmine/plugins/redmine_backlogs \
    && sed -i -e 's/gem "nokogiri".*/gem "nokogiri", "~> 1.10.0"/g' /var/lib/redmine/plugins/redmine_backlogs/Gemfile \
    && sed -i -e 's/gem "capybara", "~> 1"/gem "capybara", "~> 3.25.0"/g' /var/lib/redmine/plugins/redmine_backlogs/Gemfile \
    && sed -i -e 's/gem "holidays", "~>.*[0-9]"/gem "holidays", "~> 8.1.0"/g' /var/lib/redmine/plugins/redmine_backlogs/Gemfile 
    # scm creator
    # && svn co http://svn.s-andy.com/scm-creator /var/lib/redmine/plugins/redmine_scm \
    # issue template
    # && hg clone https://bitbucket.org/akiko_pusu/redmine_issue_templates /var/lib/redmine/plugins/redmine_issue_templates \
    # code review
    # && hg clone https://bitbucket.org/haru_iida/redmine_code_review /var/lib/redmine/plugins/redmine_code_review \
    # clipboard_image_paste
    # && git clone https://github.com/peclik/clipboard_image_paste.git /var/lib/redmine/plugins/clipboard_image_paste \
    # excel export
    # && git clone https://github.com/two-pack/redmine_xls_export.git /var/lib/redmine/plugins/redmine_xls_export \
    # && sed -i -e 's/gem "nokogiri".*/gem "nokogiri", ">= 1.6.7.2"/g' /var/lib/redmine/plugins/redmine_xls_export/Gemfile \
    # drafts
    # && git clone https://github.com/jbbarth/redmine_drafts.git /var/lib/redmine/plugins/redmine_drafts

ADD scm-post-create.sh /var/lib/redmine/
ADD redmine/Makefile /var/lib/redmine/
RUN cd /var/lib/redmine \
    && make rake

RUN  rm -rf ~/.bundle/ \
    && rm -rf /usr/lib/ruby/gems/*/cache/* \
    && apk --purge del .redmine-builddpes \
    && rm -rf /var/cache/apk/* \
    && adduser -h /redmine -s /sbin/nologin -D -H redmine \
    && chown -R redmine:redmine /var/lib/redmine

USER redmine:redmine

WORKDIR /var/lib/redmine

VOLUME ["/var/lib/redmine/files"]

RUN echo "#!/bin/sh" > /var/lib/redmine/entrypoint.sh \
    && echo "/usr/bin/mysqld_safe &" >> /var/lib/redmine/entrypoint.sh \
    && echo "exec '$@'" >> /var/lib/redmine/entrypoint.sh \
    && chmod +x /var/lib/redmine/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
