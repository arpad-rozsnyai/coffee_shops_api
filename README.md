# coffee_shops_api

A Rails 8.1 API-only app: given a user's `x`/`y` coordinates, returns the nearest coffee shops in
the `coffee_shops` table via a **GraphQL API**.

This started as a take-home coding challenge with a REST/JSON:API contract; that phase is over, and
the REST endpoint has since been removed in favor of GraphQL — see [Architecture](#architecture)
below for what changed and why.

## Prerequisites

- Ruby **3.2.1** (pinned in `.ruby-version` and `Gemfile`; managed here via [rvm](https://rvm.io))
- Rails **8.1.3.1** (installed via Bundler, not a separate system install)
- PostgreSQL, running locally and reachable via `config/database.yml`

## Setup

```bash
git clone <this repo>
cd coffee_shops_api
bundle install
bin/rails db:prepare
```

Or use the generated convenience script, which installs dependencies and starts the server (it does
**not** prepare the database — run `bin/rails db:prepare` first):

```bash
bin/setup
```

### Populating the database

The `coffee_shops` table starts empty. Import shops from the remote CSV feed with:

```bash
bin/rails coffee_shops:import
```

This fetches, parses, and persists new shops (skipping ones already imported, matched by
name+coordinates); it's a manual/offline step, not something any request triggers automatically. Run
it again any time the feed changes.

## Configuration

### `COFFEE_SHOPS_CSV_URL`

The remote CSV data source used by the import task is configured in one place:
`config/initializers/coffee_shops.rb`. It defaults to the original challenge dataset and can be
overridden with an environment variable:

```bash
COFFEE_SHOPS_CSV_URL="https://example.com/my_coffee_shops.csv" bin/rails coffee_shops:import
```

## Running the server

```bash
bin/dev              # or: bin/rails server
```

Starts Puma on `http://localhost:3000` by default. Visit `/` for a small HTML landing page, or
`/graphiql` for an interactive GraphQL explorer (development only).

## Running tests

```bash
bundle exec rspec                                   # full suite
bundle exec rspec spec/path/to/some_spec.rb          # one file
bundle exec rspec spec/path/to/some_spec.rb:42       # one example, by line
```

RSpec (+ WebMock, which disables all real outbound HTTP in specs) is the real test suite, covering
the CSV client/parser/importer, the model, the GraphQL schema, and the finder end to end.

## Linting

```bash
bin/rubocop           # style (rubocop-rails-omakase house style)
```

The repo also ships `bin/brakeman` (static security analysis) and `bin/bundler-audit` (gem
vulnerability audit); `bin/ci` runs all of the above plus the test suite as a single local pipeline.

## API

### `POST /graphql`

The only live API. Send a GraphQL `query` (and optional `variables`/`operationName`) as JSON or
form-encoded params.

#### Example: nearest shops to a coordinate

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($x: Float!, $y: Float!) { nearestCoffeeShops(x: $x, y: $y) { distance coffeeShop { id name x y } } }",
    "variables": { "x": 47.6, "y": -122.4 }
  }'
```

```json
{
  "data": {
    "nearestCoffeeShops": [
      { "distance": 0.0645, "coffeeShop": { "id": "1", "name": "Starbucks Seattle2", "x": 47.5869, "y": -122.3368 } },
      { "distance": 0.0861, "coffeeShop": { "id": "2", "name": "Starbucks Seattle", "x": 47.5809, "y": -122.316 } },
      { "distance": 10.0793, "coffeeShop": { "id": "3", "name": "Starbucks SF", "x": 37.5209, "y": -122.334 } }
    ]
  }
}
```

An invalid/missing `x` or `y` returns a standard GraphQL variable-coercion error under `"errors"`,
not a custom error shape.

#### Other queries

```graphql
{ coffeeShops { id name x y address openUntil } }   # all persisted shops (capped at 500)
{ coffeeShop(id: "1") { name x y } }                 # a single shop by id, or null
```

No mutations exist yet — the API is read-only (write support is a separate future ticket).

### Exploring the API: GraphiQL

In development, `GET /graphiql` serves an interactive GraphQL explorer (schema docs, autocomplete,
a query editor) — the GraphQL-native replacement for the Swagger UI the old REST endpoint had. It's
development-only, not mounted in test or production.

## Architecture

See `CLAUDE.md` for the full internal architecture writeup (import pipeline vs. request-time
pipeline, file-by-file responsibilities, and the conventions new code should follow) — it's the
authoritative, kept-in-sync doc. In short:

- **Import pipeline** (offline, via `bin/rails coffee_shops:import`): `CsvClient` fetches the CSV,
  `CsvParser` parses it, `CoffeeShopImporter` persists new rows into the `coffee_shops` table,
  skipping duplicates.
- **Request-time pipeline** (`POST /graphql` only): `CoffeeShopsApiSchema` resolves queries directly
  against the persisted `CoffeeShop` ActiveRecord model — no CSV fetch happens on the request path.
- **REST was removed, not deprecated.** `Api::V1::CoffeeShopsController`, its JSON:API serializer,
  the CSV-backed repository it used, and the Rswag/OpenAPI docs setup are gone. `CsvClient`/`CsvParser`
  were kept — they're still used by the import task.

### Distance calculation

Distances are planar Euclidean (`Math.hypot`), appropriate for the flat `x`/`y` coordinate space this
app defines — not geographic lat/long. Full floating-point precision is preserved through pairing and
sorting; rounding to four decimal places happens exactly once, at the GraphQL type layer — a
presentation concern, not a computation one, so sort order is never affected by rounding.

## Assumptions and trade-offs

- **No caching:** `nearestCoffeeShops`/`coffeeShops` query the database directly on every request. Postgres
  is already the persistence layer, so this is a normal DB-backed read, not a remote-fetch-per-request
  concern the way the old CSV-backed REST endpoint was.
- **Headerless CSV parsing is intentional**, not a gap: the real remote dataset has no header row.
  Columns are read positionally by the importer.
- **`coffeeShops` is capped at 500 results**, not paginated — the first (and only) "list everything"
  field in the app; a flat cap was the minimal fix for an otherwise-unbounded response, not a
  substitute for real pagination if that's needed later.
- **`Ruby` is pinned to 3.2.1** in `.ruby-version`/`Gemfile` — this is deliberate and load-bearing, not
  stale; make sure your active Ruby matches before assuming an install/CI issue is a code bug.

## Possible future improvements

Not implemented today — natural next steps if this keeps growing:

- **Mutations** (create/update/delete coffee shops) — deliberately out of scope for now.
- **Pagination** on `coffeeShops`, replacing the flat 500-row cap, if the dataset grows large.
- **Rate limiting and/or authentication** on `/graphql`, if this were exposed publicly rather than
  used internally — it currently has neither, matching the rest of the app.
- **Scheduled/automatic imports** instead of the manual `bin/rails coffee_shops:import` step.
