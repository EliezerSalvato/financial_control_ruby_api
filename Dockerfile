# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.5

FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libjemalloc2 \
      libpq5 \
      nano && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 \
      /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD=/usr/local/lib/libjemalloc.so

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      pkg-config \
      libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./

RUN bundle config set frozen true && \
    bundle install && \
    rm -rf ~/.bundle \
      ${BUNDLE_PATH}/ruby/*/cache \
      ${BUNDLE_PATH}/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile -j 1 --gemfile
RUN bundle exec bootsnap precompile -j 1 app/ lib/

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 \
    --gid 1000 \
    --create-home \
    --shell /bin/bash

USER rails

COPY --chown=rails:rails --from=build \
  ${BUNDLE_PATH} ${BUNDLE_PATH}

COPY --chown=rails:rails --from=build \
  /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

HEALTHCHECK --interval=30s --timeout=5s \
CMD ["curl", "-f", "http://localhost/up"]

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
