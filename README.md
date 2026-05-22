# AgentLedger PH — Lazarus / FPC version

A Windows desktop ledger application for small GCash / e-wallet agents in the Philippines. Built with **Lazarus 3.x** + **Free Pascal Compiler 3.2+**, using **SQLdb + SQLite**. Free for **all** uses — including commercial.

Tracks daily cash and wallet balances, records Cash-In / Cash-Out / E-Load / Bills Payment / Send Money / Utang / Manual Adjustment transactions, auto-computes service fees from configurable rules, manages customer utang with partial payments, and produces end-of-day reconciliation and reports.

---

## Quick start

### 1. Install Lazarus

Download **Lazarus 3.0** or newer from <https://www.lazarus-ide.org/>. The Windows installer is around 150 MB and bundles FPC. During install you can choose any destination drive (e.g. `D:\Lazarus`).

No account, no email, no license tier.

### 2. Make sure SQLite is reachable

This app needs `sqlite3.dll` (on Windows) findable by the OS. Either:

- Use the one bundled with Lazarus — usually at `<lazarus-install>\sqlite3.dll`, automatically on PATH; **or**
- Drop `sqlite3.dll` (32-bit if you compile Win32, 64-bit if Win64) next to the compiled EXE. Get the official build from <https://sqlite.org/download.html>.

If the app starts but fails the database init with a "can't load library" error, this is the cause.

### 3. Open and build

1. Open `AgentLedgerPH.lpi` in Lazarus.
2. **Run → Build** (`Ctrl+F9`).
3. **Run → Run** (`F9`).

On first launch the app creates `data\agentledger.db` next to the executable and seeds a default Owner:

| Username | Password   | Role  |
|----------|------------|-------|
| `admin`  | `admin123` | Owner |

Change this password immediately from **Master → Users**.

### 4. Seed sample data

After logging in, use **File → Seed sample data** to populate:

- Default fee rules for Cash-In, Cash-Out, E-Load, Bills Payment, Send Money
- A few sample customers
- Two extra users (`staff1`/`staff123` and `viewer1`/`viewer123`)

---

## Folder layout

```
AgentLedger PH Lazarus/
├── AgentLedgerPH.lpr            — program entry point
├── AgentLedgerPH.lpi            — Lazarus project file
├── data/                        — SQLite database (created at runtime)
├── backups/                     — backup files (created on first backup)
└── src/
    ├── DataModule/
    │   ├── uDM.pas              — TSQLite3Connection + TSQLTransaction
    │   └── uDM.lfm
    ├── Models/
    │   └── uModels.pas
    ├── Services/
    │   ├── uSession.pas         — current-user / session state
    │   ├── uAuthService.pas     — login, password hashing (SHA-1+salt), user CRUD
    │   ├── uSessionService.pas  — open/close daily session, expected totals
    │   ├── uTransactionService.pas — record txns, compute cash/wallet impact
    │   ├── uCustomerService.pas
    │   ├── uFeeService.pas      — configurable fee rule lookup
    │   ├── uUtangService.pas    — debt + partial-payment tracking
    │   ├── uAuditService.pas
    │   ├── uBackupService.pas   — DB file backup / restore
    │   └── uSeedService.pas
    ├── Reports/
    │   └── uReportService.pas
    └── Forms/
        ├── uFormLogin            (.pas + .lfm)
        ├── uFormMain             (.pas + .lfm)  ← dashboard + main menu
        ├── uFormSession          (.pas + .lfm)
        ├── uFormTransaction      (.pas + .lfm)
        ├── uFormCustomers        (.pas + .lfm)
        ├── uFormUtang            (.pas + .lfm)
        ├── uFormFeeRules         (.pas + .lfm)
        ├── uFormUsers            (.pas + .lfm)
        ├── uFormReconciliation   (.pas + .lfm)
        ├── uFormReports          (.pas + .lfm)
        └── uFormAuditLog         (.pas + .lfm)
```

---

## Architecture

Same layered design as the Delphi version:

- **Forms** (LCL UI) call services. No SQL in form code.
- **DataModule** owns one `TSQLite3Connection` + one `TSQLTransaction` with helpers:
  `NewQuery`, `ExecSQL`, `Commit`, `LastInsertRowId`, `ScalarInt/Float/Str`.
- **Models** are plain records and enums.
- **Services** hold business logic, parameterized SQL, role checks, and audit writes.
- **Reports** are read-only aggregation queries returning typed records.

Pascal language mode is `{$mode delphi}` throughout — code reads almost identically to Delphi.

---

## Differences from the Delphi version

| Topic | Delphi | Lazarus port |
|---|---|---|
| Database driver | FireDAC (`TFDConnection`, `TFDQuery`) | SQLdb (`TSQLite3Connection`, `TSQLQuery`, `TSQLTransaction`) |
| Transaction model | Auto-commit | Explicit `CommitRetaining` via `DM.Commit` after each DML |
| Password hash | SHA-256 (`System.Hash.THashSHA2`) | **SHA-1 + salt** (FPC stdlib `sha1` unit) — hash values are not interoperable with the Delphi build's DB |
| File I/O | `System.IOUtils.TPath/TFile/TDirectory` | `SysUtils` + `FileUtil` + `LazFileUtils` |
| Form files | `.dfm` | `.lfm` |
| Project file | `.dpr` / `.dproj` | `.lpr` / `.lpi` |
| Generics | `System.Generics.Collections` | `Generics.Collections` (FPC's port — same syntax) |
| Cost | Free for non-commercial; paid otherwise | **Free, commercial use included** |

The SQLite schema, the cash/wallet math, the role model, the audit log structure, and every UI screen are identical to the Delphi build. You cannot, however, swap a database file between the two builds: passwords are hashed differently. Either rotate passwords after switching builds, or pick one build and stick with it.

---

## Roles, sessions, cash/wallet math, fee rules, utang, reports, backup, audit log

Identical to the Delphi build. See those sections in the original README for the full spec. In short:

- **Roles** — Owner (full control), Staff (transactions + reconcile + customer add/edit), Viewer (read-only).
- **Sessions** — start with `Open Session` (starting cash + starting wallet). One open at a time.
- **Cash & wallet impact** per transaction type:
  - Cash-In:    `cash += amount+fee`, `wallet -= amount`
  - Cash-Out:   `cash -= amount`,     `wallet += amount+fee`
  - E-Load / Bills / Send Money: `cash += amount+fee`, `wallet -= amount`
  - Utang Payment: `cash += amount`
  - Manual Adjustment: amount field = signed cash, fee field = signed wallet
- **Reconcile** — enter counted cash and wallet; system shows short / over.
- **Utang** — tick the utang box on a transaction (with a chosen customer) to log it as outstanding. Pay it back later via **Master → Utang**, partial payments allowed.
- **Reports** — Daily Closing, Service Fee Profit, Cash-In vs Cash-Out, Staff Activity.
- **Backup** — File → Backup writes a `.db` file to `backups\` with a timestamp; Restore replaces the live DB after a safety copy.
- **Audit log** — every privileged action is recorded with user, action, entity, entity_id, details, timestamp.

---

## Notes & limitations

- Passwords use SHA-1 with a fixed application salt. For local single-shop use this is fine; for production deployment to many agents, swap to PBKDF2 / bcrypt via a third-party FPC crypto package (`DCPcrypt`, `HashLib4Pascal`).
- Backups are unencrypted SQLite files. Treat them with the same care as the live DB.
- Single-machine app — SQLite, one user at a time. No network/multi-station support.
- Amounts are stored as SQLite `REAL` (binary floating point). For very high-precision accounting, switch to integer centavos.

---

## Default credentials after seeding

| Username  | Password    | Role   |
|-----------|-------------|--------|
| `admin`   | `admin123`  | Owner  |
| `staff1`  | `staff123`  | Staff  |
| `viewer1` | `viewer123` | Viewer |

**Change all of these before going live.**
