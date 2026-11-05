# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 4-hour Senior Full-Stack assessment: a background screening **package builder**. Next.js 15 frontend (`frontend/`), Sinatra 4 API (`backend/`), SQLite through Sequel. The spec is `ASSESSMENT.md`, the mockups are in `assets/mockups/embedded/`, and the design decisions are in `docs/adr/`. Evaluators weight domain modeling, keeping logic out of the presentation and data layers, tests and documented trade-offs above feature count.

## Commands (run from the repo root unless noted)

```bash
npm run setup          # root npm install, bundle install, rake db:setup (migrate+seed), frontend npm install
npm run dev            # API on 127.0.0.1:4567 + Next on :3000 (concurrently)
npm test               # rspec + vitest
npm run db:reset       # delete SQLite file, migrate, seed

cd backend && bundle exec rspec spec/domain/package_spec.rb        # one backend file
cd backend && bundle exec rspec -e "Example 3"                     # backend examples by name
cd frontend && npx vitest run src/features/package-builder/rules   # one frontend dir
cd frontend && npx tsc --noEmit && npx eslint                      # typecheck + lint
```

Development happens on Windows; the evaluator may be on macOS. Keep scripts as npm scripts (no `.sh`/`.ps1`). Line endings are forced to LF by `.gitattributes`.

## Backend architecture (tactical DDD, see docs/adr/0002)

Layers can only depend on the layers above them: `app/domain` → `app/application` → `app/infrastructure` + `app/http`. `config/boot.rb` requires every file **explicitly in layer order** (there is no autoloader), so **a new file must be added to that list**. It also defines `Container`, the composition root.

- **Domain** is pure Ruby, and value objects use `Data.define`. `Packaging::Package` is the aggregate root, and every change validates through `Packaging::SelectionPolicy`, which interprets the requirement and conflict rules. `Pricing::PricingEngine` runs discount strategies (`Pricing::Discounts::*`) against the undiscounted subtotal. Money is integer cents.
- **The catalog lives in the database, not in code.** `db/seeds/catalog.yml` → `rake db:seed` (idempotent, one transaction) → tables → `SequelCatalogRepository#load` → `ServiceCatalog`. Discount rows are `type` + JSON `params`, which `DiscountRuleMapper` turns into strategy objects. A new discount type needs: a domain class, a mapper branch, a serializer branch and a seed row.
- Saved packages store only service codes; prices are recomputed when read. `Package.rehydrate` skips validation on purpose, and loaded packages carry their `violations` instead.
- The server (`config.ru`) migrates and seeds an empty database on boot. The database file comes from `DATABASE_PATH` (a file path, because `sqlite://` URLs break on Windows drive letters); the default is `backend/db/<RACK_ENV>.sqlite3`.
- The HTTP layer maps `Domain::ValidationError` → 422, `Application::NotFound` → 404 and `BadRequest` → 400. Every error uses the envelope `{error:{code,message,violations}}`.

## Frontend architecture

- The browser only calls Next.js; `next.config.ts` rewrites `/api/*` to `BACKEND_URL` (default `http://127.0.0.1:4567`).
- `GET /api/catalog` sends the rules **as data**. `features/package-builder/rules/selectionRules.ts` is a *generic* interpreter of them, with no hard-coded service codes. It returns decisions (`add` / `blocked` / `conflict` / `confirm`); `state/builderReducer.ts` (pure) records them; `hooks/usePackageBuilder.ts` connects the two.
- **Pricing is never calculated on the frontend.** `useEvaluation` calls `POST /api/packages/evaluate` (debounced, aborting earlier requests).
- Removing a service others depend on, and replacing a superseded service, both go through `ConfirmDialog`. Cancel must leave the state unchanged (docs/adr/0005).

## Spec quirks

The spec's template prices, Example 4 and several mockup totals contradict its own rules. We follow the rules plus Appendix Example 3's arithmetic. See `docs/spec-discrepancies.md` before "fixing" a price to match the spec.
