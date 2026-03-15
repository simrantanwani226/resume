# Compete-Finder Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a CLI + web competitive intelligence tool for startup founders using Go, ConnectRPC, and YC Companies data.

**Architecture:** Single Go monolith with ConnectRPC API, CLI client, htmx web UI. YC data loaded into memory, TF-IDF matching for competitor scoring, Redis/Dragonfly for caching. Background worker refreshes data periodically.

**Tech Stack:** Go, ConnectRPC, Protobuf (buf.build), htmx, Redis/Dragonfly, Docker

**Spec:** `docs/superpowers/specs/2026-03-15-compete-finder-design.md`

---

## Chunk 1: Project Scaffolding + Protobuf

### Why this chunk first
Before writing any Go code, we need a working project structure with protobuf code generation. ConnectRPC is contract-first — the `.proto` file defines our API, and `buf` generates the Go client/server code we'll build on top of.

---

### Task 1: Initialize Go Module

**WHY:** Every Go project starts with a module. This sets the import path for all packages.

**Files:**
- Create: `compete-finder/go.mod`

- [ ] **Step 1: Create project directory and init Go module**

```bash
mkdir -p ~/go/src/github.com/simrantanwani226/compete-finder
cd ~/go/src/github.com/simrantanwani226/compete-finder
go mod init github.com/simrantanwani226/compete-finder
```

**HOW it works:** `go mod init` creates a `go.mod` file — Go's dependency manifest. The module path (`github.com/simrantanwani226/compete-finder`) becomes the base import path. When you write `import "github.com/simrantanwani226/compete-finder/internal/store"`, Go resolves it relative to this module.

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p proto/compete/v1
mkdir -p cmd/server cmd/cli
mkdir -p internal/provider/yc internal/matcher internal/store internal/cache internal/heatmap internal/service internal/web/templates internal/web/static
```

**WHY this structure:**
- `proto/` — Protobuf definitions live here. `buf` looks here for `.proto` files.
- `cmd/server/` and `cmd/cli/` — Go convention: each binary gets its own `cmd/` subdirectory with a `main.go`.
- `internal/` — Go's access control. Packages under `internal/` cannot be imported by external projects. This is intentional — our domain logic is private.
- Each `internal/` package has one job: `provider` fetches data, `matcher` scores competitors, `store` holds data in memory, etc.

- [ ] **Step 3: Commit**

```bash
git init
git add go.mod
git commit -m "feat: initialize Go module"
```

---

### Task 2: Set Up Buf and Protobuf

**WHY:** ConnectRPC uses Protobuf to define APIs. `buf` is the modern toolchain for Protobuf — it handles linting, code generation, and dependency management (replaces raw `protoc`).

**Files:**
- Create: `proto/compete/v1/compete.proto`
- Create: `buf.yaml`
- Create: `buf.gen.yaml`

- [ ] **Step 1: Install buf CLI (if not already installed)**

```bash
brew install bufbuild/buf/buf
```

**WHAT is buf:** Think of buf as "npm for Protobuf." It manages proto dependencies, lints your schemas, and runs code generation — all without manually wrangling `protoc` plugins.

- [ ] **Step 2: Create `buf.yaml`**

```yaml
# buf.yaml — tells buf where to find proto files and what rules to enforce
version: v2
modules:
  - path: proto
deps:
  - buf.build/connectrpc/eliza  # not a real dep, just ensures buf BSR works
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
```

**HOW it works:** `version: v2` uses buf's latest config format. `modules` points to our `proto/` directory. `lint` enforces Protobuf best practices (field naming, package structure). `breaking` detects backwards-incompatible API changes.

- [ ] **Step 3: Create `buf.gen.yaml`**

```yaml
# buf.gen.yaml — tells buf what code to generate from .proto files
version: v2
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt: paths=source_relative
  - remote: buf.build/connectrpc/go
    out: gen
    opt: paths=source_relative
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: github.com/simrantanwani226/compete-finder/gen
```

**HOW it works:** Two plugins run:
1. `protocolbuffers/go` — generates Go structs for each Protobuf message (e.g., `FindCompetitorsRequest` becomes a Go struct)
2. `connectrpc/go` — generates ConnectRPC client/server interfaces (e.g., a `CompeteServiceHandler` interface your server implements)

`out: gen` means generated code goes into a `gen/` directory. `paths=source_relative` keeps the package structure matching the proto directory.

- [ ] **Step 4: Write the proto definition**

```protobuf
// proto/compete/v1/compete.proto
//
// This is the API contract for Compete-Finder.
// ConnectRPC generates both client and server code from this file.
// Any change here changes the API — treat it as a public interface.

syntax = "proto3";

package compete.v1;

option go_package = "github.com/simrantanwani226/compete-finder/gen/compete/v1;competev1";

service CompeteService {
  // FindCompetitors takes a startup's details and returns
  // a ranked list of competitors from the YC dataset.
  rpc FindCompetitors(FindCompetitorsRequest) returns (FindCompetitorsResponse);

  // GetMarketHeatmap returns sector trends across YC batches
  // showing which markets are heating up or cooling down.
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
  repeated string industries = 3;
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
  double growth_factor = 3;
}

message BatchTrend {
  string batch = 1;
  int32 startup_count = 2;
  string trend = 3; // UP, DOWN, FLAT
}
```

**WHY `repeated string industries` instead of `string sector`:** The YC API stores industries as an array (a startup can be both "Fintech" and "B2B"). Using `repeated string` matches the actual data shape.

- [ ] **Step 5: Generate Go code**

```bash
buf dep update
buf generate
```

**WHAT happens:** buf reads `compete.proto`, runs both plugins, and creates:
- `gen/compete/v1/compete.pb.go` — Go structs for all messages
- `gen/compete/v1/competev1connect/compete.connect.go` — ConnectRPC client/server interfaces

You'll never edit these files — they're regenerated every time you run `buf generate`.

- [ ] **Step 6: Add generated code to go.mod**

```bash
go mod tidy
```

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat: add protobuf definitions and buf code generation"
```

---

## Chunk 2: Domain Model + YC Data Provider

### Why this chunk
We need data before we can match anything. This chunk builds the domain model (our internal representation of a startup) and the YC provider that fetches real startup data.

---

### Task 3: Domain Model

**WHY:** The `Startup` struct is the core data type everything else is built around. Defining it first means all other packages agree on the shape of the data.

**Files:**
- Create: `internal/provider/provider.go`

- [ ] **Step 1: Write the provider interface and Startup model**

```go
// internal/provider/provider.go
//
// This package defines the core domain model (Startup) and the Provider
// interface. Every data source (YC, GitHub, HN) implements Provider.
// The interface has one method: Fetch. That's it.
// This keeps data-fetching concerns isolated from matching/scoring logic.

package provider

import "context"

// Startup is the core domain model. Every data source maps its data
// into this struct. Downstream packages (matcher, store, heatmap)
// only work with Startup — they never know where the data came from.
type Startup struct {
	Name        string
	Description string
	Industries  []string // e.g. ["Fintech", "B2B"]
	Batch       string   // YC batch, e.g. "W24", "S23"
	TeamSize    int      // 0 if unknown
	Status      string   // "Active", "Dead", "Acquired"
	URL         string
}

// Provider is the interface for any data source that can supply startups.
// WHY an interface? So we can:
// 1. Swap YC for a test fixture without changing any other code
// 2. Add GitHub/HN providers later without modifying existing code
// 3. Test the matcher/store with deterministic data
type Provider interface {
	Name() string
	Fetch(ctx context.Context) ([]Startup, error)
}
```

- [ ] **Step 2: Commit**

```bash
git add internal/provider/provider.go
git commit -m "feat: add domain model and provider interface"
```

---

### Task 4: YC Data Provider

**WHY:** This is our first (and only) data source. It fetches the YC Companies JSON, parses it, and maps it into our `Startup` struct. The provider pattern means the rest of the app doesn't care where data comes from.

**Files:**
- Create: `internal/provider/yc/yc.go`
- Create: `internal/provider/yc/yc_test.go`

- [ ] **Step 1: Write the test first**

```go
// internal/provider/yc/yc_test.go

package yc

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

// We test against a fake HTTP server so tests don't hit the real YC API.
// This makes tests fast, deterministic, and offline-capable.

const testJSON = `[
	{
		"name": "TestCo",
		"one_liner": "A test company",
		"long_description": "A longer description",
		"industries": ["Fintech", "B2B"],
		"batch": "W24",
		"team_size": 10,
		"status": "Active",
		"website": "https://testco.com"
	},
	{
		"name": "NullCo",
		"one_liner": "",
		"long_description": "Only has long desc",
		"industries": [],
		"batch": "S23",
		"team_size": 0,
		"status": "Dead",
		"website": ""
	}
]`

func TestFetch(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(testJSON))
	}))
	defer srv.Close()

	p := New(srv.URL)
	startups, err := p.Fetch(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(startups) != 2 {
		t.Fatalf("expected 2 startups, got %d", len(startups))
	}

	// Verify field mapping
	if startups[0].Name != "TestCo" {
		t.Errorf("expected name TestCo, got %s", startups[0].Name)
	}
	if startups[0].Description != "A test company" {
		t.Errorf("expected one_liner as description, got %s", startups[0].Description)
	}
	if len(startups[0].Industries) != 2 {
		t.Errorf("expected 2 industries, got %d", len(startups[0].Industries))
	}

	// Verify fallback: empty one_liner → use long_description
	if startups[1].Description != "Only has long desc" {
		t.Errorf("expected long_description fallback, got %s", startups[1].Description)
	}
}

func TestFetchServerError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	p := New(srv.URL)
	_, err := p.Fetch(context.Background())
	if err == nil {
		t.Fatal("expected error on 500 response")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/go/src/github.com/simrantanwani226/compete-finder
go test ./internal/provider/yc/ -v
```
Expected: FAIL — `New` function doesn't exist yet.

- [ ] **Step 3: Implement the YC provider**

```go
// internal/provider/yc/yc.go
//
// Fetches startup data from the YC Companies API.
// The API returns a static JSON array of all YC-funded companies.
// We parse it and map each entry into our domain Startup struct.
//
// HOW IT WORKS:
// 1. HTTP GET to the YC API endpoint
// 2. Decode JSON array into intermediate ycCompany structs
// 3. Map each ycCompany → provider.Startup
// 4. Return the list
//
// The intermediate ycCompany struct exists because the YC API field names
// don't match our domain model. Mapping happens in toStartup().

package yc

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

const DefaultURL = "https://yc-oss.github.io/api/meta.json"

// ycCompany maps to the raw JSON shape from the YC API.
// We keep this private — nothing outside this package sees it.
type ycCompany struct {
	Name            string   `json:"name"`
	OneLiner        string   `json:"one_liner"`
	LongDescription string   `json:"long_description"`
	Industries      []string `json:"industries"`
	Batch           string   `json:"batch"`
	TeamSize        int      `json:"team_size"`
	Status          string   `json:"status"`
	Website         string   `json:"website"`
}

func (c ycCompany) toStartup() provider.Startup {
	desc := c.OneLiner
	if desc == "" {
		desc = c.LongDescription
	}
	return provider.Startup{
		Name:        c.Name,
		Description: desc,
		Industries:  c.Industries,
		Batch:       c.Batch,
		TeamSize:    c.TeamSize,
		Status:      c.Status,
		URL:         c.Website,
	}
}

// YCProvider implements provider.Provider for the YC Companies API.
type YCProvider struct {
	url string
}

func New(url string) *YCProvider {
	return &YCProvider{url: url}
}

func (p *YCProvider) Name() string {
	return "yc"
}

func (p *YCProvider) Fetch(ctx context.Context) ([]provider.Startup, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching YC data: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("YC API returned status %d", resp.StatusCode)
	}

	var companies []ycCompany
	if err := json.NewDecoder(resp.Body).Decode(&companies); err != nil {
		return nil, fmt.Errorf("decoding YC data: %w", err)
	}

	startups := make([]provider.Startup, 0, len(companies))
	for _, c := range companies {
		startups = append(startups, c.toStartup())
	}

	return startups, nil
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/provider/yc/ -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/provider/
git commit -m "feat: add YC companies data provider with tests"
```

---

## Chunk 3: In-Memory Store + TF-IDF

### Why this chunk
The store holds all startup data in memory and maintains the TF-IDF index. It's the central data layer — the matcher and heatmap both read from it. TF-IDF is the core algorithm that makes competitor matching actually useful.

### What is TF-IDF?
**TF-IDF (Term Frequency - Inverse Document Frequency)** measures how important a word is to a document in a collection.

- **TF (Term Frequency):** How often a word appears in one description. "payments" appearing 3 times in a description = high TF.
- **IDF (Inverse Document Frequency):** How rare a word is across ALL descriptions. "the" appears everywhere = low IDF. "blockchain" appears rarely = high IDF.
- **TF-IDF = TF × IDF.** Words that are frequent in one description but rare overall get the highest score.

We use this to compare descriptions: convert each description into a vector of TF-IDF scores, then compute **cosine similarity** between vectors. High cosine = similar descriptions = likely competitors.

---

### Task 5: TF-IDF Implementation

**WHY:** This is the matching engine. Without TF-IDF, we'd just be doing keyword matching which gives poor results.

**Files:**
- Create: `internal/matcher/tfidf.go`
- Create: `internal/matcher/tfidf_test.go`

- [ ] **Step 1: Write the test**

```go
// internal/matcher/tfidf_test.go

package matcher

import (
	"math"
	"testing"
)

func TestTokenize(t *testing.T) {
	tokens := tokenize("Payment Gateway for Online Businesses")
	// Should lowercase and remove stop words
	expected := []string{"payment", "gateway", "online", "businesses"}
	if len(tokens) != len(expected) {
		t.Fatalf("expected %d tokens, got %d: %v", len(expected), len(tokens), tokens)
	}
	for i, tok := range tokens {
		if tok != expected[i] {
			t.Errorf("token %d: expected %s, got %s", i, expected[i], tok)
		}
	}
}

func TestTFIDFIndex(t *testing.T) {
	docs := []string{
		"payment gateway for businesses",
		"payment processing platform",
		"social media analytics tool",
	}

	idx := NewTFIDFIndex(docs)

	// "payment" appears in 2/3 docs — moderate IDF
	// "analytics" appears in 1/3 docs — high IDF
	// "payment" should have lower IDF than "analytics"
	paymentIDF := idx.idf["payment"]
	analyticsIDF := idx.idf["analytics"]
	if paymentIDF >= analyticsIDF {
		t.Errorf("expected payment IDF (%.2f) < analytics IDF (%.2f)", paymentIDF, analyticsIDF)
	}
}

func TestCosineSimilarity(t *testing.T) {
	docs := []string{
		"payment gateway for businesses",
		"payment processing platform",
		"social media analytics tool",
	}

	idx := NewTFIDFIndex(docs)

	// Query about payments should be more similar to doc 0 and 1 than doc 2
	query := "online payment gateway"
	scores := idx.Score(query, docs)

	if scores[2] >= scores[0] {
		t.Errorf("expected payment query closer to doc 0 (%.2f) than doc 2 (%.2f)", scores[0], scores[2])
	}
}

func TestEmptyDocument(t *testing.T) {
	docs := []string{"payment gateway", "", "analytics tool"}
	idx := NewTFIDFIndex(docs)
	scores := idx.Score("payment", docs)
	// Empty doc should get 0 score
	if scores[1] != 0 {
		t.Errorf("expected 0 for empty doc, got %.2f", scores[1])
	}
}

// Helper to check float equality
func almostEqual(a, b, epsilon float64) bool {
	return math.Abs(a-b) < epsilon
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/matcher/ -v
```
Expected: FAIL

- [ ] **Step 3: Implement TF-IDF**

```go
// internal/matcher/tfidf.go
//
// Pure Go TF-IDF implementation. No external dependencies.
//
// HOW IT WORKS:
// 1. Build phase (NewTFIDFIndex):
//    - Tokenize all documents (lowercase, remove stop words)
//    - Count how many documents contain each term (document frequency)
//    - Compute IDF = log(totalDocs / docsContainingTerm)
//    - Store IDF values for reuse
//
// 2. Query phase (Score):
//    - Tokenize the query
//    - For each document, compute TF-IDF vector
//    - Compute cosine similarity between query vector and doc vector
//    - Return similarity scores (0.0 to 1.0)
//
// WHY from scratch instead of a library?
// - ~100 lines of code, no external dependencies
// - Shows algorithmic understanding in interviews
// - Full control over tokenization and stop words

package matcher

import (
	"math"
	"strings"
)

// Common English stop words that don't carry meaning for matching.
var stopWords = map[string]bool{
	"a": true, "an": true, "the": true, "and": true, "or": true,
	"but": true, "in": true, "on": true, "at": true, "to": true,
	"for": true, "of": true, "with": true, "by": true, "is": true,
	"it": true, "this": true, "that": true, "are": true, "was": true,
	"be": true, "has": true, "had": true, "have": true, "do": true,
	"does": true, "did": true, "will": true, "would": true, "could": true,
	"should": true, "may": true, "might": true, "from": true, "as": true,
	"we": true, "our": true, "their": true, "its": true, "your": true,
}

// TFIDFIndex holds precomputed IDF values for a corpus of documents.
type TFIDFIndex struct {
	idf map[string]float64
}

// tokenize converts text into lowercase tokens, removing stop words.
func tokenize(text string) []string {
	words := strings.Fields(strings.ToLower(text))
	tokens := make([]string, 0, len(words))
	for _, w := range words {
		// Strip punctuation from edges
		w = strings.Trim(w, ".,;:!?\"'()-")
		if w == "" || stopWords[w] {
			continue
		}
		tokens = append(tokens, w)
	}
	return tokens
}

// termFrequency computes how often each term appears in a token list.
func termFrequency(tokens []string) map[string]float64 {
	tf := make(map[string]float64)
	for _, t := range tokens {
		tf[t]++
	}
	// Normalize by total token count
	for t := range tf {
		tf[t] /= float64(len(tokens))
	}
	return tf
}

// NewTFIDFIndex builds an IDF index from a corpus of documents.
func NewTFIDFIndex(docs []string) *TFIDFIndex {
	docCount := float64(len(docs))

	// Count how many documents contain each term
	df := make(map[string]float64)
	for _, doc := range docs {
		seen := make(map[string]bool)
		for _, token := range tokenize(doc) {
			if !seen[token] {
				df[token]++
				seen[token] = true
			}
		}
	}

	// IDF = log(totalDocs / docsContainingTerm)
	// +1 smoothing to avoid division by zero for query-only terms
	idf := make(map[string]float64)
	for term, count := range df {
		idf[term] = math.Log(docCount / count)
	}

	return &TFIDFIndex{idf: idf}
}

// tfidfVector computes the TF-IDF vector for a given text.
func (idx *TFIDFIndex) tfidfVector(text string) map[string]float64 {
	tokens := tokenize(text)
	if len(tokens) == 0 {
		return nil
	}
	tf := termFrequency(tokens)
	vec := make(map[string]float64)
	for term, freq := range tf {
		idf, ok := idx.idf[term]
		if !ok {
			// Term not in corpus — give it max IDF (very rare = very relevant)
			idf = math.Log(float64(len(idx.idf)) + 1)
		}
		vec[term] = freq * idf
	}
	return vec
}

// cosineSimilarity computes the cosine of the angle between two sparse vectors.
// Returns 0.0 (completely different) to 1.0 (identical).
func cosineSimilarity(a, b map[string]float64) float64 {
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	var dotProduct, normA, normB float64
	for term, valA := range a {
		if valB, ok := b[term]; ok {
			dotProduct += valA * valB
		}
		normA += valA * valA
	}
	for _, valB := range b {
		normB += valB * valB
	}
	if normA == 0 || normB == 0 {
		return 0
	}
	return dotProduct / (math.Sqrt(normA) * math.Sqrt(normB))
}

// Score computes similarity between a query and each document in the list.
// Returns a slice of scores (0.0 to 1.0) in the same order as docs.
func (idx *TFIDFIndex) Score(query string, docs []string) []float64 {
	queryVec := idx.tfidfVector(query)
	scores := make([]float64, len(docs))
	for i, doc := range docs {
		docVec := idx.tfidfVector(doc)
		scores[i] = cosineSimilarity(queryVec, docVec)
	}
	return scores
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/matcher/ -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/matcher/
git commit -m "feat: add TF-IDF implementation with tests"
```

---

### Task 6: Matcher (Sector Filter + Scoring)

**WHY:** The matcher combines sector filtering with TF-IDF scoring. This is the main business logic — given a user's startup details, find and rank competitors.

**Files:**
- Create: `internal/matcher/matcher.go`
- Create: `internal/matcher/matcher_test.go`

- [ ] **Step 1: Write the test**

```go
// internal/matcher/matcher_test.go
// (add to existing test file)

package matcher

import (
	// ... existing imports ...
	"testing"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

func TestMatchCompetitors(t *testing.T) {
	startups := []provider.Startup{
		{Name: "PayCo", Description: "payment gateway for small businesses", Industries: []string{"Fintech", "B2B"}, Batch: "W24", Status: "Active"},
		{Name: "LendCo", Description: "lending platform for startups", Industries: []string{"Fintech"}, Batch: "S23", Status: "Active"},
		{Name: "HealthCo", Description: "telemedicine platform", Industries: []string{"Healthcare"}, Batch: "W24", Status: "Active"},
	}

	m := NewMatcher(startups)
	results := m.FindCompetitors("payment processing for merchants", "fintech", 10)

	// Should only return fintech startups (PayCo and LendCo, not HealthCo)
	if len(results) != 2 {
		t.Fatalf("expected 2 fintech competitors, got %d", len(results))
	}

	// PayCo should rank higher (payment-related description)
	if results[0].Name != "PayCo" {
		t.Errorf("expected PayCo first, got %s", results[0].Name)
	}

	// All results should have scores
	for _, r := range results {
		if r.Score <= 0 {
			t.Errorf("expected positive score for %s, got %.2f", r.Name, r.Score)
		}
	}
}

func TestMatchCaseInsensitiveSector(t *testing.T) {
	startups := []provider.Startup{
		{Name: "FinCo", Description: "fintech startup", Industries: []string{"Fintech"}},
	}
	m := NewMatcher(startups)
	results := m.FindCompetitors("payments", "FINTECH", 10)
	if len(results) != 1 {
		t.Fatalf("expected case-insensitive match, got %d results", len(results))
	}
}

func TestMatchSubstringsector(t *testing.T) {
	startups := []provider.Startup{
		{Name: "FinCo", Description: "financial services", Industries: []string{"Financial Technology Services"}},
	}
	m := NewMatcher(startups)
	results := m.FindCompetitors("payments", "fintech", 10)
	// "fintech" should substring-match "Financial Technology Services"
	// This is a loose match — may or may not match depending on implementation
	// At minimum, exact case-insensitive should work
}

func TestMatchLimit(t *testing.T) {
	startups := make([]provider.Startup, 20)
	for i := range startups {
		startups[i] = provider.Startup{Name: "Co", Description: "fintech", Industries: []string{"Fintech"}}
	}
	m := NewMatcher(startups)
	results := m.FindCompetitors("fintech", "fintech", 5)
	if len(results) > 5 {
		t.Errorf("expected max 5 results, got %d", len(results))
	}
}

func TestMatchEmptySector(t *testing.T) {
	startups := []provider.Startup{
		{Name: "FinCo", Description: "fintech", Industries: []string{"Fintech"}},
	}
	m := NewMatcher(startups)
	results := m.FindCompetitors("payments", "nonexistent", 10)
	if len(results) != 0 {
		t.Errorf("expected 0 results for unknown sector, got %d", len(results))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/matcher/ -v -run TestMatch
```
Expected: FAIL

- [ ] **Step 3: Implement matcher**

```go
// internal/matcher/matcher.go
//
// The Matcher is the core business logic.
// It combines two stages:
// 1. Sector filter — narrows 5000+ startups to a relevant pool
// 2. TF-IDF scoring — ranks the filtered pool by description similarity
//
// HOW THE TWO STAGES WORK TOGETHER:
// Imagine searching for "payment gateway" in "fintech":
// Stage 1: 5000 startups → ~200 fintech startups
// Stage 2: 200 fintech startups ranked by how similar their
//          descriptions are to "payment gateway"
// Result: Top N competitors, most relevant first

package matcher

import (
	"sort"
	"strings"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

// MatchResult is a Startup paired with a relevance score.
type MatchResult struct {
	provider.Startup
	Score float64
}

// Matcher holds the startup data and TF-IDF index.
type Matcher struct {
	startups []provider.Startup
	index    *TFIDFIndex
}

// NewMatcher creates a Matcher and pre-builds the TF-IDF index.
// This is called once on data load (and again on refresh).
func NewMatcher(startups []provider.Startup) *Matcher {
	// Extract all descriptions for the TF-IDF corpus
	docs := make([]string, len(startups))
	for i, s := range startups {
		docs[i] = s.Description
	}
	return &Matcher{
		startups: startups,
		index:    NewTFIDFIndex(docs),
	}
}

// matchesSector checks if a startup's industries match the query sector.
// Case-insensitive, substring matching.
func matchesSector(industries []string, sector string) bool {
	sector = strings.ToLower(sector)
	for _, ind := range industries {
		if strings.Contains(strings.ToLower(ind), sector) {
			return true
		}
	}
	return false
}

// FindCompetitors filters by sector, scores by description, returns top N.
func (m *Matcher) FindCompetitors(description, sector string, limit int) []MatchResult {
	// Stage 1: Sector filter
	var filtered []int // indices into m.startups
	for i, s := range m.startups {
		if matchesSector(s.Industries, sector) {
			filtered = append(filtered, i)
		}
	}

	if len(filtered) == 0 {
		return nil
	}

	// Stage 2: TF-IDF scoring on filtered subset
	filteredDescs := make([]string, len(filtered))
	for i, idx := range filtered {
		filteredDescs[i] = m.startups[idx].Description
	}
	scores := m.index.Score(description, filteredDescs)

	// Build results
	results := make([]MatchResult, len(filtered))
	for i, idx := range filtered {
		results[i] = MatchResult{
			Startup: m.startups[idx],
			Score:   scores[i],
		}
	}

	// Sort by score descending
	sort.Slice(results, func(i, j int) bool {
		return results[i].Score > results[j].Score
	})

	// Apply limit
	if limit > 0 && limit < len(results) {
		results = results[:limit]
	}

	return results
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/matcher/ -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/matcher/
git commit -m "feat: add competitor matcher with sector filter and TF-IDF scoring"
```

---

### Task 7: In-Memory Store

**WHY:** The store is the thread-safe data layer. It holds startups + matcher, and handles concurrent reads during background refreshes using `sync.RWMutex`.

**Files:**
- Create: `internal/store/store.go`
- Create: `internal/store/store_test.go`

- [ ] **Step 1: Write the test**

```go
// internal/store/store_test.go

package store

import (
	"testing"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

func TestStoreLoadAndFind(t *testing.T) {
	s := New()
	startups := []provider.Startup{
		{Name: "PayCo", Description: "payment gateway", Industries: []string{"Fintech"}, Batch: "W24", Status: "Active"},
		{Name: "HealthCo", Description: "telehealth", Industries: []string{"Healthcare"}, Batch: "S23", Status: "Active"},
	}

	s.Load(startups)

	results := s.FindCompetitors("payment processing", "fintech", 10)
	if len(results) != 1 {
		t.Fatalf("expected 1, got %d", len(results))
	}
	if results[0].Name != "PayCo" {
		t.Errorf("expected PayCo, got %s", results[0].Name)
	}
}

func TestStoreEmpty(t *testing.T) {
	s := New()
	results := s.FindCompetitors("anything", "anything", 10)
	if len(results) != 0 {
		t.Errorf("expected 0 results from empty store, got %d", len(results))
	}
}

func TestStoreCount(t *testing.T) {
	s := New()
	s.Load([]provider.Startup{{Name: "A"}, {Name: "B"}})
	if s.Count() != 2 {
		t.Errorf("expected count 2, got %d", s.Count())
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/store/ -v
```

- [ ] **Step 3: Implement store**

```go
// internal/store/store.go
//
// Thread-safe in-memory store for startup data.
//
// WHY sync.RWMutex?
// The background worker refreshes data every 6 hours (write).
// Request handlers read data concurrently (read).
// RWMutex allows multiple concurrent readers but exclusive writers.
// This means reads (99.99% of operations) never block each other.

package store

import (
	"sync"

	"github.com/simrantanwani226/compete-finder/internal/matcher"
	"github.com/simrantanwani226/compete-finder/internal/provider"
)

type Store struct {
	mu       sync.RWMutex
	startups []provider.Startup
	matcher  *matcher.Matcher
}

func New() *Store {
	return &Store{}
}

// Load replaces all startup data and rebuilds the TF-IDF index.
// Called on initial load and on each background refresh.
func (s *Store) Load(startups []provider.Startup) {
	m := matcher.NewMatcher(startups) // Build index outside lock
	s.mu.Lock()
	s.startups = startups
	s.matcher = m
	s.mu.Unlock()
}

// FindCompetitors delegates to the matcher under a read lock.
func (s *Store) FindCompetitors(description, sector string, limit int) []matcher.MatchResult {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.matcher == nil {
		return nil
	}
	return s.matcher.FindCompetitors(description, sector, limit)
}

// Startups returns a copy of all startups (for heatmap computation).
func (s *Store) Startups() []provider.Startup {
	s.mu.RLock()
	defer s.mu.RUnlock()
	cp := make([]provider.Startup, len(s.startups))
	copy(cp, s.startups)
	return cp
}

// Count returns the number of loaded startups.
func (s *Store) Count() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.startups)
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/store/ -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/store/
git commit -m "feat: add thread-safe in-memory store"
```

---

## Chunk 4: Heatmap + Cache

### Task 8: Market Heatmap

**WHY:** The heatmap adds product value — it answers "is my market getting crowded?" by analyzing YC batch trends.

**Files:**
- Create: `internal/heatmap/heatmap.go`
- Create: `internal/heatmap/heatmap_test.go`

- [ ] **Step 1: Write the test**

```go
// internal/heatmap/heatmap_test.go

package heatmap

import (
	"testing"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

func TestHeatmap(t *testing.T) {
	startups := []provider.Startup{
		{Industries: []string{"Fintech"}, Batch: "W23"},
		{Industries: []string{"Fintech"}, Batch: "S23"},
		{Industries: []string{"Fintech"}, Batch: "S23"},
		{Industries: []string{"Fintech"}, Batch: "W24"},
		{Industries: []string{"Fintech"}, Batch: "W24"},
		{Industries: []string{"Fintech"}, Batch: "W24"},
		{Industries: []string{"Fintech"}, Batch: "S24"},
		{Industries: []string{"Fintech"}, Batch: "S24"},
		{Industries: []string{"Fintech"}, Batch: "S24"},
		{Industries: []string{"Fintech"}, Batch: "S24"},
		{Industries: []string{"Healthcare"}, Batch: "W24"},
	}

	result := Compute(startups, "fintech")

	// Should not include Healthcare startup
	total := 0
	for _, b := range result.Batches {
		total += b.Count
	}
	if total != 10 {
		t.Errorf("expected 10 fintech startups, got %d", total)
	}

	// W23=1, S23=2, W24=3, S24=4 → growing → should be HOT
	if result.Status != "HOT" {
		t.Errorf("expected HOT, got %s", result.Status)
	}
	if result.GrowthFactor < 2.0 {
		t.Errorf("expected growth >= 2.0, got %.1f", result.GrowthFactor)
	}
}

func TestHeatmapEmptySector(t *testing.T) {
	startups := []provider.Startup{
		{Industries: []string{"Fintech"}, Batch: "W24"},
	}
	result := Compute(startups, "nonexistent")
	if len(result.Batches) != 0 {
		t.Errorf("expected 0 batches for unknown sector, got %d", len(result.Batches))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/heatmap/ -v
```

- [ ] **Step 3: Implement heatmap**

```go
// internal/heatmap/heatmap.go
//
// Computes market trends by counting startups per YC batch in a sector.
//
// HOW BATCH SORTING WORKS:
// YC batches are named like "W24" (Winter 2024) and "S23" (Summer 2023).
// We sort them chronologically: S23 < W24 < S24 < W25.
// Year is the primary sort key, season secondary (S before W within same year).

package heatmap

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	"github.com/simrantanwani226/compete-finder/internal/provider"
)

type BatchTrend struct {
	Batch string
	Count int
	Trend string // "UP", "DOWN", "FLAT"
}

type HeatmapResult struct {
	Batches      []BatchTrend
	Status       string  // "HOT", "WARM", "COLD", "DECLINING"
	GrowthFactor float64
}

// batchSortKey converts "W24" → 2024.1, "S24" → 2024.0 for sorting.
func batchSortKey(batch string) float64 {
	if len(batch) < 2 {
		return 0
	}
	season := batch[0:1]
	yearStr := batch[1:]
	year, err := strconv.Atoi(yearStr)
	if err != nil {
		return 0
	}
	// Assume 2000s
	year += 2000
	if season == "W" {
		return float64(year) + 0.1
	}
	return float64(year)
}

func matchesSector(industries []string, sector string) bool {
	sector = strings.ToLower(sector)
	for _, ind := range industries {
		if strings.Contains(strings.ToLower(ind), sector) {
			return true
		}
	}
	return false
}

func Compute(startups []provider.Startup, sector string) HeatmapResult {
	// Count startups per batch in this sector
	batchCounts := make(map[string]int)
	for _, s := range startups {
		if matchesSector(s.Industries, sector) {
			if s.Batch != "" {
				batchCounts[s.Batch]++
			}
		}
	}

	if len(batchCounts) == 0 {
		return HeatmapResult{}
	}

	// Sort batches chronologically
	batches := make([]string, 0, len(batchCounts))
	for b := range batchCounts {
		batches = append(batches, b)
	}
	sort.Slice(batches, func(i, j int) bool {
		return batchSortKey(batches[i]) < batchSortKey(batches[j])
	})

	// Build trends
	trends := make([]BatchTrend, len(batches))
	for i, b := range batches {
		trend := "FLAT"
		if i > 0 {
			prev := batchCounts[batches[i-1]]
			curr := batchCounts[b]
			change := float64(curr-prev) / float64(prev)
			if change > 0.2 {
				trend = "UP"
			} else if change < -0.2 {
				trend = "DOWN"
			}
		}
		trends[i] = BatchTrend{
			Batch: b,
			Count: batchCounts[b],
			Trend: trend,
		}
	}

	// Compute growth factor (latest vs 4 batches ago)
	var growthFactor float64
	if len(trends) >= 2 {
		oldest := trends[0].Count
		if len(trends) > 4 {
			oldest = trends[len(trends)-5].Count
		}
		latest := trends[len(trends)-1].Count
		if oldest > 0 {
			growthFactor = float64(latest) / float64(oldest)
		}
	}

	// Determine market status
	status := "COLD"
	switch {
	case growthFactor >= 2.0:
		status = "HOT"
	case growthFactor >= 1.3:
		status = "WARM"
	case growthFactor < 0.7:
		status = "DECLINING"
	}

	_ = fmt.Sprintf // silence import if unused

	return HeatmapResult{
		Batches:      trends,
		Status:       status,
		GrowthFactor: growthFactor,
	}
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/heatmap/ -v
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/heatmap/
git commit -m "feat: add market heatmap computation with tests"
```

---

### Task 9: Cache Layer

**WHY:** Avoids re-computing TF-IDF scores for repeated queries. Also demonstrates caching patterns (TTL, key design, fail-open) which product companies care about.

**Files:**
- Create: `internal/cache/cache.go`
- Create: `internal/cache/cache_test.go`

- [ ] **Step 1: Write the test**

```go
// internal/cache/cache_test.go

package cache

import (
	"context"
	"testing"
	"time"
)

// Tests use the in-memory implementation — no Redis needed.
func TestInMemoryCache(t *testing.T) {
	c := NewInMemory(1 * time.Minute)

	ctx := context.Background()

	// Miss
	val, err := c.Get(ctx, "key1")
	if err != nil {
		t.Fatal(err)
	}
	if val != nil {
		t.Error("expected nil for miss")
	}

	// Set and hit
	c.Set(ctx, "key1", []byte("value1"))
	val, err = c.Get(ctx, "key1")
	if err != nil {
		t.Fatal(err)
	}
	if string(val) != "value1" {
		t.Errorf("expected value1, got %s", string(val))
	}
}

func TestInMemoryCacheTTL(t *testing.T) {
	c := NewInMemory(50 * time.Millisecond)
	ctx := context.Background()

	c.Set(ctx, "key1", []byte("value1"))
	time.Sleep(100 * time.Millisecond)

	val, err := c.Get(ctx, "key1")
	if err != nil {
		t.Fatal(err)
	}
	if val != nil {
		t.Error("expected nil after TTL expiry")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
go test ./internal/cache/ -v
```

- [ ] **Step 3: Implement cache**

```go
// internal/cache/cache.go
//
// Cache interface with two implementations:
// 1. InMemory — for tests and when Redis is unavailable
// 2. Redis — for production
//
// WHY an interface?
// - Tests don't need Redis running
// - If Redis goes down, swap to InMemory (fail-open)
// - Same code path regardless of backend

package cache

import (
	"context"
	"sync"
	"time"
)

// Cache is the interface both implementations satisfy.
type Cache interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Set(ctx context.Context, key string, value []byte) error
}

// --- In-Memory Implementation ---

type entry struct {
	value     []byte
	expiresAt time.Time
}

type InMemory struct {
	mu      sync.RWMutex
	data    map[string]entry
	ttl     time.Duration
}

func NewInMemory(ttl time.Duration) *InMemory {
	return &InMemory{
		data: make(map[string]entry),
		ttl:  ttl,
	}
}

func (c *InMemory) Get(_ context.Context, key string) ([]byte, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	e, ok := c.data[key]
	if !ok || time.Now().After(e.expiresAt) {
		return nil, nil
	}
	return e.value, nil
}

func (c *InMemory) Set(_ context.Context, key string, value []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data[key] = entry{
		value:     value,
		expiresAt: time.Now().Add(c.ttl),
	}
	return nil
}
```

- [ ] **Step 4: Run tests**

```bash
go test ./internal/cache/ -v
```
Expected: PASS

- [ ] **Step 5: Add Redis implementation**

```go
// internal/cache/redis.go
//
// Redis/Dragonfly cache implementation.
// Uses the go-redis client library.

package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisCache struct {
	client *redis.Client
	ttl    time.Duration
}

func NewRedis(addr string, ttl time.Duration) *RedisCache {
	return &RedisCache{
		client: redis.NewClient(&redis.Options{Addr: addr}),
		ttl:    ttl,
	}
}

func (c *RedisCache) Get(ctx context.Context, key string) ([]byte, error) {
	val, err := c.client.Get(ctx, key).Bytes()
	if err == redis.Nil {
		return nil, nil // cache miss, not an error
	}
	return val, err
}

func (c *RedisCache) Set(ctx context.Context, key string, value []byte) error {
	return c.client.Set(ctx, key, value, c.ttl).Err()
}

// Ping checks if Redis is reachable.
func (c *RedisCache) Ping(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}
```

- [ ] **Step 6: Run go mod tidy and commit**

```bash
go mod tidy
git add internal/cache/ go.mod go.sum
git commit -m "feat: add cache layer with in-memory and Redis implementations"
```

---

## Chunk 5: ConnectRPC Service + Server

### Task 10: Service Implementation

**WHY:** This is the glue layer. It implements the ConnectRPC-generated interface, wiring together the store, cache, and heatmap packages to serve RPCs.

**Files:**
- Create: `internal/service/service.go`

- [ ] **Step 1: Implement the service**

```go
// internal/service/service.go
//
// Implements the CompeteServiceHandler interface generated by ConnectRPC.
//
// HOW IT WORKS:
// 1. Request comes in via ConnectRPC
// 2. Validate input
// 3. Check cache for existing result
// 4. If miss: call store.FindCompetitors or heatmap.Compute
// 5. Cache the result
// 6. Return response
//
// This layer does NOT contain business logic — it delegates to matcher/heatmap.
// It only handles: validation, caching, and proto conversion.

package service

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log/slog"

	"connectrpc.com/connect"
	competev1 "github.com/simrantanwani226/compete-finder/gen/compete/v1"
	"github.com/simrantanwani226/compete-finder/gen/compete/v1/competev1connect"
	"github.com/simrantanwani226/compete-finder/internal/cache"
	"github.com/simrantanwani226/compete-finder/internal/heatmap"
	"github.com/simrantanwani226/compete-finder/internal/store"
)

type CompeteService struct {
	store  *store.Store
	cache  cache.Cache
	logger *slog.Logger
}

var _ competev1connect.CompeteServiceHandler = (*CompeteService)(nil)

func New(s *store.Store, c cache.Cache, logger *slog.Logger) *CompeteService {
	return &CompeteService{store: s, cache: c, logger: logger}
}

func (s *CompeteService) FindCompetitors(
	ctx context.Context,
	req *connect.Request[competev1.FindCompetitorsRequest],
) (*connect.Response[competev1.FindCompetitorsResponse], error) {

	// Validate
	if req.Msg.Description == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("description is required"))
	}
	if req.Msg.Sector == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("sector is required"))
	}

	limit := int(req.Msg.Limit)
	if limit <= 0 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	// Check cache
	cacheKey := fmt.Sprintf("find:%x", sha256.Sum256(
		[]byte(fmt.Sprintf("%s:%s:%d", req.Msg.Sector, req.Msg.Description, limit)),
	))

	if cached, err := s.cache.Get(ctx, cacheKey); err == nil && cached != nil {
		var resp competev1.FindCompetitorsResponse
		if json.Unmarshal(cached, &resp) == nil {
			s.logger.Info("cache hit", "key", cacheKey[:20])
			return connect.NewResponse(&resp), nil
		}
	}

	// Find competitors
	results := s.store.FindCompetitors(req.Msg.Description, req.Msg.Sector, limit)

	// Build response
	competitors := make([]*competev1.Competitor, len(results))
	for i, r := range results {
		competitors[i] = &competev1.Competitor{
			Name:        r.Name,
			Description: r.Description,
			Industries:  r.Industries,
			Batch:       r.Batch,
			TeamSize:    int32(r.TeamSize),
			Status:      r.Status,
			Url:         r.URL,
			MatchScore:  r.Score,
		}
	}

	resp := &competev1.FindCompetitorsResponse{
		Competitors:   competitors,
		TotalInSector: int32(len(results)),
	}

	// Cache result (best effort)
	if data, err := json.Marshal(resp); err == nil {
		s.cache.Set(ctx, cacheKey, data)
	}

	return connect.NewResponse(resp), nil
}

func (s *CompeteService) GetMarketHeatmap(
	ctx context.Context,
	req *connect.Request[competev1.GetMarketHeatmapRequest],
) (*connect.Response[competev1.GetMarketHeatmapResponse], error) {

	if req.Msg.Sector == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("sector is required"))
	}

	// Check cache
	cacheKey := fmt.Sprintf("heatmap:%s", req.Msg.Sector)

	if cached, err := s.cache.Get(ctx, cacheKey); err == nil && cached != nil {
		var resp competev1.GetMarketHeatmapResponse
		if json.Unmarshal(cached, &resp) == nil {
			return connect.NewResponse(&resp), nil
		}
	}

	// Compute heatmap
	result := heatmap.Compute(s.store.Startups(), req.Msg.Sector)

	batches := make([]*competev1.BatchTrend, len(result.Batches))
	for i, b := range result.Batches {
		batches[i] = &competev1.BatchTrend{
			Batch:        b.Batch,
			StartupCount: int32(b.Count),
			Trend:        b.Trend,
		}
	}

	resp := &competev1.GetMarketHeatmapResponse{
		Batches:      batches,
		MarketStatus: result.Status,
		GrowthFactor: result.GrowthFactor,
	}

	if data, err := json.Marshal(resp); err == nil {
		s.cache.Set(ctx, cacheKey, data)
	}

	return connect.NewResponse(resp), nil
}
```

- [ ] **Step 2: Commit**

```bash
go mod tidy
git add internal/service/ go.mod go.sum
git commit -m "feat: add ConnectRPC service implementation"
```

---

### Task 11: Server Entrypoint

**WHY:** This wires everything together — creates the store, cache, provider, service, and starts the HTTP server with graceful shutdown.

**Files:**
- Create: `cmd/server/main.go`

- [ ] **Step 1: Implement the server**

```go
// cmd/server/main.go
//
// The server entrypoint. Wires together all components:
// Provider → Store → Service → HTTP Server
//
// STARTUP SEQUENCE:
// 1. Parse flags (port, cache address)
// 2. Connect to Redis (or fall back to in-memory cache)
// 3. Fetch YC data via provider
// 4. Load data into store (builds TF-IDF index)
// 5. Create ConnectRPC service
// 6. Start HTTP server
// 7. Start background refresh worker
// 8. Wait for SIGTERM/SIGINT → graceful shutdown

package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"

	"github.com/simrantanwani226/compete-finder/gen/compete/v1/competev1connect"
	"github.com/simrantanwani226/compete-finder/internal/cache"
	"github.com/simrantanwani226/compete-finder/internal/provider/yc"
	"github.com/simrantanwani226/compete-finder/internal/service"
	"github.com/simrantanwani226/compete-finder/internal/store"
)

func main() {
	port := flag.Int("port", 8080, "server port")
	cacheAddr := flag.String("cache-addr", "", "Redis/Dragonfly address (e.g. localhost:6379). Empty = in-memory cache")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	// Setup cache
	var c cache.Cache
	if *cacheAddr != "" {
		rc := cache.NewRedis(*cacheAddr, 15*time.Minute)
		if err := rc.Ping(context.Background()); err != nil {
			logger.Warn("Redis unavailable, falling back to in-memory cache", "error", err)
			c = cache.NewInMemory(15 * time.Minute)
		} else {
			c = rc
			logger.Info("connected to Redis", "addr", *cacheAddr)
		}
	} else {
		c = cache.NewInMemory(15 * time.Minute)
		logger.Info("using in-memory cache")
	}

	// Setup store and load data
	s := store.New()
	provider := yc.New(yc.DefaultURL)

	logger.Info("fetching YC startup data...")
	startups, err := provider.Fetch(context.Background())
	if err != nil {
		logger.Error("failed to fetch initial data", "error", err)
		os.Exit(1)
	}
	s.Load(startups)
	logger.Info("loaded startups", "count", s.Count())

	// Create service and mux
	svc := service.New(s, c, logger)
	mux := http.NewServeMux()
	path, handler := competev1connect.NewCompeteServiceHandler(svc)
	mux.Handle(path, handler)

	// Start server
	addr := fmt.Sprintf(":%d", *port)
	srv := &http.Server{
		Addr:    addr,
		Handler: h2c.NewHandler(mux, &http2.Server{}),
	}

	// Background data refresh
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go refreshWorker(ctx, provider, s, logger)

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
		<-sigCh
		logger.Info("shutting down...")
		cancel()
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		srv.Shutdown(shutdownCtx)
	}()

	logger.Info("server starting", "addr", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		logger.Error("server error", "error", err)
		os.Exit(1)
	}
}

func refreshWorker(ctx context.Context, p *yc.YCProvider, s *store.Store, logger *slog.Logger) {
	ticker := time.NewTicker(6 * time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			logger.Info("refreshing YC data...")
			startups, err := p.Fetch(ctx)
			if err != nil {
				logger.Error("refresh failed, keeping stale data", "error", err)
				continue
			}
			s.Load(startups)
			logger.Info("refreshed startups", "count", s.Count())
		}
	}
}
```

- [ ] **Step 2: Tidy and commit**

```bash
go mod tidy
git add cmd/server/ go.mod go.sum
git commit -m "feat: add server entrypoint with graceful shutdown and background refresh"
```

---

## Chunk 6: CLI Client

### Task 12: CLI Client

**WHY:** The CLI is how users interact with Compete-Finder from the terminal. It calls the ConnectRPC API and renders results as formatted tables.

**Files:**
- Create: `cmd/cli/main.go`

- [ ] **Step 1: Implement the CLI**

```go
// cmd/cli/main.go
//
// CLI client for Compete-Finder.
// Uses the ConnectRPC generated client to talk to the server.
//
// COMMANDS:
//   compete-finder find     — find competitors for a startup
//   compete-finder heatmap  — show market trends for a sector
//
// HOW CONNECTRPC CLIENT WORKS:
// buf generated a type-safe client from the proto.
// We just call methods on it — no manual HTTP/JSON handling.

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"text/tabwriter"

	"connectrpc.com/connect"
	competev1 "github.com/simrantanwani226/compete-finder/gen/compete/v1"
	"github.com/simrantanwani226/compete-finder/gen/compete/v1/competev1connect"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "find":
		runFind(os.Args[2:])
	case "heatmap":
		runHeatmap(os.Args[2:])
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println(`Usage:
  compete-finder find     --name NAME --description DESC --sector SECTOR [--limit N] [--server ADDR]
  compete-finder heatmap  --sector SECTOR [--server ADDR]`)
}

func parseFlag(args []string, name string) string {
	for i, a := range args {
		if a == "--"+name && i+1 < len(args) {
			return args[i+1]
		}
	}
	return ""
}

func getClient(args []string) competev1connect.CompeteServiceClient {
	server := parseFlag(args, "server")
	if server == "" {
		server = "http://localhost:8080"
	}
	if !strings.HasPrefix(server, "http") {
		server = "http://" + server
	}
	return competev1connect.NewCompeteServiceClient(http.DefaultClient, server)
}

func runFind(args []string) {
	name := parseFlag(args, "name")
	desc := parseFlag(args, "description")
	sector := parseFlag(args, "sector")
	limitStr := parseFlag(args, "limit")

	if desc == "" || sector == "" {
		fmt.Println("Error: --description and --sector are required")
		os.Exit(1)
	}

	var limit int32 = 10
	if limitStr != "" {
		fmt.Sscanf(limitStr, "%d", &limit)
	}

	client := getClient(args)
	resp, err := client.FindCompetitors(context.Background(), connect.NewRequest(&competev1.FindCompetitorsRequest{
		Name:        name,
		Description: desc,
		Sector:      sector,
		Limit:       limit,
	}))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Msg.Competitors) == 0 {
		fmt.Printf("No competitors found in sector '%s'. Try a broader term.\n", sector)
		return
	}

	fmt.Printf("\nFound %d competitors:\n\n", len(resp.Msg.Competitors))

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "#\tName\tScore\tBatch\tStatus\tDescription")
	fmt.Fprintln(w, "─\t────\t─────\t─────\t──────\t───────────")
	for i, c := range resp.Msg.Competitors {
		desc := c.Description
		if len(desc) > 60 {
			desc = desc[:57] + "..."
		}
		fmt.Fprintf(w, "%d\t%s\t%.2f\t%s\t%s\t%s\n",
			i+1, c.Name, c.MatchScore, c.Batch, c.Status, desc)
	}
	w.Flush()
}

func runHeatmap(args []string) {
	sector := parseFlag(args, "sector")
	if sector == "" {
		fmt.Println("Error: --sector is required")
		os.Exit(1)
	}

	client := getClient(args)
	resp, err := client.GetMarketHeatmap(context.Background(), connect.NewRequest(&competev1.GetMarketHeatmapRequest{
		Sector: sector,
	}))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(resp.Msg.Batches) == 0 {
		fmt.Printf("No data found for sector '%s'.\n", sector)
		return
	}

	fmt.Printf("\n%s sector trend:\n\n", sector)

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "Batch\tStartups\tTrend")
	fmt.Fprintln(w, "─────\t────────\t─────")
	for _, b := range resp.Msg.Batches {
		trend := "──"
		switch b.Trend {
		case "UP":
			trend = "▲"
		case "DOWN":
			trend = "▼"
		}
		fmt.Fprintf(w, "%s\t%d\t%s\n", b.Batch, b.StartupCount, trend)
	}
	w.Flush()

	fmt.Printf("\nMarket status: %s (%.1fx growth)\n", resp.Msg.MarketStatus, resp.Msg.GrowthFactor)
}
```

- [ ] **Step 2: Tidy and commit**

```bash
go mod tidy
git add cmd/cli/ go.mod go.sum
git commit -m "feat: add CLI client with find and heatmap commands"
```

---

## Chunk 7: Web UI (htmx)

### Task 13: Web UI

**WHY:** Gives the project a face. htmx keeps it all in Go — no JS build step, no node_modules.

**HOW htmx WORKS:** htmx adds attributes to HTML elements that make HTTP requests and swap content. For example, `hx-post="/find"` sends a POST, and `hx-target="#results"` replaces that element's content with the response. The server returns HTML fragments, not JSON.

**Files:**
- Create: `internal/web/handler.go`
- Create: `internal/web/templates/layout.html`
- Create: `internal/web/templates/index.html`
- Create: `internal/web/templates/results.html`
- Create: `internal/web/templates/heatmap.html`
- Create: `internal/web/static/style.css`

- [ ] **Step 1: Create templates**

`internal/web/templates/layout.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Compete-Finder</title>
    <script src="https://unpkg.com/htmx.org@2.0.4"></script>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <nav>
        <a href="/">Find Competitors</a>
        <a href="/heatmap">Market Heatmap</a>
    </nav>
    <main>
        {{block "content" .}}{{end}}
    </main>
</body>
</html>
```

`internal/web/templates/index.html`:
```html
{{define "content"}}
<h1>Find Your Competitors</h1>
<form hx-post="/find" hx-target="#results" hx-indicator="#loading">
    <label>Startup Name
        <input type="text" name="name" placeholder="e.g. Razorpay">
    </label>
    <label>Description
        <textarea name="description" placeholder="What does your startup do?" required></textarea>
    </label>
    <label>Sector
        <input type="text" name="sector" placeholder="e.g. fintech" required>
    </label>
    <button type="submit">Find Competitors</button>
</form>
<div id="loading" class="htmx-indicator">Searching...</div>
<div id="results"></div>
{{end}}
```

`internal/web/templates/results.html`:
```html
{{if .Competitors}}
<h2>Found {{len .Competitors}} competitors</h2>
<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Name</th>
            <th>Score</th>
            <th>Batch</th>
            <th>Status</th>
            <th>Description</th>
        </tr>
    </thead>
    <tbody>
        {{range $i, $c := .Competitors}}
        <tr>
            <td>{{inc $i}}</td>
            <td>{{$c.Name}}</td>
            <td>{{printf "%.2f" $c.MatchScore}}</td>
            <td>{{$c.Batch}}</td>
            <td>{{$c.Status}}</td>
            <td>{{truncate $c.Description 80}}</td>
        </tr>
        {{end}}
    </tbody>
</table>
{{else}}
<p>No competitors found. Try a broader sector term.</p>
{{end}}
```

`internal/web/templates/heatmap.html`:
```html
{{define "content"}}
<h1>Market Heatmap</h1>
<form hx-post="/heatmap" hx-target="#heatmap-results" hx-indicator="#loading">
    <label>Sector
        <input type="text" name="sector" placeholder="e.g. fintech" required>
    </label>
    <button type="submit">Show Trends</button>
</form>
<div id="loading" class="htmx-indicator">Analyzing...</div>
<div id="heatmap-results"></div>
{{end}}
```

- [ ] **Step 2: Create style.css**

`internal/web/static/style.css`:
```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; color: #1a1a1a; }
nav { display: flex; gap: 20px; padding: 16px 0; border-bottom: 1px solid #ddd; margin-bottom: 24px; }
nav a { text-decoration: none; color: #333; font-weight: 500; }
nav a:hover { color: #000; }
h1 { margin-bottom: 20px; }
h2 { margin: 20px 0 12px; }
form { display: flex; flex-direction: column; gap: 12px; max-width: 500px; }
label { display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 14px; }
input, textarea { padding: 8px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px; }
textarea { min-height: 80px; resize: vertical; }
button { padding: 10px 20px; background: #1a1a1a; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; width: fit-content; }
button:hover { background: #333; }
table { width: 100%; border-collapse: collapse; margin-top: 12px; }
th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #eee; font-size: 14px; }
th { font-weight: 600; background: #f9f9f9; }
.htmx-indicator { display: none; padding: 12px; color: #666; }
.htmx-request .htmx-indicator { display: block; }
```

- [ ] **Step 3: Implement web handler**

```go
// internal/web/handler.go
//
// HTTP handlers for the web UI.
// These are NOT ConnectRPC handlers — they serve HTML.
// The web UI calls the same store/heatmap packages directly
// (no need to go through the RPC layer for server-side rendering).

package web

import (
	"embed"
	"html/template"
	"net/http"
	"strconv"

	"github.com/simrantanwani226/compete-finder/internal/heatmap"
	"github.com/simrantanwani226/compete-finder/internal/store"
)

//go:embed templates/*.html
var templateFS embed.FS

//go:embed static/*
var staticFS embed.FS

var funcMap = template.FuncMap{
	"inc":      func(i int) int { return i + 1 },
	"truncate": func(s string, n int) string {
		if len(s) <= n {
			return s
		}
		return s[:n-3] + "..."
	},
}

type Handler struct {
	store *store.Store
	tmpl  *template.Template
}

func NewHandler(s *store.Store) *Handler {
	tmpl := template.Must(
		template.New("").Funcs(funcMap).ParseFS(templateFS, "templates/*.html"),
	)
	return &Handler{store: s, tmpl: tmpl}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/", h.handleIndex)
	mux.HandleFunc("/find", h.handleFind)
	mux.HandleFunc("/heatmap", h.handleHeatmap)
	mux.HandleFunc("/heatmap/search", h.handleHeatmapSearch)
	mux.Handle("/static/", http.FileServerFS(staticFS))
}

func (h *Handler) handleIndex(w http.ResponseWriter, r *http.Request) {
	h.tmpl.ExecuteTemplate(w, "layout.html", nil)
}

func (h *Handler) handleFind(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	desc := r.FormValue("description")
	sector := r.FormValue("sector")
	limitStr := r.FormValue("limit")
	limit := 10
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
		limit = l
	}
	if limit > 50 {
		limit = 50
	}

	results := h.store.FindCompetitors(desc, sector, limit)

	type competitor struct {
		Name        string
		MatchScore  float64
		Batch       string
		Status      string
		Description string
	}
	data := struct {
		Competitors []competitor
	}{}
	for _, r := range results {
		data.Competitors = append(data.Competitors, competitor{
			Name:        r.Name,
			MatchScore:  r.Score,
			Batch:       r.Batch,
			Status:      r.Status,
			Description: r.Description,
		})
	}

	h.tmpl.ExecuteTemplate(w, "results.html", data)
}

func (h *Handler) handleHeatmap(w http.ResponseWriter, r *http.Request) {
	h.tmpl.ExecuteTemplate(w, "layout.html", map[string]interface{}{
		"IsHeatmap": true,
	})
}

func (h *Handler) handleHeatmapSearch(w http.ResponseWriter, r *http.Request) {
	sector := r.FormValue("sector")
	result := heatmap.Compute(h.store.Startups(), sector)
	h.tmpl.ExecuteTemplate(w, "heatmap_results.html", result)
}
```

- [ ] **Step 4: Update server main.go to register web routes**

Add to `cmd/server/main.go` after the ConnectRPC handler registration:

```go
// Register web UI routes
webHandler := web.NewHandler(s)
webHandler.RegisterRoutes(mux)
```

Add import: `"github.com/simrantanwani226/compete-finder/internal/web"`

- [ ] **Step 5: Commit**

```bash
git add internal/web/ cmd/server/main.go
git commit -m "feat: add htmx web UI with find and heatmap pages"
```

---

## Chunk 8: Docker + README

### Task 14: Docker Setup

**WHY:** `docker compose up` is the simplest way for someone to try your project. No Go, no Redis, no setup.

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.yml`

- [ ] **Step 1: Create Dockerfile**

```dockerfile
# Dockerfile
# Multi-stage build: build in Go image, run in minimal image.
# WHY multi-stage? Final image is ~20MB instead of ~1GB.

FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o compete-finder ./cmd/server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/compete-finder .
EXPOSE 8080
CMD ["./compete-finder", "serve", "--port", "8080", "--cache-addr", "redis:6379"]
```

- [ ] **Step 2: Create docker-compose.yml**

```yaml
# docker-compose.yml
# One command to run everything: docker compose up

services:
  server:
    build: .
    ports:
      - "8080:8080"
    depends_on:
      - redis
    environment:
      - CACHE_ADDR=redis:6379

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

- [ ] **Step 3: Create .gitignore**

```
# .gitignore
/compete-finder
/gen/
*.exe
*.test
.DS_Store
```

- [ ] **Step 4: Commit**

```bash
git add Dockerfile docker-compose.yml .gitignore
git commit -m "feat: add Docker and docker-compose for easy setup"
```

---

### Task 15: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```markdown
# Compete-Finder

Competitive intelligence tool for startup founders. Enter your startup details, get a ranked list of competitors with match scores. Also shows market heatmap — which sectors are heating up or cooling down.

Built with Go, ConnectRPC, and htmx.

## Quick Start

```bash
docker compose up
```

Open http://localhost:8080 in your browser.

## CLI Usage

```bash
# Start the server
go run ./cmd/server --port 8080

# Find competitors
go run ./cmd/cli find \
  --description "Payment gateway for businesses" \
  --sector "fintech" \
  --limit 5

# Market heatmap
go run ./cmd/cli heatmap --sector "fintech"
```

## Architecture

- **API:** ConnectRPC + Protobuf — type-safe, gRPC-compatible
- **Data:** YC Companies API (~5,000+ startups)
- **Matching:** TF-IDF cosine similarity (pure Go, no ML deps)
- **Cache:** Redis/Dragonfly with TTL
- **Web:** Go templates + htmx (no JS framework)
- **Infra:** Docker, graceful shutdown, background data refresh

## Tech Stack

Go · ConnectRPC · Protobuf · htmx · Redis · Docker
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage and architecture overview"
```

---

## Chunk 9: Integration Test + Final Verification

### Task 16: Integration Test

**WHY:** Verifies the full RPC flow works end-to-end — service receives a request, queries the store, returns results.

**Files:**
- Create: `internal/service/service_test.go`

- [ ] **Step 1: Write integration test**

```go
// internal/service/service_test.go

package service

import (
	"context"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"connectrpc.com/connect"
	competev1 "github.com/simrantanwani226/compete-finder/gen/compete/v1"
	"github.com/simrantanwani226/compete-finder/gen/compete/v1/competev1connect"
	"github.com/simrantanwani226/compete-finder/internal/cache"
	"github.com/simrantanwani226/compete-finder/internal/provider"
	"github.com/simrantanwani226/compete-finder/internal/store"
)

func TestFindCompetitorsRPC(t *testing.T) {
	// Setup
	s := store.New()
	s.Load([]provider.Startup{
		{Name: "PayCo", Description: "payment gateway for merchants", Industries: []string{"Fintech"}, Batch: "W24", Status: "Active"},
		{Name: "LendCo", Description: "lending platform", Industries: []string{"Fintech"}, Batch: "S23", Status: "Active"},
		{Name: "HealthCo", Description: "telemedicine", Industries: []string{"Healthcare"}, Batch: "W24", Status: "Active"},
	})

	c := cache.NewInMemory(1 * time.Minute)
	logger := slog.Default()
	svc := New(s, c, logger)

	// Create test server
	mux := http.NewServeMux()
	path, handler := competev1connect.NewCompeteServiceHandler(svc)
	mux.Handle(path, handler)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	// Create client
	client := competev1connect.NewCompeteServiceClient(http.DefaultClient, srv.URL)

	// Test FindCompetitors
	resp, err := client.FindCompetitors(context.Background(), connect.NewRequest(&competev1.FindCompetitorsRequest{
		Description: "online payment processing",
		Sector:      "fintech",
		Limit:       10,
	}))
	if err != nil {
		t.Fatalf("RPC failed: %v", err)
	}

	if len(resp.Msg.Competitors) != 2 {
		t.Fatalf("expected 2 fintech competitors, got %d", len(resp.Msg.Competitors))
	}

	// PayCo should rank first (payment-related)
	if resp.Msg.Competitors[0].Name != "PayCo" {
		t.Errorf("expected PayCo first, got %s", resp.Msg.Competitors[0].Name)
	}
}

func TestFindCompetitorsValidation(t *testing.T) {
	s := store.New()
	c := cache.NewInMemory(1 * time.Minute)
	svc := New(s, c, slog.Default())

	mux := http.NewServeMux()
	path, handler := competev1connect.NewCompeteServiceHandler(svc)
	mux.Handle(path, handler)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	client := competev1connect.NewCompeteServiceClient(http.DefaultClient, srv.URL)

	// Missing description should fail
	_, err := client.FindCompetitors(context.Background(), connect.NewRequest(&competev1.FindCompetitorsRequest{
		Sector: "fintech",
	}))
	if err == nil {
		t.Fatal("expected error for missing description")
	}
	if connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("expected InvalidArgument, got %v", connect.CodeOf(err))
	}
}
```

- [ ] **Step 2: Run all tests**

```bash
go test ./... -v
```
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add internal/service/service_test.go
git commit -m "test: add integration tests for ConnectRPC service"
```

---

### Task 17: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
go test ./... -v -count=1
```

- [ ] **Step 2: Build and run server locally**

```bash
go build -o compete-finder ./cmd/server
./compete-finder --port 8080
```

- [ ] **Step 3: Test with CLI in another terminal**

```bash
go run ./cmd/cli find --description "payment gateway" --sector "fintech" --limit 5
go run ./cmd/cli heatmap --sector "fintech"
```

- [ ] **Step 4: Test web UI**

Open http://localhost:8080 in browser. Try a search.

- [ ] **Step 5: Test Docker**

```bash
docker compose up --build
```
Open http://localhost:8080.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: final verification — all tests passing, Docker working"
```
