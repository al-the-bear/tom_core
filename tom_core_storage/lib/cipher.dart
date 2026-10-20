/// AES-256-GCM sealing for [TomStorageCache]'s files, under a key kept in the
/// platform secret store. Its own entry point so that a build which does not
/// seal its cache carries no cipher implementation.
library;

export 'src/cipher/aes_gcm_cache_cipher.dart';
