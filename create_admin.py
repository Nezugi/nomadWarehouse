#!/usr/bin/env python3
# CLI: Create an admin account or promote an existing user to admin

import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

username = input("Username: ").strip()
if not username:
    print("Error: Username must not be empty.")
    sys.exit(1)

password = input("Password: ").strip()
if len(password) < 6:
    print("Error: Password must be at least 6 characters.")
    sys.exit(1)

# Check if user already exists
existing = m.get_user_by_name(username)
if existing:
    con = m.get_db()
    con.execute("UPDATE users SET is_admin=1 WHERE id=?", (existing["id"],))
    con.commit()
    con.close()
    print(f"User '{username}' promoted to admin.")
else:
    uid = m.create_user(username, password, is_admin=1)
    if uid:
        print(f"Admin account '{username}' created.")
    else:
        print("Error: Could not create account.")
        sys.exit(1)
