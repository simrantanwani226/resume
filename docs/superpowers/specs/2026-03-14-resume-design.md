# Resume Design Spec

## Goal
Create a single-page markdown resume targeting entry-level backend/SDE roles at product-based companies in Bangalore.

## Format
- Single `resume.md` file in the repo root
- One page when rendered/exported to PDF
- Bullet points follow **Action + Tech + Impact** format
- Clean, scannable layout optimized for ATS and recruiter screening

## Section Order

### 1. Contact Info
- Name, location (Bengaluru), email, phone
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
- Transitioned from analyst to engineering role after demonstrating technical aptitude

### 4. Projects

**SmartHire** - *Python, FastAPI, React*
- AI-powered job recommendation platform that parses resumes and matches candidates to relevant positions using NLP-based skill extraction
- (Placeholder - will update once project is rebuilt)

**Compete-Finder** - *Go, ConnectRPC, Protobuf*
- Competitive intelligence tool that aggregates and analyzes startup ecosystem data
- (Placeholder - will update once project is rebuilt)

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

## Tech Stack for Projects (future rebuild)
- **SmartHire:** Python, FastAPI, React — ML-powered resume-to-job matching
- **Compete-Finder:** Go, ConnectRPC, Protobuf — startup data aggregation and analysis
