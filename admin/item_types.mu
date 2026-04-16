#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main as m

print("#!c=0")
token  = os.environ.get("var_session", "")
user   = m.require_admin(token)
action = os.environ.get("var_action", "")

back = f"{m.page_path}/admin/admin.mu`session={token}"
print(f">{m.site_name} — Item Types")
print(m.nav_bar(user, token, back_url=back))

# ── Create type ───────────────────────────────
if action == "add" or "field_type_name" in os.environ:
    try:
        name     = os.environ.get("field_type_name", "").strip()[:60]
        desc     = os.environ.get("field_type_desc", "").strip()[:200]
        location = os.environ.get("field_type_location", "").strip()[:60]
        min_str  = os.environ.get("field_type_min", "0").strip()

        if not name:
            raise ValueError("Name must not be empty.")
        min_stock = int(min_str) if min_str else 0

        con = m.get_db()
        con.execute(
            "INSERT INTO item_types(name,description,default_location,default_min_stock) "
            "VALUES(?,?,?,?)",
            (name, desc, location, min_stock)
        )
        con.commit()
        con.close()
        m.success(f"Type '{name}' created.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Delete type ───────────────────────────────
if action == "delete":
    try:
        tid = int(os.environ.get("var_tid", ""))
        con = m.get_db()
        # Set references to NULL instead of hard-deleting
        con.execute("UPDATE items SET item_type_id=NULL WHERE item_type_id=?", (tid,))
        con.execute("DELETE FROM item_types WHERE id=?", (tid,))
        con.commit()
        con.close()
        m.success("Type deleted. Affected items no longer have a type.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Save inline edit ──────────────────────────
if action == "save_edit":
    try:
        tid      = int(os.environ.get("var_tid", ""))
        name     = os.environ.get("field_type_name", "").strip()[:60]
        desc     = os.environ.get("field_type_desc", "").strip()[:200]
        location = os.environ.get("field_type_location", "").strip()[:60]
        min_str  = os.environ.get("field_type_min", "0").strip()

        if not name:
            raise ValueError("Name must not be empty.")
        min_stock = int(min_str) if min_str else 0

        con = m.get_db()
        con.execute(
            "UPDATE item_types SET name=?,description=?,default_location=?,default_min_stock=? "
            "WHERE id=?",
            (name, desc, location, min_stock, tid)
        )
        con.commit()
        con.close()
        m.success("Type updated.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── List ──────────────────────────────────────
types = m.get_item_types()
con   = m.get_db()

print()
print(">>Existing Types")
if not types:
    m.notice("No types defined yet.")
else:
    for t in types:
        cnt = con.execute(
            "SELECT COUNT(*) FROM items WHERE item_type_id=?", (t["id"],)
        ).fetchone()[0]
        print()
        print(f"`!{t['name']}`!  `F777{cnt} item(s)`f")
        if t["description"]:
            print(f"`F555{t['description']}`f")
        if t["default_location"]:
            print(f"`F777Default Location:`f  {t['default_location']}")
        if t["default_min_stock"]:
            print(f"`F777Default Min Stock:`f  {t['default_min_stock']}")
        print(f"`[Delete`{m.page_path}/admin/item_types.mu`action=delete|tid={t['id']}|session={token}]")
        print()
        # Inline edit form
        print(f">>>Edit: {t['name']}")
        print(f"Name          `B333`<40|type_name`{t['name']}>`b")
        print(f"Description   `B333`<40|type_desc`{t['description']}>`b")
        print(f"Def. Location `B333`<40|type_location`{t['default_location']}>`b")
        print(f"Def. Min Stock`B333`<8|type_min`{t['default_min_stock']}>`b")
        print(f"`[Save`{m.page_path}/admin/item_types.mu`*|action=save_edit|tid={t['id']}|session={token}]")
        print()

con.close()

# ── New type form ─────────────────────────────
print()
print(">>New Type")
print(f"Name          `B333`<40|type_name`>`b")
print(f"Description   `B333`<40|type_desc`>`b")
print(f"Def. Location `B333`<40|type_location`>`b")
print(f"Def. Min Stock`B333`<8|type_min`0>`b")
print(f"`[Create`{m.page_path}/admin/item_types.mu`*|action=add|session={token}]")
m.print_footer()
