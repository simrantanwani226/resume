# Simran Tanwani

Backend Software Engineer

simrantanwani0226@gmail.com | +91-6268215757 | Bengaluru |
[LinkedIn](https://linkedin.com/in/simran-tanwani) | [GitHub](https://github.com/simrantanwani226)

---

## Summary

Built subscription billing for a **multi-million-user** consumer app and sole-authored a greenfield module inside a large, established Java codebase — shipping features end-to-end across Java, Go, and TypeScript, from design through production rollout.

---

## Skills

- **Languages:** Go, Java, JavaScript/TypeScript
- **Frameworks:** Spring Boot, Spring Framework, JPA, Go Fiber, Node.js, Vercel AI SDK
- **Databases:** PostgreSQL (SQL), Redis & Dragonfly (NoSQL), pgx, sqlc
- **DevOps & CI/CD:** Kubernetes (K3s), ArgoCD, Docker, Git, Maven, Google Cloud Tasks, OpenTelemetry
- **Protocols:** gRPC / ConnectRPC, Protocol Buffers, REST
- **Practices:** Microservices, Design Patterns, Clean Coding, Agile/Scrum

---

## Experience

### Software Development Engineer (SDE-1) | [Healofy](https://play.google.com/store/apps/details?id=com.healofy) | May 2025 – Present

- Built a 3-tier subscription billing system (Java/Spring Boot, PostgreSQL, Razorpay) with multi-currency pricing and app-version-aware feature gating for a consumer app with **millions of users** — enabling safe rollouts across Android client versions and renewal-event tracking for revenue analytics
- Shipped a 3-level hierarchical content-catalog module in Java as a full vertical slice (REST controllers, service layer, JPA repositories, migration) — a **greenfield feature** added to a large, established monolith, serving ~4K multilingual content items to ~246K daily active users
- Authored **2 Go microservices** (ConnectRPC, Protobuf, pgx v5, sqlc, OpenTelemetry) handling batches of 100 records/request with schema validation, composite-key dedup, and transactional audit logging — powering content delivery for two consumer apps
- Designed a multi-provider LLM orchestration service (TypeScript/Node.js, Vercel AI SDK) integrating **3 providers** (Claude, GPT, Mistral) with per-persona routing, per-user context injection, and per-provider timeout/retry — output capped at 1000 tokens to control cost and latency
- Owned database infrastructure across **4 production PostgreSQL databases** — schema migrations on live tables, a connection-pooling migration from pgbouncer to direct PostgreSQL, and analytics writes decoupled onto a Google Cloud Tasks queue, off the request path; also bootstrapped IaC (TypeScript) with secrets management for **3 third-party integrations**
- Eliminated an N+1 query in cart personalization with batched prefetching — cut database round-trips from **O(N) to O(1)** per render in a high-traffic e-commerce flow

### Business Analyst | [Healofy](https://play.google.com/store/apps/details?id=com.healofy) | Aug 2024 – Apr 2025

- Automated subscription & revenue reporting, cutting manual effort by **~60%**
- Established **company-wide** reporting standards for stakeholders across Product, Finance & Growth

---

## Projects

**[Compete-Finder](https://github.com/simrantanwani226/Compete-Finder)** - *Go, Connect RPC, Protobuf* - scores Y Combinator startups by TF-IDF similarity to surface the top-N competitors for a product, with a sector-growth heatmap across YC batches

**[QuickMatch](https://github.com/simrantanwani226/QuickMatch)** - *Java, Spring Boot* - layered REST service (controller/service/repository, JPA + H2) scoring keyword overlap between a resume and a job description

---

## Education

**MCA**, Dayananda Sagar Academy of Technology & Management — 2022–2024 · CGPA 9.46

**BCA**, Prestige Institute of Management & Research — 2019–2022 · CGPA 9.58
