#!/usr/bin/env python3
# nomadWarehouse — main.py
# Central library: Database, Sessions, Permissions, Helper functions
# Used by all .mu pages via: import sys, os; sys.path.insert(0, os.path.dirname(__file__)); import main as m

import sqlite3
import hashlib
import secrets
import os
from datetime import datetime, timedelta, timezone

# ─────────────────────────────────────────────
# CONFIGURATION — adjust here
# ─────────────────────────────────────────────
storage_path = "/home/user/.nomadWarehouse"   # Path to database — specify actual user!
page_path    = ":/page/warehouse"             # Node path — must start with :
site_name        = "nomadWarehouse"               # Display name
site_description = "Inventory management with user permissions"  # Short description
node_homepage = ":/page/index.mu"             # Node homepage

SESSION_TTL_DAYS = 7
# ─────────────────────────────────────────────

DB_PATH = os.path.join(storage_path, "warehouse.db")


def get_db():
    os.makedirs(storage_path, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    return con


def init_db():
    con = get_db()
    c = con.cursor()

    c.executescript("""
    CREATE TABLE IF NOT EXISTS users (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        username     TEXT    NOT NULL UNIQUE,
        pw_hash      TEXT    NOT NULL,
        pw_salt      TEXT    NOT NULL,
        display_name TEXT    DEFAULT '',
        is_admin     INTEGER DEFAULT 0,
        registered_at TEXT   DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS categories (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        slug        TEXT    NOT NULL UNIQUE,
        name        TEXT    NOT NULL,
        description TEXT    DEFAULT '',
        sort_order  INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS item_types (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        description TEXT    DEFAULT '',
        default_location TEXT DEFAULT '',
        default_min_stock INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS items (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id  INTEGER NOT NULL REFERENCES categories(id),
        item_type_id INTEGER REFERENCES item_types(id),
        name         TEXT    NOT NULL,
        item_number  TEXT    DEFAULT '',
        description  TEXT    DEFAULT '',
        location     TEXT    DEFAULT '',
        unit         TEXT    DEFAULT 'Units',
        value        REAL    DEFAULT 0.0,
        stock        INTEGER DEFAULT 0,
        min_stock    INTEGER DEFAULT 0,
        created_by   INTEGER REFERENCES users(id),
        created_at   TEXT    DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS take_reasons (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT    NOT NULL
    );

    CREATE TABLE IF NOT EXISTS store_reasons (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT    NOT NULL
    );

    CREATE TABLE IF NOT EXISTS movements (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id     INTEGER NOT NULL REFERENCES items(id),
        user_id     INTEGER NOT NULL REFERENCES users(id),
        type        TEXT    NOT NULL CHECK(type IN ('take','store')),
        reason_id   INTEGER,
        quantity    INTEGER NOT NULL DEFAULT 1,
        source      TEXT    DEFAULT '',
        notes       TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS loans (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id      INTEGER NOT NULL REFERENCES items(id),
        user_id      INTEGER NOT NULL REFERENCES users(id),
        movement_id  INTEGER NOT NULL REFERENCES movements(id),
        quantity     INTEGER NOT NULL DEFAULT 1,
        due_date     TEXT    NOT NULL,
        returned_at  TEXT    DEFAULT NULL,
        return_notes TEXT    DEFAULT '',
        is_overdue   INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS reservations (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id      INTEGER NOT NULL REFERENCES items(id),
        user_id      INTEGER NOT NULL REFERENCES users(id),
        quantity     INTEGER NOT NULL DEFAULT 1,
        reserved_from TEXT   NOT NULL,
        reserved_until TEXT  NOT NULL,
        notes        TEXT    DEFAULT '',
        created_at   TEXT    DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS user_permissions (
        user_id       INTEGER PRIMARY KEY REFERENCES users(id),
        can_view      INTEGER DEFAULT 0,
        can_add_item  INTEGER DEFAULT 0,
        can_edit_item INTEGER DEFAULT 0,
        can_take      INTEGER DEFAULT 0,
        can_store     INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS category_permissions (
        user_id       INTEGER NOT NULL REFERENCES users(id),
        category_id   INTEGER NOT NULL REFERENCES categories(id),
        can_take      INTEGER DEFAULT 0,
        can_store     INTEGER DEFAULT 0,
        can_add_item  INTEGER DEFAULT 0,
        can_edit_item INTEGER DEFAULT 0,
        PRIMARY KEY (user_id, category_id)
    );

    CREATE TABLE IF NOT EXISTS sessions (
        token      TEXT    PRIMARY KEY,
        user_id    INTEGER NOT NULL REFERENCES users(id),
        expires_at TEXT    NOT NULL
    );

    CREATE TABLE IF NOT EXISTS settings (
        key   TEXT PRIMARY KEY,
        value TEXT DEFAULT ''
    );
    """)

    # Migration: safely add new columns
    _migrate_column(c, "items",  "unit",         "TEXT DEFAULT 'Piece'")
    _migrate_column(c, "items",  "min_stock",    "INTEGER DEFAULT 0")
    _migrate_column(c, "items",  "item_type_id", "INTEGER REFERENCES item_types(id)")
    _migrate_column(c, "loans",  "return_notes", "TEXT DEFAULT ''")
    _migrate_column(c, "loans",  "quantity",     "INTEGER NOT NULL DEFAULT 1")
    _migrate_column(c, "movements", "quantity",  "INTEGER NOT NULL DEFAULT 1")
    _migrate_column(c, "movements", "source",    "TEXT DEFAULT ''")
    _migrate_column(c, "movements", "notes",     "TEXT DEFAULT ''")

    con.commit()
    con.close()


def _migrate_column(cursor, table, column, col_def):
    existing = [r[1] for r in cursor.execute(f"PRAGMA table_info({table})")]
    if column not in existing:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_def}")


# ─────────────────────────────────────────────
# Passive Cleanup — on every import
# ─────────────────────────────────────────────
def cleanup():
    now = _now()
    con = get_db()
    # Expired sessions
    con.execute("DELETE FROM sessions WHERE expires_at < ?", (now,))
    # Expired reservations
    con.execute("DELETE FROM reservations WHERE reserved_until < ?", (now,))
    # Mark overdue loans
    con.execute("""
        UPDATE loans SET is_overdue=1
        WHERE returned_at IS NULL AND due_date < ? AND is_overdue=0
    """, (now[:10],))  # compare only date part
    con.commit()
    con.close()


# ─────────────────────────────────────────────
# Password
# ─────────────────────────────────────────────
def hash_password(password, salt=None):
    if salt is None:
        salt = secrets.token_hex(16)
    h = hashlib.sha256((salt + password).encode()).hexdigest()
    return h, salt


def check_password(password, pw_hash, pw_salt):
    h, _ = hash_password(password, pw_salt)
    return h == pw_hash


# ─────────────────────────────────────────────
# Sessions
# ─────────────────────────────────────────────
def create_session(user_id):
    token = secrets.token_hex(32)
    expires = (_dt_now() + timedelta(days=SESSION_TTL_DAYS)).strftime("%Y-%m-%dT%H:%M:%S")
    con = get_db()
    con.execute("INSERT INTO sessions(token,user_id,expires_at) VALUES(?,?,?)",
                (token, user_id, expires))
    con.commit()
    con.close()
    return token


def get_session_user(token):
    if not token:
        return None
    con = get_db()
    row = con.execute(
        "SELECT u.* FROM sessions s JOIN users u ON s.user_id=u.id "
        "WHERE s.token=? AND s.expires_at > ?",
        (token, _now())
    ).fetchone()
    con.close()
    return row


def delete_session(token):
    con = get_db()
    con.execute("DELETE FROM sessions WHERE token=?", (token,))
    con.commit()
    con.close()


# ─────────────────────────────────────────────
# Users
# ─────────────────────────────────────────────
def create_user(username, password, is_admin=0):
    pw_hash, pw_salt = hash_password(password)
    con = get_db()
    try:
        con.execute(
            "INSERT INTO users(username,pw_hash,pw_salt,is_admin) VALUES(?,?,?,?)",
            (username, pw_hash, pw_salt, is_admin)
        )
        user_id = con.execute("SELECT last_insert_rowid()").fetchone()[0]
        # Create empty permissions row for new user
        con.execute("INSERT OR IGNORE INTO user_permissions(user_id) VALUES(?)", (user_id,))
        con.commit()
        return user_id
    except sqlite3.IntegrityError:
        return None
    finally:
        con.close()


def get_user_by_name(username):
    con = get_db()
    row = con.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
    con.close()
    return row


def get_user_by_id(user_id):
    con = get_db()
    row = con.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    con.close()
    return row


# ─────────────────────────────────────────────
# Permissions
# ─────────────────────────────────────────────
def get_global_perms(user_id):
    con = get_db()
    row = con.execute("SELECT * FROM user_permissions WHERE user_id=?", (user_id,)).fetchone()
    con.close()
    return row


def get_cat_perm(user_id, category_id):
    con = get_db()
    row = con.execute(
        "SELECT * FROM category_permissions WHERE user_id=? AND category_id=?",
        (user_id, category_id)
    ).fetchone()
    con.close()
    return row


def can_view(user, category_id=None):
    if not user:
        return False
    if user["is_admin"]:
        return True
    p = get_global_perms(user["id"])
    return bool(p and p["can_view"])


def can_add_item(user, category_id):
    if not user:
        return False
    if user["is_admin"]:
        return True
    p = get_global_perms(user["id"])
    if not (p and p["can_add_item"]):
        return False
    cp = get_cat_perm(user["id"], category_id)
    return bool(cp and cp["can_add_item"])


def can_edit_item(user, category_id):
    if not user:
        return False
    if user["is_admin"]:
        return True
    p = get_global_perms(user["id"])
    if not (p and p["can_edit_item"]):
        return False
    cp = get_cat_perm(user["id"], category_id)
    return bool(cp and cp["can_edit_item"])


def can_take(user, category_id):
    if not user:
        return False
    if user["is_admin"]:
        return True
    p = get_global_perms(user["id"])
    if not (p and p["can_take"]):
        return False
    cp = get_cat_perm(user["id"], category_id)
    return bool(cp and cp["can_take"])


def can_store(user, category_id):
    if not user:
        return False
    if user["is_admin"]:
        return True
    p = get_global_perms(user["id"])
    if not (p and p["can_store"]):
        return False
    cp = get_cat_perm(user["id"], category_id)
    return bool(cp and cp["can_store"])


def set_global_perms(user_id, can_view_, can_add_item_, can_edit_item_, can_take_, can_store_):
    con = get_db()
    con.execute("""
        INSERT INTO user_permissions(user_id,can_view,can_add_item,can_edit_item,can_take,can_store)
        VALUES(?,?,?,?,?,?)
        ON CONFLICT(user_id) DO UPDATE SET
            can_view=excluded.can_view,
            can_add_item=excluded.can_add_item,
            can_edit_item=excluded.can_edit_item,
            can_take=excluded.can_take,
            can_store=excluded.can_store
    """, (user_id, can_view_, can_add_item_, can_edit_item_, can_take_, can_store_))
    con.commit()
    con.close()


def set_cat_perm(user_id, category_id, can_take_, can_store_, can_add_item_, can_edit_item_):
    con = get_db()
    con.execute("""
        INSERT INTO category_permissions(user_id,category_id,can_take,can_store,can_add_item,can_edit_item)
        VALUES(?,?,?,?,?,?)
        ON CONFLICT(user_id,category_id) DO UPDATE SET
            can_take=excluded.can_take,
            can_store=excluded.can_store,
            can_add_item=excluded.can_add_item,
            can_edit_item=excluded.can_edit_item
    """, (user_id, category_id, can_take_, can_store_, can_add_item_, can_edit_item_))
    con.commit()
    con.close()


# ─────────────────────────────────────────────
# Categories
# ─────────────────────────────────────────────
def get_categories():
    con = get_db()
    rows = con.execute("SELECT * FROM categories ORDER BY sort_order, name").fetchall()
    con.close()
    return rows


def get_category(cat_id):
    con = get_db()
    row = con.execute("SELECT * FROM categories WHERE id=?", (cat_id,)).fetchone()
    con.close()
    return row


def get_category_by_slug(slug):
    con = get_db()
    row = con.execute("SELECT * FROM categories WHERE slug=?", (slug,)).fetchone()
    con.close()
    return row


# ─────────────────────────────────────────────
# Items
# ─────────────────────────────────────────────
def get_items(category_id=None, search=None):
    con = get_db()
    sql = """
        SELECT i.*, c.name AS cat_name, t.name AS type_name
        FROM items i
        LEFT JOIN categories c ON i.category_id=c.id
        LEFT JOIN item_types t ON i.item_type_id=t.id
        WHERE 1=1
    """
    params = []
    if category_id:
        sql += " AND i.category_id=?"
        params.append(category_id)
    if search:
        sql += " AND (i.name LIKE ? OR i.item_number LIKE ? OR i.location LIKE ?)"
        s = f"%{search}%"
        params += [s, s, s]
    sql += " ORDER BY c.sort_order, i.name"
    rows = con.execute(sql, params).fetchall()
    con.close()
    return rows


def get_item(item_id):
    con = get_db()
    row = con.execute("""
        SELECT i.*, c.name AS cat_name, t.name AS type_name
        FROM items i
        LEFT JOIN categories c ON i.category_id=c.id
        LEFT JOIN item_types t ON i.item_type_id=t.id
        WHERE i.id=?
    """, (item_id,)).fetchone()
    con.close()
    return row


def get_low_stock_items():
    con = get_db()
    rows = con.execute("""
        SELECT i.*, c.name AS cat_name
        FROM items i
        LEFT JOIN categories c ON i.category_id=c.id
        WHERE i.min_stock > 0 AND i.stock <= i.min_stock
        ORDER BY (i.stock - i.min_stock), i.name
    """).fetchall()
    con.close()
    return rows


def get_inventory_value():
    """Returns total inventory value and value per category."""
    con = get_db()
    total = con.execute("SELECT COALESCE(SUM(value*stock),0) FROM items").fetchone()[0]
    by_cat = con.execute("""
        SELECT c.name, COALESCE(SUM(i.value*i.stock),0) AS val, COUNT(i.id) AS cnt
        FROM categories c
        LEFT JOIN items i ON i.category_id=c.id
        GROUP BY c.id
        ORDER BY c.sort_order, c.name
    """).fetchall()
    con.close()
    return total, by_cat


# ─────────────────────────────────────────────
# Movements
# ─────────────────────────────────────────────
def get_movements(item_id, limit=30):
    con = get_db()
    rows = con.execute("""
        SELECT m.*, u.username,
               CASE m.type WHEN 'take' THEN tr.label ELSE sr.label END AS reason_label
        FROM movements m
        JOIN users u ON m.user_id=u.id
        LEFT JOIN take_reasons  tr ON m.type='take'  AND m.reason_id=tr.id
        LEFT JOIN store_reasons sr ON m.type='store' AND m.reason_id=sr.id
        WHERE m.item_id=?
        ORDER BY m.created_at DESC
        LIMIT ?
    """, (item_id, limit)).fetchall()
    con.close()
    return rows


def record_movement(item_id, user_id, mtype, reason_id, quantity, source="", notes=""):
    con = get_db()
    con.execute(
        "INSERT INTO movements(item_id,user_id,type,reason_id,quantity,source,notes) "
        "VALUES(?,?,?,?,?,?,?)",
        (item_id, user_id, mtype, reason_id or None, quantity, source, notes)
    )
    mov_id = con.execute("SELECT last_insert_rowid()").fetchone()[0]
    if mtype == "take":
        con.execute("UPDATE items SET stock=MAX(0,stock-?) WHERE id=?", (quantity, item_id))
    else:
        con.execute("UPDATE items SET stock=stock+? WHERE id=?", (quantity, item_id))
    con.commit()
    con.close()
    return mov_id


# ─────────────────────────────────────────────
# Loans
# ─────────────────────────────────────────────
def create_loan(item_id, user_id, movement_id, quantity, due_date):
    con = get_db()
    con.execute(
        "INSERT INTO loans(item_id,user_id,movement_id,quantity,due_date) VALUES(?,?,?,?,?)",
        (item_id, user_id, movement_id, quantity, due_date)
    )
    con.commit()
    con.close()


def get_user_loans(user_id, only_open=True):
    con = get_db()
    sql = """
        SELECT l.*, i.name AS item_name, i.item_number, i.location
        FROM loans l
        JOIN items i ON l.item_id=i.id
        WHERE l.user_id=?
    """
    if only_open:
        sql += " AND l.returned_at IS NULL"
    sql += " ORDER BY l.due_date"
    rows = con.execute(sql, (user_id,)).fetchall()
    con.close()
    return rows


def get_overdue_loans():
    con = get_db()
    rows = con.execute("""
        SELECT l.*, i.name AS item_name, i.item_number, u.username,
               julianday('now') - julianday(l.due_date) AS days_overdue
        FROM loans l
        JOIN items i ON l.item_id=i.id
        JOIN users u ON l.user_id=u.id
        WHERE l.returned_at IS NULL AND l.is_overdue=1
        ORDER BY days_overdue DESC
    """).fetchall()
    con.close()
    return rows


def return_loan(loan_id, notes=""):
    """Mark loan as returned.
    No separate movement/stock update — the caller (store.mu) already handles that."""
    now = _now()
    con = get_db()
    loan = con.execute("SELECT * FROM loans WHERE id=?", (loan_id,)).fetchone()
    if loan and not loan["returned_at"]:
        con.execute(
            "UPDATE loans SET returned_at=?, return_notes=?, is_overdue=0 WHERE id=?",
            (now, notes, loan_id)
        )
        con.commit()
    con.close()


def close_loan_admin(loan_id, notes=""):
    """Admin writes off a loan without a physical return."""
    now = _now()
    con = get_db()
    con.execute(
        "UPDATE loans SET returned_at=?, return_notes=?, is_overdue=0 WHERE id=?",
        (now, notes or "Admin write-off", loan_id)
    )
    con.commit()
    con.close()


# ─────────────────────────────────────────────
# Reservations
# ─────────────────────────────────────────────
def create_reservation(item_id, user_id, quantity, reserved_from, reserved_until, notes=""):
    con = get_db()
    con.execute(
        "INSERT INTO reservations(item_id,user_id,quantity,reserved_from,reserved_until,notes) "
        "VALUES(?,?,?,?,?,?)",
        (item_id, user_id, quantity, reserved_from, reserved_until, notes)
    )
    con.commit()
    con.close()


def get_item_reservations(item_id):
    con = get_db()
    rows = con.execute("""
        SELECT r.*, u.username
        FROM reservations r
        JOIN users u ON r.user_id=u.id
        WHERE r.item_id=? AND r.reserved_until >= date('now')
        ORDER BY r.reserved_from
    """, (item_id,)).fetchall()
    con.close()
    return rows


def get_reserved_qty(item_id):
    """Sum of all active reservations for an item (currently within time window)."""
    con = get_db()
    row = con.execute("""
        SELECT COALESCE(SUM(quantity), 0) AS total
        FROM reservations
        WHERE item_id=?
          AND reserved_from <= date('now')
          AND reserved_until >= date('now')
    """, (item_id,)).fetchone()
    con.close()
    return row["total"] if row else 0


def get_user_reservations(user_id):
    con = get_db()
    rows = con.execute("""
        SELECT r.*, i.name AS item_name, i.item_number
        FROM reservations r
        JOIN items i ON r.item_id=i.id
        WHERE r.user_id=? AND r.reserved_until >= date('now')
        ORDER BY r.reserved_from
    """, (user_id,)).fetchall()
    con.close()
    return rows


def delete_reservation(res_id, user_id):
    con = get_db()
    con.execute("DELETE FROM reservations WHERE id=? AND user_id=?", (res_id, user_id))
    con.commit()
    con.close()


# ─────────────────────────────────────────────
# Reasons
# ─────────────────────────────────────────────
def get_take_reasons():
    con = get_db()
    rows = con.execute("SELECT * FROM take_reasons ORDER BY label").fetchall()
    con.close()
    return rows


def get_store_reasons():
    con = get_db()
    rows = con.execute("SELECT * FROM store_reasons ORDER BY label").fetchall()
    con.close()
    return rows


# ─────────────────────────────────────────────
# Item Types / Templates
# ─────────────────────────────────────────────
def get_item_types():
    con = get_db()
    rows = con.execute("SELECT * FROM item_types ORDER BY name").fetchall()
    con.close()
    return rows


def get_item_type(type_id):
    con = get_db()
    row = con.execute("SELECT * FROM item_types WHERE id=?", (type_id,)).fetchone()
    con.close()
    return row


# ─────────────────────────────────────────────
# Micron Helper Functions
# ─────────────────────────────────────────────
def nav_bar(user, token="", back_url=None):
    lines = []
    lines.append("-")
    parts = []
    parts.append(f"`[Warehouse`{page_path}/index.mu`session={token}]")
    parts.append(f"`[Inventory`{page_path}/inventory.mu`session={token}]")
    parts.append(f"`[Help`{page_path}/help.mu`session={token}]")
    if user:
        parts.append(f"`[My Loans`{page_path}/my_loans.mu`session={token}]")
        parts.append(f"`[Reservations`{page_path}/my_reservations.mu`session={token}]")
    if user and user["is_admin"]:
        parts.append(f"`F1a6`[Admin`{page_path}/admin/admin.mu`session={token}]`f")
    if user:
        parts.append(f"`[Logout`{page_path}/logout.mu`session={token}]")
    else:
        parts.append(f"`[Login`{page_path}/login.mu]")
        parts.append(f"`[Register`{page_path}/register.mu]")
    if back_url:
        parts.append(f"`[<- Back`{back_url}]")
    parts.append(f"`Fca4`[← Node Home`{node_homepage}]`f")
    lines.append("  ".join(parts))
    lines.append("-")
    return "\n".join(lines)


def fmt_time(ts):
    if not ts:
        return ""
    try:
        dt = datetime.strptime(ts[:16], "%Y-%m-%dT%H:%M")
        return dt.strftime("%d-%m-%Y %H:%M")
    except Exception:
        return ts[:16]


def fmt_date(ts):
    if not ts:
        return ""
    try:
        return datetime.strptime(ts[:10], "%Y-%m-%d").strftime("%d-%m-%Y")
    except Exception:
        return ts[:10]


def stock_color(stock, min_stock):
    """Returns Micron color code for stock display (3 hex digits, no F-prefix)."""
    if min_stock > 0 and stock == 0:
        return "f55"   # red: empty
    if min_stock > 0 and stock <= min_stock:
        return "ca4"   # orange: below minimum
    return "1a6"       # green: okay


def item_link(item, token=""):
    return f"`[{item['name']}`{page_path}/item_detail.mu`id={item['id']}|session={token}]"


def user_link(username, user_id, token=""):
    return f"`[{username}`{page_path}/profile.mu`uid={user_id}|session={token}]"


def error(msg):
    print(f"`Ff55{msg}`f")


def success(msg):
    print(f"`F1a6{msg}`f")


def notice(msg):
    print(f"`F4af{msg}`f")


def require_login(token):
    """Return user or print error message and exit."""
    user = get_session_user(token)
    if not user:
        error("Not logged in.")
        print(f"`[-> Login`{page_path}/login.mu]")
        exit()
    return user


def require_admin(token):
    user = require_login(token)
    if not user["is_admin"]:
        error("Access denied.")
        exit()
    return user


# ─────────────────────────────────────────────
# Internal Helpers
# ─────────────────────────────────────────────
def _now():
    return datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")


def _dt_now():
    return datetime.utcnow()


def _today():
    return datetime.utcnow().strftime("%Y-%m-%d")


# ─────────────────────────────────────────────
# Init on import
# ─────────────────────────────────────────────
def print_header(subtitle=None):
    """Unified page header: site name + description."""
    print(f"`!`F0af{site_name}`!`f")
    print(f"`F777{site_description}`f")
    if subtitle:
        print(f"`F555{subtitle}`f")
    print("")

def print_footer():
    """Footer with suite notice."""
    print("-")
    print("`F444Off-Grid Community Suite · NomadNet`f")

def lxmf_link(address):
    """Returns a clickable LXMF address link."""
    if address:
        return f"`[{address}`lxmf://{address}]"
    return ""


init_db()
cleanup()
