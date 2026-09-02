# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rails 8.1 API-only app. Given a user's `X`/`Y` coordinates, finds the nearest coffee shops in the
`coffee_shops` table. **This started as a take-home coding challenge (AgileFreaks); that phase is
over.** The original README-documented REST/JSON:API contract has been deliberately replaced, not
extended — the app now takes ongoing feature requests like any normal product codebase, and **the
only live API is GraphQL** (`POST /graphql`). Do not treat the old challenge contract as something to
preserve or restore.

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

## Workflow: git

Never run `git commit`, `git push`, or any other state-changing git command (`reset`, `rebase`,
`checkout`/`restore` that discards changes, `branch -D`, force-push, etc.) unless the user explicitly
asks for that specific action in that turn. This includes when a prompt sounds git-adjacent but isn't
— e.g. "create the PR title and description" asks for text only, not for the change to actually be
committed/pushed/opened as a PR. Read-only git commands (`status`, `diff`, `log`) are always fine.
Leave the working tree's changes staged/unstaged as-is for the user to commit themselves unless told
otherwise.

## Commands

```bash
bin/setup                                          # install deps, start server (does NOT prepare the db — run bin/rails db:prepare first)
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

`factory_bot_rails` is available for ActiveRecord model specs (`config.include
FactoryBot::Syntax::Methods` in `spec/rails_helper.rb`, so specs call `build`/`create` directly, no
`FactoryBot.` prefix). Factories live in `spec/factories/`, one file per model (see
`spec/factories/coffee_shops.rb`). This is separate from the `spec/fixtures/files/coffee_shops/*.csv`
fixtures, which are raw CSV text used to stub the remote feed for `CsvClient`/`CsvParser` specs, not
ActiveRecord test data.

## Architecture

**ActiveRecord + PostgreSQL are wired up and populated; `CoffeeShop` is a persisted model and the
system of record.** `active_record/railtie` is required in `config/application.rb`, the `pg` gem is in
the `Gemfile`, and `config/database.yml` configures the `coffee_shops_api_{development,test,production}`
databases. `CoffeeShop` (`app/models/coffee_shop.rb`) is an `ApplicationRecord` backed by the
`coffee_shops` table (`db/migrate/20260902112014_create_coffee_shops.rb`, plus
`db/migrate/20260902163534_add_slug_to_coffee_shops.rb`): `name`, `coordinate_x`, `coordinate_y`,
`slug` (all `null: false`), plus nullable `address` and `open_until`. `name`/`coordinate_x`/
`coordinate_y` also carry `presence` validations, pairing the DB constraint with a model-level one.
`alias_attribute :x, :coordinate_x` and `alias_attribute :y, :coordinate_y` give it a short `x`/`y`
interface used throughout (`#distance_to(x, y)`, `NearestCoffeeShopsFinder`, the GraphQL types).

**`slug` is the uniqueness anchor, not `[name, coordinate_x, coordinate_y]`.** The old composite
unique index on those three columns is gone — `slug` (unique index, `presence`+`uniqueness`
validations) replaces it. It's derived, once, from `name`/`coordinate_x`/`coordinate_y` in a
`before_validation on: :create` callback (`CoffeeShop#generate_slug`), always overwriting any
explicitly-assigned value — it's not accepted input, it's computed. `attr_readonly :slug` then makes
it immutable after creation (`update`/`save` raise `ActiveRecord::ReadonlyAttributeError` if you try to
change it — Rails 7.1+ behavior; only a bypass like `update_column` can force it, deliberately, the
same as any `attr_readonly` column). Plain `#parameterize` on the joined string would collide a
coordinate with its sign-flipped counterpart (`-` is stripped as a non-alphanumeric character, same as
the join separator) — `#signed_component` guards against that by encoding negative values with a
literal `neg` prefix before parameterizing (e.g. `x: -122.316` → `neg122.316` → `neg122-316`, distinct
from the positive `122-316`). Not searchable, not exposed via GraphQL (`Types::CoffeeShopType` has no
`slug` field) — purely an internal identity/uniqueness concern for now.

The migration's backfill deliberately does not call into the live `CoffeeShop` model — it re-implements
the same slug algorithm on a migration-local `MigrationCoffeeShop < ActiveRecord::Base` scoped to the
table, per standard Rails practice: a migration's data transformation should be a frozen snapshot, not
tied to a model class that's free to change its logic later.

ActiveJob and ActionCable (and the other Rails 8 defaults that ride along with them —
`solid_cache`/`solid_queue`/`solid_cable`, `config/cable.yml`) remain removed — nothing in this app
enqueues jobs or uses websockets.

There are two separate pipelines. Don't conflate them — the import pipeline is offline/manual and
populates the table; the request-time pipeline is GraphQL-only and only ever reads the table.

**Import pipeline** (populates the DB; run manually via a rake task, never as part of a request):

1. `CoffeeShops.csv_url` (`config/initializers/coffee_shops.rb`) — the single authoritative source for
   the CSV URL. Defaults to the original challenge dataset, overridable via `COFFEE_SHOPS_CSV_URL` env
   var. Nothing else should hardcode this URL.
2. `CsvClient#fetch` (`app/services/csv_client.rb`) — GETs the URL via stdlib `Net::HTTP` and returns
   the body. Converts timeouts, connection failures, invalid URIs, and non-2xx responses into
   `CsvClient::RemoteDataSourceError`. Does no parsing, no caching. **It does normalize encoding**,
   though — `Net::HTTP` always tags `response.body` as `ASCII-8BIT` regardless of what the server's
   `Content-Type` charset says (confirmed against the real feed, which declares `charset=utf-8` yet
   still comes back `ASCII-8BIT`-tagged); left alone, that byte-soup tag survives into
   `CoffeeShop#generate_slug`'s `#parameterize` call downstream and blows up with `ArgumentError:
   Cannot transliterate strings with ASCII-8BIT encoding`. `#normalize_encoding` reads the declared
   charset from `response.type_params["charset"]` (falling back to UTF-8 if absent), force-encodes to
   that, validates it, and transcodes to UTF-8 — raising `RemoteDataSourceError` instead if the body
   isn't valid text in its declared charset, or if the declared charset name is bogus.
3. `CsvParser.parse(csv_string)` (`app/services/csv_parser.rb`) — parses with stdlib `CSV`. **The
   remote source has no header row** — columns are positional: `Name, X, Y` (confirmed against the
   real feed; do not reintroduce a header-row assumption, e.g. `CSV.parse(..., headers: true)` or a
   required-headers check — that was tried and breaks against the real feed, which starts directly
   with data). Uses strict `Float()` (never `to_f`) for coordinates. Row-level problems (blank name,
   missing/non-numeric coordinates) are silently skipped so one bad row doesn't break the batch; a
   structurally unparseable CSV (e.g. an unterminated quote) raises `CsvParser::ParseError` (nested
   under `CsvParser`, not a top-level class — see Error convention below). A well-formed but empty
   feed returns an empty array — that's not an error.
4. `CoffeeShopImporter#call` (`app/services/coffee_shop_importer.rb`) — builds unsaved
   `CoffeeShop.new(name:, x:, y:)` per parsed row via `parser.parse(client.fetch)`, skips rows that
   already exist (matched on `name`+`coordinate_x`+`coordinate_y`, enforced by the DB unique index),
   and `save!`s the rest. Invoked via `bin/rails coffee_shops:import` (`lib/tasks/coffee_shops.rake`).
   Nothing runs this automatically — the table only reflects the feed as of the last manual import.

**Request-time pipeline** (GraphQL only — there is no REST API):

1. `POST /graphql` → `GraphqlController#execute` (`app/controllers/graphql_controller.rb`) — executes
   `params[:query]`/`params[:variables]`/`params[:operationName]` against `CoffeeShopsApiSchema` and
   renders the result as-is. `#prepare_variables` normalizes `variables` whether it arrives as a
   JSON-encoded string param or a nested JSON object (Rails parses a JSON body into
   `ActionController::Parameters`) — both are real, distinct code paths GraphQL clients use depending
   on how they encode the request; both are covered in `spec/requests/graphql_spec.rb`.
2. `CoffeeShopsApiSchema` (`app/graphql/coffee_shops_api_schema.rb`) → `Types::QueryType`
   (`app/graphql/types/query_type.rb`) — **query-only, no mutations** (a deliberate, current-scope
   decision, not an oversight — write support is a separate future ticket). Three fields:
   - `coffeeShops` — `CoffeeShop.limit(MAX_COFFEE_SHOPS)` (currently `500`). Capped because this is the
     only "list everything" field in the app; every other field is inherently bounded. If you add
     pagination later, replace the flat cap rather than layering an argument on top of it.
   - `coffeeShop(id: ID!)` — `CoffeeShop.find_by(id:)`, returns a nullable single `CoffeeShopType`,
     **not an array**. This is deliberate GraphQL convention (singular field name → nullable single
     object; plural field name → non-null list) and was specifically confirmed against an
     interviewer's feedback — don't "fix" it into an array for consistency with the other fields.
   - `nearestCoffeeShops(x: Float!, y: Float!)` — `NearestCoffeeShopsFinder.new(repository:
     CoffeeShop).call(x:, y:)`. Passing the `CoffeeShop` AR class itself as `repository:` works because
     the finder only ever calls `repository.all`, and `CoffeeShop.all` satisfies that — no separate "DB
     repository" class exists or is needed for this.
3. `Types::CoffeeShopType` / `Types::NearestCoffeeShopType` (`app/graphql/types/`) — render the
   response directly from `CoffeeShop`/`{coffee_shop:, distance:}`; there's no separate serializer
   class the way REST had one. `NearestCoffeeShopType#distance` is where the once-only 4-decimal
   rounding happens now (a presentation concern, same reasoning as before, just relocated).
4. `NearestCoffeeShopsFinder#call(x:, y:)` (`app/services/nearest_coffee_shops_finder.rb`) — pairs each
   shop with `{ coffee_shop:, distance: }` via `CoffeeShop#distance_to` (`Math.hypot`), and takes the 3
   nearest via `min_by(MAX_RESULTS) { [distance, name] }` — a partial selection rather than a full
   sort, since only the top `MAX_RESULTS` are ever needed. Name is a tiebreaker for deterministic
   ordering on exact distance ties. `repository:` is a **required** keyword arg (no default) — there's
   only ever one caller now, and it always passes `CoffeeShop` explicitly.

`HomeController` (`app/controllers/home_controller.rb`) only has `index` — a static landing page, no
data pipeline involved. An HTML `/search` form was added and then removed again the same session
(2026-09-02); don't reintroduce it without checking whether it's actually wanted this time.
**`CoordinateValidator` (`app/services/coordinate_validator.rb`) is now unused in the live app** — its
only caller was that removed `#search` action; it's kept only because removing it wasn't explicitly
asked for, not because anything still calls it (confirm with a repo-wide grep before assuming
otherwise). GraphQL's own `Float!` argument coercion is what actually validates `nearestCoffeeShops`'
`x`/`y` now.

**GraphiQL (development only):** `GET /graphiql` mounts `GraphiQL::Rails::Engine`
(`config/routes.rb`, guarded by `if Rails.env.development?` — confirmed absent from
`Rails.application.routes.routes` under `RAILS_ENV=production`), the interactive explorer, as the
Swagger-UI replacement. It needs Sprockets (`sprockets-rails` + `graphiql-rails`, both
`group :development` in the `Gemfile` — this app otherwise has no asset pipeline). Two things that
will bite you if touched carelessly:
- **Gemfile order matters:** `sprockets-rails` must be listed *before* `graphiql-rails`.
  `graphiql-rails`'s engine (`lib/graphiql/rails/engine.rb`) only registers its assets for
  precompilation if `Sprockets` is already `defined?` at load time; `Bundler.require` loads gems in
  Gemfile declaration order, so getting this backwards makes it silently fall back to serving from an
  empty `public/` dir in the gem instead — no boot error, just a broken page. Confirmed by actually
  reordering and re-booting, not by reasoning about it.
- **`graphiql-rails` 1.10.5 only precompiles its own `.css`, not its `.js`** (a gap in the gem itself,
  confirmed by reading `lib/graphiql/rails/engine.rb`) — without `config/initializers/graphiql.rb`
  explicitly adding `graphiql/rails/application.js` to `config.assets.precompile`, `/graphiql` 500s
  with `Sprockets::Rails::Helper::AssetNotPrecompiledError` on the JS asset specifically (the CSS
  loads fine, which is what makes this one non-obvious). `app/assets/config/manifest.js` exists only
  because Sprockets requires the file to be present at all — this app has no assets of its own.

**REST API removed — do not reintroduce without discussion.** `Api::V1::CoffeeShopsController`,
`CoffeeShopDistanceSerializer`, `CoffeeShopRepository`, and the Rswag/OpenAPI docs setup (the
`rswag-api`/`rswag-ui`/`rswag-specs` gems, `config/initializers/rswag_*.rb`, the `/api-docs` mount, and
the checked-in `swagger/` dir) were all deliberately deleted, not deprecated — GraphQL replaced REST
entirely, with no backward-compatibility shim kept. **`CsvClient` and `CsvParser` were *not* removed**
— don't assume "REST is gone" means the whole CSV layer is dead; they're still load-bearing for
`CoffeeShopImporter`/the import rake task, which is how the table GraphQL reads from gets populated.
Only `CoffeeShopRepository` (a thin `parser.parse(client.fetch)` wrapper that existed solely to feed
the old request-time CSV pipeline) was genuinely orphaned and removed along with REST.

**Namespacing convention:** `CoffeeShops` (plural module, `config/initializers/coffee_shops.rb`) is
config-only — just `CoffeeShops.csv_url`. Everything under `app/services/` and `app/models/` is a
flat, top-level class (`CsvClient`, `CsvParser`, `CoffeeShop`, ...) with no app-specific module
nesting — matches the directory layout 1:1, per Zeitwerk convention. `app/graphql/types/` is the one
place that *does* nest under a module (`Types::`) — that's standard graphql-ruby convention, still
matches its directory layout 1:1, and isn't a violation of the services/models rule above (which is
scoped to those two directories).

**Error convention:** each failure domain gets its own narrow `StandardError` subclass, nested inside
the one class that raises it rather than given its own top-level file: `CsvClient::RemoteDataSourceError`
(`app/services/csv_client.rb`) and `CsvParser::ParseError` (`app/services/csv_parser.rb`). Raised only
from specifically-rescued exceptions — no broad `rescue StandardError`. Both are still actively used —
by `CoffeeShopImporter`/the rake task now, not a request-time controller.

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
- No REST API — GraphQL (`POST /graphql`) is the only live query interface; see above.
- No GraphQL mutations yet — queries only; CRUD/write support is a separate, future ticket.