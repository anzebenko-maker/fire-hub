# Fire Hub — MVP Design Spec

**Date:** 2026-04-24
**Status:** Spec locked, pre-implementation
**For:** AB (personal FI dashboard, self-hosted, not a productization)

---

## 1. Overview & Goal

**Fire Hub** is a self-hosted personal finance hub built by forking **[Sure](https://github.com/we-promise/sure)** — the actively-maintained community fork of the now-archived Maybe Finance — and extending it with a custom **FI (Financial Independence) progress dashboard**.

> **Base clarification (verified 2026-04-24):** The original `maybe-finance/maybe` repo is archived (final release `v0.6.0`, no longer maintained). The active successor is `we-promise/sure` (7,800+ stars, pushed today, actively developed, rebranded to "Sure" to sidestep Maybe's trademark). Fire Hub forks Sure. License is AGPLv3 (no constraints for personal self-hosted use). Per the trademark notice, the Fire Hub README must state that the app is based on Maybe Finance / Sure but is **not affiliated with or endorsed by Maybe Finance Inc.**

AB's north-star metric is "**investments pay for lifestyle**" — concretely, when monthly investment distributions (dividends, ETF distributions, interest) cover monthly lifestyle cost (fixed bills + variable spending), FI is achieved. The TFSA is the mental "engine" AB wants to grow; in practice, RRSP and non-registered accounts also contribute.

The tool is the single hub AB wants to track and build toward that outcome.

## 2. Scope & Non-goals

**In scope (MVP):**

- Fork Maybe Finance, run self-hosted on the Mac mini.
- Accounts: cash, credit cards, TFSA, RRSP, non-registered, mortgage, other debt.
- Transaction ledger with manual entry + CSV import (no bank-feed automation).
- Investment holdings + prices (Maybe's native capability).
- Net-worth view (Maybe's native; kept as secondary).
- **Custom FI Progress Dashboard** as the primary landing page.
- Tiered coverage metric (Lean FI / Full FI / Fat FI).
- Per-account distribution breakdown.
- Monthly distribution timeline chart.
- Fixed vs. variable cost itemization.
- Target lifestyle cost setting.

**Out of scope (MVP):**

- Plaid / SimpleFIN / any bank-feed automation (deferred — decide account-by-account after living with manual entry).
- Brokerage API integrations (Questrade, Wealthsimple, IBKR) — APIs are poor in CA anyway.
- Crypto exchange APIs.
- Crossover projection chart (needs 6+ months history to be meaningful).
- Savings-rate widget.
- What-if sliders.
- Per-holding distribution attribution.
- Multi-user / sharing.
- Public-internet hosting, TLS, domain.

**Non-goals (never):**

- Productization / selling to others. This is a personal tool.
- Replacing Maybe's existing net-worth engine or account/transaction models.

## 3. Architecture

**Base:** Fork of Sure (Rails 7.2, Hotwire/Turbo, PostgreSQL, Redis, Tailwind CSS, Sidekiq + `sidekiq-cron`).

**What Sure already ships** (verified 2026-04-24 by inspecting `we-promise/sure` `db/schema.rb`, `app/models/`, and `config/routes.rb`) — none of this needs to be built:

- **Accounts** (STI on `accountable_type`): `Depository`, `CreditCard`, `Investment`, `Crypto`, `Loan`, `Property`, `Vehicle`, `OtherAsset`, `OtherLiability`. Asset/liability classification is a virtual column.
- **Transactions** (via `Entry` + `Entryable` polymorphism) with categories, merchants, tags, and transfers.
- **Categories**: string `classification` ("expense" | "income"), parent/child hierarchy, color + Lucide icon, `bootstrap!` seeder with sensible defaults, auto-categorization via `Rule` model.
- **Budgets + BudgetCategories** (envelope-style, not needed for MVP but available).
- **Investments**: `Holding`, `Security`, `Trade`, `MarketDataImporter` (price feeds), multi-currency via `ExchangeRate`.
- **Net-worth + income aggregation**: `BalanceSheet` and `IncomeStatement` service objects already compute by-period and by-category totals, medians, averages. **The math for our coverage ratios can largely reuse `IncomeStatement` with a scope refinement — we do not need to write new aggregation queries from scratch.**
- **CSV import**: `TransactionImport`, `TradeImport`, `AccountImport`, `MintImport` (Mint CSV format).
- **Plaid integration**: `PlaidItem`, `PlaidAccount`, full OAuth + sync flow. Shipped. Deferred for MVP but "flip the switch" later, not "build it."
- **AI Assistant** (`Chat`, `Assistant`, `Message`, `ToolCall`): built-in chat that can call out to Anthropic / OpenAI. **Must be disabled in Fire Hub env config** to avoid surprise API charges — AB runs everything on Claude Max via `claude -p` and does not want paid API usage. Flag the disable in Phase 4 deploy.
- **MFA, sessions, registration, password reset, onboarding flow, settings (profile / preferences / hosting / security), family export, subscription page** — all shipped.

**Extensions (Fire Hub's bespoke layer):** Additive only — new migrations, a new controller/views for the FI dashboard, a new service object, and a couple narrow columns on existing tables. No modifications to Sure's core models or controllers. This keeps `git merge upstream/main` conflict-free.

**Hosting:** Native Rails on the Mac mini (no Docker). Puma serves HTTP on port 3000. Tailscale MagicDNS exposes it to AB's personal devices only.

**Data ingestion:** Manual transaction entry + CSV import via Sure's existing import UI. No external integrations enabled in MVP (Plaid + Mint CSV are shipped but stay off until AB chooses to enable per-account).

**Currency:** CAD primary, USD secondary (Sure handles multi-currency natively via `ExchangeRate`; price feeds already built in).

**Upstream sync strategy:** Fork has `upstream` remote tracking `we-promise/sure:main`. Monthly `git fetch upstream && git merge upstream/main`. All Fire Hub code lives in clearly-namespaced paths (`app/controllers/fi_dashboard_controller.rb`, `app/models/fi_coverage.rb`, `app/views/fi/*`, `db/migrate/*_fire_hub_*.rb`) so conflicts are rare.

## 4. Data Model Additions

All additions are schema-light and purely additive. Revised after verifying Sure already has `Category.classification` ("expense" | "income") — we refine within that instead of duplicating it.

### 4.1 `Category` — two narrow columns that refine existing `classification`

```ruby
# migration
add_column :categories, :fixed,     :boolean            # for expense categories; true = fixed cost, nil/false = variable
add_column :categories, :fi_source, :string             # for income categories; "distribution" = counts toward coverage, nil = employment/other
add_index  :categories, :fixed
add_index  :categories, :fi_source

# model
scope :fixed_expenses,     -> { expenses.where(fixed: true) }
scope :variable_expenses,  -> { expenses.where(fixed: [ false, nil ]) }
scope :distribution_income, -> { incomes.where(fi_source: "distribution") }
```

**Rationale:**
- `fixed` only applies to expense categories (mortgage, utilities, etc. vs. groceries, restaurants). Nullable — existing categories stay `nil` and default to variable behavior until reclassified.
- `fi_source` only applies to income categories. Set to `"distribution"` for "TFSA Distributions", "RRSP Distributions", etc. — the numerator of the coverage ratio. Left `nil` for paycheque/other income (not counted toward FI but stays tracked).
- Two narrow columns > one wide enum: cleaner semantics (each column means one thing), fewer migrations later, no overlap with Sure's existing `classification`.

### 4.2 `Family` — add FI settings

Maybe uses a `Family` model for the user household. Extend it with:

```ruby
# migration
add_column :families, :target_lifestyle_cost_cents, :integer
add_column :families, :fi_full_multiplier,          :decimal, precision: 4, scale: 2, default: 1.00
add_column :families, :fi_fat_multiplier,           :decimal, precision: 4, scale: 2, default: 1.20
add_column :families, :variable_lookback_months,    :integer, default: 3
```

- `target_lifestyle_cost_cents` — user-set monthly target cost, used for the "target coverage" view. Nullable (user may choose not to set one).
- `fi_full_multiplier` — Full FI denominator multiplier (default 1.0).
- `fi_fat_multiplier` — Fat FI denominator multiplier (default 1.2).
- `variable_lookback_months` — rolling window for variable-spending average.

### 4.3 `Account` — add one flag

```ruby
# migration
add_column :accounts, :counts_in_fi_engine, :boolean, default: true, null: false
```

Allows excluding accounts from FI math (e.g., a speculative crypto wallet, a kids' RESP). Defaults `true` for all investment-type accounts at seeding; `false` for cash/credit/loan accounts (they don't produce distributions anyway, but the flag is universal for model simplicity).

### 4.4 Derivation: no new transaction field

A transaction is a "distribution" iff:
- `transaction.category.classification == "income"` AND `transaction.category.fi_source == "distribution"`, AND
- `transaction.account.counts_in_fi_engine == true`, AND
- `transaction.account.accountable_type == "Investment"` (Sure's existing account type).

No new column on `transactions`. Categorization is the source of truth. AB reclassifies via Maybe's existing category UI.

**DRIP (reinvested) distributions:** A distribution counts toward the coverage ratio whether it was paid out as cash or auto-reinvested. Rationale: the coverage ratio measures **what the portfolio produced**, not **what was withdrawn** — reinvested distributions are still income, just immediately redeployed. When a brokerage reports DRIPs as paired transactions (income in, buy out), both appear in the ledger and the income side feeds coverage. When a brokerage reports DRIPs only as share-count increases with no cash event (some do this), AB must enter the distribution manually as an `investment_income` transaction (and optionally a corresponding buy) to capture it in coverage. This is a known trade-off of manual ingestion.

### 4.5 Query shapes (for reference)

Leverages Sure's existing `IncomeStatement` and `Period` infrastructure rather than rolling fresh queries. The `FiCoverage` service object wraps `IncomeStatement` with narrower category scopes:

```ruby
# app/models/fi_coverage.rb — new service object
class FiCoverage
  def initialize(family)
    @family   = family
    @income   = IncomeStatement.new(family)
    @settings = family  # target_lifestyle_cost_cents, fi_full_multiplier, etc.
  end

  def monthly_fixed
    @income.expense_totals(
      period: Period.current_month,
      category_scope: family.categories.fixed_expenses
    ).total
  end

  def monthly_variable
    @income.avg_expense(
      interval: "month",
      category_scope: family.categories.variable_expenses,
      lookback: @settings.variable_lookback_months
    )
  end

  def monthly_distributions
    @income.income_totals(
      period: Period.current_month,
      category_scope: family.categories.distribution_income,
      account_scope: family.accounts.where(counts_in_fi_engine: true, accountable_type: "Investment")
    ).total
  end

  def lean_coverage = monthly_distributions / monthly_fixed
  def full_coverage = monthly_distributions / (monthly_fixed + monthly_variable * @settings.fi_full_multiplier)
  def fat_coverage  = monthly_distributions / (monthly_fixed + monthly_variable * @settings.fi_fat_multiplier)
end
```

**Note:** Sure's `IncomeStatement#expense_totals` and `#income_totals` don't currently accept `category_scope`/`account_scope` kwargs. Fire Hub adds this as a small, additive change to those methods (extending, not rewriting), or — preferred — subclasses/wraps them. Exact approach to be decided in the Phase 3 plan.

## 5. The FI Dashboard

**Location:** `/fi` — becomes the default landing page on login (override Maybe's default root route).

**Layout:** One scrollable page, four bands, desktop-first but usable on mobile (Tailwind responsive).

### 5.1 Band 1 — Tiered Coverage (hero)

Full-width. Three stacked horizontal progress bars:

- **Lean FI** — `distributions / fixed_costs` (green-gold)
- **Full FI** — `distributions / (fixed + variable × full_multiplier)` (blue)
- **Fat FI** — `distributions / (fixed + variable × fat_multiplier)` (purple)

Each bar shows:
- Percentage of the tier achieved (0-100%+, no hard cap).
- Dollar delta to close the gap ("$2,140 short of Lean FI").
- When ≥ 100%, bar glows subtly and label becomes "✓ Achieved +X%".

### 5.2 Band 2 — Engine + Lifestyle (two cards)

**Left card — "The Engine"**
- TFSA balance (headline).
- Engine total balance (TFSA + RRSP + non-reg, if multiple).
- Trailing-12-month distribution yield % (distributions ÷ avg engine balance).
- Last month's distributions ($, with MoM delta).
- Tiny sparkline of engine balance trajectory (last 12 months).

**Right card — "The Lifestyle"**
- Monthly fixed cost ($).
- Monthly variable cost (rolling 3-mo avg, $).
- Target lifestyle cost (if set by user, shown as reference line on the bars).
- Total monthly burn ($).

### 5.3 Band 3 — Distribution Timeline

Full-width bar chart. Last 12 months of distributions received, grouped by month.

- X-axis: month.
- Y-axis: $ received.
- Hover: per-account breakdown for that month.
- Toggle: monthly / weekly view.

Charting library: reuse whatever Maybe already bundles (likely Chartkick + Chart.js or similar).

### 5.4 Band 4 — Breakdowns (two tables)

**Left — Per-account distributions**

| Account | Last 12mo $ | Avg monthly | % of total |
|---|---|---|---|
| TFSA (highlighted) | ... | ... | ... |
| RRSP | ... | ... | ... |
| Non-reg | ... | ... | ... |

**Right — Fixed cost itemization**

| Category | Monthly avg | % of fixed |
|---|---|---|
| Mortgage | ... | ... |
| Hydro | ... | ... |
| Daycare | ... | ... |
| (etc.) | ... | ... |

Each row clickable → drills to Maybe's existing transaction list filtered to that account/category.

### 5.5 Design principle

**One unmistakable number per widget.** Scannable in 3 seconds:
- Band 1 = three percentages.
- Band 2 = two dollar amounts (distributions vs. burn).
- Band 3 = distribution trend shape.
- Band 4 = where the money comes from / goes to.

Top-to-bottom = summary to detail.

## 6. Setup & Hosting

### 6.1 Development environment (laptop)

- Ruby via `rbenv` (version per Maybe's `.ruby-version`).
- PostgreSQL via `brew install postgresql@16`.
- Redis via `brew install redis`.
- `bundle install`, `rails db:setup`, `rails server`, `bin/jobs` (or Sidekiq) in another terminal.

### 6.2 Production host (Mac mini)

- Same toolchain: rbenv, Postgres, Redis natively installed.
- App clone at `~/Code/fire-hub/` (or equivalent; AB's preference).
- Two `launchd` plists (stored in `~/Library/LaunchAgents/`):
  - `com.ab.firehub.web.plist` — runs `bundle exec puma -C config/puma.rb` on port 3000.
  - `com.ab.firehub.worker.plist` — runs background worker (SolidQueue or Sidekiq depending on Maybe's current).
- Both set to run at login and restart on crash.

### 6.3 Access

- Tailscale MagicDNS record (e.g., `fire-hub.tail-xxxxx.ts.net`) pointed at Mac mini, port 3000.
- No public exposure. No reverse proxy. No TLS cert management.
- If later a public URL is wanted, Caddy in front of Puma is a one-file config; not MVP.

### 6.4 Backups

- Nightly cron: `pg_dump fire_hub_production | age -r <pubkey> > ~/Backups/fire-hub/YYYY-MM-DD.sql.age`.
- 30-day rolling retention locally (delete older via cron).
- Weekly copy to iCloud Drive (monthly snapshots retained 1 year).
- Restore script committed as `bin/restore_backup` — takes a dated backup, decrypts, pipes to `psql`.
- Secrets (DB password, Rails `SECRET_KEY_BASE`, age key) stored in 1Password + `.env` (not committed).

### 6.5 Upstream sync

- Fork on GitHub. `upstream = maybe-finance/maybe`.
- Monthly cadence: `git fetch upstream && git merge upstream/main`. Resolve migration ordering if any.
- CI not needed at MVP; AB runs tests locally (`bin/rails test`).

## 7. Seed Data

Day-1 seeding to make the dashboard meaningful immediately:

### 7.1 Categories

Sure's `Category.bootstrap!` seeds a basic tree (Income, Loan Payments, Fees, Entertainment, Food & Drink, Shopping, Home Improvement, …). Fire Hub's seed extends that: subcategorizes where useful, sets `fixed: true` on fixed-cost categories, and adds the FI-specific income categories with `fi_source: "distribution"`.

**Fixed expense** (AB to finalize the list; starter set below):
- Mortgage
- Hydro / electricity
- Water / sewer
- Internet
- Cellphone
- Home / auto / life insurance
- Daycare
- Property tax (monthly-equivalent)
- Subscriptions (streaming, software, etc.)
- Car payment (if any)

**Variable expense** (starter):
- Groceries
- Restaurants / takeout
- Gas / transit
- Entertainment
- Kids (clothes, activities, etc.)
- Clothing
- Medical / dental (out-of-pocket)
- Gifts
- Travel

**Investment income:**
- TFSA distributions
- RRSP distributions
- Non-registered distributions / dividends
- Interest income

**Employment income:**
- Paycheque
- Bonus / other work income

### 7.2 Accounts

- TFSA (investment)
- RRSP (investment)
- Non-registered brokerage (investment) — if applicable
- Chequing (depository)
- Savings (depository)
- Credit cards (liability, one per card)
- Mortgage (liability, with starting balance)
- Car loan / line of credit (liability, if applicable)

Starting balances pulled from AB's most recent statements on seeding day.

### 7.3 Backfill

- **Fixed costs:** last 3 months of recurring transactions (mortgage, utilities, daycare, subscriptions) entered manually. This is the anchor for Lean FI and worth the ~30 minutes.
- **Distributions:** last 12 months of TFSA + RRSP + non-reg distributions from statements (usually available as CSV or PDF). This seeds the distribution timeline chart.
- **Variable:** not backfilled — starts accumulating from day one. Accept the variable number is noisy for the first 30 days.

### 7.4 Target lifestyle cost

AB sets `target_lifestyle_cost_cents` in settings on first login. Order-of-magnitude — can refine any time.

## 8. Phased Build Order

**Phase 1 — Foundation (days 1-3)**
1. Fork `we-promise/sure` to AB's GitHub as `fire-hub`. Clone to laptop + Mac mini.
2. Update README with AGPLv3 + "not affiliated with Maybe Finance Inc." attribution. Rename any "Sure"/"Maybe" branding in the UI shell to "Fire Hub" (trademark compliance).
3. Set up native dev env on laptop (rbenv, Postgres, Redis, `bin/setup`, `bin/dev`).
4. Verify vanilla Sure runs. Log in with demo credentials. Click through every page (dashboard, accounts, transactions, budgets, categories, holdings, settings) to internalize the UI.
5. **Disable AI Assistant**: set `OPENAI_ACCESS_TOKEN` / `ANTHROPIC_ACCESS_TOKEN` to empty in `.env.local`, or flag the relevant routes off. Verify no outbound AI calls on any page load.
6. Write the migration: `Category.fixed` + `Category.fi_source`, `Family` FI settings (target_lifestyle_cost_cents, multipliers, lookback), `Account.counts_in_fi_engine`.
7. Run migration on dev DB. Confirm app still boots and all vanilla pages still work.
8. Write model tests for the new columns and scopes (`fixed_expenses`, `variable_expenses`, `distribution_income`).

**Phase 2 — Seed real data (days 3-7)**
7. Define AB's full category tree (list fixed + variable + income categories).
8. Write a Rails seed script (`db/seeds/fire_hub_categories.rb`) that creates them with correct `kind` values.
9. Create accounts in UI. Set starting balances.
10. Backfill 3 months of fixed-cost transactions (manual entry).
11. Backfill 12 months of distribution transactions from statements.
12. Set `target_lifestyle_cost` in Family settings.

**Phase 3 — FI Dashboard (days 7-14)**
13. `FiCoverage` service object: coverage math, memoized queries.
14. `FiDashboardController#show` + `/fi` route.
15. Views: `app/views/fi/show.html.erb` with the four bands.
16. Band 1 — tiered coverage progress bars (Tailwind + a bit of custom CSS for the glow state).
17. Band 2 — Engine + Lifestyle cards.
18. Band 3 — distribution timeline chart (Chartkick-style).
19. Band 4 — the two breakdown tables.
20. Make `/fi` the post-login landing route (override Maybe's `root`).
21. Settings UI for Family FI fields (target cost, multipliers, lookback).
22. Controller + model tests for `FiCoverage`.

**Phase 4 — Deploy to Mac mini (day 14)**
23. Install rbenv / Postgres / Redis on Mac mini if not already.
24. Clone fork. `bundle install`. `rails db:create`.
25. Dump laptop DB, restore to Mac mini DB. Data lands intact.
26. Write two launchd plists. Load them. Confirm auto-start.
27. Add Tailscale MagicDNS record for the Mac mini.
28. First login from phone via Tailscale. Verify all four bands render.
29. Set up backup cron + iCloud copy. Test a restore in a scratch DB.

**Phase 5 — Live with it (weeks 3-6+)**
30. Categorize new transactions weekly.
31. Watch coverage bars move. Adjust target cost if it feels wrong.
32. Note which ingestion integrations would save real time. Build them one at a time as bespoke additions.

**MVP completion:** end of Phase 4 (~2 weeks of evenings/weekend work, longer if first-time Rails).

## 9. Deferred / v2+ (explicitly not MVP)

In rough order of likely value:

1. **Crossover projection chart** — requires ≥6 months of distribution trend data. When ready: linear extrapolation of distribution growth vs. flat lifestyle cost → projected date of 100% coverage.
2. **Savings rate widget** — `(employment_income - total_spending) / employment_income`, monthly. Answers "how hard am I feeding the engine?"
3. **SimpleFIN Bridge integration** — $15 USD/yr, covers major CA banks. Maybe already supports it; AB just enables and connects. Decide per-account.
4. **Plaid integration** — free dev tier, OAuth-y setup, Maybe already supports it.
5. **Crypto exchange APIs** (Coinbase, Kraken) — only if AB holds crypto.
6. **Per-holding distribution attribution** — "HYLD paid $X, XEQT paid $Y." Useful for yield-shopping decisions.
7. **What-if sliders** — "+ $500/mo contribution → crossover shifts by N months."
8. **Wealthsimple / Questrade scraped feeds** — unofficial community libs exist, brittle.
9. **Caddy + public URL** — only if AB ever wants the app reachable without Tailscale.
10. **Multi-device widget** — iOS home-screen widget showing current Lean FI %. Fun, not load-bearing.

## 10. Open Questions

None at spec-lock. All major decisions resolved during brainstorming + post-brainstorm code inspection:

- ✓ Fork (not build from scratch)
- ✓ **Base: `we-promise/sure`** (active community fork — `maybe-finance/maybe` is archived)
- ✓ Manual ingestion only in MVP (Plaid + Mint CSV are shipped but stay off)
- ✓ AI Assistant disabled in env config (no API costs)
- ✓ Tiered coverage metric (Lean / Full / Fat)
- ✓ Fixed vs. variable category split (via `Category.fixed` boolean)
- ✓ Distribution-income identified via `Category.fi_source = "distribution"`
- ✓ Aggregate all accounts, TFSA highlighted
- ✓ House = lifestyle cost (mortgage in fixed)
- ✓ Native Rails on Mac mini (no Docker)
- ✓ Tailscale for remote access
- ✓ Project name: Fire Hub (sidesteps Maybe/Sure trademark)
- ✓ Coverage math reuses Sure's existing `IncomeStatement` service object

## 11. References

- **Sure repo (our fork base):** https://github.com/we-promise/sure — community fork of Maybe Finance, active
- **Sure self-hosting docs:** https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md
- **Sure Discord:** https://discord.gg/36ZGBsxYEK
- **Sure DeepWiki:** https://deepwiki.com/we-promise/sure (browsable code-aware docs)
- **Maybe Finance (archived, historical):** https://github.com/maybe-finance/maybe, final release `v0.6.0`
- FIRE movement / coverage tiers: standard community taxonomy.
- TFSA contribution rules: CRA / [canada.ca/tfsa](https://www.canada.ca).
