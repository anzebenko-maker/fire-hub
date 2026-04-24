# Fire Hub — Personal FI Dashboard

**Fire Hub** is a self-hosted personal finance + Financial Independence (FI) tracker. It is a private fork of [Sure](https://github.com/we-promise/sure), which is itself a community fork of the archived [Maybe Finance](https://github.com/maybe-finance/maybe) project.

> [!IMPORTANT]
> Fire Hub is **not affiliated with or endorsed by Maybe Finance Inc.** or the Sure maintainers. "Maybe" is a trademark of Maybe Finance Inc. and is not used in this fork. Fire Hub is licensed under AGPLv3, consistent with its upstream ancestors.

## What Fire Hub adds on top of Sure (Phase 3+)

- **Tiered Coverage Dashboard** — Lean FI / Full FI / Fat FI progress bars driven by whether monthly investment distributions cover monthly lifestyle cost.
- **Per-account distribution breakdown** with TFSA highlighted as the "engine."
- **FI-specific settings** — target lifestyle cost, tier multipliers, variable-spending lookback window (stored via Sure's `Setting` model).

Phase 1-2 of Fire Hub is pure setup + real-data seeding against vanilla Sure — no code changes. The bespoke FI dashboard arrives in Phase 3, informed by what's genuinely missing after a few weeks of living with Sure's shipped reports (Budgets, InvestmentActivity, RecurringTransactions, Reports).

See `docs/fire-hub/specs/2026-04-24-fire-hub-mvp-design.md` for the canonical spec and `docs/fire-hub/plans/` for implementation plans.

## Hosting

Fire Hub is self-hosted. For personal use the target is native Rails on macOS (laptop + Mac mini + Tailscale for remote access). The upstream Docker-based path ([docs/hosting/docker.md](docs/hosting/docker.md)) also works unchanged.

---

## Upstream Sure documentation

The sections below are inherited from Sure and describe the underlying codebase. They remain accurate for Fire Hub since Phase 1-2 is an unmodified fork.

## Hosting Sure

Sure is a fully working personal finance app that can be [self hosted with Docker](docs/hosting/docker.md).

## Forking and Attribution

This repo is a community fork of the archived Maybe Finance repo.
You’re free to fork it under the AGPLv3 license — but we’d love it if you stuck around and contributed here instead.

To stay compliant and avoid trademark issues:

- Be sure to include the original [AGPLv3 license](https://github.com/maybe-finance/maybe/blob/main/LICENSE) and clearly state in your README that your fork is based on Maybe Finance but is **not affiliated with or endorsed by** Maybe Finance Inc.
- "Maybe" is a trademark of Maybe Finance Inc. and therefore, use of it is NOT allowed in forked repositories (or the logo)

## Performance Issues

With data-heavy apps, inevitably, there are performance issues. We've set up a public dashboard showing the problematic requests seen on the demo site, along with the stacktraces to help debug them.

[https://www.skylight.io/app/applications/s6PEZSKwcklL/recent/6h/endpoints](https://oss.skylight.io/app/applications/s6PEZSKwcklL/recent/6h/endpoints)

Any contributions that help improve performance are very much welcome.

## Local Development Setup

**If you are trying to _self-host_ the app, [read this guide to get started](docs/hosting/docker.md).**

The instructions below are for developers to get started with contributing to the app.

### Requirements

- See `.ruby-version` file for required Ruby version
- PostgreSQL >9.3 (latest stable version recommended)
- Redis > 5.4 (latest stable version recommended)

### Getting Started
```sh
cd sure
cp .env.local.example .env.local
bin/setup
bin/dev

# Optionally, load demo data
rake demo_data:default
```

Visit http://localhost:3000 to view the app.

If you loaded the optional demo data, log in with these credentials:

- Email: `user@example.com`
- Password: `Password1!`

For further instructions, see guides below.

### Setup Guides

- [Mac dev setup](https://github.com/we-promise/sure/wiki/Mac-Dev-Setup-Guide)
- [Linux dev setup](https://github.com/we-promise/sure/wiki/Linux-Dev-Setup-Guide)
- [Windows dev setup](https://github.com/we-promise/sure/wiki/Windows-Dev-Setup-Guide)
- Dev containers - visit [this guide](https://code.visualstudio.com/docs/devcontainers/containers)

### One-click

[![Run on PikaPods](https://www.pikapods.com/static/run-button.svg)](https://www.pikapods.com/pods?run=sure)

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/T_draF?referralCode=CW_fPQ)


## License and Trademarks

Maybe and Sure are both distributed under
an [AGPLv3 license](https://github.com/we-promise/sure/blob/main/LICENSE).
- "Maybe" is a trademark of Maybe Finance, Inc.
- "Sure" is not, and refers to this community fork.
