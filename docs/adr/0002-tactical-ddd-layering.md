# ADR 0002: Tactical DDD with four layers in plain Ruby

**Status:** Accepted

## Context

The evaluation weights domain modeling and keeping business logic out of the presentation and data-access code. The rules are small but connected: dependencies, conflicts, discounts that stack, and the question of what happens when a service other services depend on is removed. These rules should live in one place we can test, not be spread across route handlers.

## Decision

The backend is split into layers. Each layer may only depend on the layers above it in this list:

```
domain/          Pure Ruby. No gems, no I/O.
application/     Use cases. Coordinate domain objects and repositories.
infrastructure/  Sequel/SQLite adapters, the seeder, row-to-object mappers.
http/            Sinatra routes and JSON serializers. No business rules.
config/boot.rb   Composition root: the only file that wires concrete adapters together.
```

Tactical DDD building blocks used:

| Building block | Where |
|---|---|
| **Value objects** (Ruby 3.2+ `Data`, immutable) | `Money`, `Service`, `Category`, `RequirementRule`, `ConflictRule`, `DiscountLine`, `PriceQuote`, `Violation` |
| **Aggregate root** | `Packaging::Package`: every change goes through it, and it enforces the invariants |
| **Domain services** | `Packaging::SelectionPolicy` (interprets the rules), `Pricing::PricingEngine` |
| **Strategy objects** | `Pricing::Discounts::VolumeDiscount`, `BundleDiscount` |
| **Repositories (interfaces)** | `Catalog::CatalogRepository`, `Packaging::PackageRepository` |
| **Reference data** | `Catalog::ServiceCatalog`, read-only and loaded through its repository |

Things deliberately left out, to avoid over-engineering:
- Domain events, CQRS and an IoC container.
- dry-rb gems. Ruby's own `Data` covers value objects.
- Autoloading. `config/boot.rb` requires files explicitly, in layer order, so the dependency direction is visible.

## Consequences

- Domain specs run against the real rules with no HTTP and no database writes.
- Application specs use the in-memory repository.
- The HTTP layer is thin enough that its specs mainly check status codes and JSON shapes.
- The package aggregate is stored as an ordered list of service codes. Prices are computed when needed, never stored (ADR 0003).
