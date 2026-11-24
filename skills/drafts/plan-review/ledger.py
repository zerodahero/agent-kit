#!/usr/bin/env python3
"""Maintains the review ledger at the end of a plan.

  ledger.py init  <plan>                      append an empty ledger
  ledger.py apply <plan> <report> <session>   merge one round's report
  ledger.py set   <plan> < edits              set cells, one edit per line

`apply` maps the report's new keys to ledger IDs, applies its dispositions, reopens
regressions, adds a signals row, and prints what the author decides next. `set` reads
lines `L-14 | decision | accept — reason`, `L-14 | status | escalated`, or
`header | Status | converged`. LEDGER-FORMAT.md defines every field.
"""

import re
import sys
from collections import Counter

COLS = ["ID", "Sev", "Raised", "Finding", "Claude's decision", "Status", "Shift", "Depends on"]
SIGNAL_COLS = ["Round", "New 🔴/🟡", "fix-caused", "new-surface", "missed-earlier", "Ping-pong", "Hotspot"]
DISPOSITION_STATUS = {
    "verified-fixed": "resolved",
    "rebuttal-accepted": "rebuttal-accepted",
    "deferral-accepted": "deferred",
    "disputed": "disputed",
    "still-open": "open",
}
# A closing disposition applies only to the decision it closes, per the closure table.
CLOSES = {"verified-fixed": "accept", "rebuttal-accepted": "rebut", "deferral-accepted": "defer"}
OPEN_STATUSES = ("open", "disputed", "escalated")
SEVS = ("🔴", "🟡", "🔵")
PIPE = re.compile(r"(?<!\\)\|")


def die(msg):
    sys.exit(f"error: {msg}")


def esc(text):
    return text.replace("|", r"\|").strip()


def row_line(cells):
    return "| " + " | ".join(cells) + " |"


def table_head(cols):
    return [row_line(cols), "|" + "---|" * len(cols)]


def parse_row(line):
    return [c.strip() for c in PIPE.split(line.strip())[1:-1]]


class Plan:
    """The plan file, with the ledger section split into its parts."""

    def __init__(self, path):
        self.path = path
        with open(path, encoding="utf-8") as f:
            self.lines = f.read().split("\n")
        try:
            self.start = self.lines.index("## Review ledger")
        except ValueError:
            self.start = None
            return
        self.end = next(
            (i for i in range(self.start + 1, len(self.lines)) if self.lines[i].startswith("## ")),
            len(self.lines),
        )
        self.header_at = self.find(lambda l: l.startswith("Reviewer:"), "the header line")
        self.ledger_at = self.find(lambda l: l.startswith("| ID |"), "the ledger table")
        self.signals_at = self.find(lambda l: l.startswith("| Round |"), "the signals table")
        self.rows = [parse_row(l) for l in self.body(self.ledger_at)]
        self.signals = [parse_row(l) for l in self.body(self.signals_at)]
        self.header = dict(
            part.split(": ", 1) for part in self.lines[self.header_at].split(" · ") if ": " in part
        )

    def find(self, test, what):
        for i in range(self.start, self.end):
            if test(self.lines[i]):
                return i
        die(f"the ledger has no {what}. Run `ledger.py init` on a plan without a ledger.")

    def body(self, head_at):
        out = []
        for line in self.lines[head_at + 2 : self.end]:
            if not line.startswith("|"):
                break
            out.append(line)
        return out

    def row(self, lid):
        for r in self.rows:
            if r[0] == lid:
                return r
        die(f"the ledger has no {lid}.")

    def save(self):
        header = " · ".join(f"{k}: {v}" for k, v in self.header.items())
        parts = [
            (self.header_at, 1, [header]),
            (self.ledger_at, 2 + len(self.body(self.ledger_at)), table_head(COLS) + [row_line(r) for r in self.rows]),
            (self.signals_at, 2 + len(self.body(self.signals_at)), table_head(SIGNAL_COLS) + [row_line(r) for r in self.signals]),
        ]
        # Replace from the bottom up, so earlier indexes stay valid.
        for at, length, new in sorted(parts, reverse=True):
            self.lines[at : at + length] = new
        with open(self.path, "w", encoding="utf-8") as f:
            f.write("\n".join(self.lines))


def init(path):
    plan = Plan(path)
    if plan.start is not None:
        die("the plan already has a ledger.")
    anchor = re.search(r"^## Anchor (v\d+)", "\n".join(plan.lines), re.M)
    if not anchor:
        die("the plan has no `## Anchor v<K>` heading. Write the anchor first.")
    skeleton = [
        "## Review ledger",
        "",
        f"Reviewer: — · Session: — · Rounds: 0 · Anchor: {anchor.group(1)} · Status: in review",
        "",
        *table_head(COLS),
        "",
        "### Signals",
        "",
        *table_head(SIGNAL_COLS),
        "",
        "### Escalations",
        "",
        "None.",
        "",
    ]
    lines = plan.lines
    while lines and lines[-1] == "":
        lines.pop()
    plan.lines = lines + [""] + skeleton
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(plan.lines))
    print(f"ledger added to {path}")


def parse_report(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    head = next((l for l in lines if l.startswith("Plan: ")), None)
    if not head:
        die(f"{path} has no header line.")
    header = dict(p.split(": ", 1) for p in head.split(" · ") if ": " in p)
    dispositions = []
    findings = []
    for line in lines:
        m = re.match(r"^- (L-\d+) · ([a-z-]+) · ", line)
        if m:
            dispositions.append((m.group(1), m.group(2)))
            continue
        if not line.startswith("- ") or line[2:3] not in SEVS:
            continue
        fields = line[2:].split(" · ")
        f = {"sev": fields[0][0], "key": fields[1], "tag": "", "shift": "none", "depends": "—"}
        rest = fields[2:]
        while rest and not rest[0].startswith(("Shift:", "Depends on:", "§")):
            f["tag"] = rest.pop(0).split(":")[0]
        if rest and rest[0].startswith("Shift:"):
            f["shift"] = rest.pop(0)[len("Shift:") :].strip()
        if rest and rest[0].startswith("Depends on:"):
            f["depends"] = rest.pop(0)[len("Depends on:") :].strip()
        text = " · ".join(rest)
        section, _, what = text.partition(" — ")
        first = re.split(r"(?<=[.;])\s", what.strip(), maxsplit=1)[0]
        f["section"] = section.strip()
        f["finding"] = f"{section.strip()} — {first}" if what else text
        findings.append(f)
    return header, dispositions, findings


def apply(path, report, session):
    plan = Plan(path)
    if plan.start is None:
        die("the plan has no ledger. Run `ledger.py init` first.")
    header, dispositions, findings = parse_report(report)
    rnd = int(header.get("Round", "0"))
    done = int(plan.header.get("Rounds", "0"))
    if rnd != done + 1:
        die(f"the report is round {rnd}, and the ledger holds {done} rounds. Merge round {done + 1} next.")

    # Map every new key first, so Depends on can name keys from the same report.
    next_id = max((int(r[0][2:]) for r in plan.rows), default=0) + 1
    keymap = {}
    repeats = []
    unique = []
    seen = set()
    for f in findings:
        if f["key"] in seen:
            repeats.append(f["key"])
            continue
        seen.add(f["key"])
        unique.append(f)
        if re.match(r"^R\d+-F\d+$", f["key"]):
            keymap[f["key"]] = f"L-{next_id:02d}"
            next_id += 1
    findings = unique

    def translate(depends):
        return ", ".join(keymap.get(d.strip(), d.strip()) for d in depends.split(","))

    mismatched = []
    for lid, disp in dispositions:
        row = plan.row(lid)
        wanted = CLOSES.get(disp)
        if row[5] not in OPEN_STATUSES or disp not in DISPOSITION_STATUS or (
            wanted and not row[4].startswith(wanted)
        ):
            mismatched.append(f"{lid} {disp} (decision: {row[4] or 'none'}, status: {row[5]})")
            continue
        row[5] = DISPOSITION_STATUS[disp]

    needs = []
    shifts = []
    for f in findings:
        shift = f["shift"] if f["shift"] == "none" else f"{f['shift']}, reviewer"
        if f["shift"].startswith("load-bearing"):
            shifts.append(f"{keymap.get(f['key'], f['key'])}: {f['shift']}")
        if f["key"] in keymap:
            lid = keymap[f["key"]]
            raised = f"{rnd} · {f['key']}" + (f" · {f['tag']}" if f["tag"] else "")
            low = f["sev"] == "🔵"
            plan.rows.append([
                lid, f["sev"], raised, esc(f["finding"]),
                "defer — low" if low else "", "deferred" if low else "open",
                esc(shift), translate(f["depends"]),
            ])
            if not low:
                needs.append(lid)
        else:
            # A ledger ID in the key column is a regression of a resolved item.
            row = plan.row(f["key"])
            row[2] += f" · regression r{rnd}"
            row[5] = "open"
            row[6] = esc(shift)
            needs.append(f["key"])

    still = [r[0] for r in plan.rows
             if r[5] in ("open", "disputed") and r[1] != "🔵" and r[0] not in needs]

    blocking = [f for f in findings if f["key"] in keymap and f["sev"] != "🔵"]
    def share(tag):
        if rnd == 1 or not blocking:
            return "—"
        n = sum(1 for f in blocking if f["tag"] == tag)
        return f"{round(100 * n / len(blocking))}%"
    sections = Counter(f["section"] for f in findings if f["key"] in keymap)
    hotspot = "—"
    if sections:
        name, count = sections.most_common(1)[0]
        hotspot = f"{esc(name)} ({count})"
    plan.signals.append([str(rnd), str(len(blocking)), share("fix-caused"), share("new-surface"),
                         share("missed-earlier"), "—", hotspot])

    plan.header["Reviewer"] = header.get("Reviewer", plan.header.get("Reviewer", "—"))
    plan.header["Session"] = session
    plan.header["Rounds"] = str(rnd)
    plan.header["Anchor"] = header.get("Anchor", plan.header.get("Anchor", "—"))
    plan.save()

    fix_caused = sum(1 for f in blocking if f["tag"] == "fix-caused")
    print(f"round {rnd} merged: {len(findings)} findings, {len(dispositions)} dispositions")
    print("key map: " + (", ".join(f"{k} → {v}" for k, v in keymap.items()) or "none"))
    print(f"new 🔴/🟡: {len(blocking)}, fix-caused: {fix_caused}")
    print("load-bearing shifts: " + ("; ".join(shifts) or "none"))
    print("disputed: " + (", ".join(r[0] for r in plan.rows if r[5] == "disputed") or "none"))
    print(f"recommend: {header.get('Recommend', 'continue')}")
    print("repeated keys (first kept): " + (", ".join(repeats) or "none"))
    print("dispositions not applied (check by hand): " + ("; ".join(mismatched) or "none"))
    print("decide (new or regressed): " + (", ".join(needs) or "none"))
    print("still open (keep or change the decision): " + (", ".join(still) or "none"))


def set_cells(path):
    plan = Plan(path)
    if plan.start is None:
        die("the plan has no ledger.")
    columns = {"decision": 4, "status": 5, "shift": 6, "depends": 7, "finding": 3}
    for raw in sys.stdin.read().splitlines():
        if not raw.strip():
            continue
        parts = [p.strip() for p in raw.split("|", 2)]
        if len(parts) != 3:
            die(f"cannot read `{raw}`. Write `<ID> | <field> | <value>`.")
        target, field, value = parts
        if target == "header":
            plan.header[field] = value
            continue
        if field not in columns:
            die(f"unknown field `{field}`. Use one of: {', '.join(columns)}.")
        row = plan.row(target)
        row[columns[field]] = esc(value)
        # A deferral on a 🔵 closes at once; every other decision waits on the reviewer.
        if field == "decision" and value.startswith("defer") and row[1] == "🔵":
            row[5] = "deferred"
    plan.save()
    print("ledger updated")


def main():
    args = sys.argv[1:]
    if args[:1] == ["init"] and len(args) == 2:
        init(args[1])
    elif args[:1] == ["apply"] and len(args) == 4:
        apply(*args[1:])
    elif args[:1] == ["set"] and len(args) == 2:
        set_cells(args[1])
    else:
        die(__doc__)


if __name__ == "__main__":
    main()
