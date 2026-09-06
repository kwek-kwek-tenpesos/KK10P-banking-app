You are an expert repository architect and setup assistant. I have placed the Docs_ProjectWorkflowStarterKit/ folder into this repository root.

Your task is to inspect this repository, detect whether it is a fresh project or an existing project, and configure our token-optimized documentation workflow (v2.0 standard).

SAFETY RULES:
1. Do NOT modify, delete, or recompile any source code, assets, scripts, or project configurations.
2. Do NOT run git commands (no git add, git commit, etc.).
3. Work ONLY with documentation, templates, and ignore files.
4. If documentation or tracking already exists, MIGRATE it. Never wipe or overwrite existing project history.

Follow these setup steps:

---

STEP 1: REPOSITORY INSPECTION & DETECTION
1. Inspect the project root and source directories to detect:
   - Project Name (from package.json, folder name, .sln, or project settings)
   - Primary Tech Stack (e.g., Unity C#, Next.js TypeScript, Flutter, Python, ASP.NET)
   - Relevant manual verification areas (e.g., game feel, responsive UI, hardware, API tests)
   - Protected boundaries (e.g., private repo, secrets, package caches)
2. Determine project state:
   - Is this an existing project with established docs and tasks, or a fresh project?

---

STEP 2: CREATE OR CONSOLIDATE NUMBERED DOCS DIRECTORIES
Ensure the Docs/ directory contains all 8 standardized numbered lifecycle folders:
- Docs/00_Drafts/
- Docs/01_Tracking/
- Docs/02_Planning/
- Docs/03_Walkthroughs/
- Docs/04_Architecture/
- Docs/05_Design/
- Docs/06_Guides/
- Docs/07_Archive/

IF THIS IS AN EXISTING PROJECT:
Safely move existing documentation into these 8 categories without deleting content:
- Move raw scratchpads and draft folders (like DraftCore) into Docs/00_Drafts/.
- Move feature plans, TDDs, status, and QA criteria into Docs/02_Planning/.
- Move walkthroughs and handover logs into Docs/03_Walkthroughs/.
- Move systems docs, player input, optimization, and settings docs into Docs/04_Architecture/.
- Move GDDs, narrative/story scripts, and UI design docs into Docs/05_Design/.
- Move contributor guides, audio/art specs, and review standards into Docs/06_Guides/.
- Move deprecated audits or old notes into Docs/07_Archive/.
Clean up empty legacy directories after files are safely moved.

---

STEP 3: DEPLOY OR UPGRADE ROOT FILES
1. AGENTS.md:
   - Copy Docs_ProjectWorkflowStarterKit/AGENTS.md to the repository root (or upgrade the existing one).
   - Populate its Project Profile using the detected project name, tech stack, and paths:
      - Active Task File: Docs/01_Tracking/task.md
      - Task Archive Directory: Docs/01_Tracking/archive/
      - Implementation Plan Directory: Docs/02_Planning/
      - Walkthrough Folder: Docs/03_Walkthroughs/
      - Changelog File: CHANGELOG.md
2. Root Ignore Files:
   - Copy Docs_ProjectWorkflowStarterKit/aiignore-template.md as .aiignore in the project root.
   - Also create a copy named .cursorignore in the project root.
   - Ensure Docs_ProjectWorkflowStarterKit/ is included in the ignore rules so the master kit is not indexed during normal coding turns.

---

STEP 4: INITIALIZE OR PRUNE TASK TRACKING
1. Ensure the Docs/01_Tracking/archive/ directory is created.
2. Check for an existing task tracking file (at root, in tracking folders, or in Docs/):
   - IF AN EXISTING TASK FILE EXISTS:
     - Move it to Docs/01_Tracking/task.md.
     - Move all completed checklists, verified baselines, and past sprint post-mortems into a dedicated archive file: Docs/01_Tracking/archive/task-[YYYY-MM-DD]-[feature-or-baseline-name].md.
     - In Docs/01_Tracking/task.md, retain ONLY the active sprint or pending bug fix.
     - Place the [CURRENT EXECUTION STATE - HANDOFF] block at the very top.
     - Keep active task.md under 80 lines.
   - IF THIS IS A FRESH PROJECT (No prior task file):
     - Copy Docs_ProjectWorkflowStarterKit/task-template.md to Docs/01_Tracking/task.md.
     - Ensure Docs/01_Tracking/archive/ exists.

3. Deploy Planning and Walkthrough Templates:
   - Copy Docs_ProjectWorkflowStarterKit/implementation-plan-template.md to Docs/02_Planning/implementation-plan-template.md (do not overwrite existing active plans).
   - Copy Docs_ProjectWorkflowStarterKit/walkthrough-template.md to Docs/03_Walkthroughs/walkthrough-template.md.

---

STEP 5: REPORT SUMMARY
Output a clean summary showing:
1. Detected Project State (Fresh or Existing), Project Name, and Tech Stack.
2. The populated Project Profile inside AGENTS.md.
3. Summary of directories created or files migrated.
4. Lines pruned into Docs/01_Tracking/archive/ (if an existing project).