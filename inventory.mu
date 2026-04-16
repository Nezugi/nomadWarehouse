#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token  = os.environ.get("var_session", "")
user   = m.get_session_user(token)
cat_id = os.environ.get("var_cat", "")
search = os.environ.get("field_q", os.environ.get("var_q", "")).strip()[:60]

if not m.can_view(user):
    m.print_header()
    m.error("Access denied.")
    print(m.nav_bar(user, token))
    exit()

# Determine category
cat = None
if cat_id:
    try:
        cat = m.get_category(int(cat_id))
    except Exception:
        pass

title = cat["name"] if cat else "Inventory"
print(f">{m.site_name} — {title}")
print(m.nav_bar(user, token, back_url=f"{m.page_path}/index.mu`session={token}"))

# Search bar
print()
print(">>Search")
print(f"Term `B333`<40|q`>`b")
if cat:
    print(f"`[Search`{m.page_path}/inventory.mu`*|cat={cat_id}|session={token}]")
else:
    print(f"`[Search`{m.page_path}/inventory.mu`*|session={token}]")

# Load items
items = m.get_items(category_id=int(cat_id) if cat_id else None, search=search or None)

if not items:
    print()
    m.notice("No items found.")
else:
    print()
    print(f"`F777{len(items)} Item(s)`f")
    print("-")
    current_cat = None
    for it in items:
        if not cat and it["cat_name"] != current_cat:
            current_cat = it["cat_name"]
            print(f"`F4af {current_cat}`f")
        color = m.stock_color(it["stock"], it["min_stock"])
        stock_str = f"`F{color}{it['stock']}`f"
        num_str = f" `F555#{it['item_number']}`f" if it["item_number"] else ""
        loc_str = f" `F777{it['location']}`f" if it["location"] else ""
        type_str = f" `F555[{it['type_name']}]`f" if it["type_name"] else ""
        print(f"{stock_str}x {it['unit']}  {m.item_link(it, token)}{num_str}{type_str}{loc_str}")

print()
# Add item — only if user has both global + category permission
if cat and m.can_add_item(user, int(cat_id)):
    print(f"`[+ Create Item`{m.page_path}/new_item.mu`cat={cat_id}|session={token}]")
elif user and user["is_admin"]:
    cats = m.get_categories()
    print(">>Create item in category:")
    for c in cats:
        print(f"`[{c['name']}`{m.page_path}/new_item.mu`cat={c['id']}|session={token}]")
m.print_footer()
