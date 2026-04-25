# Fire Hub — Phase 2: Seed Real Data Plan

**Goal:** Get AB's actual financial data into Fire Hub so he can use vanilla Sure for 2-4 weeks and discover what's genuinely missing before building the bespoke FI dashboard in Phase 3.

**Architecture:** All AB's data lives in his own `Family` (created at registration), separate from the demo `dylan_family` family. Demo data stays as a reference/sandbox — no `db:reset` needed. The category tree is seeded from `db/seeds/fire_hub_categories.rb`; everything else is manual data entry.

**Estimated time:** 60-90 minutes of focused data entry, then 2-4 weeks of passive use.

---

## Task 1: Register your real account

In a terminal, start the app:

```sh
cd ~/Documents/fire-hub
bundle exec bin/rails server
```

Browser: `http://localhost:3000/registration/new`

Register with the email you actually want to use (e.g., `anzebenko@gmail.com`). Use a strong password — even though this is local-only, you'll be storing real account balances. Tailscale will eventually expose this app.

Sure's onboarding wizard runs after registration:
- Pick locale (`en`)
- Pick currency (`CAD`)
- Pick country (`CA`)
- Pick timezone (`America/Edmonton`)
- Pick date format (Canadian convention: `DD-MM-YYYY` or `YYYY-MM-DD`)

Land on dashboard. Your new family exists, no accounts yet.

---

## Task 2: Seed your Fire Hub category tree

In a *second* terminal:

```sh
cd ~/Documents/fire-hub
eval "$(/opt/homebrew/bin/rbenv init - zsh)"
FIRE_HUB_USER=anzebenko@gmail.com bin/rails runner db/seeds/fire_hub_categories.rb
```

Replace `anzebenko@gmail.com` with whatever email you registered with.

Expected output: prints "Done." with three category counts (Fixed Costs: 9 children, Variable Costs: 9 children, Investment Income: 0 children).

Browser: `/categories` — confirm the tree exists. Children of "Fixed Costs": Mortgage, Hydro, Water, Internet, Cellphone, Daycare, Property Tax, Insurance, Subscriptions. Children of "Variable Costs": Groceries, Restaurants, Gas, Entertainment, Kids, Clothing, Medical, Gifts, Travel.

**Tweak as needed.** Rename, delete, or add children to match your actual life. The names of the *parents* ("Fixed Costs", "Variable Costs", "Investment Income") matter for Phase 3 — keep those exact strings. The children are flexible.

---

## Task 3: Create your accounts

Browser: `/accounts` → "New account" for each.

| Account | Sure type | Currency | Notes |
|---|---|---|---|
| Chequing | Depository → Checking | CAD | Whatever your daily account is |
| Savings | Depository → Savings | CAD | If you have one |
| TFSA | Investment | CAD | The "engine" — Phase 3 highlights this |
| RRSP | Investment | CAD | If applicable |
| Non-Reg | Investment | CAD | If applicable |
| Credit Cards | Credit Card | CAD | One per card |
| Mortgage | Loan | CAD | Set principal as starting balance |
| Car Loan | Loan | CAD | If applicable |

Set **starting balance** from your most recent statement for each. Sure will track the account from that point forward.

For investment accounts, you'll add Holdings separately under each account (Holdings tab) — pick the security ticker (e.g., HYLD.TO, XEQT.TO, VFV.TO), share count, average cost. Sure pulls live prices via `MarketDataImporter`.

---

## Task 4: Backfill 3 months of fixed costs

Most of these are recurring transactions Sure could auto-detect — but it needs *some* history first. Manual entry of the last 3 months gives Phase 3's "monthly fixed cost" calculation an anchor immediately.

For each fixed cost (mortgage, hydro, water, internet, cellphone, daycare, insurance, etc.):

1. Browser: `/transactions/new` (or use Sure's transaction-entry shortcut from any account view).
2. Pick the account it came from (usually chequing).
3. Pick the category (e.g., "Mortgage").
4. Enter the amount and date for each of the last 3 monthly occurrences.

After ~3 monthly cycles in the data, browse `/recurring_transactions` — Sure should auto-detect each fixed bill and start projecting next-expected dates. If it doesn't, manually create the recurring transaction record at `/recurring_transactions/new`.

---

## Task 5: Backfill 12 months of TFSA distributions

This is the *numerator* of your FI coverage ratio — how much your TFSA paid you.

Pull your TFSA's distribution history from your brokerage statement (Wealthsimple / Questrade / IBKR — the brokerage usually has a dedicated "income" section in its activity export). For each distribution event:

1. Create an income category under "Investment Income" if it doesn't exist (e.g., "TFSA Distributions").
2. Enter a transaction in the TFSA account:
   - **Account:** TFSA
   - **Category:** TFSA Distributions
   - **Amount:** the distribution amount (positive)
   - **Date:** the distribution date
3. If the distribution was DRIPped (auto-reinvested), also enter a Trade in the TFSA for the corresponding share purchase. If it was paid as cash, leave it as a transaction only.

Repeat for last 12 months. This is the slowest part — budget 30-45 minutes if you have weekly distribution payers.

**Time-saver:** if your brokerage provides a CSV export of distributions, import it via `/imports/new` (Sure's import system handles transaction CSV imports). Map the columns: Date, Description (security name), Amount, Category ("TFSA Distributions"), Account ("TFSA"). One bulk import vs. dozens of manual entries.

---

## Task 6: Set monthly target lifestyle cost

For now, this is informational. Phase 3 will wire it into the dashboard.

Browse `/settings/profile` — Sure may not have a target-cost field yet. That's fine; jot your number down somewhere (~$5,500/mo or whatever). Phase 3 will add the field via Sure's `Setting` model.

---

## Task 7: Live with it for 2-4 weeks

Daily / weekly:
- Categorize new transactions as they happen (chequing transactions especially).
- Glance at `/recurring_transactions` — confirm Sure detected each fixed bill correctly.
- Glance at `/budgets` — Sure auto-creates monthly budgets you can adjust.
- Glance at `/reports` — period-by-period income/expense breakdowns.
- For investments, glance at the per-account view to see distributions accumulating.

After 2-4 weeks, return with a concrete list answering: "what does Sure NOT show me that I want for FI tracking?" Examples that would justify Phase 3:

- "Sure shows total income vs total expense, but doesn't separate fixed-cost-coverage from variable-cost-coverage by distributions specifically."
- "Sure has no view that says 'your distributions cover X% of your monthly bills'."
- "I want to see per-account distribution rates side-by-side, not just total."

If those gaps exist, Phase 3 builds the FI dashboard to fill them.
If Sure's existing views actually cover everything: ship a small "FI snapshot" widget on the dashboard and call it done.

---

## Out of scope for Phase 2

- Any code changes (no schema, no controllers, no views).
- Backups + Mac mini deploy — Phase 4.
- Plaid/SimpleFIN/SnapTrade automation — post-Phase 5 unless manual entry becomes too painful.

---

## Done definition

Phase 2 is "done" when:
- AB has registered a real account with his real email.
- The category tree exists under his family.
- All real accounts exist with starting balances.
- 3 months of fixed-cost transactions are entered.
- 12 months of TFSA distributions are entered.
- AB has used the app for at least 2 weeks across normal life events (paying bills, getting paid, receiving distributions).
- AB has a written list of "what's still missing" that informs Phase 3 spec revisions.

Tag at the end: `v0.2.0-real-data` (after the 2-4 week soak period, not when seeding finishes).
