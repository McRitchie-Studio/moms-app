# Moms App

A small personal audiobook library. Digest a **public-domain** audiobook from the
Internet Archive / LibriVox into a tidy record — cover, metadata, and its chapters
stitched into one file — then play it in the browser with chapter-jump markers.

Built as a Studio-engine satellite. It also hosts a family **photo slideshow**, and
runs as a **fully public** site (no sign-in) — live at
[karenmcritchie.com](https://karenmcritchie.com).

## Stack

- Ruby 3.3.11 · Rails 8.1 · PostgreSQL
- [`studio-engine`](https://rubygems.org/gems/studio-engine) — auth / theme / components / error logs
- `ffmpeg` (with libmp3lame) — chapter concatenation
- ActiveStorage — cover + stitched audio

## Setup

```bash
bundle install
bin/rails db:prepare          # create + migrate
bin/rails tailwindcss:build
bin/rails db:seed             # seeds the admin + digests the Sherlock Holmes demo
bin/rails server -p 3600
```

Requirements: PostgreSQL running locally and `ffmpeg` on your PATH (`brew install ffmpeg`).

Open http://localhost:3600 — the site is **fully public**, so no sign-in is needed to
browse the photos or play the audiobooks. (The engine's auth machinery is present but
unused.)

## The demo

`bin/rails db:seed` digests **The Adventures of Sherlock Holmes** (LibriVox, read by
Mark F. Smith — public domain): it downloads all 12 chapters and stitches them into
one ~11¼-hour MP3, then serves it at `/books/the-adventures-of-sherlock-holmes`.

The stitched audio is ~648 MB — far above GitHub's file limit — so **media is not
committed**; the seed regenerates it from the public-domain source. That download
takes a few minutes. For a lighter demo (first two chapters only):

```bash
SEED_CHAPTER_LIMIT=2 bin/rails db:seed
```

## Digest another book

Go to `/books/new` and paste any Internet Archive identifier for a LibriVox
recording (e.g. `adventures_sherlockholmes_1007_librivox`). Leave the chapter count
blank for the whole book, or set a number to stitch just the first N chapters.

## How it works

- `Librivox::Client` reads Internet Archive metadata (`app/services/librivox/`) — mock-first, swappable for tests.
- `BookImporter` creates the `Book` + `Chapter` records and attaches the cover.
- `BookStitcher` downloads the included chapters and concatenates them with `ffmpeg`.
- `StitchBookJob` runs the stitch in the background from the web form.

Only public-domain works are supported by design.

## Deployment (production)

Live at **https://karenmcritchie.com** — a fully public family site on Heroku,
reusing the app the domain already pointed at.

| | |
|---|---|
| Heroku app | `obscure-plains-6405` · stack `heroku-24` · Basic web dyno |
| Add-on | `heroku-postgresql:essential-0` (a single database) |
| Buildpack | `heroku/ruby` (ffmpeg deferred — see follow-ups) |
| Storage | ActiveStorage → S3 bucket `moms-app-production` (`us-east-2`) |
| Domain / SSL | name.com CNAMEs (apex + `www`) → the app's `*.herokudns.com` targets; Heroku ACM cert |

**Config vars (Heroku):** `RAILS_MASTER_KEY`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION=us-east-2`, `S3_BUCKET=moms-app-production`, and
`DATABASE_URL` (set by the add-on). AWS creds come from 1Password (`agent.aws`).

**Production config** (`config/environments/production.rb`, `config/database.yml`):
one Postgres for everything — `database.yml` defines `cache`/`queue`/`cable` all
pointing at `DATABASE_URL` (the solid_* gem models eager-load and `connects_to` those
keys), while the app uses `:memory_store` cache + `:async` jobs/cable, so no solid_*
tables are needed. `force_ssl` + `assume_ssl` (Heroku terminates TLS) with a host
allow-list for the domain.

**Redeploy:**

```bash
git push heroku main   # build, then release-phase db:migrate
```

**(Re)seeding the audiobook in prod:** the ~648 MB stitched MP3 is not re-stitched on a
dyno. Populate by running the importer + attaching the already-stitched local file
against the prod DB + S3 from your machine (`RAILS_ENV=production DATABASE_URL=<prod>`
plus the S3 env vars): it imports metadata + cover, then attaches the audio (uploaded
to S3). The one-off script used for the first deploy is in the git history.

**Known follow-ups:**
- **ffmpeg is not on the dyno.** The `heroku-community/apt` + `Aptfile` route pulls a
  huge dependency tree (~10-min builds), so it was dropped for `heroku/ruby` only.
  Playback of already-stitched audio is fine; digesting a *new* book on the live site
  won't stitch until a lean ffmpeg buildpack is added (the `Aptfile` is ready for it).
- **The `Digest a book` form is public** — re-gate it if that matters.
