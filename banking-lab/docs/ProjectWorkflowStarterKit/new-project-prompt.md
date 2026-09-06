You are an expert software architect and repository initializer. I am starting a brand new project and have placed the Docs_ProjectWorkflowStarterKit/ folder in the root.

Here are the project parameters:

- Target Project Name: [Enter Project Name here, e.g., MyFlutterApp / InventoryService / NovaGame]
- Target Tech Stack: [Enter Stack here, e.g., Flutter Dart / ASP.NET Core C# / Unity 6 C# / Next.js TypeScript / Python FastAPI]
- Target Platform / Type: [Enter Type here, e.g., Mobile App / REST API Backend / Desktop 3D Game / Full-Stack Web App]

Your task is to initialize our standardized token-optimized workflow (v2.0) matching our standard two-digit numbered folder hierarchy.

SAFETY RULES:

1. Work ONLY with documentation, templates, and ignore files.
2. Do NOT run git commands unless explicitly instructed.

Follow these setup steps:

---

STEP 1: CREATE THE STANDARD 8-FOLDER DOCS DIRECTORY
Create the Docs/ directory in the project root with the following 8 numbered lifecycle folders:

- Docs/00_Drafts/
- Docs/01_Tracking/
- Docs/02_Planning/
- Docs/03_Walkthroughs/
- Docs/04_Architecture/
- Docs/05_Design/
- Docs/06_Guides/
- Docs/07_Archive/

---

STEP 2: CONFIGURE AND DEPLOY ROOT AGENTS.MD

1. Copy Docs_ProjectWorkflowStarterKit/AGENTS.md to the repository root.
2. Populate the Project Profile header using the parameters provided above:
   - Project Name: [Use Target Project Name]
   - Active Task File: Docs/01_Tracking/task.md
   - Task Archive Directory: Docs/01_Tracking/archive/
   - Implementation Plan Directory: Docs/02_Planning/
   - Walkthrough Folder: Docs/03_Walkthroughs/
   - Changelog File: CHANGELOG.md
   - Primary Tech Stack: [Use Target Tech Stack]
   - Manual Verification Areas: Tailor this automatically based on the chosen stack:
     * If Flutter / Mobile: Mobile touch ergonomics, safe area padding, widget responsiveness, platform hot-reload, physical device tests.
     * If ASP.NET / Backend: OpenAPI/Swagger contracts, EF database migrations, HTTP status codes, auth JWT tokens, payload validation.
     * If Unity / Game: Game feel, input tumble/rotation, audio, zero-GC per-frame allocations, draw calls, hardware performance.
     * If Web / React: Responsive mobile/desktop viewports, hydration, form validation, route redirects, Lighthouse performance.
   - Protected Boundaries: Private repository; do not expose secrets or API keys; do not modify third-party package caches without authorization.

---

STEP 3: DEPLOY ROOT IGNORE FILES

1. Copy Docs_ProjectWorkflowStarterKit/aiignore-template.md as .aiignore in the project root.
2. Create a duplicate copy named .cursorignore in the project root.
3. Ensure Docs_ProjectWorkflowStarterKit/ is included in the ignore list so the master kit does not consume tokens during coding turns.

---

STEP 4: DEPLOY INITIAL WORKING TEMPLATES

1. Copy Docs_ProjectWorkflowStarterKit/task-template.md to Docs/01_Tracking/task.md.
   - Set the initial task title to: Task Tracking: Project Initialization & Environment Setup
   - Set Current Execution State:
     * Active Files: Repository configuration and environment files
     * Current Blocker / Status: Environment setup in progress
     * Next Immediate Action: Initialize repository scaffolding for [Target Tech Stack]
   - Set Phase 1 checklist to:
     * [ ]  Verify local SDK and tooling installation for [Target Tech Stack]
     * [ ]  Initialize project baseline scaffolding and dependency manifests
     * [ ]  Confirm clean compilation or development server launch
2. Create the Docs/01_Tracking/archive/ directory.
3. Copy Docs_ProjectWorkflowStarterKit/implementation-plan-template.md to Docs/02_Planning/implementation-plan-template.md.
4. Copy Docs_ProjectWorkflowStarterKit/walkthrough-template.md to Docs/03_Walkthroughs/walkthrough-template.md.
5. Create an initial CHANGELOG.md in the project root with the standard Keep a Changelog format, starting with an Unreleased section.

---

STEP 5: REPORT SUMMARY
Output a clean confirmation report showing:

1. Configured Project Profile inside AGENTS.md.
2. Generated Docs/ folder tree (00_Drafts through 07_Archive).
3. Recommended first CLI command to scaffold the codebase (e.g., flutter create, dotnet new webapi, npx create-next-app, etc.).