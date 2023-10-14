############### Builder stage ###############
FROM rust:1.72.1 AS builder
ARG PROJECT_NAME=zero2prod

ENV SQLX_OFFLINE=true
ENV RUST_BACKTRACE=1

WORKDIR "/app"

# Optional, update rustup to the latest version
# rustup update stable

RUN mkdir -p ./src
RUN echo "fn main() {}" > ./src/dummy.rs
RUN echo "" > ./src/dummy-lib.rs
COPY Cargo.toml Cargo.lock .
RUN sed -i 's#src/main.rs#src/dummy.rs#' Cargo.toml
RUN sed -i 's#src/lib.rs#src/dummy-lib.rs#' Cargo.toml
RUN cargo build --release
RUN sed -i 's#src/dummy.rs#src/main.rs#' Cargo.toml
RUN sed -i 's#src/dummy-lib.rs#src/lib.rs#' Cargo.toml
COPY ./src ./src
COPY sqlx-data.json ./
RUN cargo build --release


############### Runtime stage ###############
# FROM debian:bullseye-slim AS runtime
FROM debian:bookworm-slim AS runtime
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
COPY --from=builder /app/target/release/zero2prod zero2prod

# We need the configuration file at runtime
COPY configuration configuration

# Lauch our binary
ENTRYPOINT ["./zero2prod"]