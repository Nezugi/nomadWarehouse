#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
user    = m.get_session_user(token)
item_id = os.environ.get("var_id", "")
action  = os.environ.get("var_action", "")

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

if not m.can_take(user, item["category_id"]):
    m.print_header()
    m.error("Permission denied — cannot withdraw items.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/item_detail.mu`id={item_id}|session={token}"
print(f">{m.site_name} — Take Item")
print(m.nav_bar(user, token, back_url=back))

reserved  = m.get_reserved_qty(item_id)
available = max(0, item["stock"] - reserved)

submitted = action == "take" or "field_quantity" in os.environ

if submitted:
    try:
        qty_str    = os.environ.get("field_quantity", "1").strip()
        reason_str = os.environ.get("field_reason", "").strip()
        is_loan    = os.environ.get("field_is_loan", "") == "yes"
        due_str    = os.environ.get("field_due_date", "").strip()
        notes      = os.environ.get("field_notes", "").strip()[:200]

        qty = int(qty_str) if qty_str else 1
        if qty < 1:
            raise ValueError("Quantity must be at least 1.")
        if qty > available:
            if reserved > 0:
                raise ValueError(
                    f"Only {available} {item['unit']} available "
                    f"({reserved} reserved, {item['stock']} total)."
                )
            else:
                raise ValueError(f"Only {item['stock']} {item['unit']} available.")

        reason_id = int(reason_str) if reason_str else None

        mov_id = m.record_movement(item_id, user["id"], "take", reason_id, qty, notes=notes)

        if is_loan:
            if not due_str:
                raise ValueError("Return date is required for a loan.")
            # Input DD-MM-YYYY → DB format YYYY-MM-DD
            try:
                from datetime import datetime as _dt
                due_db = _dt.strptime(due_str.strip(), "%d-%m-%Y").strftime("%Y-%m-%d")
            except ValueError:
                raise ValueError("Invalid date format. Please use DD-MM-YYYY (e.g. 25-12-2026).")
            m.create_loan(item_id, user["id"], mov_id, qty, due_db)
            m.success(f"{qty}x withdrawn. Return by {m.fmt_date(due_db)}.")
        else:
            m.success(f"{qty}x withdrawn.")

        print(f"`[-> To Item`{m.page_path}/item_detail.mu`id={item_id}|session={token}]")
        exit()
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Form ──────────────────────────────────────
color = m.stock_color(item["stock"], item["min_stock"])
avail_color = "f55" if available == 0 else ("ca4" if available <= item["min_stock"] and item["min_stock"] > 0 else "1a6")
print()
print(f"Item:  `!{item['name']}`!")
if item["item_number"]:
    print(f"`F777#{item['item_number']}`f")
print(f"Stock:     `F{color}{item['stock']} {item['unit']}`f")
if reserved > 0:
    print(f"`Fca4Reserved: {reserved} {item['unit']}`f")
    print(f"`F{avail_color}Available: {available} {item['unit']}`f")
if available == 0:
    print()
    m.error("No units available — all reserved.")
    print(f"`[<- Back`{m.page_path}/item_detail.mu`id={item_id}|session={token}]")
    exit()
print()

print(">>Withdrawal")
print(f"Quantity `B333`<8|quantity`1>`b")
print()

reasons = m.get_take_reasons()
if reasons:
    print("Reason:")
    for r in reasons:
        print(f"`<^|reason|{r['id']}`> {r['label']}")
    print()

print(f"Note `B333`<40|notes`>`b")
print()

print("Book as loan:")
print(f"`<?|is_loan|yes`> Yes — Return by: `F555(DD-MM-YYYY)`f")
print(f"`B333`<24|due_date`>`b  `F555Format: DD-MM-YYYY`f")
print()
print(f"`[Take`{m.page_path}/take.mu`*|action=take|id={item_id}|session={token}]")
m.print_footer()
