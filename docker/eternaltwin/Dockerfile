# syntax=docker/dockerfile:1.7
#
# Local dev Eternaltwin built from the upstream `main` branch
# (https://gitlab.com/eternaltwin/eternaltwin): REST API + OAuth + the Angular
# website embedded in a single `eternaltwin` binary.
#
# Config: ./eternaltwin/eternaltwin.toml, mounted at /etc/eternaltwin/eternaltwin.toml
# (new config format; the old `yarn etwin` setup is Dockerfile.legacy + etwin.toml).
#
# Bump ETERNALTWIN_REF (full commit sha) to update, then
#   docker compose up -d --build kadokadeo_eternaltwin
# The cargo/yarn caches are BuildKit cache mounts, so a bump only rebuilds what changed.

ARG NODE_IMAGE=node:22-bookworm
ARG RUNTIME_IMAGE=debian:bookworm-slim

# ---------------------------------------------------------------------------
# Sources
FROM ${NODE_IMAGE} AS source
ARG ETERNALTWIN_REPO=https://gitlab.com/eternaltwin/eternaltwin.git
ARG ETERNALTWIN_REF=63ace6b0fe60b9cb1540781d0e6ece6b57f342d8
WORKDIR /src
RUN git init -q . \
    && git remote add origin "${ETERNALTWIN_REPO}" \
    && git fetch -q --depth 1 origin "${ETERNALTWIN_REF}" \
    && git checkout -q FETCH_HEAD \
    && git log -1 --format='%H %cd' > /src/ETERNALTWIN_COMMIT \
    && rm -rf .git

# ---------------------------------------------------------------------------
# Website (Angular, `minimal` configuration), embedded later by crates/app
FROM ${NODE_IMAGE} AS website
WORKDIR /src
COPY --from=source /src /src
# Yarn 4 comes from the repo (`yarnPath` in .yarnrc.yml).
RUN --mount=type=cache,target=/root/.yarn/berry/cache,sharing=locked \
    yarn install --immutable
RUN cd packages/website \
    && NODE_OPTIONS=--max-old-space-size=6144 yarn run minimal:build \
    && test -f dist/minimal/browser/index.html

# ---------------------------------------------------------------------------
# Rust binary
FROM ${NODE_IMAGE} AS backend
ARG RUST_TOOLCHAIN=stable
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain "${RUST_TOOLCHAIN}" \
    && rustc --version && cargo --version
WORKDIR /src
COPY --from=website /src /src
# packages/website/dist/minimal/browser exists, so crates/app/build.rs embeds it without rebuilding.
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/src/target,sharing=locked \
    cargo build --release --locked --bin eternaltwin \
    && install -D target/release/eternaltwin /out/eternaltwin

# ---------------------------------------------------------------------------
# Runtime
FROM ${RUNTIME_IMAGE}
ARG UID=1000
ARG GID=1000
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g "${GID}" eternaltwin \
    && useradd -u "${UID}" -g "${GID}" -m eternaltwin
COPY --from=backend /out/eternaltwin /usr/local/bin/eternaltwin
COPY --from=source /src/ETERNALTWIN_COMMIT /usr/local/share/eternaltwin/COMMIT
WORKDIR /etc/eternaltwin
USER eternaltwin
EXPOSE 50320
# The config is found by searching the working directory (eternaltwin.toml).
# `db sync` creates or upgrades the schema, `start` seeds (users, apps, forum sections) and serves.
CMD ["sh", "-c", "eternaltwin db sync && exec eternaltwin start"]
