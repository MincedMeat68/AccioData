# ADR 0001: Persist with SQLite through Sequel, behind repository interfaces

**Status:** Accepted

## Context

Saved packages have to survive a restart (core requirements 8–10), and the evaluator must be able to run the app with one command on macOS, Windows or Linux. The spec leaves storage open: in-memory, JSON files, or a simple database.

## Options considered

| Option | For | Against |
|---|---|---|
| In-memory | Zero setup | Lost on restart; doesn't meet "load the most recently saved package when returning" |
| JSON file | No dependencies | We would have to write atomic writes, locking and queries ourselves; no referential integrity |
| **SQLite + Sequel** | One file, nothing to install. Real SQL, migrations, transactions and foreign keys. The `sqlite3` gem ships precompiled for Windows, macOS (Intel and Apple Silicon) and Linux | One native gem, though it is precompiled. Only one writer at a time, which is fine for this app |
| PostgreSQL (Docker) | Closest to production | The evaluator must have Docker running |
| ActiveRecord | Familiar | Active Record mixes domain objects with persistence, which works against the DDD layering (ADR 0002) |
| ROM-rb | Data mapper that suits DDD | Steep learning curve for a 4-hour task |

## Decision

Use **SQLite through Sequel's dataset API** (not `Sequel::Model`). The domain defines two interfaces, `Domain::Catalog::CatalogRepository` and `Domain::Packaging::PackageRepository`. Hand-written adapters in `app/infrastructure/persistence/` map rows to aggregates. An `InMemoryPackageRepository` implements the same interface for fast application-layer tests.

- The database file is never committed. Migrations (`backend/db/migrations`) create it, and `rake db:seed` fills the catalog (ADR 0003).
- The server also migrates and seeds an empty database on boot, so `npm run dev` works even if setup was skipped.
- `Gemfile.lock` lists every platform (`x64-mingw-ucrt`, `arm64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`), so `bundle install` never has to compile SQLite.
- The database is configured with `DATABASE_PATH` (a file path) rather than a `sqlite://` URL, because URLs handle Windows drive letters badly.

## Consequences

- Swapping to Postgres means changing the Sequel connection and running the migrations. The domain and application layers don't change.
- A package is saved as a whole (`packages` row plus its `package_items` rows) in a single transaction.
- Foreign keys stop a package from referencing a service that doesn't exist.
