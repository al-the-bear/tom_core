#!/usr/bin/env python3
"""The last line every gate prints, and the reason it is a shared function.

Each checker in this folder ends by deciding an exit status from a number it
has just computed -- dangling references, defective documents, miscalled
constructors. Until this module existed the number was printed in the
checker's own words (``faults``, ``unresolvable references``, ``claims naming
a non-kind``, ``citing a missing section``) and the exit status was derived
separately, a line or two below.

Two things follow from that, and both matter to a runner:

**The count was not addressable.** A checker's summary block is prose written
for a person, and no two are worded alike. Anything wanting to *compare* today's
count against a recorded one -- which is what makes a backlog shrink instead of
sit -- had to carry a regex per checker, in a different file from the checker.
That is the same shape as the problem the checkers exist to solve: a fact
restated somewhere it cannot be kept true.

**Nothing tied the count to the status.** A checker could report faults and
exit 0, or exit 1 having reported none, and no reader would be any the wiser.

[report_faults] fixes both by construction: the count is printed in a fixed
form the runner can read, and the exit status is computed *from that same
number* rather than beside it. A gate that uses it cannot disagree with itself.

Adding a checker:

    from gate_report import report_faults
    ...
    return report_faults(len(faults))

``tool/check_gates.py`` discovers ``check_*.py`` automatically and fails on any
checker whose output carries no [FAULT_LINE], so a new gate is enforced from
the day it lands rather than from the day someone remembers to register it.
"""

from __future__ import annotations

#: The sentinel. Uppercase and hyphenated so it cannot collide with a summary
#: label, and so a person scanning console output can see it is a contract.
FAULT_LINE = "GATE-FAULTS"


def report_faults(faults: int) -> int:
    """Print the machine-readable fault total and return the exit status.

    Call this as the last statement of a checker's ``main``, passing the number
    of faults it found -- the finest-grained count it has, not the number of
    files those faults are spread across. A gate baselined on defective *files*
    cannot tell "one more bad row in a document already known to be bad" from
    no change at all, which is most of what regression looks like here.
    """
    if faults < 0:
        raise ValueError(f"a fault count cannot be negative: {faults}")
    print(f"{FAULT_LINE}: {faults}")
    return 1 if faults else 0
