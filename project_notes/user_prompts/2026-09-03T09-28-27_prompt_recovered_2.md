# User Prompt (recovered from transcript) — 2026-09-03T09-28-27

**Session**: 11e4c54c-5e83-4c6e-9591-c67011f67c37
**Source**: Cursor stop-hook transcript-sweep

---

<dynamic_tools>
You have access to tools through dynamic namespaces, e.g. MCP servers, using `GetDynamicTools` and `CallDynamicTool`.

## Dynamic Tool Discovery and Invocation

Use `GetDynamicTools` to discover tool schemas, then `CallDynamicTool` to invoke one tool. Aim to minimize round-trips: ideally one discovery call followed by one invocation.

If the user mentions a product or service represented by an available namespace, and the request likely depends on it, proactively inspect that namespace before answering. If you are unsure which namespace matches, search with a relevant pattern.

`GetDynamicTools` supports these modes:

1. `{"namespace":"<id>"}`: returns schemas and full descriptions for every tool in that namespace.
2. `{"namespace":"<id>","toolName":"<name>"}`: returns one tool schema with its full description.
3. `{"pattern":"<regex>"}`: searches namespace and tool names.
4. `{"namespace":"<id>","pattern":"<regex>"}`: searches tools within one namespace.
5. No arguments: returns the full catalog.

Pattern-search and catalog results shorten long descriptions, marked by a trailing "... [truncated]"; namespace and single-tool lookups always return the complete description.

Always inspect a tool's schema before invoking it with `CallDynamicTool`.

If the available dynamic tools do not fully support what the user asked you to do, complete the work you can with the current tool set. In your work summary, include what you were unable to do and why. Do not use browser automation to work around missing tools unless the user explicitly asks you to use the browser.

Available dynamic tool namespaces:

<dynamic_tool_namespaces>
<namespace name="cdets" tools="get_mandatory_fields, get_defect, create_defect, edit_defect, get_options_for_field, search_defects, text_to_cdets_query, attach_file_to_defect" source="mcp" />
<namespace name="webex-rag-new" tools="list_conversation_sources, search_conversations" namespaceUseInstructions="Search Cisco Webex field engineer conversation archives with semantic search.

WORKFLOW:
1. Call list_conversation_sources() to discover available data sources
2. Match user's query to appropriate source using keywords and descriptions
3. Call search_conversations() with the user's query as-is

USER QUERY: Use the user's query directly. You may ask clarifying questions to help improve it, but user has full control.
FILTERS: Optional contributor username, date ranges, and sort order available.
RESULTS: LLM summaries with metadata and original threads. Always cite sources and provide Webex URLs." source="mcp" />
<namespace name="devnet-content-search" tools="Meraki-API-Doc-Search, Meraki-API-OperationId-Search, CatalystCenter-API-Doc-Search" namespaceUseInstructions="This server provides tools to fetch DevNet content, like Learning Labs, documents, APIs, SandBoxes..." source="mcp" />
<namespace name="tech-playbook" tools="search_use_cases, get_use_case_details, submit_use_case, edit_submitted_use_case, provide_feedback, rate_use_case, submit_feedback, list_fields, get_server_info, get_documentation, edit_production_record, rename_with_delete_prefix, unrename_delete_prefix, delete_use_case, get_search_health" namespaceUseInstructions="You are connected to the Tech Playbook MCP server (Cisco CX).
This server provides access to a curated library of PROVEN AI and automation
use cases collected from real Cisco CX engineering work.

=== 🔴 GOLDEN RULE ===

The MCP server reads and (curator-gated) writes the Production base only.
The Ingestion base was retired in D36 (2026-05-05) — any `INGESTION_*` env
var triggers a startup hard-fail. Form-channel records
(`i_Submission Channel == "Airtable Form"`) are immutable — writes refuse.

=== ⚠️ ARCHITECTURE ===

Production base (CX AI Global) — READ + WRITE. All submissions, edits, feedback,
ratings, and soft-deletes. Curated for 1000+ engineers.
Legacy Playbook base — READ-ONLY, transitional, will be retired.

Search: Production (default) and Legacy Playbook (read-only).
Writes: Production base only (submit, edit-own, feedback, rate, soft-delete).
Form-channel records: untouchable — all writes verify channel before mutating.

=== AVAILABLE TOOLS ===

Search & Discovery:
1. search_use_cases — Find use cases by keyword + lifecycle stage
 (source='production' default, 'legacy_playbook' read-only)
2. get_use_case_details — Get full details by record ID

Submission (writes to Production):
3. submit_use_case — Submit a new use case (⚠️ DEDUP + QUALITY protocols below)
4. edit_submitted_use_case — Edit your own STAGE_1_Submitted record
 (auth-gated; submitter or admin; PATCH semantics; Form-channel protected)
5. delete_use_case — Soft-delete by prepending 'DELETE: ' to title
 (auth-gated; submitter or admin; Form-channel protected; never destructive)

Feedback (writes to Production):
6. provide_feedback — Thumbs up/down (Airtable comment on Production record)
7. rate_use_case — Rate 1-5 stars
8. submit_feedback — Submit structured feedback to Production Feedback table

Curator (admin-only — CURATOR_ALLOWLIST):
9. edit_production_record — Two-phase commit; full-field admin edits
10. rename_with_delete_prefix — Bulk soft-delete via DELETE: prefix
11. unrename_delete_prefix — Bulk un-soft-delete

Reference:
12. get_documentation — User guide by topic. Topics: overview, connecting,
 tools, feedback, feedback_guide, submitting, quality_guide, ranking, faq
13. list_fields — Discover fields in Production/Legacy tables
14. get_server_info — Version, health, available tools

=== PROTOCOL 1: RATING & FEEDBACK (After Every Search/Retrieval) ===

⚠️ MANDATORY — Before providing feedback, read the Feedback Quality Guide:
 📖 get_documentation(topic='feedback_guide')

After EVERY search or details retrieval, you MUST:
1. REVIEW the AI-evaluated rating included with each result (quality score
 based on description depth, links, tools, impact, etc.)
2. PRESENT the evaluation to the user: "I evaluated this as X/5 stars
 because [strengths/gaps]. Do you agree or would you rate differently?"
3. USE the user's rating if they provide one; otherwise use the AI evaluation.
 ⚠️ NEVER default to 5 stars without evaluation or user input.
4. CALL rate_use_case(record_id, star_rating) with the final rating
5. CALL provide_feedback(record_id, rating, session_summary)
6. For detailed issues: submit_feedback() with template from feedback_guide
7. If broken/outdated → report at: https://wwwin-github.cisco.com/dbednarc/ai-playbook-mcp/issues/new

=== PROTOCOL 2: DEDUP (Before Every Submission) ===

NEVER call submit_use_case() without searching for duplicates first:

1. search_use_cases(query='...') — search the production base
2. Try 2-3 keyword variations using **technology and pattern** terms (e.g. Reveal.js,
 Chrome CDP, python-pptx, HTML, PPTX) — not internal repo or folder nicknames alone
3. If 80%+ match found → rate/feedback THAT instead of duplicating
4. Show matches to user: 'I found similar use cases. Should we provide
 feedback on those instead of creating a new one?'
5. Only proceed if the approach is genuinely different

One well-rated UC with rich feedback > three thin duplicates.

=== PROTOCOL 3: SUBMISSION QUALITY (Mandatory for All Submissions) ===

Before submitting, read the full Style Guide (**both** MCP text and HTML page for completeness):
 📖 get_documentation(topic='quality_guide')
 📖 https://wwwin-github.cisco.com/pages/dbednarc/ai-usecases-master-class/usecase_style_guide.html
 📖 https://wwwin-github.cisco.com/pages/dbednarc/ai-usecases-master-class/playbook_submissions.html

--- Naming (Idea Title) ---
• Pattern-first: name the **transferable workflow** (tools + outcome), 8+ words.
• Repo/folder **codenames belong in** github_repo_url, Key Artifacts, Replication Step 1
 (`git clone ...`) — **not** as the headline title.
• BAD: 'tech-talk-demo-prep' | GOOD: 'HTML-first Reveal.js decks with Chrome CDP export to PPTX'
• Deep link: https://wwwin-github.cisco.com/pages/dbednarc/ai-usecases-master-class/usecase_style_guide.html#field-title-naming

--- 7 Golden Rules (Non-Negotiable) ---
1. Full description lives in the submission — not a link to it
2. No local paths (/Users/, ~/, C:\) — use GitHub URLs
3. Step 1 of Replication Steps = git clone <repo-url>
4. Every script named AND linked (name + line count + GitHub URL)
5. Sample Prompt included (specific, copy-pasteable)
6. Minimum 5 paragraphs in Description (5,000-25,000 chars)
7. Searched BOTH Playbook tables for duplicates first

--- Required Sections (each maps to a SEPARATE tool parameter) ---
• title: 8+ words, specific (include tool/technology name); **not** a repo/folder nickname
 DO: 'RADKit-Driven WLC Config Drift Monitoring Across HA Pairs'
 DON'T: 'Config Monitoring' | DON'T: 'tech-talk-demo-prep' (use pattern + tech; repo → Key Artifacts / git clone)

• description: 5+ paragraphs, self-contained:
 P1: What it is (solution + key innovation)
 P2: Architecture (scripts, data flow, APIs)
 P3: Scale and scope (devices, volumes, runtimes)
 P4: Operational details (error handling, edge cases)
 P5: Boundaries and safety (what it does NOT do)

• problem_solved: 2+ paragraphs (fills SEPARATE Airtable field):
 - What was the pain BEFORE? (specific, not 'it was hard')
 - Why do existing approaches fail? (name them)
 - Who benefits? Concrete time/effort saved?

• potential_impact: 2+ sentences on business value. Include:
 time saved, who benefits, scale, ROI estimate.
 Example: 'Saves 45 min per refresh for 12 teams. ~36 hrs/year each.'

• ai_relevance: 2+ sentences on how AI specifically helps.
 What does AI do that scripts/humans alone cannot?
 Example: 'LLM extracts structured metadata from free-form notes.'

• use_case_type: MUST be one of: 'Internal Only', 'Customer', 'Both'

• sample_prompt: copy-pasteable AI agent prompt (fills SEPARATE Airtable field)
• replication_steps: 8-10 numbered with exact commands
 Step 1 ALWAYS = git clone <repo-url>
• prerequisites: 3+ items (tools, access, prior UCs)
• key_artifacts: script name + line count + GitHub link
• gotchas: 2+ real failure modes and edge cases
• related_use_cases: 1+ cross-references (title + ID)
• tools_used: AI tools used (Claude, RADKit, LLM API, etc.)
• other_tools: Non-AI tools (Python, Bash, jq, HTML/CSS, etc.)
• github_repo_url: primary repo URL
• ai_outcome: Airtable ``AI Outcome`` (multipleSelects). Comma-separated from:
 'Saves Time', 'Improves Quality', 'Advances Innovation'
• idea_maturity: EXACT string from Airtable singleSelect:
 'It is only an idea for now',
 'There is a working prototype. Only I am using it',
 'There is a working prototype. Multiple people are using it',
 'It is already in production.',
 'I have a solution ready to use'
• source_role_community: Submitter role community short form (default: 'ENG').
 Determines the Idea ID prefix (AI-ENG-81 vs AI-81).
 Valid: ENG, UNI, CS, DM, SD, EC, LEAD.

--- 7-Rule Audit (Run Before Submitting) ---
R1 DEPTH: 5+ substantive paragraphs?
R2 LINKS: Every artifact has a GitHub URL?
R3 SELF-CONTAINED: Step 1 = git clone?
R4 CROSS-LINKS: Related Use Cases populated?
R5 TOOLS: Scripts = name + line count + link?
R6 ACCURACY: Description matches actual code?
R7 SAMPLE PROMPT: Specific, copy-pasteable?
ALL 7 must PASS. Fix failures before submitting.

--- Description Depth Standards ---
UNACCEPTABLE: 1-2 paragraphs, <1,000 chars → REJECT
NEEDS WORK: 3-4 paragraphs, 1,000-3,000 chars → Must enrich
ACCEPTABLE: 5-7 paragraphs, 3,000-8,000 chars → Can submit
EXEMPLARY: 8+ paragraphs, 8,000+ chars → Role model

--- Anti-Patterns (Will Cause Rejection) ---
• Repo nickname title: internal project/repo name as Idea Title → pattern + technology instead
• Link Dump: 'See GitHub for full description' → PUT IT HERE
• Local Paths: '/Users/...' → use GitHub URLs
• Vague Steps: 'Set up environment' → which? how?
• One-Liner: 'A script that does X' → no how, no tools, no scale
• Missing Prompt: no Sample Prompt → how does anyone invoke this?
• The Island: uses RADKit/CDP but never links foundational UCs

Every rating and piece of feedback is reviewed by curators.
Quality is paramount. This Playbook serves 1000+ Cisco CX engineers." source="mcp" />
<namespace name="second-brain" tools="ping, search, get_full_summary, get_original_email, get_source_status, search_by_person, health_check, ensure_email_sync, search_sr, sr_graph_view, register_sr, link_sr_to_project, get_sr_dashboard, list_tracked_srs, get_morning_brief, list_priority_candidates, get_active_goals, get_goal, list_strategic_signals, get_triage_advice, dump_webex_space, get_dump_status, search_attachments, graph_search_email, graph_get_email, graph_email_status, list_project_memories, get_project_memory, list_source_family_completeness, prioritizer_strategic_openings, prioritizer_today_customers, vault_browse, vault_read, vault_graph, vault_ingest, vault_lint, search_with_raw, harvest_session, linear_create_issue, decision_consult, record_failed_attempt, graph_entity, graph_search, graph_timeline" namespaceUseInstructions="Search across all communications and project docs: emails, Webex spaces, DMs, meetings, calendar, bookmarks, AI project files. IMPORTANT: Before searching emails, call health_check() first. If it reports email sync issues, call ensure_email_sync() to fix them. This prevents stale/missing email results. MANDATORY: After EVERY search, you MUST perform a gap analysis benchmark — the search results include instructions. Generate an HTML report at ~/Documents/claude_projects/second_brain/docs/gap_analysis/. This is required to improve search quality." source="mcp" />
<namespace name="circuit" tools="circuit_chat, circuit_upload_file, circuit_get_result, circuit_list_models, circuit_list_agents, circuit_new_session" source="mcp" />
<namespace name="salesforce-dx" tools="get_username, resume_tool_operation, run_soql_query, create_org_snapshot, create_scratch_org, delete_org, list_all_orgs, open_org, assign_permission_set" source="mcp" />
<namespace name="cursor" tools="CreateGoal, GenerateImage, UpdateGoal" namespaceUseInstructions="Native Cursor tools for this session. These are highly recommended and useful tools that you should use when the right situation arises. Don't be afraid to look at one if it seems relevant, even if you don't end up using it. You MUST read the tool schemas before calling them." source="cursor" />
</dynamic_tool_namespaces>

## MCP Resource Access

You also have access to MCP resources via `FetchMcpResource`.
If an MCP-backed namespace requires authentication, call `mcp_auth` through `CallDynamicTool` for that namespace, then inspect it again and retry if appropriate. Do not authenticate namespaces preemptively or repeatedly.
</dynamic_tools>
