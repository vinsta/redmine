FROM ubuntu:20.04
MAINTAINER luckyv

RUN apt-get update \
    && apt-get install -y software-properties-common \
    # && apt-add-repository ppa:brightbox/ruby-ng \
    # && apt-get update 
    && echo "mysql-server-5.7 mysql-server/root_password password redmine" | debconf-set-selections \
    && echo "mysql-server-5.7 mysql-server/root_password_again password redmine" | debconf-set-selections \
    && apt-get install -y sudo tzdata build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
        libcurl4-openssl-dev mysql-server-5.7 libmysqlclient-dev libapr1-dev libaprutil1-dev apache2-utils \
        apache2-dev imagemagick libmagick++-dev fonts-takao-pgothic subversion libapache2-svn git gitweb \
        libssh2-1 libssh2-1-dev cmake libgpg-error-dev ruby2.5 ruby2.5-dev zlib1g-dev libdigest-sha-perl \
        libapache-dbi-perl libdbd-mysql-perl libauthen-simple-ldap-perl \
    && gem install bundler \
    && gem install passenger --no-rdoc --no-ri \
    && passenger-install-apache2-module --auto

# Redmine
RUN svn co http://svn.redmine.org/redmine/branches/4.1-stable/ /var/lib/redmine
ADD config/* /var/lib/redmine/config/
WORKDIR /var/lib/redmine

# redmine backlogs
RUN git clone -b feature/redmine3 https://github.com/backlogs/redmine_backlogs.git /var/lib/redmine/plugins/redmine_backlogs \
	&& sed -i -e 's/gem "nokogiri".*/gem "nokogiri", "~> 1.10.0"/g' /var/lib/redmine/plugins/redmine_backlogs/Gemfile \
	&& sed -i -e 's/gem "capybara", "~> 1"/gem "capybara", "~> 3.31.0"/g' /var/lib/redmine/plugins/redmine_backlogs/Gemfile \
	# scm creator
	&& svn co http://svn.s-andy.com/scm-creator /var/lib/redmine/plugins/redmine_scm \
	# issue template
	&& apt-get install -y mercurial \
	&& hg clone https://bitbucket.org/akiko_pusu/redmine_issue_templates /var/lib/redmine/plugins/redmine_issue_templates \
	# code review
	&& hg clone https://bitbucket.org/haru_iida/redmine_code_review /var/lib/redmine/plugins/redmine_code_review \
	# clipboard_image_paste
	&& git clone https://github.com/peclik/clipboard_image_paste.git /var/lib/redmine/plugins/clipboard_image_paste \
	# excel export
	&& git clone https://github.com/two-pack/redmine_xls_export.git /var/lib/redmine/plugins/redmine_xls_export \
	&& sed -i -e 's/gem "nokogiri".*/gem "nokogiri", ">= 1.6.7.2"/g' /var/lib/redmine/plugins/redmine_xls_export/Gemfile \
	# drafts
	&& git clone https://github.com/jbbarth/redmine_drafts.git /var/lib/redmine/plugins/redmine_drafts

ADD scm-post-create.sh /var/lib/redmine/

# bundle and rake
RUN bundle install --without development test --path vendor/bundle \
	&& bundle exec gem install mysql \
	&& chown -R www-data:www-data /var/lib/redmine/
ADD redmine/Makefile /var/lib/redmine/
RUN make rake

# apache2
ADD apache2/conf-available/redmine.conf /etc/apache2/conf-available/
ADD apache2/mods-available/dav_svn.conf /etc/apache2/mods-available/
ADD apache2/sites-available/000-default.conf /etc/apache2/sites-available/
# use Redmine Auth
RUN mkdir -p /etc/perl/Apache/Authn \
	&& cp /var/lib/redmine/extra/svn/Redmine.pm /etc/perl/Apache/Authn/Redmine.pm \
	&& passenger-install-apache2-module --snippet >> /etc/apache2/conf-available/redmine.conf \
	&& a2enconf redmine \
	&& a2enmod cgi alias env \
	# repository
	&& mkdir /var/lib/svn/ \
	&& chown -R www-data:www-data /var/lib/svn/ /var/lib/git/

# ginalize
EXPOSE 80
ADD entrypoint.sh /root/
ENTRYPOINT sh /root/entrypoint.sh
