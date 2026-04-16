#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
user    = m.require_admin(token)
action  = os.environ.get("var_action", "")
uid_str = os.environ.get("var_uid", "")

back = f"{m.page_path}/admin/admin.mu`session={token}"
print(f">{m.site_name} — Users & Permissions")
print(m.nav_bar(user, token, back_url=back))

# ── Save global permissions ───────────────────
if action == "save_global" and uid_str:
    try:
        uid = int(uid_str)
        cv  = 1 if os.environ.get("field_can_view", "")    == "yes" else 0
        ca  = 1 if os.environ.get("field_can_add", "")     == "yes" else 0
        ce  = 1 if os.environ.get("field_can_edit", "")    == "yes" else 0
        ct  = 1 if os.environ.get("field_can_take", "")    == "yes" else 0
        cs  = 1 if os.environ.get("field_can_store", "")   == "yes" else 0
        m.set_global_perms(uid, cv, ca, ce, ct, cs)
        m.success("Global permissions saved.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Save category permissions ─────────────────
if action == "save_cat" and uid_str:
    try:
        uid = int(uid_str)
        cats = m.get_categories()
        con  = m.get_db()
        for cat in cats:
            cid = cat["id"]
            ct  = 1 if os.environ.get(f"field_cat_{cid}_take", "")  == "yes" else 0
            cs  = 1 if os.environ.get(f"field_cat_{cid}_store", "") == "yes" else 0
            ca  = 1 if os.environ.get(f"field_cat_{cid}_add", "")   == "yes" else 0
            ce  = 1 if os.environ.get(f"field_cat_{cid}_edit", "")  == "yes" else 0
            m.set_cat_perm(uid, cid, ct, cs, ca, ce)
        con.close()
        m.success("Category permissions saved.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Select user ───────────────────────────────
if uid_str:
    try:
        uid_int  = int(uid_str)
        sel_user = m.get_user_by_id(uid_int)
        if not sel_user:
            raise ValueError()
    except Exception:
        sel_user = None
else:
    sel_user = None

# User list
con   = m.get_db()
users = con.execute("SELECT * FROM users ORDER BY username").fetchall()
con.close()

print()
print(">>User List")
for u in users:
    badge = "`F1a6 Admin`f" if u["is_admin"] else "`F777 User`f"
    print(f"{badge}  `[{u['username']}`{m.page_path}/admin/users.mu`uid={u['id']}|session={token}]")

# ── User detail view ──────────────────────────
if sel_user:
    gp = m.get_global_perms(sel_user["id"])
    print()
    print(f">>Permissions: {sel_user['username']}")

    # Global permissions
    print()
    print(">>>Global Rights")
    def cb(field, label, perm_val):
        checked = "yes" if perm_val else ""
        print(f"`<?|{field}|yes`{checked}> {label}")
    cb("can_view",  "View inventory",      gp and gp["can_view"])
    cb("can_add",   "Create items",        gp and gp["can_add_item"])
    cb("can_edit",  "Edit items",          gp and gp["can_edit_item"])
    cb("can_take",  "Withdraw items",      gp and gp["can_take"])
    cb("can_store", "Store items",         gp and gp["can_store"])
    print()
    print(f"`[Save Global Rights`{m.page_path}/admin/users.mu`*|action=save_global|uid={sel_user['id']}|session={token}]")

    # Category permissions
    cats = m.get_categories()
    print()
    print(">>>Category Rights")
    for cat in cats:
        cp = m.get_cat_perm(sel_user["id"], cat["id"])
        print()
        print(f"`F4af{cat['name']}`f")
        cid = cat["id"]
        def cbc(field, label, val):
            checked = "yes" if val else ""
            print(f"`<?|{field}|yes`{checked}> {label}")
        cbc(f"cat_{cid}_take",  "Withdraw",    cp and cp["can_take"])
        cbc(f"cat_{cid}_store", "Store",       cp and cp["can_store"])
        cbc(f"cat_{cid}_add",   "Create items", cp and cp["can_add_item"])
        cbc(f"cat_{cid}_edit",  "Edit items",   cp and cp["can_edit_item"])
    print()
    print(f"`[Save Category Rights`{m.page_path}/admin/users.mu`*|action=save_cat|uid={sel_user['id']}|session={token}]")
m.print_footer()
