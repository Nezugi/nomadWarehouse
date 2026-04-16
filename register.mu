#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token    = os.environ.get("var_session", "")
user_in  = os.environ.get("field_username", "")
pass_in  = os.environ.get("field_password", "")
pass2_in = os.environ.get("field_password2", "")

submitted = "field_username" in os.environ

print(f">{m.site_name} — Register")

if submitted:
    try:
        user_in  = user_in.strip()[:32]
        pass_in  = pass_in.strip()
        pass2_in = pass2_in.strip()
        if not user_in:
            raise ValueError("Username must not be empty.")
        if len(user_in) < 3:
            raise ValueError("Username must be at least 3 characters.")
        if len(pass_in) < 6:
            raise ValueError("Password must be at least 6 characters.")
        if pass_in != pass2_in:
            raise ValueError("Passwords do not match.")
        if m.get_user_by_name(user_in):
            raise ValueError("Username already taken.")
        uid = m.create_user(user_in, pass_in)
        if not uid:
            raise ValueError("Registration failed.")
        new_token = m.create_session(uid)
        m.success("Account created! You are now logged in.")
        m.print_header()
        print(m.nav_bar(m.get_user_by_id(uid), new_token))
        exit()
    except ValueError as e:
        m.error(str(e))

print()
print(">>New Account")
print(f"Username         `B333`<32|username`>`b")
print(f"Password         `B333`<!32|password`>`b")
print(f"Confirm Password `B333`<!32|password2`>`b")
print()
print(f"`[Register`{m.page_path}/register.mu`*]")
print()
print(f"`F777Already have an account?`f  `[Login`{m.page_path}/login.mu]")
print(m.nav_bar(None))
m.print_footer()
