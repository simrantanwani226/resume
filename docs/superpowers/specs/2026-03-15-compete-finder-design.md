# Compete-Finder Design Spec

## Goal

A CLI-powered competitive intelligence tool for startup founders. Enter your startup details, get a ranked list of competitors with match scores. Also provides market heatmap showing sector trends over time.

## Tech Stack

- **Language:** Go
- **API:** ConnectRPC + Protobuf (buf.build toolchain)
- **Data source:** YC Companies API (yc-oss.github.io/api/meta.json)
- **Cache:** Redis/Dragonfly
- **Architecture:** Single Go monolith with clean package separation

## Architecture

```
compete-finder/
├── proto/
│   └── compete/v1/
│       └── compete.proto       # Service definition
├── cmd/
│   ├── server/
│   │   └── main.go             # ConnectRPC server entrypoint
│   └── cli/
│       └── main.go             # CLI client entrypoint
├── internal/
│   ├── provider/
│   │   ├── provider.go         # Provider interface
│   │   └── yc/
│   │       └── yc.go           # YC API provider implementation
│   ├── matcher/
│   │   ├── tfidf.go            # TF-IDF implementation
│   │   └── matcher.go          # Sector filter + similarity scoring
│   ├── store/
│   │   └── store.go            # In-memory startup store + TF-IDF index
│   ├── cache/
│   │   └── cache.go            # Redis/Dragonfly caching layer
│   ├── heatmap/
│   │   └── heatmap.go          # Market heatmap computation
│   └── service/
│       └── service.go          # ConnectRPC service implementation
├── buf.yaml
├── buf.gen.yaml
├── go.mod
└── README.md
```

## Features

### 1. Find Competitors (Core)

**Flow:**
1. User runs CLI with startup name, description, and sector
2. CLI calls `FindCompetitors` RPC via ConnectRPC
3. Server checks cache — if hit, return cached results
4. If miss: filter YC startups by sector, score by description similarity, cache result
5. Return ranked list with match scores

**Matching logic (two-stage):**
- Stage 1: Filter by sector/industry tag (exact match)
- Stage 2: TF-IDF + cosine similarity on descriptions
  - Tokenize descriptions (lowercase, remove stop words)
  - Compute TF-IDF weights
  - Cosine similarity between user's description and each competitor
  - Score 0.0–1.0, sort descending

### 2. Market Heatmap

**Flow:**
1. User runs CLI with a sector name
2. CLI calls `GetMarketHeatmap` RPC
3. Server aggregates YC startup counts per batch for the given sector
4. Computes trend direction (growth/decline) across batches
5. Returns batch-wise breakdown with trend indicators

### 3. Engineering Defaults

- **Caching:** Redis/Dragonfly with TTL for API responses and computed results
- **Rate limiting:** Token bucket on external API calls
- **Structured logging:** Go slog with correlation IDs per request
- **Graceful shutdown:** Context cancellation, clean server stop on SIGTERM/SIGINT
- **Background data sync:** Periodic refresh of YC data using a worker goroutine

## Protobuf API

```protobuf
syntax = "proto3";

package compete.v1;

service CompeteService {
  rpc FindCompetitors(FindCompetitorsRequest) returns (FindCompetitorsResponse);
  rpc GetMarketHeatmap(GetMarketHeatmapRequest) returns (GetMarketHeatmapResponse);
}

message FindCompetitorsRequest {
  string name = 1;
  string description = 2;
  string sector = 3;
  int32 limit = 4; // default 10
}

message FindCompetitorsResponse {
  repeated Competitor competitors = 1;
  int32 total_in_sector = 2;
}

message Competitor {
  string name = 1;
  string description = 2;
  string sector = 3;
  string batch = 4;
  int32 team_size = 5;
  string status = 6;
  string url = 7;
  double match_score = 8;
}

message GetMarketHeatmapRequest {
  string sector = 1;
}

message GetMarketHeatmapResponse {
  repeated BatchTrend batches = 1;
  string market_status = 2; // HOT, WARM, COLD, DECLINING
  double growth_factor = 3; // e.g. 2.7x
}

message BatchTrend {
  string batch = 1;
  int32 startup_count = 2;
  string trend = 3; // UP, DOWN, FLAT
}
```

## CLI Interface

```bash
# Find competitors
compete-finder find \
  --name "Razorpay" \
  --description "Payment gateway for businesses" \
  --sector "fintech" \
  --limit 5

# Market heatmap
compete-finder heatmap --sector "fintech"

# Start server
compete-finder serve --port 8080 --cache-addr localhost:6379
```

## Data Source

**YC Companies API:**
- Endpoint: `https://yc-oss.github.io/api/meta.json`
- Static JSON, no auth, no rate limits
- ~5,000+ startups with: name, description, sector/tags, batch, team size, status, URL
- Loaded into memory on server start
- Background worker refreshes periodically (every 6 hours)

**Provider interface for extensibility:**
```go
type Provider interface {
    Name() string
    Fetch(ctx context.Context) ([]Startup, error)
}
```

Adding GitHub or HN enrichment later means implementing this interface.

## Design Decisions

- **Monolith over microservices:** Single binary is simpler to build, deploy, and demo. Clean package boundaries provide the same separation without infra overhead.
- **In-memory store over database:** ~5,000 entries fit easily in RAM. No need for PostgreSQL for a dataset this size. Keeps deployment simple.
- **TF-IDF from scratch:** No external ML dependencies. Pure Go implementation shows algorithmic understanding. Simple enough to implement, effective enough to produce good results.
- **Redis/Dragonfly cache:** Avoids re-computing similarity scores for repeated queries. Also demonstrates caching knowledge from resume.
- **ConnectRPC over plain REST:** Protobuf schemas enforce contract-first design. Code generation eliminates boilerplate. Compatible with gRPC clients too.
- **Market heatmap as second feature:** Adds product value beyond basic competitor lookup. Uses the same data source with different aggregation logic — minimal extra complexity.
- **No frontend:** CLI-only keeps focus on backend. Can demo with terminal recordings.
