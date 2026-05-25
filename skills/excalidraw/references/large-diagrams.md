# Large Diagram Strategy

**Build JSON one section at a time.** Do not attempt the entire file in a single pass — it
leads to worse quality and may exceed output limits.

## Section-by-Section Workflow

**Phase 1 — Build each section:**
1. Create the base file with JSON wrapper and first section of elements
2. Add one section per edit — take your time with layout and spacing
3. Use descriptive string IDs (e.g., `"trigger_rect"`, `"arrow_fan_left"`)
4. Namespace seeds by section (section 1: 100xxx, section 2: 200xxx)
5. Update cross-section bindings as you go

**Phase 2 — Review the whole:**
Check cross-section arrow bindings, overall spacing balance, and that all IDs reference
existing elements.

**Phase 3 — Render & validate** (Claude Code) or final review (Claude Chat).
