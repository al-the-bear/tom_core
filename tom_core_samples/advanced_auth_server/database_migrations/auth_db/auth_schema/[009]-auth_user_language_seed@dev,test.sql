-- Demo language preferences.
--
-- `bob` reads German; everybody else keeps the deployment default. `bob` and
-- `carol` are the two people the demo items are assigned to, so one morning
-- digest pass over the seeded data renders German for one recipient and English
-- for the next — the case `advanced_ops_server`'s digest exists to show.
--
-- Tagged `@dev,test` like the seed that creates `bob` ([003]). Idempotent: a
-- re-applied UPDATE writes the same value.

UPDATE auth_users SET language = 'de', country = NULL WHERE username = 'bob';
