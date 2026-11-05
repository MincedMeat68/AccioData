# ADR 0003: Catalog and rules stored as data in the database; validation in both places, authority on the backend

**Status:** Accepted

## Context

Spec decision points 1 and 2: *Where should validation logic live?* and *How will you model service dependencies? Config file, code constants, database?* The UI also needs real-time feedback, such as disabled buttons with a reason, without making the user submit anything.

## Options for storing the rules

| Option | For | Against |
|---|---|---|
| Code constants | Simplest | Rules become hidden in conditionals; a price change needs a code change |
| YAML config read at boot | Changes go through code review | Changing a price means redeploying; not how a real product works |
| **Database tables, seeded from YAML** | Prices and rules can change at runtime and could be set per customer or audited later. The domain loads them through a repository like any other data | More schema, and seed data is still needed |

## Decision

**Store the catalog in SQLite as data.** The tables are `categories`, `services`, `service_requirements`, `service_conflicts`, `discount_rules` and `package_templates`/`package_template_items`.

- Discounts come in different shapes (percentage tiers vs. a flat amount), so `discount_rules` holds a `type` plus JSON `params`. `DiscountRuleMapper` turns each row into the matching strategy object. A new kind of discount needs one new class plus one new mapper branch; the pricing engine doesn't change.
- `backend/db/seeds/catalog.yml` is the seed data, kept readable. `rake db:seed` loads it **idempotently in a single transaction**. Services are upserted and never deleted, because saved packages reference them.
- A conflict rule has a `supersedes` flag ("10-Panel includes 5-Panel"), so the UI can offer to **replace** the lesser service instead of only rejecting it.

**Where validation runs:** a hybrid, with the backend in charge.

- `GET /api/catalog` sends the requirement and conflict rules **as data**. The frontend's `selectionRules.ts` is a *generic* interpreter of that data: it contains no service names and no hard-coded rules. It drives instant enable/disable states, reasons and confirmation prompts.
- **Pricing is calculated only on the backend.** `POST /api/packages/evaluate` is debounced at 150 ms and returns the quote, the violations and each service's availability.
- **Every save is validated again on the backend** by the `Package` aggregate. Invalid saves get `422` with the full list of violations.

So a rule change in the database reaches both the UI and the backend without code changes, and pricing logic exists exactly once.

## Saved packages and catalog changes

- Packages store **only service codes**. Prices are recomputed from the current catalog whenever a package is read.
- Loading a package does **not** re-validate it, because rules may have tightened since it was saved. Instead it is returned with its `violations`, and the UI shows a warning so the user can fix it.

## Future work: price snapshots

In a real product, a package saved at $95 should probably keep showing $95 after the catalog prices change. That would mean storing each item's price and the full quote (`package_items.price_cents`, `packages.quote_json`) at save time. It also raises a product question: does editing a package re-price it at today's rates? We chose to document this rather than build it, because the spec has no notion of prices changing.
