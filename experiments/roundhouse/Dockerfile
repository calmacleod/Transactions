# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0.5
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    ca-certificates libffi8 libicu-dev libjemalloc2 libssl3t64 libsqlite3-0 \
    python3 procps sqlite3 zlib1g && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
ENV RAILS_ENV=production PORT=3901 WORKERS=1 SPINEL_WORKERS=2 \
    BLOG_DB=/rails/storage/production.sqlite3

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential clang curl git libffi-dev libjemalloc-dev libssl-dev \
    libsqlite3-dev pkg-config zlib1g-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
COPY c-pack /native-build
COPY support /source/experiments/roundhouse
RUN cd /native-build && \
    python3 /source/experiments/roundhouse/guard --max-rss-mb 1024 --seconds 600 -- \
      make -j1 MAKEFLAGS=-j1 CC=clang
COPY app /rails
RUN mkdir -p /rails/build/bin && cp /native-build/blog /rails/build/bin/blog

FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
COPY --chown=rails:rails --from=build /rails /rails
COPY --chown=rails:rails support/guard /rails/bin/native-guard
COPY --chown=rails:rails support/container-entrypoint /rails/bin/native-entrypoint
USER 1000:1000
EXPOSE 3901
ENTRYPOINT ["/rails/bin/native-entrypoint"]
CMD ["/rails/build/bin/blog"]
