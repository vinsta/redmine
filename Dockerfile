FROM alpine
MAINTAINER luckyv<lucky.vw@gmail.com>

ENV RAILS_ENV=production
RUN set -ex \
    && export BUNDLE_SILENCE_ROOT_WARNING=1 \
    && cd / \
    && apk --update add --virtual .redmine-deps \
         ruby ruby-bundler ruby-bigdecimal ruby-json sqlite-libs tzdata git mercurial\
    && apk add --virtual .redmine-builddpes \
         curl build-base ruby-dev sqlite-dev zlib-dev \
    && export REDMINE_TAR=https://github.com/redmine/redmine/archive/master.tar.gz \
    && export MINIMALFLAT2=$(curl --silent https://api.github.com/repos/akabekobeko/redmine-theme-minimalflat2/releases/latest | grep browser_download_url | sed -E 's/.*"([^\"]+)".*/\1/') \
    && export PURPLEMINE2=https://github.com/mrliptontea/PurpleMine2/archive/master.tar.gz \
    && curl -sSL $REDMINE_TAR | tar xz \
    && mv redmine-* redmine \
    && cd /redmine \
        && rm files/delete.me log/delete.me \
        && echo "$RAILS_ENV:" > config/database.yml \
        && echo "  adapter: sqlite3" >> config/database.yml \
        && echo "  database: files/redmine.sqlite3" >> config/database.yml \
        && echo "gem 'puma'" >> Gemfile.local \
        && echo 'config.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))' > config/additional_environment.rb \
        && bundle install --without development test rmagick \
        && cd public/themes/ \
            && curl -sSL $MINIMALFLAT2 -o minimalflat2.zip \
            && unzip minimalflat2.zip \
            && rm minimalflat2.zip \
            && curl -sSL $PURPLEMINE2 | \
               tar xz PurpleMine2-master/fonts PurpleMine2-master/images/ PurpleMine2-master/javascripts/ \
                      PurpleMine2-master/plugins PurpleMine2-master/stylesheets \
            && mv PurpleMine2-master purplemine2 \
    && cd /redmine \
        # redmine backlogs
        && git clone -b feature/redmine3 https://github.com/backlogs/redmine_backlogs.git /redmine/plugins/redmine_backlogs \
        && sed -i -e 's/gem "nokogiri".*/gem "nokogiri", "~> 1.7.2"/g' /redmine/plugins/redmine_backlogs/Gemfile \
        && sed -i -e 's/gem "capybara", "~> 1"/gem "capybara", ">= 0"/g' /redmine/plugins/redmine_backlogs/Gemfile \
        # scm creator
        && svn co http://svn.s-andy.com/scm-creator /redmine/plugins/redmine_scm \
        # issue template
        && hg clone https://bitbucket.org/akiko_pusu/redmine_issue_templates /redmine/plugins/redmine_issue_templates \
        # code review
        && hg clone https://bitbucket.org/haru_iida/redmine_code_review /redmine/plugins/redmine_code_review \
        # clipboard_image_paste
        && git clone https://github.com/peclik/clipboard_image_paste.git /redmine/plugins/clipboard_image_paste \
        # excel export
        && git clone https://github.com/two-pack/redmine_xls_export.git /redmine/plugins/redmine_xls_export \
        && sed -i -e 's/gem "nokogiri".*/gem "nokogiri", ">= 1.6.7.2"/g' /redmine/plugins/redmine_xls_export/Gemfile \
        # drafts
        && git clone https://github.com/jbbarth/redmine_drafts.git redmine/plugins/redmine_drafts \
    && rm -rf ~/.bundle/ \
    && rm -rf /usr/lib/ruby/gems/*/cache/* \
    && apk --purge del .redmine-builddpes \
    && rm -rf /var/cache/apk/* 
    # && adduser -h /redmine -s /sbin/nologin -u 1000 -D -H redmine 
    # && chown -R redmine:redmine /redmine

# USER 1000:1000

WORKDIR /redmine

VOLUME ["/redmine/files"]

ADD scm-post-create.sh /var/lib/redmine/

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
