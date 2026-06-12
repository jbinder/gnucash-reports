# Transaction Report (D/C Totals) — GnuCash Custom Report

A custom GnuCash report based on the standard Transaction Report, adding separate
**Total Debit** and **Total Credit** rows at the bottom of the report. The built-in
Transaction Report only shows a combined net total, with no way to sum the Debit and
Credit columns independently.

---

## Requirements

- GnuCash 5.x (tested on 5.15)
- Linux, macOS, or Windows

---

## Installation

### Step 1 — Find your directories

Open **Help → About GnuCash** and note the two paths:

| Variable | Purpose |
|---|---|
| `GNC_DATA_HOME` | Where the `.scm` report file goes |
| `GNC_CONFIG_HOME` | Where the `config-user.scm` loader file goes |

On Linux these are typically:
- `GNC_DATA_HOME` → `~/.local/share/gnucash/`
- `GNC_CONFIG_HOME` → `~/.config/gnucash/`

On macOS:
- `GNC_DATA_HOME` → `~/Library/Application Support/GnuCash/`
- `GNC_CONFIG_HOME` → `~/Library/Application Support/GnuCash/`

On Windows:
- Both are typically `%APPDATA%\GnuCash\`

Always use the values shown in **Help → About** rather than assuming the defaults.

### Step 2 — Copy the report file

Copy `transaction-with-dc-totals.scm` into your `GNC_DATA_HOME` directory.

```bash
# Linux example
cp transaction-with-dc-totals.scm ~/.local/share/gnucash/
```

### Step 3 — Register the report

In your `GNC_CONFIG_HOME` directory, open or create a file named exactly
`config-user.scm` and add this line:

```scheme
(load (gnc-build-userdata-path "transaction-with-dc-totals.scm"))
```

```bash
# Linux example — create the file if it doesn't exist
echo '(load (gnc-build-userdata-path "transaction-with-dc-totals.scm"))' \
  >> ~/.config/gnucash/config-user.scm
```

### Step 4 — Restart GnuCash

After restarting, the report appears in the **Reports** menu as
**Transaction Report (D/C Totals)**.

---

## Usage

1. Open **Reports → Transaction Report (D/C Totals)**
2. Click the gear icon to open report options
3. On the **Display** tab:
   - Set **Amount** to **Double** — this creates separate Debit and Credit columns
   - Tick **Show Debit/Credit Totals** (enabled by default)
4. On the **Accounts** tab, select the account(s) to report on
5. On the **General** tab, set your date range
6. Click **OK** to run the report

The report will show a **Total Debit** and **Total Credit** row at the bottom.
With Amount set to **Single**, a single net **Grand Total** row is shown instead.

To avoid re-entering settings each time, save the configured report via
**File → Save Report Configuration**.

---

## Troubleshooting

If the report does not appear in the menu after restarting GnuCash, run GnuCash
from a terminal to see any load errors:

```bash
gnucash 2>&1 | grep -i "error\|warn\|dc-totals"
```

Common issues:

| Symptom | Cause | Fix |
|---|---|---|
| Report not in menu | `.scm` file in wrong directory | Check `GNC_DATA_HOME` in Help → About |
| Report not in menu | `config-user.scm` in wrong directory | Check `GNC_CONFIG_HOME` in Help → About |
| Report not in menu | Typo in `config-user.scm` | Filename in `load` call must match exactly |
| "Report error" on open | Stale compiled cache | Delete `~/.cache/guile/ccache/` and restart |
