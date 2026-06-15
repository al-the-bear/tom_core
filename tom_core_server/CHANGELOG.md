## Unreleased

### Documentation

- Replaced the default package-template `README.md` with a customized one: a
  description of the package, a path-dependency getting-started section, correct
  usage snippets (`TomServer`, `TomArgs.fillFromArgs`, `TomEnvFile.read`,
  repository CRUD), and a Modules table covering all 13 exported modules. No
  code or public API change.
- **Authentication module**: added dartdoc to all public symbols
  (`TomAuthenticationServer`, `TomAuthenticationService`,
  `TomAuthenticationData`, `TomAuthenticationInfo`,
  `TomDummyAuthenticationService`, `LoginException`, `TomAuthenticationAdaptor`,
  `Tom2FAAdaptor`, `Tom2FAService`); a module guide at `doc/authentication.md`;
  an executable example at `example/authentication/`; and a test suite at
  `test/authentication_test.dart`. No public API change — removed only stray
  `// TODO:` comments (the deferred 2FA work is now recorded in the module
  dartdoc and the quest completion steps).

## 1.0.0

- Initial version.
