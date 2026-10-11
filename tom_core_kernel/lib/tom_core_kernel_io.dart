/// The `dart:io`-only part of tom_core_kernel.
///
/// `package:tom_core_kernel/tom_core_kernel.dart` is platform-neutral and
/// compiles for the web. What needs a filesystem lives here instead, so that
/// importing it is a decision a caller makes knowingly: only code that runs
/// natively — desktop, mobile, server — may import this library, and a package
/// that also targets the web reaches it through a conditional import.
///
/// Today that is the cross-isolate, cross-process file guard the kernel's
/// file-backed stores use: [tomWithFileLock] waits synchronously,
/// [tomWithFileLockAsync] without blocking its isolate, and both exclude every
/// other holder of the same guard file — other tasks, isolates and processes
/// alike. See `doc/little_things.md`, "Guarding a file against a second
/// writer".
library;

export 'src/tombase/little_things/file_mutex.dart'
    show
        tomWithFileLock,
        tomWithFileLockAsync,
        tomFileLockPath,
        tomFileLockStaleAfter;
