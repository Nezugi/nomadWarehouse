#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
user  = m.get_session_user(token)

m.print_header()
print(m.nav_bar(user, token))

if not m.can_view(user):
    m.notice("Please log in to view the warehouse.")
    exit()

# ── Stock warnings ───────────────────────────
low = m.get_low_stock_items()
if low:
    print()
    print(f"`F1a6 Warehouse Notices`f")
    print("-")
    for it in low:
        if it["stock"] == 0:
            label = "`Ff55 EMPTY`f"
        else:
            label = f"`Fca4 Low ({it['stock']}/{it['min_stock']})`f"
        print(f"{label}  {m.item_link(it, token)}  `F777{it['cat_name']}`f")
    print("-")

# ── Categories ────────────────────────────────
cats = m.get_categories()
con  = m.get_db()
print()
print(">>Categories")
for cat in cats:
    row = con.execute(
        "SELECT COUNT(*) AS cnt, COALESCE(SUM(stock),0) AS total FROM items WHERE category_id=?",
        (cat["id"],)
    ).fetchone()
    print(f"`[{cat['name']}`{m.page_path}/inventory.mu`cat={cat['id']}|session={token}]"
          f"  `F777{row['cnt']} Items · {int(row['total'])} Units`f")
    if cat["description"]:
        print(f"`F555{cat['description']}`f")
con.close()

# ── Inventory value ───────────────────────────
total_val, by_cat = m.get_inventory_value()
print()
print(">>Inventory Value")
print(f"`F4af Total:`f  `!{total_val:,.2f} €`!")
print()
for row in by_cat:
    if row["val"] > 0:
        print(f"`F777{row['name']}`f  {row['val']:,.2f} €  `F555({row['cnt']} Items)`f")

# ── Search ────────────────────────────────────
print()
print(">>Search")
print(f"Term `B333`<40|q`>`b")
print(f"`[Search`{m.page_path}/inventory.mu`*|session={token}]")
m.print_footer()
