#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
user  = m.require_admin(token)

print(f">{m.site_name} — Admin")
print(m.nav_bar(user, token, back_url=f"{m.page_path}/index.mu`session={token}"))

# Quick overview
con = m.get_db()
total_items  = con.execute("SELECT COUNT(*) FROM items").fetchone()[0]
total_users  = con.execute("SELECT COUNT(*) FROM users").fetchone()[0]
open_loans   = con.execute("SELECT COUNT(*) FROM loans WHERE returned_at IS NULL").fetchone()[0]
overdue_cnt  = con.execute("SELECT COUNT(*) FROM loans WHERE returned_at IS NULL AND is_overdue=1").fetchone()[0]
low_stock    = con.execute("SELECT COUNT(*) FROM items WHERE min_stock>0 AND stock<=min_stock").fetchone()[0]
con.close()

total_val, _ = m.get_inventory_value()

print()
print(">>Overview")
print(f"`F777Items:        `f{total_items}")
print(f"`F777Users:        `f{total_users}")
print(f"`F777Total Value:  `f{total_val:,.2f} €")
print(f"`F777Open Loans:   `f{open_loans}", end="")
if overdue_cnt:
    print(f"  `Ff55({overdue_cnt} overdue)`f")
else:
    print()
if low_stock:
    print(f"`Fca4Min stock below threshold: {low_stock} item(s)`f")

print()
print(">>Management")
print(f"`[Users & Permissions`{m.page_path}/admin/users.mu`session={token}]")
print(f"`[Categories`{m.page_path}/admin/categories.mu`session={token}]")
print(f"`[Withdrawal / Store Reasons`{m.page_path}/admin/reasons.mu`session={token}]")
print(f"`[Item Types / Templates`{m.page_path}/admin/item_types.mu`session={token}]")
print(f"`[Overdue Loans`{m.page_path}/admin/overdue.mu`session={token}]")
print(f"`[Min Stock Warnings`{m.page_path}/admin/low_stock.mu`session={token}]")
m.print_footer()
