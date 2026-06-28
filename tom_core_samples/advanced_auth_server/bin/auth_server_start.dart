/// Live-boot entrypoint for the advanced auth server, and the reflection root
/// for the package (see `build.yaml`).
///
/// The full boot sequence (platform → reflection → runtime → config →
/// datasource → beans → migrations → `TomServer.start()`, wired with
/// `tomDefaultAuthenticationMiddleware`) is implemented in step 13. This stub
/// keeps the package compilable and analyzable until then.
void main(List<String> args) {
  print(
    'advanced_auth_server: scaffold only — the JWT-issuer + admin-API boot is '
    'wired in step 13 of advanced_example_specification_plan.md.',
  );
}
