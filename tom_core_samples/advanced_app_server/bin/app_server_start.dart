/// Live-boot entrypoint for the advanced app server, and the reflection root
/// for the package (see `build.yaml`).
///
/// The full boot sequence (platform → reflection → runtime → config →
/// datasource → beans → migrations → `TomServer.start()`, wired with
/// `tomDefaultAuthenticationMiddleware`) is implemented in step 21. This stub
/// keeps the package compilable and analyzable until then.
void main(List<String> args) {
  print(
    'advanced_app_server: scaffold only — the secured boot sequence is wired '
    'in step 21 of advanced_example_specification_plan.md.',
  );
}
