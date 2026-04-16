#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
user    = m.get_session_user(token)
item_id = os.environ.get("var_id", "")

if not m.can_view(user):
    m.print_header()
    m.error("Access denied.")
    print(m.nav_bar(user, token))
    exit()

try:
    item_id = int(item_id)
    item = m.get_item(item_id)
    if not item:
        raise ValueError()
except Exception:
    m.print_header()
    m.error("Item not found.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/inventory.mu`cat={item['category_id']}|session={token}"
print(f">{m.site_name} — {item['name']}")
print(m.nav_bar(user, token, back_url=back))

# ── Header ───────────────────────────────────
color = m.stock_color(item["stock"], item["min_stock"])
print()
print(f"`!{item['name']}`!")
if item["item_number"]:
    print(f"`F777Item Number:`f  {item['item_number']}")
print(f"`F777Category:`f  {item['cat_name']}")
if item["type_name"]:
    print(f"`F777Type:`f  {item['type_name']}")
if item["location"]:
    print(f"`F777Location:`f  {item['location']}")
print(f"`F777Value:`f  {item['value']:,.2f} €")
print(f"`F777Stock:`f  `F{color}{item['stock']} {item['unit']}`f", end="")
if item["min_stock"] > 0:
    print(f"  `F555(Min: {item['min_stock']})`f")
else:
    print()
if item["description"]:
    print()
    print(f"{item['description']}")

# ── Actions ──────────────────────────────────
print()
print("-")
if m.can_take(user, item["category_id"]):
    print(f"`[-> Take`{m.page_path}/take.mu`id={item_id}|session={token}]  ", end="")
if m.can_store(user, item["category_id"]):
    print(f"`[-> Store`{m.page_path}/store.mu`id={item_id}|session={token}]  ", end="")
if user:
    print(f"`[-> Reserve`{m.page_path}/reserve.mu`id={item_id}|session={token}]", end="")
print()
if m.can_edit_item(user, item["category_id"]):
    print(f"`[Edit Item`{m.page_path}/edit_item.mu`id={item_id}|session={token}]")
m.print_footer()
