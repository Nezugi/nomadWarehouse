#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main as m

print("#!c=0")
token  = os.environ.get("var_session", "")
user   = m.require_admin(token)
action = os.environ.get("var_action", "")

back = f"{m.page_path}/admin/admin.mu`session={token}"
print(f">{m.site_name} — Overdue Loans")
print(m.nav_bar(user, token, back_url=back))

# ── Write off loan ────────────────────────────
if action == "writeoff":
    try:
        lid   = int(os.environ.get("var_lid", ""))
        notes = os.environ.get("field_notes", "").strip()[:200]
        m.close_loan_admin(lid, notes=notes)
        m.success("Loan written off.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Mark as returned ──────────────────────────
if action == "returned":
    try:
        lid   = int(os.environ.get("var_lid", ""))
        notes = os.environ.get("field_notes", "").strip()[:200]
        m.return_loan(lid, notes=notes)
        m.success("Loan marked as returned.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── All open loans (including non-overdue) ────
con = m.get_db()
all_open = con.execute("""
    SELECT l.*, i.name AS item_name, i.item_number, u.username,
           CAST(julianday('now') - julianday(l.due_date) AS INTEGER) AS days_overdue
    FROM loans l
    JOIN items i ON l.item_id=i.id
    JOIN users u ON l.user_id=u.id
    WHERE l.returned_at IS NULL
    ORDER BY l.is_overdue DESC, days_overdue DESC, l.due_date
""").fetchall()
con.close()

overdue  = [l for l in all_open if l["is_overdue"]]
due_soon = [l for l in all_open if not l["is_overdue"]]

print()

# ── Overdue loans ─────────────────────────────
if overdue:
    print(f">>Overdue ({len(overdue)})")
    print("-")
    for loan in overdue:
        days = loan["days_overdue"] or 0
        num  = f" #{loan['item_number']}" if loan["item_number"] else ""
        print(f"`Ff55{days} day(s) overdue`f  "
              f"`!{loan['item_name']}`!{num}  "
              f"`F777{loan['username']}`f  "
              f"due: {m.fmt_date(loan['due_date'])}  "
              f"{loan['quantity']}x")
        print()
        # Note field + action links
        print(f"Note `B333`<40|notes`>`b")
        print(f"`[Returned`{m.page_path}/admin/overdue.mu`*|action=returned|lid={loan['id']}|session={token}]"
              f"  "
              f"`[Write Off`{m.page_path}/admin/overdue.mu`*|action=writeoff|lid={loan['id']}|session={token}]")
        print()
    print("-")
else:
    m.success("No overdue loans.")

# ── Loans due soon (not yet overdue) ─────────
if due_soon:
    print()
    print(f">>Open Loans — not yet overdue ({len(due_soon)})")
    print("-")
    for loan in due_soon:
        days = loan["days_overdue"] or 0  # negative = days remaining
        remaining = -days if days <= 0 else 0
        num  = f" #{loan['item_number']}" if loan["item_number"] else ""
        print(f"`F777{remaining} day(s) remaining`f  "
              f"`!{loan['item_name']}`!{num}  "
              f"`F777{loan['username']}`f  "
              f"due: {m.fmt_date(loan['due_date'])}  "
              f"{loan['quantity']}x")
    print("-")

if not all_open:
    print()
    m.notice("No open loans.")
m.print_footer()
