#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
user    = m.get_session_user(token)
cat_id  = os.environ.get("var_cat", "")
action  = os.environ.get("var_action", "")

# Load type template if selected
type_id_sel = os.environ.get("var_type", "")

try:
    cat_id = int(cat_id)
    cat    = m.get_category(cat_id)
    if not cat:
        raise ValueError()
except Exception:
    m.print_header()
    m.error("Category not found.")
    print(m.nav_bar(user, token))
    exit()

if not m.can_add_item(user, cat_id):
    m.print_header()
    m.error("Permission denied.")
    print(m.nav_bar(user, token))
    exit()

back = f"{m.page_path}/inventory.mu`cat={cat_id}|session={token}"
print(f">{m.site_name} — Create Item")
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
        stock_str = os.environ.get("field_stock", "0").strip()
        min_str   = os.environ.get("field_min_stock", "0").strip()
        type_str  = os.environ.get("field_item_type", "0").strip()

        if not name:
            raise ValueError("Name must not be empty.")

        value     = float(val_str)   if val_str   else 0.0
        stock     = int(stock_str)   if stock_str else 0
        min_stock = int(min_str)     if min_str   else 0
        type_id   = int(type_str)    if type_str and type_str != "0" else None

        con = m.get_db()
        con.execute("""
            INSERT INTO items
            (category_id,item_type_id,name,item_number,description,location,unit,value,stock,min_stock,created_by)
            VALUES(?,?,?,?,?,?,?,?,?,?,?)
        """, (cat_id, type_id, name, number, desc, location, unit, value, stock, min_stock, user["id"]))
        new_id = con.execute("SELECT last_insert_rowid()").fetchone()[0]
        con.commit()
        con.close()
        m.success("Item created.")
        print(f"`[-> To Item`{m.page_path}/item_detail.mu`id={new_id}|session={token}]")
        print(f"`[Create Another`{m.page_path}/new_item.mu`cat={cat_id}|session={token}]")
        exit()
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Type templates ────────────────────────────
item_types = m.get_item_types()
defaults = {"location": "", "min_stock": "0"}

if type_id_sel and item_types:
    try:
        tpl = m.get_item_type(int(type_id_sel))
        if tpl:
            defaults["location"]  = tpl["default_location"]
            defaults["min_stock"] = str(tpl["default_min_stock"])
    except Exception:
        pass

print()
print(f">>Category: {cat['name']}")
print()

# Choose type template
if item_types:
    print(">>Select Template (optional)")
    print(f"`[No Template`{m.page_path}/new_item.mu`cat={cat_id}|session={token}]")
    for t in item_types:
        print(f"`[{t['name']}`{m.page_path}/new_item.mu`cat={cat_id}|type={t['id']}|session={token}]")
    print()

print(">>Item Data")
print(f"Name         `B333`<40|name`>`b")
print(f"Item Number  `B333`<32|number`>`b")
print(f"Unit         `B333`<20|unit`Units>`b")
print(f"Location     `B333`<40|location`{defaults['location']}>`b")
print(f"Description  `B333`<40|desc`>`b")
print(f"Value (EUR)  `B333`<16|value`0.00>`b")
print(f"Initial Stock`B333`<8|stock`0>`b")
print(f"Min Stock    `B333`<8|min_stock`{defaults['min_stock']}>`b")
print()

# Type selection via radio buttons
if item_types:
    print("Type:")
    print(f"`<^|item_type|0`> No type")
    for t in item_types:
        print(f"`<^|item_type|{t['id']}`> {t['name']}")
    print()

print(f"`[Create Item`{m.page_path}/new_item.mu`*|action=save|cat={cat_id}|session={token}]")
m.print_footer()
