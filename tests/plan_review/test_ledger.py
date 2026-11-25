"""Tests for skills/review/plan-review/ledger.py, run through its CLI."""

import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "skills/review/plan-review/ledger.py"
FIXTURES = Path(__file__).parent / "fixtures"


def load_ledger():
    spec = importlib.util.spec_from_file_location("ledger", LEDGER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ledger = load_ledger()


def run(*args, stdin=""):
    return subprocess.run(
        [sys.executable, str(LEDGER), *map(str, args)],
        input=stdin,
        capture_output=True,
        text=True,
    )


def ok(*args, stdin=""):
    result = run(*args, stdin=stdin)
    assert result.returncode == 0, result.stderr
    return result.stdout


def fails(*args, stdin=""):
    result = run(*args, stdin=stdin)
    assert result.returncode != 0
    return result.stderr


@pytest.fixture
def plan(tmp_path):
    path = tmp_path / "plan.md"
    shutil.copy(FIXTURES / "plan.md", path)
    return path


def rows(path):
    p = ledger.Plan(str(path))
    return {r[0]: r for r in p.rows}, p.signals, p.header


def apply_round(plan, n, session="ses_1"):
    return ok("apply", plan, FIXTURES / f"round{n}.md", session)


# init


def test_init_appends_an_empty_ledger(plan):
    plan.write_text(plan.read_text() + "\n\n\n")
    assert "ledger added" in ok("init", plan)
    text = plan.read_text()
    assert text.count("## Review ledger") == 1
    assert "\n\n\n## Review ledger" not in text, "trailing blank lines are trimmed"
    assert "Reviewer: — · Session: — · Rounds: 0 · Anchor: v1 · Status: in review" in text
    assert "| ID | Sev | Raised |" in text
    assert "### Signals" in text and "### Escalations" in text
    table, signals, _ = rows(plan)
    assert table == {} and signals == []


def test_init_refuses_a_plan_with_a_ledger(plan):
    ok("init", plan)
    assert "already has a ledger" in fails("init", plan)


def test_init_needs_an_anchor(tmp_path):
    path = tmp_path / "plan.md"
    path.write_text("# A plan\n\n## Steps\n")
    assert "no `## Anchor v<K>` heading" in fails("init", path)


# apply


def test_apply_maps_new_keys_and_defers_low_findings(plan):
    ok("init", plan)
    out = apply_round(plan, 1)
    assert "key map: R1-F1 → L-01, R1-F2 → L-02" in out
    assert "decide (new or regressed): L-01" in out

    table, signals, header = rows(plan)
    assert table["L-01"] == [
        "L-01",
        "🔴",
        "1 · R1-F1",
        "§Backfill — The backfill has no rollback.",
        "",
        "open",
        "none",
        "—",
    ]
    assert table["L-02"][4:6] == ["defer — low", "deferred"]
    assert table["L-02"][3] == r"§Steps — Step names use a \| pipe."
    assert signals == [["1", "1", "—", "—", "—", "—", "§Backfill (1)"]]
    assert header["Rounds"] == "1"
    assert header["Session"] == "ses_1"
    assert header["Reviewer"] == "gpt-test"


def test_apply_closes_only_the_decision_a_disposition_matches(plan):
    ok("init", plan)
    apply_round(plan, 1)
    ok("set", plan, stdin="L-01 | decision | accept — add a rollback\n")
    out = apply_round(plan, 2)

    table, _, _ = rows(plan)
    assert table["L-01"][5] == "resolved"
    assert table["L-02"][5] == "deferred", "a deferred row takes no disposition"
    assert "L-02 rebuttal-accepted (decision: defer — low, status: deferred)" in out


def test_apply_translates_depends_and_reports_shifts_and_repeats(plan):
    ok("init", plan)
    apply_round(plan, 1)
    ok("set", plan, stdin="L-01 | decision | accept — add a rollback\n")
    out = apply_round(plan, 2)

    table, signals, _ = rows(plan)
    assert table["L-03"][2] == "2 · R2-F1 · fix-caused"
    assert table["L-03"][6] == "load-bearing (A2) drift, reviewer"
    assert table["L-03"][7] == "L-01"
    assert table["L-04"][7] == "L-03", "a key from the same report maps to its new ID"
    assert "L-05" not in table, "a repeated key is dropped"
    assert "repeated keys (first kept): R2-F2" in out
    assert "load-bearing shifts: L-03: load-bearing (A2) drift" in out
    assert signals[1] == ["2", "2", "50%", "50%", "0%", "—", "§Staging (2)"]


def test_apply_reopens_a_regression(plan):
    ok("init", plan)
    apply_round(plan, 1)
    ok("set", plan, stdin="L-01 | decision | accept — add a rollback\n")
    apply_round(plan, 2)
    out = apply_round(plan, 3)

    table, _, _ = rows(plan)
    assert table["L-01"][2] == "1 · R1-F1 · regression r3"
    assert table["L-01"][5] == "open"
    assert "decide (new or regressed): L-01" in out
    assert "still open (keep or change the decision): L-03, L-04" in out
    assert "recommend: stop (the open items need a human)" in out


def test_apply_refuses_a_round_out_of_order(plan):
    ok("init", plan)
    err = fails("apply", plan, FIXTURES / "round2.md", "ses_1")
    assert "the report is round 2, and the ledger holds 0 rounds" in err


def test_apply_needs_a_ledger(plan):
    assert "Run `ledger.py init` first" in fails("apply", plan, FIXTURES / "round1.md", "s")


def test_apply_needs_a_report_header(plan, tmp_path):
    ok("init", plan)
    report = tmp_path / "bad.md"
    report.write_text("no header here\n")
    assert "has no header line" in fails("apply", plan, report, "s")


# set


def test_set_changes_cells_and_the_header(plan):
    ok("init", plan)
    apply_round(plan, 1)
    ok(
        "set",
        plan,
        stdin="L-01 | decision | rebut — a | pipe\nL-01 | status | escalated\n"
        "header | Status | escalated\n",
    )
    table, _, header = rows(plan)
    assert table["L-01"][4] == r"rebut — a \| pipe"
    assert table["L-01"][5] == "escalated"
    assert header["Status"] == "escalated"


def test_set_defer_closes_a_low_finding_at_once(plan, tmp_path):
    ok("init", plan)
    apply_round(plan, 1)
    ok("set", plan, stdin="L-02 | status | open\nL-02 | decision | defer — later\n")
    table, _, _ = rows(plan)
    assert table["L-02"][5] == "deferred"


@pytest.mark.parametrize(
    ("edit", "message"),
    [
        ("L-01 | colour | red", "unknown field `colour`"),
        ("L-99 | status | open", "the ledger has no L-99"),
        ("L-01 status open", "cannot read `L-01 status open`"),
    ],
)
def test_set_rejects_bad_edits(plan, edit, message):
    ok("init", plan)
    apply_round(plan, 1)
    assert message in fails("set", plan, stdin=edit + "\n")


# show


def test_show_prints_the_ledger_and_leaves_the_plan_alone(plan):
    ok("init", plan)
    apply_round(plan, 1)
    before = plan.read_text()
    out = ok("show", plan)
    assert plan.read_text() == before
    assert out.startswith("## Review ledger\n")
    assert "| L-01 |" in out and "### Signals" in out and "### Escalations" in out
    assert "## Anchor" not in out


def test_show_needs_a_ledger(plan):
    assert "Run `ledger.py init` first" in fails("show", plan)


def test_usage_on_bad_arguments():
    assert "ledger.py init" in fails("frobnicate")


# parse_report


def test_parse_report_reads_fields():
    header, dispositions, findings = ledger.parse_report(str(FIXTURES / "round2.md"))
    assert header["Round"] == "2"
    assert dispositions == [("L-01", "verified-fixed"), ("L-02", "rebuttal-accepted")]
    first = findings[0]
    assert first["sev"] == "🔴"
    assert first["key"] == "R2-F1"
    assert first["tag"] == "fix-caused"
    assert first["shift"] == "load-bearing (A2) drift"
    assert first["depends"] == "L-01"
    assert first["section"] == "§Staging"
    assert first["finding"] == "§Staging — The staging table changes `benefit`."
