#!/usr/bin/env python3
"""Hold the advanced sample's account rosters to the seeds they describe.

Run from anywhere::

    python3 tool/check_sample_account_rosters.py              # the report
    python3 tool/check_sample_account_rosters.py --self-test  # check the checker

Exits non-zero when a roster and its seed disagree, so it can gate a build.

The advanced sample has three account rosters, seeded in three places, and its
READMEs enumerate them by hand in many more:

``auth-db``
    The ``auth_db`` rows: every ``INSERT INTO auth_users`` in the auth
    server's migrations. These are the accounts the servers authenticate
    against.
``app-offline``
    The end-user app's offline fake, ``InMemoryAppBackend.demoAccounts``.
``admin-offline``
    The admin console's offline fake, the ``user(...)`` calls in
    ``InMemoryAdminBackend._seed``.

The three are not the same set, and the confusion between them is what this
gate exists for: one roster offered "for either client" was the admin
console's, so a reader following it into the app tried an account that does
not exist there and never learned the two that carry the second-factor demo.

**An enumeration declares which roster it is.** A region of a document that
lists one completely is wrapped in a marker naming it::

    <!-- account-roster: auth-db --> `admin`, `alice`, ... <!-- /account-roster -->

The markers may sit inline, so a region can be one phrase of a sentence or a
whole table. A partial, illustrative mention -- "sign in as `alice`" -- carries
no marker and is not checked.

Five faults are reported.

``MISSING``
    The roster seeds an account the region never names.
``FOREIGN``
    The region names an account another roster seeds and this one does not --
    ``admin`` listed for the end-user app. A backticked word that is in no
    roster at all is prose, not an account, and is ignored. An offline fake's
    ids (``u-alice``) are read as the account they key.
``VOCAB``
    The phrase "seeded live account" -- reserved for the ``auth-db`` rows --
    appears inside an offline region, or on the same line as an offline id.
    That reuse made a sentence point a reader at a table describing a
    different id space.
``SOURCE``
    The auth server's boot-time ``_demoPasswords`` map, which gives every
    seeded row its demo password, covers a different set of accounts than the
    migrations seed -- an account that can never log in, or a password for an
    account that does not exist.
``UNREAD``
    A seed source could not be read, or a region names a roster this gate does
    not know. Counted as a fault rather than skipped: a comparison against an
    empty roster passes by comparing nothing.

The documents read are every ``.md`` under ``tom_core_samples``. ``--self-test``
perturbs every marked region by one name in each direction and requires the
checker to object, and plants the reserved phrase in an offline region.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from gate_report import report_faults

REPO_ROOT = Path(__file__).resolve().parent.parent
SAMPLES = REPO_ROOT / "tom_core_samples"

AUTH_MIGRATIONS = SAMPLES / "advanced_auth_server" / "database_migrations" / "auth_db"
AUTH_PASSWORDS = SAMPLES / "advanced_auth_server" / "bin" / "auth_server_start.dart"
APP_BACKEND = (
    SAMPLES / "advanced_app_client" / "lib" / "backend" / "in_memory_app_backend.dart"
)
ADMIN_BACKEND = (
    SAMPLES
    / "advanced_authadmin_client"
    / "lib"
    / "backend"
    / "in_memory_admin_backend.dart"
)

#: One ``INSERT INTO auth_users ... VALUES ...;`` statement.
USERS_INSERT = re.compile(r"INSERT\s+INTO\s+auth_users\b(.*?);", re.S | re.I)
#: A row's leading ``(id, 'username'``.
USERS_ROW = re.compile(r"\(\s*\d+\s*,\s*'(\w+)'")
#: The body of ``static const Map<String, String> demoAccounts = { ... };``.
DEMO_ACCOUNTS = re.compile(r"demoAccounts\s*=\s*\{(.*?)\};", re.S)
#: The body of ``const Map<String, String> _demoPasswords = { ... };``.
DEMO_PASSWORDS = re.compile(r"_demoPasswords\s*=\s*\{(.*?)\};", re.S)
#: A map key, ``'alice':``.
MAP_KEY = re.compile(r"'(\w+)'\s*:")
#: An admin seed call, ``user('u-admin', 'admin', ...``.
ADMIN_USER = re.compile(r"\buser\(\s*'[^']*'\s*,\s*'(\w+)'")

#: A marked region, possibly inline. Group 1 is the roster, group 2 the body.
REGION = re.compile(
    r"<!--\s*account-roster:\s*(\S+)\s*-->(.*?)<!--\s*/account-roster\s*-->",
    re.S,
)
#: A backticked word, optionally an offline id (``u-alice``).
NAMED = re.compile(r"`(?:u-)?([a-z]+)`")
#: The reserved phrase.
RESERVED = re.compile(r"seeded\s+live\s+account", re.I)
#: An offline fake's id.
OFFLINE_ID = re.compile(r"`u-[a-z]+`")

OFFLINE = ("app-offline", "admin-offline")


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def auth_db_roster() -> set[str]:
    names: set[str] = set()
    for sql in sorted(AUTH_MIGRATIONS.rglob("*.sql")):
        for statement in USERS_INSERT.finditer(_read(sql)):
            names.update(USERS_ROW.findall(statement.group(1)))
    return names


def _map_keys(pattern: re.Pattern[str], path: Path) -> set[str]:
    match = pattern.search(_read(path))
    return set(MAP_KEY.findall(match.group(1))) if match else set()


def rosters() -> dict[str, set[str]]:
    """Every roster this gate knows, read from its seed."""
    return {
        "auth-db": auth_db_roster(),
        "app-offline": _map_keys(DEMO_ACCOUNTS, APP_BACKEND),
        "admin-offline": set(ADMIN_USER.findall(_read(ADMIN_BACKEND))),
    }


@dataclass
class Region:
    document: Path
    line: int
    roster: str
    body: str

    @property
    def named(self) -> set[str]:
        return set(NAMED.findall(self.body))


def regions(document: Path) -> list[Region]:
    text = _read(document)
    return [
        Region(document, text.count("\n", 0, m.start()) + 1, m.group(1), m.group(2))
        for m in REGION.finditer(text)
    ]


def documents() -> list[Path]:
    return sorted(
        p
        for p in SAMPLES.rglob("*.md")
        if not any(part.startswith(".") for part in p.relative_to(SAMPLES).parts)
    )


@dataclass
class Findings:
    faults: list[str] = field(default_factory=list)


def audit_region(region: Region, known: dict[str, set[str]]) -> list[str]:
    where = f"{region.document.relative_to(REPO_ROOT)}:{region.line}"
    if region.roster not in known:
        return [f"UNREAD   {where}  names no known roster `{region.roster}`"]
    roster = known[region.roster]
    every = set().union(*known.values())
    faults = [
        f"MISSING  {where}  ({region.roster}) does not name `{name}`"
        for name in sorted(roster - region.named)
    ]
    faults += [
        f"FOREIGN  {where}  ({region.roster}) names `{name}`, which it does not seed"
        for name in sorted((region.named & every) - roster)
    ]
    if region.roster in OFFLINE and RESERVED.search(region.body):
        faults.append(
            f"VOCAB    {where}  ({region.roster}) uses the phrase reserved for"
            " the auth_db rows"
        )
    return faults


def audit_vocabulary(document: Path) -> list[str]:
    faults = []
    for number, line in enumerate(_read(document).splitlines(), start=1):
        if RESERVED.search(line) and OFFLINE_ID.search(line):
            faults.append(
                f"VOCAB    {document.relative_to(REPO_ROOT)}:{number}  the phrase"
                " reserved for the auth_db rows sits beside an offline id"
            )
    return faults


def audit_sources(known: dict[str, set[str]]) -> list[str]:
    faults = [
        f"UNREAD   the `{name}` roster read as empty from its seed"
        for name, roster in known.items()
        if not roster
    ]
    passwords = _map_keys(DEMO_PASSWORDS, AUTH_PASSWORDS)
    if not passwords:
        faults.append("UNREAD   `_demoPasswords` could not be read")
    elif known["auth-db"] and passwords != known["auth-db"]:
        for name in sorted(known["auth-db"] - passwords):
            faults.append(f"SOURCE   `{name}` is seeded in auth_db with no demo password")
        for name in sorted(passwords - known["auth-db"]):
            faults.append(f"SOURCE   `{name}` has a demo password and no auth_db row")
    return faults


def audit(known: dict[str, set[str]]) -> tuple[list[Region], list[str]]:
    found = [r for d in documents() for r in regions(d)]
    faults = audit_sources(known)
    for region in found:
        faults += audit_region(region, known)
    for document in documents():
        faults += audit_vocabulary(document)
    return found, faults


def self_test(known: dict[str, set[str]]) -> int:
    found = [r for d in documents() for r in regions(d)]
    if not found:
        print("self-test: no marked rosters to perturb", file=sys.stderr)
        return 2
    every = set().union(*known.values())
    checks = 0
    for region in found:
        roster = known.get(region.roster, set())
        dropped = sorted(roster)[0]
        stripped = Region(
            region.document,
            region.line,
            region.roster,
            re.sub(rf"`(?:u-)?{dropped}`", "", region.body),
        )
        if not any(f.startswith("MISSING") for f in audit_region(stripped, known)):
            print(f"self-test: dropping `{dropped}` raised no MISSING", file=sys.stderr)
            return 2
        checks += 1
        foreign = sorted(every - roster)
        if foreign:
            planted = Region(
                region.document,
                region.line,
                region.roster,
                region.body + f" `{foreign[0]}`",
            )
            if not any(f.startswith("FOREIGN") for f in audit_region(planted, known)):
                print(
                    f"self-test: listing `{foreign[0]}` raised no FOREIGN",
                    file=sys.stderr,
                )
                return 2
            checks += 1
        if region.roster in OFFLINE:
            misused = Region(
                region.document,
                region.line,
                region.roster,
                region.body + " the seeded live accounts",
            )
            if not any(f.startswith("VOCAB") for f in audit_region(misused, known)):
                print("self-test: the reserved phrase raised no VOCAB", file=sys.stderr)
                return 2
            checks += 1
    print(f"self-test: MISSING, FOREIGN and VOCAB all fire ({checks} perturbations)")
    return 0


def main(argv: list[str]) -> int:
    known = rosters()
    if "--self-test" in argv:
        return self_test(known)

    found, faults = audit(known)
    # A gate that stops finding its markers reports a clean sample.
    if not found:
        print(f"no account-roster regions found under {SAMPLES}", file=sys.stderr)
        return 2

    for fault in faults:
        print(fault)
    print(
        "\nrosters: "
        + ", ".join(f"{name} {len(roster)}" for name, roster in known.items())
        + f"\nregions read: {len(found)}\nfaults: {len(faults)}"
    )
    return report_faults(len(faults))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
