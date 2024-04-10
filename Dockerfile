# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.0
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev libvips node-gyp pkg-config python-is-python3

# Install JavaScript dependencies
ARG NODE_VERSION=20.10.0
ARG YARN_VERSION=1.22.17
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM bitnami/kubectl:latest as kubectl
FROM alpine/helm:latest as helm

# Final stage for app image
FROM base

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=helm /usr/bin/helm /usr/local/bin/helm

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git curl unzip node-gyp libvips postgresql-client pkg-config python-is-python3 buildah slirp4netns fuse-overlayfs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install AWS CLI version 2
RUN ARCH=$(dpkg --print-architecture) && \
    SUFFIX=$([ "$ARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-$SUFFIX.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm awscliv2.zip

# Install AWS SSM Agent
RUN ARCH=$(dpkg --print-architecture) \
    && SUFFIX=$([ "$ARCH" = "arm64" ] && echo "arm64" || echo "64bit") \
    && curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_$SUFFIX/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
    && dpkg -i session-manager-plugin.deb \
    && rm session-manager-plugin.deb


# Istall werf 
# RUN curl -sSL https://werf.io/install.sh | bash -s -- --version 1.2 --channel stable
# Accept Werf version as an argument
ARG WERF_VERSION=1.2.300

# Download Werf, replace vX.Y.Z with the desired version
RUN curl -L https://tuf.werf.io/targets/releases/$WERF_VERSION/linux-amd64/bin/werf -o /usr/local/bin/werf \
    && chmod +x /usr/local/bin/werf

# (Optional) Verify Werf installation
RUN werf version

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp data
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
