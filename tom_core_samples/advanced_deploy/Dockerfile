# syntax=docker/dockerfile:1.4
#
# Production image of one advanced-sample server: an AOT-compiled executable
# on a scratch base holding only the Dart runtime's shared libraries, the
# certificate bundle, and the package's assets/, database_migrations/ and
# openapi/ — the files the boot reads relative to its working directory.
#
# One Dockerfile builds all three servers; the build arguments name the
# package and its entry point:
#
#   docker build -f tom_ai/core/tom_core_samples/advanced_deploy/Dockerfile \
#     --build-arg PACKAGE=advanced_app_server \
#     --build-arg ENTRY=bin/app_server_start.dart \
#     -t advanced-app-server:local tom_ai
#
# The build context is the `tom_ai` directory, because the servers depend on
# their framework by path (tom_core_kernel, tom_core_server, the reflection
# generator, tom_core_openapi). Dockerfile.dockerignore beside this file admits
# only those packages, so the context stays small.
#
# The reflection seed (`bin/*.reflection.dart`) is committed and compiled in;
# nothing is generated during the build.

ARG DART_VERSION=3.12

FROM dart:${DART_VERSION} AS build
ARG PACKAGE
ARG ENTRY
WORKDIR /src
COPY . .
WORKDIR /src/core/tom_core_samples/${PACKAGE}
RUN dart pub get
RUN mkdir -p /out/app \
 && dart compile exe "${ENTRY}" -o /out/app/server \
 && cp -r assets database_migrations /out/app/ \
 && if [ -d openapi ]; then cp -r openapi /out/app/; fi \
 && mkdir -p /out/app/data

FROM scratch
# The Dart image's /runtime holds what an AOT executable needs from the
# system: the C library, the resolver and the CA bundle.
COPY --from=build /runtime/ /
# Owned by the unprivileged user the container runs as, so a server that
# writes (the ops server's mail and anchor directories) can do so under
# /app/data without a writable root file system.
COPY --from=build --chown=65532:65532 /out/app /app
WORKDIR /app
USER 65532:65532
ENTRYPOINT ["/app/server"]
