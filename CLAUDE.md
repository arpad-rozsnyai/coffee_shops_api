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
interface used throughout (`NearestCoffeeShopsFinder`, the GraphQL types).

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

`CoffeeShops::DEFAULT_LIMIT` (`config/initializers/coffee_shops.rb`, currently `5`) is the single
shared fallback for every GraphQL `limit` argument left unspecified — both `coffeeShops` and
`nearestCoffeeShops` reference it rather than each carrying its own default constant, specifically so
that changing "what does an unspecified limit default to" is a one-line change in one place, not a
per-field one. Don't reintroduce a field-local default constant (e.g. a `DEFAULT_COFFEE_SHOPS_LIMIT`
on `Types::QueryType` or a `DEFAULT_LIMIT` on `NearestCoffeeShopsFinder`) even if a field's default
value should later diverge from the others — extend `CoffeeShops` with a second, more specific
constant instead of duplicating the "positive integer, else fall back" check per field.

1. `POST /graphql` → `GraphqlController#execute` (`app/controllers/graphql_controller.rb`) — executes
   `params[:query]`/`params[:variables]`/`params[:operationName]` against `CoffeeShopsApiSchema` and
   renders the result as-is. `#prepare_variables` normalizes `variables` whether it arrives as a
   JSON-encoded string param or a nested JSON object (Rails parses a JSON body into
   `ActionController::Parameters`) — both are real, distinct code paths GraphQL clients use depending
   on how they encode the request; both are covered in `spec/requests/graphql_spec.rb`.
2. `CoffeeShopsApiSchema` (`app/graphql/coffee_shops_api_schema.rb`) → `Types::QueryType`
   (`app/graphql/types/query_type.rb`) for reads, `Types::MutationType`
   (`app/graphql/types/mutation_type.rb`) for the `login`/`refreshToken` auth mutations described below
   — coffee shop data itself is still **read-only** (a deliberate, current-scope decision, not an
   oversight — CRUD/write support for `CoffeeShop` is a separate future ticket; see Authentication
   below for why mutations exist at all now). Three query fields:
   - `coffeeShops` — `CoffeeShop.limit(MAX_COFFEE_SHOPS)` (currently `500`). Capped because this is the
     only "list everything" field in the app; every other field is inherently bounded. If you add
     pagination later, replace the flat cap rather than layering an argument on top of it.
   - `coffeeShop(id: ID!)` — `CoffeeShop.find_by(id:)`, returns a nullable single `CoffeeShopType`,
     **not an array**. This is deliberate GraphQL convention (singular field name → nullable single
     object; plural field name → non-null list) and was specifically confirmed against an
     interviewer's feedback — don't "fix" it into an array for consistency with the other fields.
   - `nearestCoffeeShops(x: Float!, y: Float!, name: String, limit: Int)` —
     `NearestCoffeeShopsFinder.new(repository: CoffeeShop).call(x:, y:, name:, limit:)`. `limit` follows
     the same "default when omitted/null/non-positive" rule as `coffeeShops`' `limit`
     (`Types::QueryType#positive_or_default`, shared by both fields), and the two fields share the same
     fallback value too — `CoffeeShops::DEFAULT_LIMIT`, not a per-field constant (see above). `name` is
     the same case-insensitive partial match as `coffeeShops`' `name` (`CoffeeShop.name_contains`) —
     when given, only matching shops are considered before finding/ordering the nearest ones; when
     omitted, every shop is a candidate, same as before this argument existed.
3. `Types::CoffeeShopType` / `Types::NearestCoffeeShopType` (`app/graphql/types/`) — render the
   response directly from `CoffeeShop`/`{coffee_shop:, distance:}`; there's no separate serializer
   class the way REST had one. `NearestCoffeeShopType#distance` is where the once-only 4-decimal
   rounding happens now (a presentation concern, same reasoning as before, just relocated).
4. `NearestCoffeeShopsFinder#call(x:, y:, name: nil, limit: nil)`
   (`app/services/nearest_coffee_shops_finder.rb`) — when `name` is present, `repository.name_contains`
   narrows the scope before the distance `SELECT`/`ORDER`/`LIMIT` chain is applied on top of it,
   otherwise `repository` itself (unfiltered) is used; this means `repository:` now also needs to
   support `.name_contains` (a `CoffeeShop`-specific scope), reinforcing that this parameter isn't a
   generic repository abstraction — it's always `CoffeeShop`, by design (see below). The distance
   calculation and the nearest-first ordering both happen in the database, not Ruby:
   `SELECT coffee_shops.*, SQRT(POWER(coordinate_x - ?, 2) + POWER(coordinate_y - ?, 2)) AS distance`
   (bound via `sanitize_sql_array`, not string interpolation) `ORDER BY distance ASC, name ASC LIMIT
   ?`. Plain SQL, no PostGIS/geospatial
   extension — this is a flat 2D Euclidean distance, which plain arithmetic already expresses exactly;
   reach for PostGIS only if the columns ever become real geographic coordinates needing great-circle
   distance. `name` is a second `ORDER BY` column (not a Ruby tiebreaker) for deterministic ordering on
   exact distance ties. Postgres returns the computed `distance` column typed as a float already
   (confirmed against the real adapter — no manual cast needed), so `shop.distance` in the `.map` is a
   `Float` even though `distance` isn't a real column on `CoffeeShop`. `repository:` is a **required**
   keyword arg (no default) — there's only ever one caller now, and it always passes `CoffeeShop`
   explicitly; it must support `.select`/`.order`/`.limit`/`.sanitize_sql_array`, not just `.all` (an
   AR class or relation, not an arbitrary object).

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
config-only — `CoffeeShops.csv_url` and the `CoffeeShops::DEFAULT_LIMIT` constant. Everything under
`app/services/` and `app/models/` is a
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

**Authentication.** `User` (`app/models/user.rb`) is an ApplicationRecord backed by the `users` table
(`db/migrate/20260903085407_devise_create_users.rb`): `name`, `email`, `encrypted_password` (all
`null: false`), unique index on `email`. Uses the `devise` gem, but only for the model layer —
`devise :database_authenticatable, :validatable` (email format/uniqueness, password length, presence
validations) — no other devise modules (`:registerable`, `:recoverable`, `:rememberable`, etc.) are
included since nothing in this app does self-service signup or password reset; add a module only when
a feature actually needs it. `devise_for :users` is deliberately **not** in `config/routes.rb` — this
app never mounts Devise's own controllers (sessions/registrations/passwords), since auth is exposed
exclusively through the two GraphQL mutations below, not REST. Users are provisioned only via
`bin/rails users:create name=... email=... password=...` (`lib/tasks/users.rake`) — there is no
self-registration path.

Tokens are JWTs (the `jwt` gem) rather than DB-backed sessions — validating one doesn't require a
lookup beyond loading the `User` by id — but issuing an *access* token is not fully stateless: see
`current_access_token_jti` below. `Auth` (`config/initializers/auth.rb`, config-only, mirrors the
`CoffeeShops` module convention) holds `Auth::JWT_ALGORITHM` (`"HS256"`), `Auth::ACCESS_TOKEN_TTL`
(3 minutes), and `Auth::REFRESH_TOKEN_TTL` (2 hours) — the single source of truth for both TTLs.
`JwtEncoder.new(user:, token_type: :access | :refresh).call` (`app/services/jwt_encoder.rb`) signs a
`{sub:, type:, exp:}` payload with `Auth.jwt_secret` and returns `[token, expires_at]`.
`Auth.jwt_secret` is `ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)` — same
env-var-with-a-default pattern as `CoffeeShops.csv_url`, so the JWT signing secret can be rotated
independently of Rails' own `secret_key_base` without code changes. `JwtDecoder.new(token:,
expected_type: :access | :refresh).call` (`app/services/jwt_decoder.rb`) verifies the signature and
expiry, checks the `type` claim matches `expected_type` (an access token cannot be used where a
refresh token is expected, or vice versa), and loads the `User`, raising the nested
`JwtDecoder::InvalidTokenError` (see Error convention below) for any failure — bad signature, expired,
wrong type, a since-deleted user, or a superseded `jti` (see below).

**Access tokens are single-active-token-per-user, enforced via `User#current_access_token_jti`**
(`db/migrate/20260903103104_add_current_access_token_jti_to_users.rb`, a nullable string). Every time
`JwtEncoder` issues an *access* token (from either `login` or `refreshToken`), it generates a random
`SecureRandom.uuid`, unconditionally overwrites `user.current_access_token_jti` with it via
`update_column`, and embeds the same value as the payload's `jti` claim (RFC 7519's standard "JWT ID"
field, not a bespoke one) — this is the one place token issuance writes to the database. `JwtDecoder`,
when `expected_type: :access`, rejects the token unless its `jti` claim equals the user's *current*
`current_access_token_jti`, so issuing any new access token immediately invalidates every access token
issued before it for that user — including one from a still-open session on another device, not just
the caller's own previous token. This was a deliberate fix, not the original design: a user reported
that refreshing left the old access token still working until its own 3-minute expiry, which is a real
gap for a token meant to be short-lived-and-replaceable. Refresh tokens carry no `jti` claim and are
unaffected — they stay valid for their full 2-hour TTL regardless of how many access tokens are minted
from them.

This landed as a `jti`-per-token design after two earlier iterations, kept here as context for why it
looks like this rather than the more common denylist-of-revoked-tokens pattern:
- **First**: an incrementing `token_version` integer, checked as a `ver` claim. Rejected in favor of
  `jti` because `user.increment!(:token_version)` is a read-modify-write (load the current value, add
  1, write it back) — not atomic, so concurrent access-token issuance for the same user could lose an
  update. `jti` avoids this: `update_column` with a freshly generated UUID is an unconditional
  overwrite, nothing to race on.
- That iteration also shipped a real bug worth remembering the shape of: `JwtEncoder`'s bump method
  returned `user.increment!(:token_version)`'s own return value — the `User` object itself, not the new
  integer — so `payload[:ver]` was briefly a serialized `#<User:0x...>` string. Every access token
  failed its own version check as a result. Caught immediately by the request specs, not in the wild.
- A denylist of revoked token IDs (a table, one row per superseded token, checked on every decode) was
  considered and rejected too — it solves a different problem than what was asked for ("was this
  specific token revoked?" vs. "is this the latest one?"), needs a cleanup job for entries whose
  tokens would have expired anyway (this app has no background job infra - see Hard constraints), and
  adds a query per request beyond the `User` lookup `JwtDecoder` already does. `jti`-on-`User` needs
  none of that: the comparison piggybacks on the `User.find` already happening, and a stale `jti` is
  just permanently wrong, not a row to clean up.

`Types::MutationType` (`app/graphql/types/mutation_type.rb`) is the schema's one mutation root, added
specifically for these two fields — see the "No GraphQL mutations" constraint update below:
- `login(email: String!, password: String!)` — looks the user up via
  `User.find_for_authentication(email:)` (devise's canonical, case-insensitive lookup), then
  `#valid_credentials?` either calls `user.valid_password?(password)` when a user was found, or - when
  none was - hashes `password` against a fixed dummy bcrypt digest (`MutationType::DUMMY_PASSWORD_DIGEST`)
  and still returns `false`. That dummy comparison exists solely for timing parity: skipping bcrypt
  entirely on an unknown email would make a wrong-password response measurably slower than an
  unknown-email response, letting an attacker enumerate registered emails from response time alone.
  Either way, failure raises a single generic `GraphQL::ExecutionError, "Invalid email or password"`
  (never reveals whether the email or the password was wrong). On success returns
  `Types::AuthPayloadType`: `accessToken`/`accessTokenExpiresAt` and `refreshToken`/`refreshTokenExpiresAt`.
- `refreshToken(refreshToken: String!)` — decodes the given token via `JwtDecoder` with
  `expected_type: :refresh`, then mints a brand-new access token for that user. Returns
  `Types::RefreshPayloadType`: just `accessToken`/`accessTokenExpiresAt` — it does not rotate or
  re-return the refresh token, per the original request ("the refresh EP to refresh the access token").
  `JwtDecoder::InvalidTokenError` is caught here and re-raised as `GraphQL::ExecutionError`.

Every **query** field checks authentication itself, via a shared private `authenticate!` on
`Types::QueryType` (`app/graphql/types/query_type.rb`) that each of `coffeeShops`/`coffeeShop`/
`nearestCoffeeShops` calls first, raising `GraphQL::ExecutionError, "Unauthorized"` when
`context[:current_user]` is blank. **Deliberately not** a type-level `self.authorized?` override — that
hook also gates `__schema`/`__type` introspection, since they're resolved as fields on this same root
type; a `QueryType.authorized?` override was tried and confirmed (via a direct
`CoffeeShopsApiSchema.execute` call) to make introspection itself return `{"errors"=>[{"message"=>
"Unauthorized"}]}` regardless of token, which would break GraphiQL's schema explorer for every user —
don't reintroduce type-level gating here without solving that first. `GraphqlController#execute`
(`app/controllers/graphql_controller.rb`) is what populates `context[:current_user]`: it reads an
`Authorization: Bearer <token>` header, decodes it with `expected_type: :access`, and sets the user if
that succeeds — swallowing `JwtDecoder::InvalidTokenError` into `nil` rather than raising, so a missing
or invalid token reaches each query field's `authenticate!` as "no current user" (a clean GraphQL
error) instead of blowing up in the controller. `login`/`refreshToken` never call `authenticate!`, so
they remain reachable with no `Authorization` header at all — that's how a client gets its first tokens.

**Hard constraints for this codebase** (do not reintroduce without discussion):
- No Geocoder, PostGIS, or other geospatial gem/extension — nearest-shop distance is a flat 2D
  Euclidean calculation done in plain SQL (`SQRT(POWER(...))`) inside `NearestCoffeeShopsFinder`, not
  Ruby (`CoffeeShop#distance_to`/`Math.hypot` were removed once the calculation moved into the DB).
- No CSV-parsing gem — stdlib `CSV` only.
- No dotenv — env vars are read directly via `ENV.fetch`.
- No REST API — GraphQL (`POST /graphql`) is the only live query interface; see above.
- GraphQL mutations exist only for authentication (`login`, `refreshToken` on `Types::MutationType`,
  see Authentication above) — there is still no mutation for `CoffeeShop` data; CRUD/write support for
  coffee shops remains a separate, future ticket. Don't add a `CoffeeShop` mutation as a side effect of
  unrelated work, and don't assume "mutations exist now" opens that door on its own.