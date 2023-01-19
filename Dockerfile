ARG ALPINE_VERSION=3.17.0
ARG ERLANG_VERSION=25.2
ARG ELIXIR_VERSION=1.14.2
FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} as builder
WORKDIR /src
COPY . .
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mix deps.get
RUN MIX_ENV=prod mix release
RUN mv _build/prod/rel/external_dns /opt/release
RUN mv /opt/release/bin/external_dns /opt/release/bin/app
CMD _build/prod/rel/external_dns/bin/external_dns start

ARG ALPINE_VERSION=3.17.0
FROM alpine:${ALPINE_VERSION} as runner
RUN apk add --no-cache libstdc++ ncurses-libs
WORKDIR /opt/release
COPY --from=builder /opt/release .
CMD /opt/release/bin/app start
