# PrayerAsks Demo - Build Tracker

**Spec:** [`prayerasks-demo-spec.md`](prayerasks-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh prayerasks "PrayerAsks" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)`, layout fallback name, slate/candle accent CSS, landing page with crisis line | `[x]` |
| 2 | Models: `Ask`, `AskDraft` migrations, validations, constants, associations | `[x]` |
| 3 | Routes and controllers: `AsksController` CRUD, `AskDraftsController` (rate limit, CrisisError first, rescues), placeholder dashboard removed | `[x]` |
| 4 | Views and Stimulus: dashboard, form, ask page, result page, `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `prayerasks_ask_v1` prompt, parser (body length, 3 answers, own date only), `NoPrayerCheck` | `[x]` |
| 6 | Seeds: template, fictional Fernbrook example ask with a completed draft, `demo_placeholder_v1` removed (seed, case file, guards entry, DB row) | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml` (questiontap crisis terms, six required keys), `evals/cases/prayerasks_ask_v1.yml` (8 cases) | `[x]` |
| 8 | Specs: models, `NoPrayerCheck`, seeds, requests incl. unstubbed crisis; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3129, crisis_field), pre-publish check, local commit | `[x]` |

## Quick reference

```
asks_path                     GET  /asks   (also /dashboard)
new_ask_path                  GET  /asks/new
ask_path(a)                   GET  /asks/:id
edit_ask_path(a)              GET  /asks/:id/edit
ask_drafts_path(a)            POST /asks/:id/drafts      ("Help me say this")
ask_draft_path(a, d)          GET  /asks/:id/drafts/:id
```

```
Template:   prayerasks_ask_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.4)
Variables:  vocabulary, asking_for, moment_on, visibility, input_length, whats_going_on
JSON:       reworded_ask{title, body <= input}, what_changed, moment{name, occurs_on}|null,
            practical_help_ideas[0-3]{idea, why}, outcome_question{question, answers[3]}, privacy_flags[0-6]
Code rules: NoPrayerCheck, body length, exactly 3 answers, member's own date only
Crisis:     crisis_terms → CrisisError → 988, no AI call
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-prayerasks` (real Gemini calls). The free journeys (`--free`: guard and crisis) start a server, so they were not run by the build agent either.
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
