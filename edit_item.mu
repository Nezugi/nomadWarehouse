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

if not m.can_edit_item(user, item["category_id"]):
    m.print_header()
    m.error("Permission denied.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/item_detail.mu`id={item_id}|session={token}"
print(f">{m.site_name} — Edit Item")
print(m.nav_bar(user, token, back_url=back))

submitted = action == "save"

if submitted:
    try:
        name      = os.environ.get("field_name", "").strip()[:60]
        number    = os.environ.get("field_number", "").strip()[:40]
        desc      = os.environ.get("field_desc", "").strip()[:400]
        location  = os.environ.get("field_location", "").strip()[:60]
        unit      = os.environ.get("field_unit", "Units").strip()[:30] or "Units"
        val_str   = os.environ.get("field_value", "0").strip()
        min_str   = os.environ.get("field_min_stock", "0").strip()
        type_str  = os.environ.get("field_item_type", "0").strip()

        if not name:
            raise ValueError("Name must not be empty.")

        value     = float(val_str) if val_str else 0.0
        min_stock = int(min_str)   if min_str else 0
        type_id   = int(type_str)  if type_str and type_str != "0" else None

        con = m.get_db()
        con.execute("""
            UPDATE items SET name=?,item_number=?,description=?,location=?,unit=?,
            value=?,min_stock=?,item_type_id=?
            WHERE id=?
        """, (name, number, desc, location, unit, value, min_stock, type_id, item_id))
        con.commit()
        con.close()
        m.success("Changes saved.")
        print(f"`[-> To Item`{m.page_path}/item_detail.mu`id={item_id}|session={token}]")
        exit()
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# Form with current values
item_types = m.get_item_types()
print()
print(f">>Item: {item['name']}")
print()
print(f"Name       `B333`<40|name`{item['name']}>`b")
print(f"Item Number`B333`<32|number`{item['item_number']}>`b")
print(f"Unit       `B333`<20|unit`{item['unit'] or 'Units'}>`b")
print(f"Location   `B333`<40|location`{item['location']}>`b")
print(f"Description`B333`<40|desc`{item['description']}>`b")
print(f"Value (EUR)`B333`<16|value`{item['value']:.2f}>`b")
print(f"Min Stock  `B333`<8|min_stock`{item['min_stock']}>`b")
print()

if item_types:
    print("Type:")
    cur_type = item["item_type_id"] or 0
    print(f"`<^|item_type|0`> No type")
    for t in item_types:
        print(f"`<^|item_type|{t['id']}`> {t['name']}")
    print()

print(f"`[Save`{m.page_path}/edit_item.mu`*|action=save|id={item_id}|session={token}]")
m.print_footer()
