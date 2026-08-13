# coffee_shops_api

Coffee Shops REST API

## Coding Challenge Contract

### Overview

Build a REST API that accepts a user's coordinates and returns the three nearest coffee shops from a remote CSV data source.

### Input

A JSON:API-compliant request with the user's coordinates:

- `X` — horizontal position (e.g. longitude)
- `Y` — vertical position (e.g. latitude)

### Data Source

Coffee shop records are loaded from a remote CSV file with the following columns:

```
Name,X,Y
```

Data quality may vary. Malformed entries (missing fields, non-numeric coordinates, etc.) must be handled gracefully and skipped.

### Output

A JSON:API-compliant response containing the three closest coffee shops, ordered nearest to farthest.

Each result includes:

- `name` — the coffee shop name
- `x` and `y` — its location coordinates
- `distance` — Euclidean distance from the user's coordinates, rounded to four decimal places

### Distance Calculation

Distances are calculated on a plane (Euclidean / straight-line distance). Results are ordered by ascending distance.

### Expected Ordering (reference case)

For `X=47.6`, `Y=-122.4`:

1. Starbucks Seattle2
2. Starbucks Seattle
3. Starbucks SF

### Protocol

All client requests and server responses follow the [JSON:API](https://jsonapi.org) specification.