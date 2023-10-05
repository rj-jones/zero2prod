############### Builder stage ###############
FROM rust:1.72.1 AS builder
ARG PROJECT_NAME=zero2prod

# Enforce sqlx offline mode
ENV SQLX_OFFLINE true

WORKDIR /app

# Optional, update rustup to the latest version
# rustup update stable

# Install the build deps crate to allow caching of dependencies
RUN cargo install --git https://github.com/rj-jones/build-deps-updated

# Build the dependencies
RUN cd /app && USER=root cargo new --bin $PROJECT_NAME
WORKDIR /app/$PROJECT_NAME
COPY Cargo.toml Cargo.lock ./
RUN cargo-build-deps-updated --release
COPY . /app/$PROJECT_NAME/

# Build out application, leveraging the cached deps
RUN cargo build --release --bin zero2prod


############### Runtime stage ###############
FROM debian:bullseye-slim AS runtime
ARG PROJECT_NAME=zero2prod

WORKDIR /app

# Install OpenSSL - it is dynamically linked by some the dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Using production environment
ENV APP_ENVIRONMENT production

# Copy the compiled binary from the builder environment
COPY --from=builder /app/$PROJECT_NAME/target/release/zero2prod zero2prod

# We need the configuration file at runtime
COPY configuration configuration

# Lauch our binary
ENTRYPOINT ["./zero2prod"]