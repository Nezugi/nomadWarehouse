# nomadWarehouse

A shared inventory management system for [NomadNet](https://github.com/markqvist/NomadNet) nodes — track stock, manage withdrawals and returns, control who can access what with per-category permissions.

> Part of the **Off-Grid Community Suite** for NomadNet nodes.

---

## Features

- **User accounts** with registration and admin approval
- **Per-category permissions** — view, take, store, create, edit — granted separately per user per category
- **Items** with name, article number, description, value, unit, storage location, minimum stock
- **Withdrawal** — optional return deadline; overdue items appear on the admin control list
- **Loan list** — each user sees their currently borrowed items
- **Deposit** — with admin-defined reasons and optional source field
- **Withdrawal reasons** — admin-defined, selectable on checkout
- **Deposit reasons** — separate admin-defined list
- **Reservations** — reserve items for a future time window; reserved stock excluded from available quantity
- **Movement history** — full log of all withdrawals and deposits
- **Low stock alerts** — items below minimum stock highlighted
- **Clickable LXMF addresses** throughout
- **Admin panel** — users, permissions, categories, items, reasons, overdue list
- **No external packages** — only Python standard library

---

## Installation

```bash
cp -r warehouse/ ~/.nomadnetwork/storage/pages/warehouse/
chmod +x ~/.nomadnetwork/storage/pages/warehouse/*.mu
chmod +x ~/.nomadnetwork/storage/pages/warehouse/admin/*.mu
mkdir -p /home/YOUR_USER/.nomadWarehouse
# edit main.py — set storage_path
python3 ~/.nomadnetwork/storage/pages/warehouse/create_admin.py
# restart NomadNet
```

> When updating files while NomadNet is running, use atomic swap to avoid "Text file busy":
> `cp file.mu /tmp/file.mu && mv /tmp/file.mu ~/.nomadnetwork/storage/pages/warehouse/file.mu`

---

## Configuration

```python
storage_path     = "/home/YOUR_USER/.nomadWarehouse"
page_path        = ":/page/warehouse"
site_name        = "nomadWarehouse"
site_description = "Shared inventory & resource management"
node_homepage    = ":/page/index.mu"
```

---

## Permission System

Permissions are granted **per user** and **per category**. A user needs both to act.

| Permission | What it allows |
|---|---|
| view | Browse inventory in this category |
| take | Withdraw items |
| store | Deposit items |
| create | Add new items |
| edit | Edit item details |

---

## Item Fields

| Field | Required |
|---|---|
| Name | ✓ |
| Article number | — |
| Description | — |
| Value | ✓ |
| Unit (pieces, kg, …) | ✓ |
| Storage location | ✓ |
| Minimum stock | — |
| Category | ✓ |

---

## File Structure

```
warehouse/
├── main.py              ← database, sessions, helpers
├── create_admin.py      ← CLI: create admin account
├── index.mu             ← inventory overview by category
├── login.mu / logout.mu / register.mu
├── inventory.mu         ← full inventory list
├── item_detail.mu       ← item detail + movement history
├── new_item.mu          ← add item
├── edit_item.mu         ← edit item
├── take.mu              ← withdrawal form
├── store.mu             ← deposit form
├── reserve.mu           ← reservation form
├── my_loans.mu          ← user's borrowed items
├── my_reservations.mu   ← user's reservations
├── help.mu              ← user guide
└── admin/
    ├── admin.mu         ← admin overview
    ├── users.mu         ← manage users & permissions
    ├── categories.mu    ← manage categories
    ├── reasons.mu       ← manage withdrawal / deposit reasons
    ├── overdue.mu       ← overdue loans control list
    ├── low_stock.mu     ← low stock alerts
    └── item_types.mu    ← item type management
```

---

## Permissions Overview

| Action | Guest | Registered (pending) | Approved User | Admin |
|---|---|---|---|---|
| Browse inventory | — | — | ✓ (if permitted) | ✓ |
| Withdraw items | — | — | ✓ (if permitted) | ✓ |
| Deposit items | — | — | ✓ (if permitted) | ✓ |
| Create items | — | — | ✓ (if permitted) | ✓ |
| Edit items | — | — | ✓ (if permitted) | ✓ |
| Manage users & permissions | — | — | — | ✓ |
| Manage categories | — | — | — | ✓ |
| View overdue list | — | — | — | ✓ |

---

## Database

SQLite at `~/.nomadWarehouse/warehouse.db` — created automatically on first run.

---

## Access

```
YOUR_NODE_HASH:/page/warehouse/index.mu
```

## License

MIT
