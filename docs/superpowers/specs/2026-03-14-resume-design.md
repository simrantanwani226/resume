# Resume Design Spec

## Goal
Create a single-page markdown resume targeting entry-level backend/SDE roles at product-based companies in Bangalore.

## Format
- Single `resume.md` file in the repo root
- One page when rendered/exported to PDF
- Bullet points follow **Action + Tech + Impact** format
- Clean, scannable layout optimized for ATS and recruiter screening
- **One-page overflow strategy:** If content exceeds one page, trim project descriptions first, then reduce experience bullets. Skills grid and education stay compact.

## Section Order

### 1. Contact Info
- Name, location (Bengaluru), email, phone (user to fill in actual values)
- LinkedIn and GitHub links
- Single line, no frills

### 2. Skills (compact 4-line grid)
- **Languages:** Go, Java, Python, JavaScript/TypeScript
- **Frameworks:** Spring Boot, ConnectRPC, Go Fiber, React, FastAPI
- **Databases:** PostgreSQL, Redis/Dragonfly
- **DevOps:** Kubernetes (K3s), ArgoCD, Docker, Git

### 3. Experience

**SDE-1 | Healofy | May 2025 - Present**
- Primary backend developer for Materrverse and Astroverse apps, building user-facing content APIs using Go and ConnectRPC
- Integrated Fynd third-party platform into the Java/Spring Boot system
- Achieved ~5x reduction in monthly cloud spend by optimizing build and deployment infrastructure
- Built internal user-facing tools on the Healofy app using Go Fiber
- Maintained and enhanced the core Healofy backend (Java/Spring Boot, PostgreSQL)

**Analyst | Healofy | Aug 2024 - Apr 2025**
- Automated subscription and revenue reporting workflows, reducing manual effort by ~60%
- Analyzed subscription and marketplace datasets to deliver actionable insights for Product, Finance, and Growth teams
- Standardized reporting structures adopted organization-wide for key metrics and KPIs

### 4. Projects

**SmartHire** - *Python, FastAPI, React*
- AI-powered job recommendation platform that parses resumes and matches candidates to relevant positions using NLP-based skill extraction
- *[Bullets to be finalized after project rebuild — must follow Action + Tech + Impact format]*

**Compete-Finder** - *Go, ConnectRPC, Protobuf*
- Competitive intelligence tool that aggregates and analyzes startup ecosystem data
- *[Bullets to be finalized after project rebuild — must follow Action + Tech + Impact format]*

**Note:** Projects are personal/side projects — no date ranges shown intentionally.

### 5. Education
- **MCA** | Dayananda Sagar Academy of Technology & Management, Bengaluru | 2022-2024 | CGPA: 9.46
- **BCA** | Prestige Institute of Management & Research, Indore | 2019-2022 | CGPA: 9.58

## Design Decisions
- **Skills first:** Recruiters at product companies scan for tech stacks before reading experience
- **Projects before education:** Demonstrates hands-on ability for entry-level candidates
- **No summary section:** At entry-level it tends to be filler; projects and experience speak instead
- **~5x framing for cost optimization:** Clean, impressive metric without overpromising
- **Analyst role included but brief:** Shows growth trajectory from analyst to engineer at same company
- **Project descriptions are placeholders:** Will be updated once Smarthire (Python/FastAPI + React) and Compete-Finder (Go/ConnectRPC) are rebuilt with real depth
- **No certifications/awards section:** Intentionally excluded — not provided by user. Can be added later if relevant.
- **Skills reflect actual experience only:** No padding with tools the candidate hasn't used professionally.
