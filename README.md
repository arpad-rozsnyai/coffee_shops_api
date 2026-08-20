# coffee_shops_api

A Rails 8.1 API-only app built for a coding challenge: given a user's `x`/`y` coordinates, return
the three nearest coffee shops from a remote CSV data source, as a JSON:API response.

## Challenge overview

- Accept a user's coordinates (`x`, `y`).
- Fetch coffee shop records from a remote CSV file (`Name,X,Y`, no header row).
- Return the three closest shops, ordered nearest to farthest, with distance rounded to four
  decimal places.
- Handle malformed data and remote-source failures gracefully.
- All responses follow the [JSON:API](https://jsonapi.org) specification.

Reference case, verified against the live default data source: for `x=47.6, y=-122.4`, the nearest
three are `Starbucks Seattle2`, `Starbucks Seattle`, `Starbucks SF`, in that order.

## Prerequisites

- Ruby **3.2.1** (pinned in `.ruby-version` and `Gemfile`; managed here via [rvm](https://rvm.io))
- Rails **8.1.3.1** (installed via Bundler, not a separate system install)

## Setup

```bash
git clone <this repo>
cd coffee_shops_api
bundle install
```

Or use the generated convenience script, which installs dependencies, prepares the (infrastructure-only)
database, and starts the server in one step:

```bash
bin/setup
```

## Configuration

### `COFFEE_SHOPS_CSV_URL`

The remote CSV data source is configured in one place: `config/initializers/coffee_shops.rb`. It
defaults to the challenge's dataset and can be overridden with an environment variable:

```bash
COFFEE_SHOPS_CSV_URL="https://example.com/my_coffee_shops.csv" bin/dev
```

## Running the server

```bash
bin/dev              # or: bin/rails server
```

Starts Puma on `http://localhost:3000` by default.

## Running tests

```bash
bundle exec rspec                                   # full suite
bundle exec rspec spec/path/to/some_spec.rb          # one file
bundle exec rspec spec/path/to/some_spec.rb:42       # one example, by line
```

RSpec (+ WebMock, which disables all real outbound HTTP in specs) is the real test suite, covering
the CSV client, parser, model, repository, finder, validator, serializer, and full request/response
cycle end to end.

## Linting

```bash
bin/rubocop           # style (rubocop-rails-omakase house style)
```

The repo also ships `bin/brakeman` (static security analysis) and `bin/bundler-audit` (gem
vulnerability audit); `bin/ci` runs all of the above plus the test suite as a single local pipeline.

## API

### `GET /api/v1/coffee_shops`

| Param | Required | Description |
|---|---|---|
| `x` | yes | User's horizontal coordinate (numeric) |
| `y` | yes | User's vertical coordinate (numeric) |

Both are passed as query parameters; the response body is JSON:API-formatted.

#### curl example

```bash
curl "http://localhost:3000/api/v1/coffee_shops?x=47.6&y=-122.4"
```

#### 200 — success

```json
{
  "data": [
    {
      "id": "c7d1b97c3ce95e02490b8a387f648034fc590ffe",
      "type": "coffee_shops",
      "attributes": {
        "name": "Starbucks Seattle2",
        "x": 47.5869,
        "y": -122.3368,
        "distance": 0.0645
      }
    },
    {
      "id": "832338aafeca778f7661e9be891959e731ad634d",
      "type": "coffee_shops",
      "attributes": {
        "name": "Starbucks Seattle",
        "x": 47.5809,
        "y": -122.316,
        "distance": 0.0861
      }
    },
    {
      "id": "5129664a64abec062f0771dd84101a1ec9ef6413",
      "type": "coffee_shops",
      "attributes": {
        "name": "Starbucks SF",
        "x": 37.5209,
        "y": -122.334,
        "distance": 10.0793
      }
    }
  ]
}
```

*(Captured from a live run against the default data source; `id` is a stable hash derived from each
shop's data — see [Architecture](#architecture) below.)*

#### 400 — invalid or missing coordinates

```bash
curl "http://localhost:3000/api/v1/coffee_shops?x=not-a-number"
```

```json
{
  "errors": [
    {
      "status": "400",
      "title": "Invalid Parameter",
      "detail": "is not a valid number",
      "source": { "parameter": "x" }
    },
    {
      "status": "400",
      "title": "Invalid Parameter",
      "detail": "can't be blank",
      "source": { "parameter": "y" }
    }
  ]
}
```

#### 503 — data source unavailable

Returned when the remote CSV can't be fetched (network/timeout/non-2xx) or is structurally
unparseable. The underlying exception is never leaked to the client:

```json
{
  "errors": [
    {
      "status": "503",
      "title": "Data Source Unavailable",
      "detail": "Coffee shop data is temporarily unavailable."
    }
  ]
}
```

## Architecture

There is no database model for coffee shop data — each request runs a small pipeline that fetches
and parses the CSV fresh, then selects and renders the result:

1. **`CoffeeShops.csv_url`** (`config/initializers/coffee_shops.rb`) — single source of truth for the
   CSV URL (default + `COFFEE_SHOPS_CSV_URL` override). Nothing else hardcodes it.
2. **`CsvClient#fetch`** (`app/services/csv_client.rb`) — GETs the URL via stdlib `Net::HTTP`,
   returns the raw body. Converts timeouts, connection failures, and non-2xx responses into
   `CsvClient::RemoteDataSourceError`. No parsing, no caching.
3. **`CsvParser.parse`** (`app/services/csv_parser.rb`) — parses the body with stdlib `CSV`
   (positional columns: `Name, X, Y`, no header row). Skips individually bad rows; raises
   `CsvParser::ParseError` only if the CSV itself is structurally broken.
4. **`CoffeeShop`** (`app/models/coffee_shop.rb`) — plain Ruby value object (`name`, `x`, `y`,
   `#distance_to(x, y)` via `Math.hypot`). This app has no database at all — no ActiveRecord.
5. **`CoffeeShopRepository#all`** (`app/services/coffee_shop_repository.rb`) — wires the client and
   parser together: `parser.parse(client.fetch)`.
6. **`NearestCoffeeShopsFinder#call(x:, y:)`** (`app/services/nearest_coffee_shops_finder.rb`) —
   pairs every shop with its distance, takes the 3 nearest via a partial selection
   (`min_by(MAX_RESULTS)`) on `[distance, name]` (name breaks exact ties deterministically).
7. **`Api::V1::CoffeeShopsController#index`** (`app/controllers/api/v1/coffee_shops_controller.rb`) —
   validates params via `CoordinateValidator`, calls the finder, renders via
   `CoffeeShopDistanceSerializer`. Maps data-source failures to 503; validation failures render 400.
8. **`CoffeeShopDistanceSerializer`** (`app/serializers/coffee_shop_distance_serializer.rb`) — builds
   the JSON:API `data` document. Rounds distance to 4 decimals (the only rounding point) and derives
   a deterministic `id` (SHA1 of `name:x:y`) since CSV rows carry no persisted identity.

### Malformed-row policy

A single bad row (blank name, missing or non-numeric `x`/`y`) is silently skipped so one bad row
doesn't break the whole batch — the rest of the CSV is still processed. A well-formed but empty feed
returns an empty result set; that's not an error.

### Structural CSV failure policy

If the CSV itself can't be parsed at all (e.g. an unterminated quoted field), `CsvParser` raises
`CsvParser::ParseError`, which the controller maps to a `503` — this is a data-source-level failure,
not a per-row one, and not something the client can fix by retrying with different input.

### Network failure policy

Connection failures, timeouts, and non-2xx HTTP responses from the CSV source all raise
`CsvClient::RemoteDataSourceError`, also mapped to `503`. The original exception message/class is
never included in the response body (verified in `spec/requests/api/v1/coffee_shops_spec.rb`).

### Distance calculation

Distances are planar Euclidean (`Math.hypot`), appropriate for the flat `x`/`y` coordinate space the
challenge defines — not geographic lat/long. Full floating-point precision is preserved through
pairing and sorting; rounding to four decimal places happens exactly once, at serialization — it's a
presentation concern, not a computation one, so sort order is never affected by rounding.

## Why no database

The CSV is the authoritative, externally-owned source of truth, fetched fresh on every request —
there's nothing for this app to persist an independent copy of, and no requirement to serve data the
source no longer has. Rails 8 defaults to SQLite-backed ActiveRecord, Solid Queue/Cache/Cable, and
Active Storage's `image_processing`/Thruster out of the box, but none of them are used by this app,
so they (and `db/`, `config/database.yml`, `config/cable.yml`) have been removed rather than carried
as dead weight.

## Why no geospatial gem

The coordinates are plain Cartesian `x`/`y`, not real-world latitude/longitude — there's no
great-circle/geodesic math to do, so a geospatial library (e.g. Geocoder) would solve a problem this
challenge doesn't have. Stdlib `Math.hypot` is exactly the right amount of tool for planar distance.

## Assumptions and trade-offs

- **No caching, by design (for now):** every request re-fetches and re-parses the CSV from scratch.
  This is the simplest behavior that's still correct — no staleness to reason about, no cache
  invalidation logic needed. The trade-off is that every request pays full network + parse latency,
  and a slow/unavailable source is felt on every request rather than being masked by a cache. See
  [Production improvements](#possible-production-improvements) below.
- **Headerless CSV parsing is intentional**, not a gap: the real remote dataset has no header row,
  confirmed by fetching the live source directly. Columns are read positionally.
- **Coordinates travel as GET query parameters**, not a JSON request body — this is a read operation
  with no side effects, so a query string is the natural fit; the *response* is what's JSON:API-shaped.
- **Synthesized `id`s:** since CSV rows have no persisted identity, `id` is a SHA1 hash of the row's
  own data (`name:x:y`). This keeps the same shop's `id` stable across different requests/queries,
  rather than tying it to its rank in any one response.
- **Ruby is pinned to 3.2.1** in `.ruby-version`/`Gemfile` — this is deliberate and load-bearing, not
  stale; make sure your active Ruby matches before assuming a install/CI issue is a code bug.

## Possible production improvements

Not implemented today — noted here as the natural next steps if this moved beyond a take-home:

- **Optional last-known-good caching:** wrap `CoffeeShopRepository#all` in something like
  `Rails.cache.fetch` with a short TTL, falling back to the last successfully-fetched CSV if a fresh
  fetch fails, instead of returning `503` immediately. Would trade a small staleness window for much
  better resilience against a flaky upstream source.
- **Retry/backoff** around `CsvClient#fetch` for transient network failures.
- **Rate limiting and/or authentication**, if this were exposed publicly rather than as a take-home
  endpoint.
- **Structured request logging/observability** around fetch latency and remote-source failure rates.

## API Documentation

`GET /api/v1/coffee_shops` is documented as an OpenAPI 3.0 spec via [rswag](https://github.com/rswag/rswag),
generated from the request specs in `spec/requests/api/v1/coffee_shops_swagger_spec.rb` so the docs can't
drift from what the endpoint actually does.

### Viewing the docs

```bash
bin/dev   # or `bin/rails server`
```

Then open **http://localhost:3000/api-docs** for the Swagger UI, or fetch the raw spec at
`http://localhost:3000/api-docs/v1/swagger.yaml`.

### Regenerating the docs

The rendered spec is checked in at `swagger/v1/swagger.yaml`. After changing the endpoint's behavior,
request/response shape, or the swagger spec itself, regenerate it with:

```bash
bin/rails rswag:specs:swaggerize
```
