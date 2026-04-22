#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token   = os.environ.get("var_session", "")
action  = os.environ.get("var_action", "")
user_in = os.environ.get("field_username", "")
pass_in = os.environ.get("field_password", "")

# Already logged in?
if m.get_session_user(token):
    m.print_header()
    m.notice("Already logged in.")
    print(m.nav_bar(m.get_session_user(token), token))
    exit()

submitted = "field_username" in os.environ

if submitted:
    try:
        if not user_in or not pass_in:
            raise ValueError("Username and password are required.")
        db_user = m.get_user_by_name(user_in)
        if not db_user or not m.check_password(pass_in, db_user["pw_hash"], db_user["pw_salt"]):
            raise ValueError("Invalid username or password.")
        new_token = m.create_session(db_user["id"])
        m.print_header()
        m.success(f"Welcome, {db_user['username']}!")
        print(m.nav_bar(db_user, new_token))
        exit()
    except ValueError as e:
        print(f">{m.site_name} — Login")
        print(m.nav_bar(None))
        m.error(str(e))
else:
    print(f">{m.site_name} — Login")
    print(m.nav_bar(None))

print()
print(">>Login")
print(f"Username`B333`<32|username`>`b")
print(f"Password`B333`<!32|password`>`b")
print()
print(f"`[Sign In`{m.page_path}/login.mu`*|action=login]")
print()
print(f"`F777No account yet?`f  `[Register`{m.page_path}/register.mu]")
m.print_footer()
