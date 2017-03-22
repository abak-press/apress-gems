FROM abakpress/ruby-app:2.3-latest

RUN git config --global user.name "Automated Release" \
  && git config --global user.email support@railsc.ru

ADD . /usr/src/apress-gems

RUN cd /usr/src/apress-gems \
  && gem build -V apress-gems.gemspec \
  && gem install $(ls -t apress-gems*.gem | head -1)

ADD release-gem /usr/local/bin/
