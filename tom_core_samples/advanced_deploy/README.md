# Advanced Sample Deployment

Production container images and Kubernetes manifests for the advanced sample's
three servers: `advanced_auth_server`, `advanced_app_server` and
`advanced_ops_server`. They are a template for any Tom server application. The
same files deploy the sample to a local [kind](https://kind.sigs.k8s.io/)
cluster, where its integration suites run against them.

| File | What it is |
| ---- | ---------- |
| `Dockerfile` | One multi-stage build for every server, parameterised by `PACKAGE` and `ENTRY` |
| `Dockerfile.dockerignore` | The allow-list of the build context: the packages the servers depend on by path |
| `k8s/base/` | The production deployment: namespace, configuration, two MariaDB StatefulSets, three server Deployments, their Services |
| `k8s/overlays/kind/` | The base on a kind cluster: local images and NodePorts, still production |
| `k8s/overlays/kind-demo/` | The kind deployment with the sample's demo data (`env: dev`) |
| `kind-cluster.yaml` | A one-node kind cluster mapping the NodePorts to host ports 8080/8081 and 3307/3308 |
| `run_kind_integration.sh` | Creates the cluster, deploys it and runs the integration suites against it |
| `otel/collector.yaml`, `otel/docker-compose.yaml` | A local OpenTelemetry Collector receiving the servers' spans and metrics on `127.0.0.1:4318` and writing them to files |

## The image

The build stage compiles the server ahead of time (`dart compile exe`), with
its committed reflection seed compiled in. The runtime stage is `scratch`
holding:

- the executable;
- the Dart image's `/runtime` (the C library, the resolver and the CA bundle);
- the package's `assets/`, `database_migrations/` and `openapi/`, which the
  boot reads relative to its working directory `/app`.

It runs as the unprivileged user 65532. An image is about 25 MB.

```bash
# from the directory holding core/, reflection/ and core_extension/ (tom_ai)
docker build -f core/tom_core_samples/advanced_deploy/Dockerfile \
  --build-arg PACKAGE=advanced_app_server \
  --build-arg ENTRY=bin/app_server_start.dart \
  -t advanced-app-server:1.0 .
```

The context is `tom_ai`, not the package, because the servers depend on
`tom_core_kernel`, `tom_core_server`, `tom_reflection_generator` and
`tom_core_openapi` by path. `Dockerfile.dockerignore` admits only those
packages and the sample's own. It leaves out `.dart_tool`, `pubspec.lock`,
tests, examples and documents, so the image is resolved and built from what a
clone holds. An application whose dependencies are hosted builds from its own
directory and needs neither.

## The configuration

A Tom server merges its YAML assets, then the OS environment, then `.env` and
the command line. A `SCREAMING_SNAKE` variable reaches the field of the same
name: `JWT_ISSUER` sets `jwtIssuer`, and `AUTH_DB_HOST` fills the
`${AUTH_DB_HOST:localhost}` term of `datasources_default.yaml`. The manifests
therefore configure everything through the environment. The images carry no
configuration a deployment has to change.

| Source | Holds |
| ------ | ----- |
| ConfigMap `advanced-config` | `env` (the runtime environment), `LOG_LEVEL`, `JWT_ISSUER`, `JWT_AUDIENCE`, the shutdown timings, the database hosts, names and users |
| Secret `advanced-db-credentials` | `auth-password`, `auth-root-password`, `app-password`, `app-root-password` |
| Secret `advanced-jwt-keys` | `signing-private.pem`, `signing-public.pem`, `payload-private.pem`, `payload-public.pem` |

**The base ships no Secret.** A template that ships key material ships
somebody's keys. Create the two Secrets from your secret store, an External
Secrets operator, or `kubectl create secret`, as `run_kind_integration.sh`
does. The PEMs are PKCS#8 RSA keys, made with
`openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048`.

The keys are split by server:

| Server | Signing keys | Payload pair | Can issue tokens |
| ------ | ------------ | ------------ | ---------------- |
| Auth server | The private signing key, a file (`JWT_SIGNING_KEY_FILE`) | Both PEMs (`JWT_RSA_PRIV_KEY`, `JWT_RSA_PUB_KEY`) | Yes |
| App server | Only the public signing key (`JWT_VERIFICATION_KEY_FILES`) | Both PEMs | No; it verifies the auth server's tokens |

Under `env: prod` a server without its key material refuses to start rather
than fall back to the framework's sample keys.

## The workloads

**Databases.** Two MariaDB 11 StatefulSets, `auth-db` and `app-db`, each with
a 1 GiB volume. They start empty: there is no initdb script. Each server applies
its own migration chain at start, under the migration lock, so replicas
starting together migrate once. A server that cannot reach its database at
start exits, and the kubelet restarts it until the database answers; that is
what happens on a first deployment, while the databases initialise. The ops server contributes `[100]` to
`app_db`'s chain beside the app server's `[000]`–`[004]`. A production
deployment typically points the datasource variables at a managed database
instead and drops the StatefulSets.

**Auth and app servers.** Deployments of two replicas behind ClusterIP
Services, auth on 8081 and app on 8080. Their probes:

| Probe | Path | Means |
| ----- | ---- | ----- |
| Startup | `/health` | Gives the boot, migrations included, up to two minutes |
| Liveness | `/health` | The process answers |
| Readiness | `/ready` | The data sources answer and the server is not shutting down |

A rolling update keeps every replica serving until its successor is ready
(`maxUnavailable: 0`). The shutdown sequence:

1. On SIGTERM the server answers `/ready` with 503 for
   `SHUTDOWN_READINESS_DELAY_SECONDS` (5).
2. The endpoints controller takes the pod out of its Service before the
   listener closes.
3. Requests in flight get `SHUTDOWN_GRACE_PERIOD_SECONDS` (20).

`terminationGracePeriodSeconds: 30` covers both. The containers run with a
read-only root file system, no capabilities and no privilege escalation, and
write only to an `emptyDir` at `/tmp`.

**Ops server.** One replica, no Service and no probes: it serves no HTTP, and
the kubelet restarts it when the process exits. SIGTERM closes its runtime, so
the job in flight finishes and the audit trail is flushed. It writes under
`/app/data`, an `emptyDir`:

- **Digests.** Without `OPS_SMTP_HOST` they become `.eml` files in
  `/app/data/mail`. Set the `OPS_SMTP_*` variables to send them.
- **Audit anchors.** They are written to `/app/data/anchors`. They belong in a
  store the server cannot rewrite: mount one there and set
  `OPS_ANCHOR_INDEPENDENT=true`.

## Tracing and the local collector

The servers record spans when `tracing` is on and export them over OTLP/HTTP —
to the receiver their metrics are pushed to. Three variables configure it:

| Variable | Field | Effect |
| -------- | ----- | ------ |
| `TRACING` | `tracing` | `true` records a span per request, SQL statement, transaction, outgoing call, job run and outbox delivery; off by default |
| `OTLP_ENDPOINT` | `otlpEndpoint` | The receiver's base URL; spans go to `<OTLP_ENDPOINT>/v1/traces`. A server with `TRACING=true` and no endpoint refuses to start |
| `TRACING_SAMPLE_PERCENT` | `tracingSamplePercent` | The percentage of new traces recorded, 0 to 100, default 100; a request from a traced caller follows the caller's decision |

`OTLP_HEADERS` (`otlpHeaders`) adds headers to every export, such as a
backend's credential; it belongs in a Secret, not the ConfigMap. A server's
spans are exported under its `appId` as `service.name`: `auth` and `app` for the
auth and app servers.

`otel/` runs an OpenTelemetry Collector on one machine. It receives OTLP over
HTTP on `127.0.0.1:4318` (`OTEL_COLLECTOR_PORT`) and writes every trace export to
`otel/out/traces.json` and every metrics export to `otel/out/metrics.json`, one
export per line (`OTEL_COLLECTOR_OUT` moves the folder):

```bash
# from tom_core_samples
docker compose -f advanced_deploy/otel/docker-compose.yaml up -d
cd advanced_app_server
TRACING=true OTLP_ENDPOINT=http://127.0.0.1:4318 \
  dart run bin/app_server_start.dart env=dev
```

A server exports a batch every five seconds and once more when it shuts down.
To look at the traces rather than read them, replace the file exporters in
`collector.yaml` with a backend's — Jaeger, Tempo, a vendor's. In a cluster the
collector runs as its own workload and `OTLP_ENDPOINT` names its Service.
`advanced_client_core/tool/run_cross_tier_integration.sh --trace` starts this
collector, runs both servers against it and checks what they exported. See
`tom_core_server/doc/tracing.md` for every span and its attributes.

## Running it on kind

```bash
tom_core_samples/advanced_deploy/run_kind_integration.sh          # deletes the cluster afterwards
tom_core_samples/advanced_deploy/run_kind_integration.sh --keep   # leaves it running
```

Requirements: docker, kind, kubectl, openssl and the Dart SDK on `PATH`, with
host ports 8080, 8081, 3307 and 3308 free. The script:

1. Creates the cluster `tom-advanced`.
2. Builds and loads the three images.
3. Creates both Secrets from freshly generated passwords and keys.
4. Deploys `overlays/kind`, the production configuration, and waits for every
   rollout. This proves the servers boot under `prod` with real keys against
   empty databases and pass their probes.
5. Restarts the app server while polling it about ten times a second, and
   fails if any request is refused during the handover.
6. Deploys `overlays/kind-demo` and restarts the servers, which apply the
   `@dev,test` demo seed.
7. Runs the sample's suites against the cluster:
   - `advanced_client_core/tool/run_cross_tier_integration.sh --external-stack`;
   - `advanced_ops_server/tool/run_ops_integration.sh --external-databases`.

## Adapting it to another application

1. Set `PACKAGE` and `ENTRY` for the server.
2. List its path dependencies in `Dockerfile.dockerignore`, or drop the file
   when everything is hosted.
3. Replace the ConfigMap's database and JWT settings with the application's
   own.
4. Keep the probe paths, the `maxUnavailable: 0` rollout and a
   `terminationGracePeriodSeconds` longer than the two shutdown timings: they
   are the framework's, not the sample's.
