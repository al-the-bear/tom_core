# Mutual-TLS test certificates

Test material for `test/web_security_test.dart`, generated with `openssl`. None
of it protects anything: every key here is public, and nothing outside this
suite trusts the CA.

| File | What |
| ---- | ---- |
| `ca.pem`, `ca.key` | The test CA the server trusts for client certificates. Its key is here because the suite issues the **server** certificate from it on every run. |
| `client.pem`, `client.key` | `CN=orders-service`, issued by the CA — the certificate the suite maps to a service principal. |
| `unmapped_client.pem`, `unmapped_client.key` | `CN=billing-service`, issued by the CA but mapped to no service. |
| `rogue_client.pem`, `rogue_client.key` | `CN=orders-service`, issued by a CA nobody trusts (its own key and certificate were discarded). |

The client certificates are valid for a hundred years. The server certificate
cannot be: macOS refuses a TLS server certificate valid for more than 825 days,
whoever issued it. So the suite issues a fresh one with `openssl` for each run,
valid for two days, and skips the live mutual-TLS group, saying why, on a
machine without `openssl`.
