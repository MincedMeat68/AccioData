# Background Screening Package Builder

A web app for building custom background screening packages. It enforces service dependencies and conflicts, applies stacking volume and bundle discounts, and saves packages.

**Stack:** Next.js 15 (React 19, TypeScript, Tailwind) · Sinatra 4 (Ruby 3.3) · SQLite through Sequel

The specification is in [`ASSESSMENT.md`](ASSESSMENT.md); the original instructions are in [`docs/assessment-instructions.md`](docs/assessment-instructions.md).

---

## Quick start

### Option A: native (recommended)

**Prerequisites:** Ruby 3.2+ (3.3 recommended) with Bundler, and Node.js 20+.

| OS | Install |
|---|---|
| macOS | `brew install ruby node` (the Ruby that ships with macOS is 2.6, which is too old; follow Homebrew's note about adding Ruby to your `PATH`), or use `rbenv`/`asdf` with the included `.ruby-version` |
| Windows | `winget install RubyInstallerTeam.RubyWithDevKit.3.3` and `winget install OpenJS.NodeJS.LTS` |
| Linux | Your package manager, or `rbenv`/`asdf` |

```bash
npm run setup   # bundle install, create + migrate + seed SQLite, npm install
npm run dev     # API on http://127.0.0.1:4567, app on http://localhost:3000
```

Open **http://localhost:3000**.

No native compilation is needed: `sqlite3` installs as a precompiled gem on every platform (see [ADR 0001](docs/adr/0001-persistence-sqlite-sequel.md)).

### Option B: Docker

```bash
docker compose up --build   # http://localhost:3000
```

### Other commands

| Command | What it does |
|---|---|
| `npm test` | Backend RSpec + frontend Vitest |
| `npm run test:backend` / `npm run test:frontend` | One suite only |
| `cd backend && bundle exec rspec spec/domain/pricing_engine_spec.rb -e "Example 3"` | One backend example (by name) |
| `cd frontend && npx vitest run -t "Flow 3"` | Frontend tests whose names match |
| `npm run db:reset` | Delete the SQLite file, then migrate and re-seed |
| `cd backend && bundle exec rake db:seed` | Re-apply `db/seeds/catalog.yml` (idempotent) |

---

## What it does

**Core requirements**
- Shows services grouped by category, with prices and descriptions.
- Adding and removing services gives **instant** feedback: four visible card states (available, selected, blocked, conflict) plus an error highlight when an add is refused.
- **Dependencies:** County and Federal Criminal require State Criminal. A blocked service explains why inline, and clicking it shows the spec's exact message.
- **Conflicts:** adding the 10-Panel while the 5-Panel is selected asks whether to **replace** it. Adding the 5-Panel while the 10-Panel is selected is refused with an explanation.
- **Removing a service others depend on** opens a confirmation dialog that names exactly what will also be removed. Cancel leaves everything as it was ([ADR 0005](docs/adr/0005-dependent-removal-and-conflict-ux.md)).
- **Pricing breakdown:** subtotal, each discount on its own line, total, amount saved, and a hint showing how many more services reach the next volume tier.
- **Save** with a name, **reopen the most recently saved package** when you return, **edit and save again**. Saving changes to an existing package (Flow 5) returns to Saved Packages, which confirms the save and highlights the package. A brand-new package stays in the builder after its first save (Flow 1).

**Stretch goals done**
- Saved packages list: summary, edit, duplicate, delete (with confirmation).
- Templates: Basic, Standard and Comprehensive, priced by the engine (no stored prices).
- Service descriptions on each card.
- "Save as New" while editing.

---

## Architecture

```
backend/                       Sinatra API: tactical DDD in plain Ruby
  app/domain/                  pure Ruby, no gems, no I/O
    shared/money.rb              Money value object (integer cents)
    catalog/                     Service, rules, ServiceCatalog, CatalogRepository interface
    packaging/                   Package aggregate, SelectionPolicy, Violation, PackageRepository interface
    pricing/                     PricingEngine, discount strategies, PriceQuote
  app/application/             use cases (PackageService, CatalogQueries)
  app/infrastructure/          Sequel repositories, seeder, discount mapper
  app/http/                    routes + serializers (no business rules)
  config/boot.rb               composition root (wires adapters into use cases)
  db/migrations/  db/seeds/catalog.yml
  spec/{domain,application,infrastructure,http}/
frontend/                      Next.js App Router
  src/features/package-builder/
    rules/selectionRules.ts      generic interpreter of the rule data
    state/builderReducer.ts      pure builder state machine
    hooks/                       usePackageBuilder, useEvaluation (debounced server pricing)
    components/
  src/features/packages/       saved-packages list
  src/lib/api/                 typed API client
docs/
  adr/                         architecture decision records
  domain-model.md              shared vocabulary, class + ER diagrams
  api.md                       endpoint reference
  spec-discrepancies.md        where the spec contradicts itself, and what we chose
```

How a change flows through the app:

1. The browser loads `GET /api/catalog`, which includes the **rules as data**.
2. `selectionRules.ts` decides instantly whether a service can be added (add, block, ask to confirm).
3. `builderReducer` records the change.
4. `useEvaluation` sends the selection to `POST /api/packages/evaluate` (debounced 150 ms), and the server returns the authoritative price.
5. On save, the backend's `Package` aggregate checks every rule again. An invalid save is rejected with `422` and the list of violations.

---

## Key decisions

Each decision is written up in full in [`docs/adr/`](docs/adr/).

| # | Decision | Why |
|---|---|---|
| [0001](docs/adr/0001-persistence-sqlite-sequel.md) | **SQLite + Sequel** behind repository interfaces | Nothing to install, data survives restarts, real transactions and foreign keys; easy to swap for Postgres later |
| [0002](docs/adr/0002-tactical-ddd-layering.md) | **Tactical DDD, four layers, plain Ruby** | Business rules live in one place that can be tested on its own; no framework in the domain layer |
| [0003](docs/adr/0003-catalog-in-database-rules-as-data.md) | **Catalog and rules stored in the database, seeded from YAML; frontend interprets the rules, backend has final say** | Instant UI feedback without duplicating rules; pricing exists once; rules change without code changes |
| [0004](docs/adr/0004-pricing-engine-and-rounding.md) | **Pricing engine built from discount strategies, integer cents** | A new discount is a new class, not an edit to the engine; exact arithmetic |
| [0005](docs/adr/0005-dependent-removal-and-conflict-ux.md) | **Block, then offer cascade or replace, always with Cancel** | Nothing is removed without the user seeing exactly what will go |
| [0006](docs/adr/0006-dev-environment-and-startup.md) | **npm scripts + Docker Compose** | One command that works the same on Windows, macOS and Linux |

### The spec's decision points

1. **Where should validation live?** In both places, with the backend in charge. The frontend interprets the rule data it receives for instant feedback; the backend's `Package` aggregate checks every save again. Pricing runs only on the backend.
2. **How are dependencies modeled?** As rows in `service_requirements` and `service_conflicts`, seeded from YAML and loaded through `CatalogRepository`. A conflict has a `supersedes` flag so the UI can offer to replace.
3. **How is pricing calculated?** By `PricingEngine` running an ordered list of discount strategies against the undiscounted subtotal. All applicable discounts stack, volume tiers are exclusive, and the total is never below $0.
4. **What happens when a service others depend on is removed?** It is blocked, and the user is offered a cascade with a clear explanation. The domain enforces the same thing with `remove(code, cascade: false)`.
5. **How is data persisted?** SQLite through Sequel. Packages store only service codes, and prices are recomputed when read (price snapshots are future work, see ADR 0003).

### Assumptions

The spec's own figures conflict with its rules in several places: the Comprehensive template is $215.75, not $254; Standard is $182.50, not $202.50; Example 4 includes both drug panels. Every case, and our other interpretations, are listed in [`docs/spec-discrepancies.md`](docs/spec-discrepancies.md).

---

## Testing

- **Backend (RSpec):**
  - **Domain:** all four appendix pricing examples, tier boundaries, dependency and conflict messages (exact spec wording), cascades, and the aggregate's invariants.
  - **Application:** Flows 1 and 5 against the in-memory repository.
  - **Infrastructure:** seeder idempotency and rollback, repository round-trips, foreign keys.
  - **HTTP:** every endpoint and error status (rack-test).
- **Frontend (Vitest):** the rule interpreter (Flows 2 and 3, cascade wording, tier hints), and the reducer (Cancel leaves the package unchanged, Confirm applies the change, dirty tracking).

## Known issues

- **`npm audit` reports a high-severity PostCSS advisory** (GHSA-qx2v-qp2m-jg93 and related). The vulnerable PostCSS is a copy bundled inside Next.js 15 (`node_modules/next/node_modules/postcss`). It only runs at build time on our own CSS, so this app is not exposed. The only fix offered is Next.js 16, a major version. We stayed on Next 15.5 rather than take on a framework upgrade during a time-boxed assessment. **Next step:** upgrade to Next 16 with its codemod (`npx @next/codemod@latest upgrade`), then re-run the typecheck, build and tests. The App Router code here uses no APIs that Next 16 removes, so the upgrade should be small.

## With more time

- **Price snapshots:** store each item's price and the quote at save time, and decide whether editing a package re-prices it (ADR 0003).
- **Optimistic concurrency:** a `lock_version` on `packages`, so two tabs can't silently overwrite each other's edits.
- **End-to-end tests:** Playwright walking through Flows 1–5, plus React Testing Library component tests.
- **Undo/redo:** the reducer already describes every change as an action, so a history stack could be added on top of it.
- **Package comparison and PDF/JSON export.**
- **An admin screen for the catalog:** the rules are already data, so this is a set of create/update/delete endpoints plus validation, such as rejecting circular requirements.
- **Search and filter** for a larger catalog.

## Working with AI

Built with Claude Code. The process: planning first, with the decisions agreed before any code (persistence, startup, cascade behavior, where validation runs, catalog in the database vs. config); then building layer by layer, with tests that use the spec's examples as fixtures. Claude found the spec's internal contradictions while planning, and they are recorded rather than coded around.
