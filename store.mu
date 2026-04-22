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

if not m.can_store(user, item["category_id"]):
    m.print_header()
    m.error("Permission denied — cannot store items.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/item_detail.mu`id={item_id}|session={token}"
print(f">{m.site_name} — Store Item")
print(m.nav_bar(user, token, back_url=back))

# Check for an open loan by this user for this item
con = m.get_db()
open_loan = con.execute("""
    SELECT * FROM loans WHERE item_id=? AND user_id=? AND returned_at IS NULL
    ORDER BY due_date LIMIT 1
""", (item_id, user["id"])).fetchone()
con.close()

submitted = action == "store"

if submitted:
    try:
        qty_str        = os.environ.get("field_quantity", "1").strip()
        reason_str     = os.environ.get("field_reason", "").strip()
        source         = os.environ.get("field_source", "").strip()[:100]
        return_loan_cb = os.environ.get("field_return_loan", "") == "yes"
        return_notes   = os.environ.get("field_return_notes", "").strip()[:200]

        qty = int(qty_str) if qty_str else 1
        if qty < 1:
            raise ValueError("Quantity must be at least 1.")

        reason_id = int(reason_str) if reason_str else None

        # Set movement notes for loan returns so the history shows it
        mov_notes = "Loan return" if (return_loan_cb and open_loan) else ""
        m.record_movement(item_id, user["id"], "store", reason_id, qty,
                          source=source, notes=mov_notes)

        # Mark loan as returned (no additional stock update here)
        if return_loan_cb and open_loan:
            m.return_loan(open_loan["id"], notes=return_notes)
            m.success(f"{qty}x stored. Loan marked as returned.")
        else:
            m.success(f"{qty}x stored.")

        print(f"`[-> To Item`{m.page_path}/item_detail.mu`id={item_id}|session={token}]")
        exit()
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Form ──────────────────────────────────────
color = m.stock_color(item["stock"], item["min_stock"])
print()
print(f"Item:  `!{item['name']}`!")
if item["item_number"]:
    print(f"`F777#{item['item_number']}`f")
print(f"Stock:  `F{color}{item['stock']} {item['unit']}`f")
print()

print(">>Store")
print(f"Quantity `B333`<8|quantity`1>`b")
print()

reasons = m.get_store_reasons()
if reasons:
    print("Reason:")
    for r in reasons:
        print(f"`<^|reason|{r['id']}`> {r['label']}")
    print()

print(f"Source   `B333`<40|source`>`b")
print()

# Offer loan return if there is an open loan
if open_loan:
    print(f"`Fca4 You have this item on loan (due {m.fmt_date(open_loan['due_date'])}).`f")
    print(f"`<?|return_loan|yes`> Mark as loan return")
    print(f"Condition`B333`<40|return_notes`>`b")
    print()

print(f"`[Store`{m.page_path}/store.mu`*|action=store|id={item_id}|session={token}]")
m.print_footer()
