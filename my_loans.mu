#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
user  = m.require_login(token)

print(f">{m.site_name} — My Loans")
m.print_header()
print(m.nav_bar(user, token))

loans = m.get_user_loans(user["id"], only_open=True)

if not loans:
    print()
    m.notice("No open loans.")
else:
    print()
    print(f"`F777{len(loans)} open loan(s)`f")
    print("-")
    for loan in loans:
        if loan["is_overdue"]:
            status = "`Ff55 OVERDUE`f"
        else:
            status = "`F1a6 Open`f"
        print(f"{status}  {m.item_link({'id': loan['item_id'], 'name': loan['item_name']}, token)}")
        print(f"`F555#{loan['item_number']}`f  {loan['location']}" if loan["item_number"] else f"`F555{loan['location']}`f")
        print(f"`F777Return by:`f  {m.fmt_date(loan['due_date'])}  {loan['quantity']}x")
        print(f"`[-> Return`{m.page_path}/store.mu`id={loan['item_id']}|session={token}]")
        print()
    print("-")

# Completed loans
past = m.get_user_loans(user["id"], only_open=False)
past = [l for l in past if l["returned_at"]]
if past:
    print()
    print(">>Returned (last 10)")
    for loan in past[-10:]:
        print(f"`F555{m.fmt_date(loan['due_date'])} · "
              f"returned {m.fmt_date(loan['returned_at'])} · "
              f"{loan['item_name']} · {loan['quantity']}x`f")
        if loan["return_notes"]:
            print(f"`F444  {loan['return_notes']}`f")
m.print_footer()
