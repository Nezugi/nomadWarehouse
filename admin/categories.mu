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
print(f">{m.site_name} — Categories")
print(m.nav_bar(user, token, back_url=back))

# ── Create category ───────────────────────────
if action == "add" or "field_cat_name" in os.environ:
    try:
        name = os.environ.get("field_cat_name", "").strip()[:60]
        desc = os.environ.get("field_cat_desc", "").strip()[:200]
        slug = name.lower().replace(" ", "_").replace("-", "_")
        slug = "".join(c for c in slug if c.isalnum() or c == "_")[:40]
        if not slug:
            raise ValueError("Name does not produce a valid slug.")
        con = m.get_db()
        # Make slug unique
        base = slug
        i = 1
        while con.execute("SELECT 1 FROM categories WHERE slug=?", (slug,)).fetchone():
            slug = f"{base}_{i}"
            i += 1
        con.execute("INSERT INTO categories(slug,name,description) VALUES(?,?,?)",
                    (slug, name, desc))
        con.commit()
        con.close()
        m.success(f"Category '{name}' created.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Delete category ───────────────────────────
if action == "delete":
    try:
        cid = int(os.environ.get("var_cid", ""))
        con = m.get_db()
        cnt = con.execute("SELECT COUNT(*) FROM items WHERE category_id=?", (cid,)).fetchone()[0]
        if cnt > 0:
            raise ValueError(f"Category still has {cnt} item(s) — delete them first.")
        con.execute("DELETE FROM categories WHERE id=?", (cid,))
        con.commit()
        con.close()
        m.success("Category deleted.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── List ──────────────────────────────────────
cats = m.get_categories()
con  = m.get_db()
print()
print(">>Categories")
for cat in cats:
    cnt = con.execute("SELECT COUNT(*) FROM items WHERE category_id=?", (cat["id"],)).fetchone()[0]
    print(f"`!{cat['name']}`!  `F777{cnt} item(s)`f")
    if cat["description"]:
        print(f"`F555{cat['description']}`f")
    if cnt == 0:
        print(f"`[Delete`{m.page_path}/admin/categories.mu`action=delete|cid={cat['id']}|session={token}]")
    print()
con.close()

# ── New category ──────────────────────────────
print()
print(">>New Category")
print(f"Name        `B333`<40|cat_name`>`b")
print(f"Description `B333`<40|cat_desc`>`b")
print(f"`[Create`{m.page_path}/admin/categories.mu`*|action=add|session={token}]")
m.print_footer()
