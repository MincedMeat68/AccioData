FROM ruby:3.3-slim

WORKDIR /app

# Gemfile.lock lists x86_64-linux and aarch64-linux, so sqlite3 installs as a
# precompiled gem; no build toolchain needed.
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without test && bundle install

COPY . .

ENV RACK_ENV=production \
    DATABASE_PATH=/data/packages.sqlite3
VOLUME /data
EXPOSE 4567

# config.ru migrates and seeds an empty database on boot.
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
