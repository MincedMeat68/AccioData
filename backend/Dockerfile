# --- Build stage: compile native gem extensions --------------------------------
# sqlite3 installs precompiled for Linux (Gemfile.lock lists x86_64-linux and
# aarch64-linux), but bigdecimal (required by sequel) has a C extension that
# must be compiled, so this stage carries a toolchain.
FROM ruby:3.3-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without test \
 && bundle install --jobs 4

# --- Runtime stage: slim image, no compiler ----------------------------------
FROM ruby:3.3-slim
WORKDIR /app
# The official image sets BUNDLE_APP_CONFIG=/usr/local/bundle, so this copies
# the installed gems and the "without test" setting together.
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

ENV RACK_ENV=production \
    DATABASE_PATH=/data/packages.sqlite3
VOLUME /data
EXPOSE 4567

# config.ru migrates and seeds an empty database on boot.
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
