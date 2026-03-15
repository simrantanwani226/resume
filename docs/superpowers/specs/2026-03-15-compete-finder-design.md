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
│   ├── service/
│   │   └── service.go          # ConnectRPC service implementation
│   └── web/
│       ├── handler.go          # HTTP handlers for web UI
│       ├── templates/
│       │   ├── layout.html     # Base layout (head, nav, footer)
│       │   ├── index.html      # Home — search form
│       │   ├── results.html    # Competitor results (htmx partial)
│       │   └── heatmap.html    # Market heatmap (htmx partial)
│       └── static/
│           └── style.css       # Minimal CSS
├── buf.yaml
├── buf.gen.yaml
├── go.mod
├── Dockerfile
├── docker-compose.yml
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
- Stage 1: Sector filter
  - User input is case-insensitive and matched against each startup's `Industries` array
  - Substring matching supported: `"fintech"` matches `"Fintech"`, `"Financial Technology Services"`
  - A startup matches if ANY of its industry tags match
  - If no sector matches found, return empty with a helpful error
- Stage 2: TF-IDF + cosine similarity on descriptions
  - IDF computed once over full YC corpus at load time (and rebuilt on data refresh)
  - User's description tokenized and weighted against the pre-built IDF
  - Cosine similarity between user's TF-IDF vector and each sector-filtered competitor
  - Score 0.0–1.0, sort descending

### 2. Market Heatmap

**Flow:**
1. User runs CLI with a sector name
2. CLI calls `GetMarketHeatmap` RPC
3. Server aggregates YC startup counts per batch for the given sector
4. Computes trend direction (growth/decline) across batches
5. Returns batch-wise breakdown with trend indicators

### 3. Web UI (htmx + Go Templates)

**Minimal, server-rendered UI served from the same Go binary.**

- **Home page:** Form with fields for startup name, description, sector. Submit triggers htmx POST.
- **Results partial:** htmx swaps in a ranked table of competitors with match scores. No full page reload.
- **Heatmap page:** Select a sector, see batch-wise trend table with visual indicators (color-coded UP/DOWN/FLAT).
- **No JS framework, no build step.** Just Go `html/template`, htmx CDN link, and minimal CSS.
- **Same server** serves both the web UI (HTTP) and ConnectRPC API — single port.

### 4. Engineering Defaults

- **Caching:** Redis/Dragonfly with TTL (15 minutes) for computed results
  - Cache key: SHA256 hash of `sector:description:limit` for FindCompetitors
  - Cache key: `heatmap:sector` for GetMarketHeatmap
  - If Redis is unavailable, fail open (serve without cache, log warning)
- **Rate limiting:** Token bucket on inbound RPCs (reserved for future external API providers — YC static JSON needs no limiting)
- **Structured logging:** Go slog with correlation IDs per request
- **Graceful shutdown:** Context cancellation, clean server stop on SIGTERM/SIGINT
- **Background data sync:** Worker goroutine refreshes YC data every 6 hours, uses `sync.RWMutex` for safe concurrent reads

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
  int32 limit = 4; // server treats 0 as default 10, max cap 50
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

# CLI flags for server address (default: localhost:8080)
compete-finder find --server localhost:8080 --name "Razorpay" ...
```

## Domain Model

```go
type Startup struct {
    Name        string
    Description string
    Industries  []string  // mapped from YC "industries" array
    Batch       string    // e.g. "W24", "S23"
    TeamSize    int       // 0 if unknown
    Status      string    // "Active", "Dead", "Acquired"
    URL         string
}
```

## Data Source

**YC Companies API:**
- Endpoint: `https://yc-oss.github.io/api/meta.json`
- Static JSON, no auth, no rate limits
- ~5,000+ startups

**YC API field mapping:**

| YC JSON field | Startup struct field | Notes |
|---|---|---|
| `name` | `Name` | Direct map |
| `one_liner` or `long_description` | `Description` | Use `one_liner`, fall back to `long_description` |
| `industries` | `Industries` | Array of strings, e.g. `["Fintech", "B2B"]` |
| `batch` | `Batch` | e.g. `"W24"` |
| `team_size` | `TeamSize` | May be 0 or missing — treat as unknown |
| `status` | `Status` | `"Active"`, `"Dead"`, `"Acquired"` |
| `website` | `URL` | Company website |

- Loaded into memory on server start
- Background worker refreshes every 6 hours using atomic pointer swap (`sync.RWMutex` on store) to avoid data races with in-flight requests
- TF-IDF index is rebuilt atomically on each refresh

**Provider interface for extensibility:**
```go
type Provider interface {
    Name() string
    Fetch(ctx context.Context) ([]Startup, error)
}
```

Adding GitHub or HN enrichment later means implementing this interface.

## Error Handling

- **YC API fetch fails on startup:** Server starts but logs error, retries on next sync cycle. Serves empty results with a clear error message until data is loaded.
- **YC API fetch fails on refresh:** Keep serving stale data, log warning, retry next cycle.
- **Redis unavailable:** Fail open — skip cache, compute results fresh, log warning.
- **Empty/missing request fields:** Return `connect.CodeInvalidArgument` with descriptive message (e.g., "description is required").
- **No sector matches found:** Return empty `competitors` list with `total_in_sector: 0`. CLI displays "No startups found in sector X. Try a broader term."
- **Limit validation:** If `limit > 50`, cap at 50. If `limit == 0`, default to 10.

## Heatmap Trend Calculation

- **Trend per batch:** Compare startup count to previous batch. UP if >20% increase, DOWN if >20% decrease, FLAT otherwise.
- **Market status thresholds (based on growth over last 4 batches):**
  - HOT: growth_factor >= 2.0x
  - WARM: growth_factor >= 1.3x
  - COLD: growth_factor between 0.7x and 1.3x
  - DECLINING: growth_factor < 0.7x
- **growth_factor:** ratio of latest batch count to the batch 4 cycles ago (2 years).

## Testing Strategy

- **Unit tests:** TF-IDF scoring, sector matching, heatmap trend calculation, cache key generation
- **Integration tests:** RPC layer with an in-memory cache implementation (same interface, no Redis needed)
- **Test data:** Small fixture JSON mimicking YC API shape for deterministic tests
- **No mocks for domain logic:** Test real matching against fixture data

## Design Decisions

- **Monolith over microservices:** Single binary is simpler to build, deploy, and demo. Clean package boundaries provide the same separation without infra overhead.
- **In-memory store over database:** ~5,000 entries fit easily in RAM. No need for PostgreSQL for a dataset this size. Keeps deployment simple.
- **TF-IDF from scratch:** No external ML dependencies. Pure Go implementation shows algorithmic understanding. Simple enough to implement, effective enough to produce good results.
- **Redis/Dragonfly cache:** Avoids re-computing similarity scores for repeated queries. Also demonstrates caching knowledge from resume.
- **ConnectRPC over plain REST:** Protobuf schemas enforce contract-first design. Code generation eliminates boilerplate. Compatible with gRPC clients too.
- **Market heatmap as second feature:** Adds product value beyond basic competitor lookup. Uses the same data source with different aggregation logic — minimal extra complexity.
- **htmx over React/SPA:** Keeps the entire project in Go. Server-rendered HTML with htmx for interactivity — no JS build pipeline, no node_modules. Shows you can build a full product without a frontend framework. Interview talking point.
- **Docker Compose for demo:** One `docker compose up` starts server + Redis. Lowers the barrier for anyone reviewing the project.
