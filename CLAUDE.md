# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rails 8.1 API-only app implementing a coding-challenge contract: accept a user's `X`/`Y` coordinates
and return the three nearest coffee shops from a remote CSV data source, ordered nearest-to-farthest,
as a JSON:API response. See `README.md` for the full contract, including the reference ordering case
used to validate correctness.

**Ruby:** developed against Ruby 4.0.5 via rvm. The committed `.ruby-version` / `Gemfile` still pin
3.2.1 — if you hit version-related install or CI issues, check which Ruby is actually active
(`rvm current`) against those files before assuming the code is at fault.

## Workflow: new features

For any prompt that implements a new feature (not needed for pure Q&A, docs, or trivial one-line
fixes), use the `feature` skill (`.claude/skills/feature/SKILL.md`) rather than implementing directly.
It reads this file for conventions, implements the feature, then drives the change through the
`devils-advocate` skill (`.claude/skills/devils-advocate/SKILL.md`) — a read-only adversarial review
for code smells, SOLID/DRY/YAGNI violations, and drift from the conventions documented below — looping
fix → re-review until two consecutive green rounds, then runs `bin/rubocop` to a clean state.

## Commands

```bash
bin/setup                                          # install deps, prepare db, start server
bin/dev                                             # start the Rails server (bin/rails server)

bundle exec rspec                                   # run the full test suite
bundle exec rspec spec/path/to/some_spec.rb          # run one spec file
bundle exec rspec spec/path/to/some_spec.rb:42       # run one example at a line number

bin/rubocop                                          # lint (rubocop-rails-omakase house style)
bin/brakeman --no-pager                              # static security analysis
bin/bundler-audit                                    # gem vulnerability audit

bin/ci                                               # runs the steps in config/ci.rb locally
```

**Testing note:** RSpec (+ WebMock) is the real test suite — specs live under `spec/`, not `test/`.
The `test/` directory is the original generated Minitest scaffold and only contains `.keep` files.
`bin/ci` and `.github/workflows/ci.yml` still invoke `bin/rails test`, which currently runs nothing;
when adding coverage for CI, add/extend RSpec specs under `spec/` and treat the Minitest step as stale.

WebMock is loaded in `spec/rails_helper.rb` and disables all real outbound HTTP in specs — any code
that hits the network needs a `stub_request` (see `spec/services/csv_client_spec.rb`).

## Architecture

**No database, period.** ActiveRecord, ActiveJob, and ActionCable (and the Rails 8 defaults that ride
along with them — `sqlite3`, `solid_cache`/`solid_queue`/`solid_cable`, `db/`, `config/database.yml`,
`config/cable.yml`) have all been removed — nothing in this app persists, enqueues jobs, or uses
websockets. Coffee shops are fetched from a remote CSV on each request and modeled as a plain Ruby
object.

**Request-time pipeline** (fetch → parse → [selection] → [render], each step decoupled and independently
testable):

1. `CoffeeShops.csv_url` (`config/initializers/coffee_shops.rb`) — the single authoritative source for
   the CSV URL. Defaults to the challenge's dataset, overridable via `COFFEE_SHOPS_CSV_URL` env var.
   Nothing else should hardcode this URL.
2. `CsvClient#fetch` (`app/services/csv_client.rb`) — GETs the URL via stdlib
   `Net::HTTP` and returns the raw body. Converts timeouts, connection failures, invalid URIs, and
   non-2xx responses into `CsvClient::RemoteDataSourceError`. Does no parsing, no caching.
3. `CsvParser.parse(csv_string)` (`app/services/csv_parser.rb`) — parses with
   stdlib `CSV`. **The remote source has no header row** — columns are positional: `Name, X, Y`
   (confirmed against the actual challenge dataset; do not reintroduce a header-row assumption, e.g.
   `CSV.parse(..., headers: true)` or a required-headers check — that was tried and breaks against the
   real feed, which starts directly with data). Uses strict `Float()` (never `to_f`) for coordinates.
   Row-level problems (blank name, missing/non-numeric coordinates) are silently skipped so one bad row
   doesn't break the batch; a structurally unparseable CSV (e.g. an unterminated quote) raises
   `CsvParser::ParseError` (nested under `CsvParser`, not a top-level class — see Error convention
   below). A well-formed but empty feed returns an empty array — that's not an error, since
   there's no header line to make "zero shops" ambiguous with "broken feed".
4. `CoffeeShop` (`app/models/coffee_shop.rb`) — plain Ruby value object (`name`, `x`, `y`,
   `#distance_to(x, y)` via `Math.hypot`). There's no ActiveRecord in this app at all; it lives in
   `app/models` purely by Zeitwerk convention.
   Returns full-precision distance; rounding to 4 decimals (per the contract) is a presentation-layer
   concern, not implemented here.
5. `CoffeeShopRepository#all` (`app/services/coffee_shop_repository.rb`) — composes steps 2 and 3
   (`parser.parse(client.fetch)`); the only place that wires `CsvClient` and `CsvParser` together.
6. `NearestCoffeeShopsFinder#call(x:, y:)` (`app/services/nearest_coffee_shops_finder.rb`) — asks the
   repository for all shops, pairs each with `{ coffee_shop:, distance: }` via `CoffeeShop#distance_to`,
   sorts by `[distance, name]` (name as a tiebreaker for deterministic ordering — `sort_by` isn't
   guaranteed stable), and takes the first 3.
7. `Api::V1::CoffeeShopsController#index` (`app/controllers/api/v1/coffee_shops_controller.rb`) —
   validates params via `CoordinateValidator`, calls the finder, renders via
   `CoffeeShopDistanceSerializer`. `rescue_from` maps `CsvClient::RemoteDataSourceError` and
   `CsvParser::ParseError` to a 503; validation failures render a 400 directly (not an exception).
8. `CoffeeShopDistanceSerializer` (`app/serializers/coffee_shop_distance_serializer.rb`) — renders the
   JSON:API `data` document; rounds distance to 4 decimals here (the only rounding point) and derives a
   deterministic `id` via `SHA1(name:x:y)` since CSV rows have no persisted identity.

**Namespacing convention:** `CoffeeShops` (plural module, `config/initializers/coffee_shops.rb`) is
config-only — just `CoffeeShops.csv_url`. Everything under `app/services/` and `app/models/` is a
flat, top-level class (`CsvClient`, `CsvParser`, `CoffeeShop`, ...) with no app-specific module
nesting — matches the directory layout 1:1, per Zeitwerk convention.

**Error convention:** each failure domain gets its own narrow `StandardError` subclass, nested inside
the one class that raises it rather than given its own top-level file: `CsvClient::RemoteDataSourceError`
(`app/services/csv_client.rb`) and `CsvParser::ParseError` (`app/services/csv_parser.rb`). Raised only
from specifically-rescued exceptions — no broad `rescue StandardError`.

This nesting is a deliberate exception to the flat-file convention above, not an oversight — a bare
top-level `CsvParseError`/`RemoteDataSourceError` each in its own file (as they originally were) was
tried and reverted. Zeitwerk only registers an autoload for the constant matching a file's name, so
`rescue_from ..., CsvParseError` in the controller had nothing telling it that constant existed until
something else happened to load `csv_parser.rb` first — it broke `Rails.application.eager_load!`
outright. Referencing the nested form instead (`CsvParser::ParseError`, `CsvClient::RemoteDataSourceError`)
fixes this: Ruby resolves the outer class via its own (correctly registered) autoload first, which loads
the whole file and defines the nested error constant as a side effect. If you add another custom error
class, nest it inside its raising class the same way — don't give it its own top-level file.

**Hard constraints for this codebase** (do not reintroduce without discussion):
- No Geocoder or other distance/geospatial gem — stdlib `Math.hypot` only.
- No CSV-parsing gem — stdlib `CSV` only.
- No dotenv — env vars are read directly via `ENV.fetch`.