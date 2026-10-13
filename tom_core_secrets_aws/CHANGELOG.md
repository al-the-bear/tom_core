# Changelog

## 0.1.0

### Added

- **`TomAwsSecretsProvider`**: a `TomSecretsProvider` over AWS Secrets
  Manager, registered as `aws` by default. A reference names the secret by name
  or ARN (`secret:aws:prod/billing#password`); `fetch` calls `GetSecretValue`
  and answers the `SecretString`, or the `SecretBinary` decoded as UTF-8, with
  the `VersionId`. Requests are signed with `tom_core_server`'s `TomAwsV4Signer`
  for the service `secretsmanager`. `call` is the public signed client for any
  Secrets Manager action.
- **`TomAwsCredentialsSource`**: the credentials of each request, from a
  function — static keys, or a role's temporary credentials.
- **`TomAwsSecretsProvider.fromConfiguration`**: the provider from the
  `secrets.aws` configuration key (`region`, `accessKeyId`, `secretAccessKey`,
  `sessionToken`, `endpoint`), each falling back to `AWS_REGION` /
  `AWS_DEFAULT_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN` and `AWS_ENDPOINT_URL_SECRETS_MANAGER` in the
  `environment` map passed. Refusals `secrets.aws.config.missing_region` and
  `secrets.aws.config.missing_credentials`.
- Failures are `TomSecretsException`s keyed `secrets.fetch.not_found` (a
  `ResourceNotFoundException`), `secrets.aws.binary_not_text` and
  `secrets.fetch.failed`, carrying AWS's own explanation and never a secret's
  value.
- `example/aws_secrets_example.dart`, the `MockClient` unit suite, the
  `emulator`-tagged suite against LocalStack and `tool/run_emulator_tests.sh`,
  which runs it in Docker.
- `README.md`, `doc/index.md`, `doc/aws_secrets.md` and
  `doc/api/api_summary_tom_core_secrets_aws.md`.
