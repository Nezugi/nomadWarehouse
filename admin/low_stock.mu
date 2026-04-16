#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
user  = m.require_admin(token)

back = f"{m.page_path}/admin/admin.mu`session={token}"
print(f">{m.site_name} — Min Stock Warnings")
print(m.nav_bar(user, token, back_url=back))

low = m.get_low_stock_items()

print()
if not low:
    m.success("All items are above their minimum stock level.")
else:
    # Split: empty vs. low
    empty = [i for i in low if i["stock"] == 0]
    low_  = [i for i in low if i["stock"] > 0]

    if empty:
        print(f">>Empty ({len(empty)})")
        print("-")
        for it in empty:
            num = f" #{it['item_number']}" if it["item_number"] else ""
            loc = f"  `F555{it['location']}`f" if it["location"] else ""
            print(f"`Ff55 EMPTY`f  "
                  f"{m.item_link(it, token)}{num}  "
                  f"`F777{it['cat_name']}`f{loc}  "
                  f"`F555Min: {it['min_stock']}`f")
        print("-")
        print()

    if low_:
        print(f">>Low ({len(low_)})")
        print("-")
        for it in low_:
            num = f" #{it['item_number']}" if it["item_number"] else ""
            loc = f"  `F555{it['location']}`f" if it["location"] else ""
            deficit = it["min_stock"] - it["stock"]
            print(f"`Fca4{it['stock']}/{it['min_stock']}`f  "
                  f"{m.item_link(it, token)}{num}  "
                  f"`F777{it['cat_name']}`f{loc}  "
                  f"`F555missing: {deficit}`f")
        print("-")

    # Total value needed to refill all items to their minimum stock
    total_missing_val = sum(
        (it["min_stock"] - it["stock"]) * it["value"]
        for it in low if it["stock"] < it["min_stock"]
    )
    if total_missing_val > 0:
        print()
        print(f"`F777Value to refill to min stock:`f  {total_missing_val:,.2f} €")
m.print_footer()
