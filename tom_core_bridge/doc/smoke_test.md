# Tom Core Bridge — Smoke Test

A minimal end-to-end check that the `core_bs` binary **builds, starts, and
answers a bridge request**. It exercises the simplest request the server
handles — `echo`, which round-trips a message — so a pass proves the transport
(stdin/stdout JSON-RPC) and the server startup are wired correctly.

> Because `core_bs` links the generated `tom_core_d4rt` bridge set, a pass also
> proves that set compiles — which is why this is the one command to run after
> regenerating the bridges. Both the automated runner and the manual procedure
> below are supported.

## The minimal request

The server answers an `echo` request by returning its `message` param:

```jsonc
// request (one JSON line on stdin)
{"jsonrpc":"2.0","id":"smoke-1","method":"echo","params":{"message":"ping"}}

// response (one JSON line on stdout, after the [BSTART] banner)
{"jsonrpc":"2.0","id":"smoke-1","result":{"message":"ping"}}
```

## Automated runner

```bash
# Builds bin/core_bs.dart to a local temp exe, launches it, sends the echo
# request, and asserts the response. Cleans up the temp binary afterwards.
dart run tool/smoke_test.dart

# Or smoke-test an already-published binary without rebuilding:
dart run tool/smoke_test.dart --binary "$TOM_BINARY_PATH/<platform-vs>/core_bs"
```

Exit codes: `0` = PASS **or** SKIP (build blocked / binary absent — see the
`[SMOKE]` line for which); `1` = FAIL (started but no valid echo response
within the timeout).

## Manual procedure

1. **Build** the binary (or use a published one):

   ```bash
   dart compile exe bin/core_bs.dart -o core_bs
   ```

2. **Launch and send the request.** The server keeps listening after
   responding, so cap the wait with `timeout` and stop on the first matching
   line:

   ```bash
   printf '%s\n' \
     '{"jsonrpc":"2.0","id":"smoke-1","method":"echo","params":{"message":"ping"}}' \
     | timeout 10 ./core_bs | grep -m1 '"id":"smoke-1"'
   ```

3. **Expected output** — a single JSON line echoing the message:

   ```text
   {"jsonrpc":"2.0","id":"smoke-1","result":{"message":"ping"}}
   ```

   (The `[BSTART] VS Code Bridge Server started` banner is also printed to
   stdout; the `grep` filters it out.)

If you see the `result` line, the binary starts and answers bridge requests.
For deeper launch diagnostics see [`operations.md`](operations.md).
