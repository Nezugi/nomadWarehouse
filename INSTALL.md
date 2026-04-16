# nomadWarehouse — Installation Guide

A shared inventory system for NomadNet nodes. Users can view stock, withdraw and return items, create loans, and manage reservations. Admins control user permissions per category.

---

## Requirements

- Python 3.8+
- NomadNet node with page serving enabled
- Packages: `pip install -r requirements.txt`

---

## Setup

### 1. Copy files

Copy the entire `warehouse/` folder into your NomadNet pages directory:

```
~/.nomadnetwork/storage/pages/warehouse/
```

### 2. Configure main.py

Edit the configuration block at the top of `main.py`:

```python
storage_path = "/home/youruser/.nomadWarehouse"   # path for the database
page_path    = ":/page/warehouse"                  # must start with :
site_name    = "nomadWarehouse"                    # display name shown in pages
node_homepage = ":/page/index.mu"                  # back link to your node home
```

### 3. Make pages executable

```bash
chmod +x ~/.nomadnetwork/storage/pages/warehouse/*.mu
chmod +x ~/.nomadnetwork/storage/pages/warehouse/admin/*.mu
```

### 4. Create the first admin account

```bash
cd ~/.nomadnetwork/storage/pages/warehouse/
python3 create_admin.py
```

### 5. Open in NomadNet

Navigate to:
```
:/page/warehouse/index.mu
```

---

## File Overview

```
warehouse/
├── index.mu               ← Dashboard: categories, stock warnings, search
├── inventory.mu           ← Item list with search and category filter
├── item_detail.mu         ← Item details + movement history
├── new_item.mu            ← Create new item
├── edit_item.mu           ← Edit existing item
├── take.mu                ← Withdraw item (reason, quantity, loan)
├── store.mu               ← Store item (reason, source, loan return)
├── my_loans.mu            ← User's open loans
├── my_reservations.mu     ← User's reservations
├── reserve.mu             ← Reserve / cancel reservation
├── login.mu               ← Login form
├── logout.mu              ← Session logout
├── register.mu            ← New account registration
├── help.mu                ← User help page
├── main.py                ← Central library (DB, sessions, helpers)
├── create_admin.py        ← CLI: create or promote admin user
├── requirements.txt       ← Python dependencies
└── admin/
    ├── admin.mu           ← Admin dashboard + quick stats
    ├── users.mu           ← Users + permissions management
    ├── categories.mu      ← Category management
    ├── reasons.mu         ← Withdrawal / store reason management
    ├── item_types.mu      ← Item types / templates
    ├── overdue.mu         ← Overdue loans list
    └── low_stock.mu       ← Min stock warnings
```

---

## Permission Model

Each user has **global permissions** and additionally **per-category permissions**.

| Permission    | Description                              |
|---------------|------------------------------------------|
| View          | Browse inventory                         |
| Create items  | Add new items to a category              |
| Edit items    | Edit existing items                      |
| Withdraw      | Take items out of the warehouse          |
| Store         | Book items into the warehouse            |

Both global and category permissions must be granted for actions like withdrawing or storing. Admins automatically have all rights across all categories.

---

## Loans & Returns

- When withdrawing, an optional return date can be set
- The loan then appears in the user's `my_loans.mu` list
- Returning works via `store.mu` — check "Mark as loan return"
- Overdue loans are flagged automatically on the next page load
- Admins can see all overdue loans in `admin/overdue.mu` and can mark them returned or write them off

---

## Reservations

- Items can be reserved for a future time window
- Reserved stock is excluded from the available quantity during that window
- Expired reservations are cleaned up automatically on each page load

---

## LXMF Addresses

Use `m.lxmf_link(address)` in any page to render a clickable LXMF address:

```python
print(m.lxmf_link("a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"))
# renders as: `[a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4`lxmf://a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4]
```
