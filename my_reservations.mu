#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
user  = m.require_login(token)

print(f">{m.site_name} — My Reservations")
m.print_header()
print(m.nav_bar(user, token))

reservations = m.get_user_reservations(user["id"])

if not reservations:
    print()
    m.notice("No active reservations.")
else:
    print()
    print(f"`F777{len(reservations)} reservation(s)`f")
    print("-")
    for res in reservations:
        print(f"`!{res['item_name']}`!  `F777#{res['item_number']}`f" if res["item_number"]
              else f"`!{res['item_name']}`!")
        print(f"`F777{m.fmt_date(res['reserved_from'])} – {m.fmt_date(res['reserved_until'])}`f"
              f"  {res['quantity']}x")
        if res["notes"]:
            print(f"`F555{res['notes']}`f")
        print(f"`[Cancel`{m.page_path}/reserve.mu`action=cancel|rid={res['id']}|session={token}]")
        print()
    m.print_footer()
