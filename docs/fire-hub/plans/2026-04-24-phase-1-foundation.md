# Fire Hub — Phase 1: Foundation (Lean) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up Fire Hub as a working fork of `we-promise/sure` on the laptop — booted, demo data loaded, AI disabled, README attributed — with **zero schema changes**. This is the "lean" Phase 1: we defer all Fire-Hub-specific code until we've lived with vanilla Sure long enough to know what's genuinely missing.

**Architecture:** Clone the fork, boot it, point AB's real data at it in Phase 2, evaluate what's missing in Phase 3. Sure ships ~90% of the machinery (BalanceSheet, IncomeStatement, RecurringTransaction detection, Reports, Budgets, InvestmentActivity page, Holdings/Securities/price feeds, Setting model for app-wide config). The bespoke Fire-Hub layer (FiCoverage service + `/fi` dashboard) is now Phase 3, not Phase 1, and its scope will be clearer after AB has used the shipped UI.

**Tech Stack:**
- Ruby 3.4.7 (per Sure's `.ruby-version`)
- Rails 7.2, Hotwire/Turbo, Tailwind
- PostgreSQL 14+, Redis 5.4+
- `bin/setup`, `bin/dev`, `bin/rails` — all shipped by Sure

**Working directory assumption:** All commands run from the Fire Hub repo root (`~/Documents/fire-hub/`) unless otherwise noted.

**Spec reference:** `~/Documents/fire-hub/docs/fire-hub/specs/2026-04-24-fire-hub-mvp-design.md`. Note §4 (schema additions) and §8 (phasing) will be updated to match this lean approach — the spec's "additions" now live in Phase 3, not Phase 1.

---

## Task 1: Fork, clone, consolidate docs

**Files:** the fork repo (new); `~/Documents/fire-hub/docs/` (moved into fork)

**Context:** A brainstorming-phase staging dir already exists at `~/Documents/fire-hub/` containing `docs/fire-hub/specs/` and `docs/fire-hub/plans/`. We need to clone the Sure fork into the same path without clobbering those docs, then commit them to the repo so the spec + plan travel with the code.

- [ ] **Step 1.1: Fork `we-promise/sure` on GitHub**

  ```bash
  gh repo fork we-promise/sure --clone=false --remote=false --fork-name=fire-hub
  ```
  Expected: `✓ Created fork <github-user>/fire-hub`.

- [ ] **Step 1.2: Stage existing docs out of the way**

  ```bash
  mv ~/Documents/fire-hub ~/Documents/fire-hub-docs-staging
  ```

- [ ] **Step 1.3: Clone the fork and add the upstream remote**

  ```bash
  cd ~/Documents
  gh repo clone fire-hub
  cd fire-hub
  git remote add upstream https://github.com/we-promise/sure.git
  git fetch upstream
  git remote -v
  ```
  Expected last output:
  ```
  origin    ...fire-hub.git (fetch)
  origin    ...fire-hub.git (push)
  upstream  https://github.com/we-promise/sure.git (fetch)
  upstream  https://github.com/we-promise/sure.git (push)
  ```

- [ ] **Step 1.4: Move the staged docs into the fork**

  ```bash
  mv ~/Documents/fire-hub-docs-staging/docs ~/Documents/fire-hub/docs
  rmdir ~/Documents/fire-hub-docs-staging
  ```

- [ ] **Step 1.5: Commit the docs**

  ```bash
  cd ~/Documents/fire-hub
  git add docs/
  git commit -m "docs: add Fire Hub spec and Phase 1 plan

  Carried over from brainstorming staging. These are the canonical
  docs as the project develops."
  ```

---

## Task 2: Install native dev dependencies

**Files:** none (system state only)

- [ ] **Step 2.1: Install rbenv + ruby-build if missing**

  ```bash
  brew install rbenv ruby-build
  ```
  Ensure `eval "$(rbenv init - zsh)"` is in `~/.zshrc`. Reload shell if not.
  Verify: `rbenv --version` prints a version.

- [ ] **Step 2.2: Install Ruby 3.4.7 per `.ruby-version`**

  ```bash
  cd ~/Documents/fire-hub
  rbenv install 3.4.7
  ruby --version
  ```
  Expected: `ruby 3.4.7 ...`

- [ ] **Step 2.3: Install and start Postgres + Redis**

  ```bash
  brew install postgresql@16 redis
  brew services start postgresql@16
  brew services start redis
  brew services list | grep -E 'postgresql|redis'
  ```
  Expected: both `started`.

  If `psql` isn't on PATH, add to `~/.zshrc`:
  ```bash
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
  ```
  then reload.

- [ ] **Step 2.4: Verify Postgres is reachable**

  ```bash
  psql postgres -c "SELECT version();"
  ```
  Expected: prints PostgreSQL version string.

---

## Task 3: Bundle, DB setup, boot

**Files:** Create: `.env.local` (copied from example, values left default)

- [ ] **Step 3.1: Copy `.env.local.example` to `.env.local`**

  ```bash
  cd ~/Documents/fire-hub
  cp .env.local.example .env.local
  ```
  Leave all AI-related keys empty (`OPENAI_ACCESS_TOKEN`, `TWELVE_DATA_API_KEY`, `LANGFUSE_*`). Default `SELF_HOSTED=true` and `PORT=3000` are correct.

- [ ] **Step 3.2: Run `bin/setup`**

  ```bash
  bin/setup
  ```
  Expected: completes without errors. Installs gems, creates dev + test databases, loads schema, seeds initial data.

  **If setup fails on a native-extension gem:** install the missing lib via `brew install <libname>` (commonly `libpq`, `libvips`, `libffi`) and re-run `bin/setup`.

- [ ] **Step 3.3: Boot with `bin/dev` in a dedicated terminal**

  ```bash
  bin/dev
  ```
  Expected: Rails on `http://localhost:3000`, Tailwind watcher running. Leave this terminal open.

- [ ] **Step 3.4: Hit the app in the browser**

  Open http://localhost:3000 — expected: Sure's registration/login page.

---

## Task 4: Demo data + smoke-test vanilla Sure

**Files:** none (data only; demo data is ephemeral and will be dropped in Phase 2)

- [ ] **Step 4.1: Load demo data**

  In a *second* terminal (leave `bin/dev` running):
  ```bash
  cd ~/Documents/fire-hub
  bin/rake demo_data:default
  ```
  Expected: finishes in 1-5 minutes.

- [ ] **Step 4.2: Log in as the demo user**

  Browser: http://localhost:3000/sessions/new

  - Email: `user@example.com`
  - Password: `Password1!`

  Expected: lands on dashboard.

- [ ] **Step 4.3: Click through every primary page — confirm each loads**

  Visit in sequence; confirm no 500 errors:
  - [ ] `/` — Dashboard (net worth, recent txns)
  - [ ] `/accounts` — account list
  - [ ] `/transactions` or nav → transactions ledger
  - [ ] `/categories` — category tree
  - [ ] `/budgets` — budgets
  - [ ] `/holdings` — investment holdings
  - [ ] `/investment_activity` — **distributions/dividends view** (interesting for FI)
  - [ ] `/recurring_transactions` — **auto-detected recurring bills** (interesting for FI)
  - [ ] `/reports` — reports + exports
  - [ ] `/settings/profile` — settings

  **If any page 500s**, capture the stack trace before continuing (future sessions need a clean baseline).

- [ ] **Step 4.4: Record the baseline test count for regression detection**

  ```bash
  bin/rails test 2>&1 | tail -5
  ```
  Expected: all green, or a known-small set of upstream failures. Note the "X runs, Y assertions, 0 failures, 0 errors" line.

---

## Task 5: Disable AI Assistant + verify no outbound LLM calls

**Files:** `.env.local` (values stay empty — this is a verification task, not a configuration one)

**Context:** Sure's `.env.local.example` leaves `OPENAI_ACCESS_TOKEN` blank, which *should* disable LLM calls. We verify empirically because AB uses Claude Max via `claude -p` and does NOT want surprise paid-API charges.

- [ ] **Step 5.1: Confirm AI env vars are empty**

  ```bash
  grep -E '^OPENAI_|^TWELVE_DATA|^LANGFUSE_|^ANTHROPIC_' .env.local
  ```
  Expected: all lines end with `=` (no values).

- [ ] **Step 5.2: Visit the Assistant / Chats UI**

  Browser: http://localhost:3000/chats

  Expected: the page either hides the chat feature, shows a "configure an LLM to enable" message, or errors gracefully. **No outbound API call.**

- [ ] **Step 5.3: Watch for outbound LLM traffic during normal use**

  In a third terminal:
  ```bash
  lsof -i -n -P | grep ruby | grep -E 'api\.openai|api\.anthropic|langfuse' || echo "clean"
  ```
  Then in the browser, reload the dashboard + click through a few pages. Re-run the `lsof` command. Expected: `clean` both times.

  **If outbound traffic appears:** capture the destination and stack trace, file a note in `docs/fire-hub/plans/ai-disable-notes.md`, and patch the offending code path to short-circuit when no token is set. Do not defer — a leaky AI is a silent-failure risk.

---

## Task 6: README rebrand + attribution notice

**Files:** Modify: `README.md`

**Context:** AGPLv3 + the Maybe trademark notice in Sure's README require any further fork to state it is based on Maybe Finance / Sure but not affiliated with Maybe Finance Inc. We replace only the README's top section; Sure's dev-setup guides below it stay unchanged. UI-level branding (logo, title bar) is **deliberately deferred to Phase 3** — it touches views and risks breaking styling; we handle it when we own the landing page.

- [ ] **Step 6.1: Replace the top of `README.md`**

  Open `README.md`. Replace everything from the top of the file through (and including) the "Backstory" section with:

  ```markdown
  # Fire Hub — Personal FI Dashboard

  **Fire Hub** is a self-hosted personal finance + Financial Independence (FI) tracker. It is a private fork of [Sure](https://github.com/we-promise/sure), which is itself a community fork of the archived [Maybe Finance](https://github.com/maybe-finance/maybe) project.

  > [!IMPORTANT]
  > Fire Hub is **not affiliated with or endorsed by Maybe Finance Inc.** or the Sure maintainers. "Maybe" is a trademark of Maybe Finance Inc. and is not used in this fork. Fire Hub is licensed under AGPLv3, consistent with its upstream ancestors.

  ## What Fire Hub adds on top of Sure (Phase 3+)

  - **Tiered Coverage Dashboard** — Lean FI / Full FI / Fat FI progress bars driven by whether monthly investment distributions cover monthly lifestyle cost.
  - **Per-account distribution breakdown** with TFSA highlighted as the "engine."
  - **FI-specific settings** — target lifestyle cost, tier multipliers, variable-spending lookback window (stored via Sure's `Setting` model).

  Phase 1-2 of Fire Hub is **pure setup + real-data seeding against vanilla Sure** — no code changes. The bespoke FI dashboard arrives in Phase 3, informed by what's genuinely missing after a few weeks of living with Sure's shipped reports (Budgets, InvestmentActivity, RecurringTransactions, Reports).

  See `docs/fire-hub/specs/2026-04-24-fire-hub-mvp-design.md` for the canonical spec.

  ## Hosting

  Fire Hub is self-hosted. For personal use the target is native Rails on macOS (laptop + Mac mini + Tailscale for remote access). See the spec §6 for details. The upstream Docker-based path (`docs/hosting/docker.md`) also works unchanged.
  ```

  Leave everything below (Sure's dev setup guides, etc.) untouched.

- [ ] **Step 6.2: Commit README update**

  ```bash
  git add README.md
  git commit -m "docs: rebrand README to Fire Hub with AGPLv3 + attribution

  Required by upstream Sure's fork notice and the Maybe trademark.
  Notes that Phases 1-2 are pure setup/seeding on vanilla Sure;
  bespoke FI dashboard work is Phase 3+, informed by lived usage."
  ```

---

## Task 7: Tag Phase 1 complete + update Obsidian notes

**Files:**
- Modify: `~/Documents/My Brain/Projects/Fire Hub/Fire Hub.md`
- Modify: `~/Documents/My Brain/Projects/_Index.md`

- [ ] **Step 7.1: Push to origin**

  ```bash
  cd ~/Documents/fire-hub
  git push -u origin main
  ```
  Expected: fork on GitHub now has all Phase 1 commits.

- [ ] **Step 7.2: Tag Phase 1**

  ```bash
  git tag -a v0.1.0-foundation -m "Phase 1 Foundation complete (lean)

  - Fork of we-promise/sure consolidated with brainstorming docs
  - Native Rails dev env (Ruby 3.4.7, Postgres 16, Redis)
  - AI Assistant disabled (verified no outbound LLM calls)
  - README attributed per AGPLv3 + Maybe trademark notice
  - Zero schema changes — deferred to Phase 3 after living with vanilla Sure"
  git push origin v0.1.0-foundation
  ```

- [ ] **Step 7.3: Append Phase 1 completion entry to the Obsidian project note**

  Edit `~/Documents/My Brain/Projects/Fire Hub/Fire Hub.md`. Under `## Session Log`, add (use the ACTUAL date of execution, not a placeholder):

  ```markdown
  ### <YYYY-MM-DD of execution>
  - Phase 1 Foundation complete. Tagged `v0.1.0-foundation`.
  - Fork of `we-promise/sure` set up locally as `fire-hub` with native Rails dev env.
  - AI Assistant disabled (empty env tokens + `lsof` verified no outbound LLM traffic on key pages).
  - README rebranded with AGPLv3 + "not affiliated with Maybe Finance Inc." notice.
  - **Zero schema changes.** Deferred to Phase 3 after we see what vanilla Sure's reports (InvestmentActivity, RecurringTransactions, Budgets, Reports) actually cover.
  - **Next:** Phase 2 — seed AB's real categories, accounts, starting balances. Backfill 3mo fixed costs + 12mo TFSA distributions. Live with vanilla Sure for 2-4 weeks to identify what's genuinely missing before building the custom FI dashboard.
  ```

- [ ] **Step 7.4: Update `_Index.md` Fire Hub row**

  Edit `~/Documents/My Brain/Projects/_Index.md`. Update the Fire Hub row to:

  ```markdown
  | [[Fire Hub]] | `~/Documents/fire-hub` | [[Fire Hub/Fire Hub]] | 🚧 Phase 1 complete (<YYYY-MM-DD>, `v0.1.0-foundation`). Sure fork booting locally, AI disabled, README rebranded. Zero schema changes. Phase 2 (seed real data + live with vanilla Sure) next. |
  ```

---

## Out of scope for this plan (do not do in Phase 1)

- Any schema additions (`Category.fixed`, `Category.fi_source`, `Account.counts_in_fi_engine`, `Family` FI settings) — **deferred to Phase 3, and likely collapses to just one `Category.fixed` column plus a handful of `Setting` fields**
- `FiCoverage` service object — **Phase 3**
- `/fi` dashboard page, view code, route overrides — **Phase 3**
- Seeding real data (AB's categories, accounts, balances, backfills) — **Phase 2**
- Deploy to Mac mini + launchd + Tailscale — **Phase 4**
- Enabling SimpleFIN / SnapTrade / Plaid / any ingestion connector — **post-Phase 5**
- UI branding rename in views — **Phase 3** (done alongside dashboard)

---

## Phased plan (post-Phase 1 — carried over from spec §8, revised for lean approach)

**Phase 2 — Seed real data + live with vanilla Sure (this session + 2-4 weeks calendar)**
- Drop demo data (`bin/rails db:reset`), re-seed Sure's bootstrap categories.
- Create parent category "Fixed Costs" with children: Mortgage, Hydro, Water, Internet, Cellphone, Insurance, Daycare, Property Tax, Subscriptions. (Uses Sure's existing parent/child — zero schema change.)
- Create parent category "Variable Costs" with children: Groceries, Restaurants, Gas, Entertainment, Kids, Clothing, Medical, Gifts, Travel.
- Create "Investment Income" category (Sure may already have one).
- Seed accounts: TFSA (investment), RRSP (investment), chequing, savings, credit cards (one per), mortgage (loan), car loan if any.
- Set starting balances from latest statements.
- Backfill 3 months of fixed-cost transactions manually.
- Backfill 12 months of TFSA distributions from brokerage statements.
- Use the app. Let Sure auto-detect recurring bills via `RecurringTransaction`. Explore `/reports`, `/investment_activity`, `/budgets`.
- After 2-4 weeks, come back with a short list: "here's what I can't answer from Sure's shipped views."

**Phase 3 — Build the bespoke FI dashboard (the custom layer)**
- Revise spec §4 schema additions based on Phase 2 findings. Likely outcome: add only `Category.fixed` (boolean) + four new `Setting` fields for target lifestyle / multipliers / lookback. `fi_source` and `counts_in_fi_engine` almost certainly don't make it.
- Build `FiCoverage` service object wrapping `IncomeStatement`.
- Build `/fi` dashboard page with four bands per spec §5.
- Make `/fi` the post-login landing route.
- Settings UI for FI tuning knobs.
- UI branding rename across views.
- Tests.

**Phase 4 — Deploy to Mac mini**
- Install rbenv / Postgres / Redis on Mac mini.
- Clone fork, `bin/setup`, restore DB from laptop `pg_dump`.
- launchd plists (web + worker).
- Tailscale MagicDNS.
- Backup cron + iCloud copy.
- First remote login via phone.

**Phase 5+ — Ingestion automation (per-account, on demand)**
- Enable SimpleFIN for banks if manual entry feels heavy.
- Enable SnapTrade for Wealthsimple / Questrade positions sync.
- Enable Coinbase / Binance if AB holds crypto.

---

## Notes for the implementer

- This plan has **no code TDD cycles**. Phase 1 is purely setup/boot/verify. The first real code work lands in Phase 3.
- If `bin/setup` fails, read the error, `brew install` the named lib, retry. Don't push past setup failures by skipping gems.
- If Sure's demo data refuses to load, check that Postgres + Redis are actually running (`brew services list`).
- If you hit any upstream Sure test failures during the baseline check (Task 4.4), copy the list to `docs/fire-hub/plans/phase-1-baseline-test-failures.md` and move on — don't try to fix upstream bugs.
- The Task 4.3 smoke test sequence specifically includes `/investment_activity` and `/recurring_transactions` — these are the two existing Sure pages most likely to reduce Phase 3's scope. Look carefully at what they show.
- AB wants the end product (tiered FI dashboard). Phase 1 is the runway, not the plane — don't spend it on things Phase 3 will own.

---

## Self-review checklist

- **Scope check:** Phase 1 is pure setup — no code, no migrations, no Fire-Hub-specific models. ✓
- **Placeholders:** none.
- **Commands:** every bash command is concrete and expected outputs are stated.
- **YAGNI:** All schema additions deferred. `fi_source`, `counts_in_fi_engine` likely dropped entirely. ✓
- **DRY:** No repetition — each step does one thing.
- **Commits:** three Phase 1 commits (docs, README, plus the tag). Tight.
- **Reversibility:** everything is reversible. Fork can be deleted; brew installs are standard; no schema to roll back.
