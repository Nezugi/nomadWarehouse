#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main as m

print("#!c=0")
token = os.environ.get("var_session", "")
m.delete_session(token)
m.print_header()
m.notice("Logged out.")
print(m.nav_bar(None))
m.print_footer()
