# Background Screening Package Builder

A web app for building custom background screening packages. It enforces service dependencies and conflicts, applies stacking volume and bundle discounts, and saves packages.

**Stack:** Next.js 15 (React 19, TypeScript, Tailwind) · Sinatra 4 (Ruby 3.3) · SQLite through Sequel

The specification is in [`ASSESSMENT.md`](ASSESSMENT.md); the original instructions are in [`docs/assessment-instructions.md`](docs/assessment-instructions.md).

---

## Running the app

There are two ways to run it. Both serve the app at **http://localhost:3000**.

| | Run locally | Run in Docker |
|---|---|---|
| You need | Ruby 3.2+ (3.3 recommended), Node.js 22.12+, Git | Docker Desktop, Git |
| Start command | `npm run setup` once, then `npm run dev` | `docker compose up --build` |
| Best for | Development and running tests | Trying the app without installing Ruby or Node |
| Data | `backend/db/development.sqlite3` | A Docker volume named `package-data` |

Both use port 3000, so run only one at a time.

### Get the code

```bash
git clone https://github.com/MincedMeat68/AccioData.git
cd AccioData
```

---

### Run locally on macOS

**1. Install the tools.** This uses [Homebrew](https://brew.sh); install it first if you don't have it. Homebrew also installs Apple's Xcode Command Line Tools, which provide the C compiler that one Ruby gem needs (see below).

```bash
brew install ruby@3.3 node
```

**2. Put Homebrew's Ruby first on your `PATH`.** macOS ships with Ruby 2.6, which is too old, and Homebrew doesn't replace it automatically. This works on both Apple Silicon and Intel Macs:

```bash
echo 'export PATH="$(brew --prefix ruby@3.3)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

If you already manage Ruby with `rbenv` or `asdf`, skip steps 1–2 for Ruby and run `rbenv install` (or `asdf install`). The repo's `.ruby-version` file selects 3.3.6.

**3. Check the versions.**

```bash
ruby -v    # 3.2 or newer (3.3.x expected)
node -v    # v22.12 or newer
```

**4. Set up and start.**

```bash
npm run setup   # installs gems + npm packages, creates and seeds the SQLite database
npm run dev     # starts the API (127.0.0.1:4567) and the app (localhost:3000)
```

Open **http://localhost:3000**. Press `Ctrl+C` in the terminal to stop both servers.

### Run locally on Windows

These commands use **PowerShell**.

**1. Install the tools** with `winget`, which is built into Windows 10 and 11. The Ruby package includes the DevKit, a C compiler that one Ruby gem needs (see below).

```powershell
winget install --id RubyInstallerTeam.RubyWithDevKit.3.3 -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Git.Git -e     # skip if you already have Git
```

**2. Close and reopen PowerShell** so the new `ruby`, `node` and `git` commands are on your `PATH`.

**3. Check the versions.**

```powershell
ruby -v    # 3.3.x
node -v    # v22.12 or newer
```

**4. Set up and start.**

```powershell
npm run setup
npm run dev
```

Open **http://localhost:3000**. Press `Ctrl+C` to stop both servers.

**If something goes wrong on Windows**
- **`npm : File ...npm.ps1 cannot be loaded because running scripts is disabled`.** PowerShell's execution policy is blocking npm. Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once, or use Command Prompt instead.
- **`bundle install` fails while compiling `bigdecimal`.** The DevKit toolchain isn't set up. Run `ridk install`, choose option **3** (MSYS2 and MINGW development toolchain), then run `npm run setup` again.

### Why one gem compiles

`sqlite3` installs precompiled on every platform. The lockfile lists Windows, both Mac architectures and Linux, see [ADR 0001](docs/adr/0001-persistence-sqlite-sequel.md). One small gem, `bigdecimal`, which Sequel depends on, compiles a C extension during `bundle install`. That is why a C compiler is needed: the Xcode Command Line Tools on macOS, or the RubyInstaller DevKit on Windows.

---

### Run in Docker on macOS

**1. Install Docker Desktop.** Either download it from [docker.com](https://www.docker.com/products/docker-desktop/) or use Homebrew:

```bash
brew install --cask docker
```

**2. Open Docker Desktop once** from Applications and accept its terms. Wait until the menu-bar icon shows the engine is running. Both Apple Silicon and Intel Macs work.

**3. Build and start.** From the `AccioData` folder:

```bash
docker compose up --build
```

The first build takes a few minutes. When the log shows `Ready`, open **http://localhost:3000**.

### Run in Docker on Windows

Docker Desktop on Windows needs **WSL 2** (Windows Subsystem for Linux).

**1. Install WSL 2.** Run this in an **Administrator** PowerShell, then restart Windows when it asks:

```powershell
wsl --install
```

**2. Install Docker Desktop.**

```powershell
winget install --id Docker.DockerDesktop -e
```

**3. Open Docker Desktop once** from the Start menu and accept its terms. Wait until the system-tray icon shows **Engine running**.

**4. Build and start.** From the `AccioData` folder:

```powershell
docker compose up --build
```

The first build takes a few minutes. When the log shows `Ready`, open **http://localhost:3000**.

### Docker commands (macOS and Windows)

| Command | What it does |
|---|---|
| `docker compose up --build` | Build the images and start the app, with logs in the terminal (`Ctrl+C` stops it) |
| `docker compose up --build -d` | The same, in the background |
| `docker compose logs -f` | Follow the logs of a background run |
| `docker compose down` | Stop the app. **Saved packages are kept** in the `package-data` volume |
| `docker compose down -v` | Stop the app and **delete the saved data**. The next start begins with an empty, freshly seeded database |

What happens: the backend starts first and migrates and seeds an empty database on first boot. The frontend starts only after the backend passes its health check. Only port 3000 is exposed; the API is reachable only through the frontend. The backend image compiles `bigdecimal` in a separate build stage, so the final image has no compiler.

---

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
- **The URL decides what the builder shows**, so a reload always shows the same thing:
  - `/` reopens the most recently saved package.
  - **+ Create New Package** and **Start New Package** open an empty draft at `/?new=1`.
  - **Edit** opens `/?package=<id>`.

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

- **`npm install` warns that `eslint@9` is deprecated.** Next 15's lint config (`eslint-config-next@15`) only supports ESLint up to 9. ESLint 10 needs Next 16. ESLint is a development-only tool.
- **We are on Next.js 15.5, not 16.** We avoided a major framework upgrade during a time-boxed assessment. **Next step:** upgrade with Next's codemod (`npx @next/codemod@latest upgrade`), move to ESLint 10, remove the `next → postcss` override below, then re-run the typecheck, build and tests. The App Router code here uses no APIs that Next 16 removes, so the upgrade should be small.
- **`npm audit` reports 0 vulnerabilities.** Three findings were fixed:
  - **PostCSS (high, GHSA-qx2v-qp2m-jg93 and related):** Next 15 pins its own copy of `postcss@8.4.31`. An npm `overrides` entry in `frontend/package.json` points Next at the patched `postcss@^8.5.23`, the same 8.x line that Next 16 ships with. `npm audit` only offered a forced Next 16 upgrade. We checked the production build and the dev server both compile the Tailwind CSS correctly.
  - **Vitest (2 critical, in `tinypool` and `@vitest/mocker`):** upgraded from 3 to 5. This is why Node 22.12+ is required.
  - **minimatch (moderate):** an override forces `minimatch@11` under `@typescript-eslint`, which still asks for a vulnerable `minimatch@10`. Remove the override once `@typescript-eslint` updates.

## With more time

- **Price snapshots:** store each item's price and the quote at save time, and decide whether editing a package re-prices it (ADR 0003).
- **Optimistic concurrency:** a `lock_version` on `packages`, so two tabs can't silently overwrite each other's edits.
- **End-to-end tests:** Playwright walking through Flows 1–5, plus React Testing Library component tests.
- **Undo/redo:** the reducer already describes every change as an action, so a history stack could be added on top of it.
- **Package comparison and PDF/JSON export.**
- **An admin screen for the catalog:** the rules are already data, so this is a set of create/update/delete endpoints plus validation, such as rejecting circular requirements.
- **Search and filter** for a larger catalog.

## How this was planned (working with AI)

Built with Claude Code. No code was written until a plan had been reviewed and approved. The plan started from my brief, then went through a round of questions in which I made the main decisions.

### 1. My initial brief

> This is a coding assessment to be accomplished with Claude Code. The specification is located in [`ASSESSMENT.md`](ASSESSMENT.md) *(local path shortened)*. We need to first plan and review your recommendations. We need to determine the best method to persist data, best business domain model (for database, api) or framework to sit on top of the data layer (thinking Tactical Domain-Driven Design (DDD)). The assessment needs to be easy to start from an evaluators machine. We also need to document the options and why we went a certain direction. We also need to thoughtfully format the project in an organized and topic based manner.

From this brief, the plan had to deliver:

| Goal from the brief | Where it ended up |
|---|---|
| Best way to persist data | SQLite + Sequel ([ADR 0001](docs/adr/0001-persistence-sqlite-sequel.md)) |
| Domain model for the database and API, using tactical DDD | Four layers in plain Ruby, with a `Package` aggregate ([ADR 0002](docs/adr/0002-tactical-ddd-layering.md), [domain model](docs/domain-model.md)) |
| Easy to start on an evaluator's machine | `npm run setup` / `npm run dev`, or `docker compose up` ([ADR 0006](docs/adr/0006-dev-environment-and-startup.md), [Running the app](#running-the-app)) |
| Document the options and why we chose each | Six ADRs, each with an options table, plus [spec discrepancies](docs/spec-discrepancies.md) |
| Organize the project by topic | `backend/` split by DDD layer, `frontend/src/features/` by feature, `docs/` by topic |

### 2. Decisions made while planning

Claude Code read the spec and proposed options with trade-offs, and I chose:

| Question | Options considered | My decision |
|---|---|---|
| How to persist saved packages | SQLite + Sequel · JSON file · PostgreSQL in Docker · ROM-rb | **SQLite + Sequel** |
| How an evaluator starts the app | npm scripts + Docker · Docker only · npm scripts only | **npm scripts, with Docker as an alternative** |
| I develop on Windows and the evaluator may use a Mac: do we need separate SQLite binaries? | – | **No.** The `sqlite3` gem is precompiled for each platform, and `Gemfile.lock` lists Windows, both Mac architectures and Linux |
| Removing State Criminal while County or Federal depends on it | Block and offer to cascade · cascade automatically · block only | **Block and offer to cascade**, with a clear message about what will happen, and the choice to cancel and leave everything as it was ([ADR 0005](docs/adr/0005-dependent-removal-and-conflict-ux.md)) |
| Where the rules run for real-time feedback | Backend only (a network call per click) · copied into TypeScript · **a middle option** | **The middle option:** the backend sends the rules as data, the frontend interprets them for instant feedback, and pricing and the final check on save stay on the backend |
| *"Shouldn't these rules and prices load from the database?"* (I asked this after seeing the first draft, which used a YAML config file) | YAML config · database only · database seeded from YAML | **Database, seeded from YAML.** Storing each package's price at save time is documented as future work ([ADR 0003](docs/adr/0003-catalog-in-database-rules-as-data.md)) |

### 3. The plan Claude Code produced

The approved plan, in summary:

- **Context:** a 4-hour assessment, judged mainly on domain modeling, keeping business logic separate, tests and documented trade-offs. Startup must be one command that works the same on Windows and macOS.
- **Seven decisions, each recorded as an ADR:** the six above, plus *spec inconsistencies*. Template prices are calculated by the pricing engine rather than copied from the spec, and every contradiction in the spec is written down.
- **Domain model:**
  - A `Package` aggregate that enforces the dependency and conflict rules.
  - A `SelectionPolicy` that interprets the rules.
  - A `PricingEngine` made of discount strategies, with money in integer cents.
  - Repository interfaces between the domain and SQLite.
- **API:** catalog, price and validate endpoints, and package create/read/update/delete, plus latest and duplicate. A single error format; invalid saves return `422` with every rule they break.
- **Frontend:** the mockups' two-column layout, four service-card states, red, yellow and green banners, debounced server-side pricing, and reopening the latest package on load.
- **Build order, one hour per step:**
  1. Scaffolding, the catalog, `Money` and the pricing engine, with specs based on the appendix examples.
  2. The aggregate, the policy, the repositories, the use cases and the routes.
  3. The frontend builder: rule interpreter, reducer, components and dialogs.
  4. Stretch goals, Docker, the ADRs, this README, and a check from a fresh clone.
- **Verification plan:**
  - RSpec covering the four appendix examples and Flows 1–5.
  - Vitest covering the rule interpreter and the reducer.
  - A walk through Flows 1–5 in Chrome.
  - Fresh-clone runs of both `npm run setup` and `docker compose up`.

### 4. How the build differed from the plan

| Area | Plan | What happened, and why |
|---|---|---|
| Catalog location | `config/catalog.yml` read by a YAML loader | Moved into database tables (`db/seeds/catalog.yml` → `rake db:seed` → `SequelCatalogRepository`), following the database decision above |
| Use cases | One class per use case | Grouped into `PackageService` and `CatalogQueries`. Fewer, cohesive classes, and each public method is still one use case |
| Real-time feedback | `/price` returns violations as well | A dedicated `POST /api/packages/evaluate` returns the price, violations and each service's availability in one call. `/price` and `/validate` remain, as the spec lists them |
| Ruby web server | Not specified | **WEBrick**, which is pure Ruby, so there is nothing to compile on an evaluator's machine |
| Node version | Node 20 | **Node 22.12+.** Upgrading Vitest to 5 cleared two critical `npm audit` findings, and Node 20 reached end-of-life in April 2026 |
| Next.js vulnerability | – | Overrode Next 15's bundled PostCSS with the patched 8.5 version instead of upgrading to Next 16 ([Known issues](#known-issues)) |
| Docker | Single-stage images | The first `docker compose up` failed: Sequel's `bigdecimal` dependency needs a C compiler. The backend image now compiles it in a separate build stage |
| Flow 5 | Stay in the builder after saving | After testing, I chose to **return to Saved Packages** after saving an existing package, as the mockup shows |
| New packages | `/` always opened the latest package | I found that **+ Create New Package** reopened the package I had just edited. The URL now decides what the builder opens: `/` for the latest package, `/?new=1` for an empty draft, `/?package=<id>` to edit one |
| Spec discrepancies | Spec figures only | The mockups' totals also contradict the rules, so they are listed too ([spec discrepancies](docs/spec-discrepancies.md)) |
| Browser testing | Screenshots in Chrome | Screenshots kept timing out, so the flows were checked by clicking through the real UI and reading the page's text and structure |

### 5. How the work was done

- **Plan first.** The decisions above were agreed before any code was written.
- **Then build layer by layer.** Domain, application, infrastructure and HTTP on the backend, then the frontend. The spec's appendix examples and user flows were used as test fixtures.
- **Then check what was built.** RSpec and Vitest, Flows 1–5 in a real browser, a fresh clone on Windows, and `docker compose up` from a clean state.
- **The spec's contradictions were recorded, not hidden.** Claude Code found them while planning. They are listed in [spec discrepancies](docs/spec-discrepancies.md) instead of being made to fit.
- **Commits mark each step**, from the first milestone to each later fix.
