# ADR 0006: Cross-platform startup through npm scripts, with Docker Compose as an alternative

**Status:** Accepted

## Context

The app is developed on Windows, and the evaluator may be on macOS. The stack (Next.js plus Sinatra) needs two runtimes and two servers. Starting it should take one command and behave the same on every OS.

## Decision

- **A root `package.json` acts as the task runner.** npm scripts behave the same on Windows, macOS and Linux, unlike `.sh` or `.ps1` scripts.
  - `npm run setup`: installs the root tools, runs `bundle install`, `rake db:setup` (migrate and seed) and `npm install` for the frontend.
  - `npm run dev`: runs both servers through `concurrently`, with labelled output.
  - `npm test`: runs RSpec and Vitest.
- **Next.js proxies `/api/*` to Sinatra** with `rewrites`, so the browser sees one origin and no CORS setup is needed. The target is `127.0.0.1`, not `localhost`, because Node may resolve `localhost` to IPv6 `::1` while the Ruby server listens on IPv4.
- **WEBrick, not Puma.** WEBrick is pure Ruby, so nothing needs compiling on the evaluator's machine. Production throughput is irrelevant here.
- **No web fonts are downloaded at build time** (the system font stack is used), so `next build` works offline.
- **`.gitattributes` forces LF line endings**, so files checked out on Windows still work inside Linux containers.
- **Version pins:** `.ruby-version` is 3.3.6 and `.nvmrc` is 20. The Gemfile requires Ruby 3.2 or later, the first version with `Data`.
- **Docker Compose** (`docker compose up --build`) is for evaluators who don't have Ruby. The backend stores its SQLite file on a named volume and migrates and seeds on first boot. The frontend uses a standalone Next.js build.

## Consequences

- The native path needs Ruby 3.2+ and Node 20+. The README gives install commands for macOS (Homebrew) and Windows (winget).
- The Ruby that ships with macOS (2.6) is too old. The README says this up front, and Docker is the fallback.
