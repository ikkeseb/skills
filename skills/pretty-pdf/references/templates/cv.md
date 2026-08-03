# CV / Resume

Use this as a starting point, not a default. Adapt structure and all five design axes to the
actual content. Render it with `assets/base.css` plus a small document-specific override.

Palette suggestion: **Slate** or personal preference. Use `.kv-grid` for structured data.
Consider a two-column layout for compact CVs. The candidate's name should carry visual weight —
`.header-large-numeral` or `.header-typeset` both work well; the example below uses a bare h1
with custom sizing, but try `<div class="header-large-numeral"><h1>...</h1></div>` for a more
statement opener.

```html
<h1 style="margin-bottom: 2mm;">Full Name</h1>
<p class="subtitle">Title / Role / Tagline</p>

<p class="meta">
  email@example.com · +47 123 45 678 · Oslo, Norway · linkedin.com/in/username
</p>

<hr>

<h2>Summary</h2>
<p>Two to three sentences capturing your profile, experience level, and what you bring.</p>

<h2>Experience</h2>

<div class="no-break">
  <h3 style="margin-bottom: 0;">Job Title — Company Name</h3>
  <p class="meta" style="margin-bottom: 2mm;">Jan 2023 – Present · Location</p>
  <p>Description of role, responsibilities, and key achievements. Focus on impact and outcomes.</p>
</div>

<div class="no-break">
  <h3 style="margin-bottom: 0;">Previous Job Title — Previous Company</h3>
  <p class="meta" style="margin-bottom: 2mm;">Jun 2020 – Dec 2022 · Location</p>
  <p>Description...</p>
</div>

<h2>Education</h2>
<div class="no-break">
  <h3 style="margin-bottom: 0;">Degree — Institution</h3>
  <p class="meta">2016 – 2020</p>
</div>

<h2>Skills</h2>
<p>Skill 1 · Skill 2 · Skill 3 · Skill 4 · Skill 5</p>
```
