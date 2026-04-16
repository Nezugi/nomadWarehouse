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
print(f">{m.site_name} — Manage Reasons")
print(m.nav_bar(user, token, back_url=back))

# ── Create withdrawal reason ──────────────────
if action == "add_take" or "field_take_label" in os.environ:
    try:
        label = os.environ.get("field_take_label", "").strip()[:80]
        if not label:
            raise ValueError("Label must not be empty.")
        con = m.get_db()
        con.execute("INSERT INTO take_reasons(label) VALUES(?)", (label,))
        con.commit()
        con.close()
        m.success(f"Withdrawal reason '{label}' created.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Create store reason ───────────────────────
if action == "add_store" or "field_store_label" in os.environ:
    try:
        label = os.environ.get("field_store_label", "").strip()[:80]
        if not label:
            raise ValueError("Label must not be empty.")
        con = m.get_db()
        con.execute("INSERT INTO store_reasons(label) VALUES(?)", (label,))
        con.commit()
        con.close()
        m.success(f"Store reason '{label}' created.")
    except ValueError as e:
        m.error(str(e))
    except Exception as e:
        m.error(f"Error: {e}")

# ── Delete withdrawal reason ──────────────────
if action == "del_take":
    try:
        rid = int(os.environ.get("var_rid", ""))
        con = m.get_db()
        con.execute("DELETE FROM take_reasons WHERE id=?", (rid,))
        con.commit()
        con.close()
        m.success("Withdrawal reason deleted.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Delete store reason ───────────────────────
if action == "del_store":
    try:
        rid = int(os.environ.get("var_rid", ""))
        con = m.get_db()
        con.execute("DELETE FROM store_reasons WHERE id=?", (rid,))
        con.commit()
        con.close()
        m.success("Store reason deleted.")
    except Exception as e:
        m.error(f"Error: {e}")

# ── Withdrawal reasons list ───────────────────
print()
print(">>Withdrawal Reasons")
take_reasons = m.get_take_reasons()
if take_reasons:
    for r in take_reasons:
        print(f"`F777{r['label']}`f  "
              f"`[x`{m.page_path}/admin/reasons.mu`action=del_take|rid={r['id']}|session={token}]")
else:
    m.notice("No withdrawal reasons defined.")

print()
print("New withdrawal reason:")
print(f"`B333`<40|take_label`>`b")
print(f"`[Create`{m.page_path}/admin/reasons.mu`*|action=add_take|session={token}]")

# ── Store reasons list ────────────────────────
print()
print(">>Store Reasons")
store_reasons = m.get_store_reasons()
if store_reasons:
    for r in store_reasons:
        print(f"`F777{r['label']}`f  "
              f"`[x`{m.page_path}/admin/reasons.mu`action=del_store|rid={r['id']}|session={token}]")
else:
    m.notice("No store reasons defined.")

print()
print("New store reason:")
print(f"`B333`<40|store_label`>`b")
print(f"`[Create`{m.page_path}/admin/reasons.mu`*|action=add_store|session={token}]")
m.print_footer()
