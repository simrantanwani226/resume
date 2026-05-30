# Simran Tanwani

simrantanwani0226@gmail.com | +91-6268215757 | Bengaluru |
[LinkedIn](https://linkedin.com/in/simran-tanwani) | [GitHub](https://github.com/simrantanwani226)

---

## Summary

Backend software engineer shipping production features across Java, Go, and TypeScript. Built subscription billing for **millions of users** and shipped the **only solo greenfield module into a legacy monolith** last year — owning design, migrations, and deployment.

---

## Skills

- **Languages:** Go, Java, Python, JavaScript/TypeScript
- **Frameworks:** Spring Boot, ConnectRPC, Go Fiber, React, FastAPI
- **Databases:** PostgreSQL, Redis, Dragonfly
- **DevOps:** Kubernetes (K3s), ArgoCD, Docker, Git

---

## Experience

### SDE-1 | [Healofy](https://play.google.com/store/apps/details?id=com.healofy) | May 2025 – Present

- Built a 3-tier subscription billing system (Java/Spring Boot, PostgreSQL, Razorpay) with multi-currency pricing and app-version-aware feature gating for a consumer app with **millions of users** — enabling safe rollouts to older Android clients and renewal tracking for revenue analytics
- Shipped a 3-level hierarchical content-catalog module in Java as a full vertical slice (REST controllers, service layer, JPA repositories, migration) — the **only greenfield feature** added solo to a large legacy monolith that year
- Authored **2 Go microservices** (ConnectRPC, Protobuf, pgx v5, sqlc, OpenTelemetry) handling batches of 100 records/request with schema validation, composite-key dedup, and transactional audit logging — powering production content features
- Built a multi-provider LLM orchestration service (TypeScript/Node.js, Vercel AI SDK) integrating **3 providers** (Claude, GPT, Mistral) with per-persona routing, per-user context injection, and per-provider timeout/retry — output capped at 1000 tokens to control cost and latency
- Authored **10 PostgreSQL migrations** across 4 production databases, migrated connection pooling from pgbouncer to direct PostgreSQL, and ran ArgoCD deployments across test/prod for new Go services — and moved analytics onto a Google Cloud Tasks queue, off the request path
- Eliminated an N+1 query in cart personalization with batched prefetching — cut database round-trips from **O(N) to O(1)** per render in a high-traffic e-commerce flow

### Business Analyst | [Healofy](https://play.google.com/store/apps/details?id=com.healofy) | Aug 2024 – Apr 2025

- Automated subscription & revenue reporting, cutting manual effort by **~60%**
- Built **company-wide** reporting standards across Product, Finance & Growth teams

---

## Projects

**[Compete-Finder](https://github.com/simrantanwani226/Compete-Finder)** - *Go, Connect RPC, Protobuf* - scores Y Combinator startups by TF-IDF similarity to surface the top-N competitors for a product, with a sector-growth heatmap across YC batches

**[QuickMatch](https://github.com/simrantanwani226/QuickMatch)** - *Java, Spring Boot* - layered REST service (controller/service/repository, JPA + H2) scoring keyword overlap between a resume and a job description

---

## Education

**MCA**, Dayananda Sagar Academy of Technology & Management — 2022–2024 · CGPA 9.46

**BCA**, Prestige Institute of Management & Research — 2019–2022 · CGPA 9.58
