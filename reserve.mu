#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
user    = m.require_login(token)
item_id = os.environ.get("var_id", "")
action  = os.environ.get("var_action", "")
res_id  = os.environ.get("var_rid", "")

# Cancel reservation
if action == "cancel" and res_id:
    try:
        m.delete_reservation(int(res_id), user["id"])
        m.print_header()
        m.success("Reservation cancelled.")
        print(m.nav_bar(user, token))
    except Exception as e:
        m.print_header()
        m.error(f"Error: {e}")
        print(m.nav_bar(user, token))
    exit()

# Create reservation
try:
    item_id = int(item_id)
    item    = m.get_item(item_id)
    if not item:
        raise ValueError()
except Exception:
    m.print_header()
    m.error("Item not found.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/item_detail.mu`id={item_id}|session={token}"
print(f">{m.site_name} — Reserve Item")
print(m.nav_bar(user, token, back_url=back))

submitted = action == "reserve" or "field_reserved_from" in os.environ

if submitted:
    try:
        from_str  = os.environ.get("field_reserved_from", "").strip()
        until_str = os.environ.get("field_reserved_until", "").strip()
        qty_str   = os.environ.get("field_quantity", "1").strip()
        notes     = os.environ.get("field_notes", "").strip()[:200]

        if not from_str or not until_str:
            raise ValueError("From and until dates are required.")
        try:
            from datetime import datetime as _dt
            from_db  = _dt.strptime(from_str.strip(),  "%d-%m-%Y").strftime("%Y-%m-%d")
            until_db = _dt.strptime(until_str.strip(), "%d-%m-%Y").strftime("%Y-%m-%d")
        except ValueError:
            raise ValueError("Invalid date format. Please use DD-MM-YYYY (e.g. 25-12-2026).")
        qty = int(qty_str) if qty_str else 1
        if qty < 1:
            raise ValueError("Quantity must be at least 1.")
        if from_db > until_db:
            raise ValueError("From date must be before until date.")

        m.create_reservation(item_id, user["id"], qty, from_db, until_db, notes)
        m.success("Reservation created.")
        print(f"`[-> To Item`{m.page_path}/item_detail.mu`id={item_id}|session={token}]")
        exit()
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

print()
print(f">>Reserve: {item['name']}")
print(f"`F777Current stock:`f  {item['stock']}")
print()
print(f"From     `B333`<24|reserved_from`>`b  `F555DD-MM-YYYY`f")
print(f"Until    `B333`<24|reserved_until`>`b  `F555DD-MM-YYYY`f")
print(f"Quantity `B333`<8|quantity`1>`b")
print(f"Note     `B333`<40|notes`>`b")
print()
print(f"`[Reserve`{m.page_path}/reserve.mu`*|action=reserve|id={item_id}|session={token}]")
m.print_footer()
