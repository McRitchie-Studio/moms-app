# Moms App

A small personal audiobook library. Digest a **public-domain** audiobook from the
Internet Archive / LibriVox into a tidy record — cover, metadata, and its chapters
stitched into one file — then play it in the browser with chapter-jump markers.

Built as a Studio-engine satellite. It also hosts a family **photo slideshow**, and
runs as a **public** site (nothing to read or play needs a sign-in) — live at
[karenmcritchie.com](https://karenmcritchie.com). Accounts are for family only:
**public signup is closed** (see [Accounts](#accounts)).

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

Open http://localhost:3600 — no sign-in is needed to browse the photos or play the
audiobooks. Signing in (`/login`, by emailed link or Google) is for the family
accounts that already exist; only an admin can digest a book.

## Accounts

Nobody can create their own account. `/signup` redirects to `/login`; a sign-in link
is mailed only to an address that already has an account (an unknown address gets the
same "check your inbox" answer and no email); an unknown Google account is refused.
studio-engine has no setting for this, so the gate lives in this app:
`app/controllers/concerns/closed_signup.rb`, pinned by
`test/integration/closed_signup_test.rb`.

**Adding a family member** is the operator's job, from the console. There is no
invite page:

```bash
heroku run --app moms-app -- bin/rails runner \
  'User.create!(email: "mom@example.com", name: "Mom")'   # add role: "admin" for an admin
```

They then sign in at `/login` with that address, by emailed link or with the Google
account that owns it. `bin/rails db:seed` creates the first admin the same way.

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

Sign in as an admin, go to `/books/new`, and paste any Internet Archive identifier for a LibriVox
recording (e.g. `adventures_sherlockholmes_1007_librivox`). Leave the chapter count
blank for the whole book, or set a number to stitch just the first N chapters.

## How it works

- `Librivox::Client` reads Internet Archive metadata (`app/services/librivox/`) — mock-first, swappable for tests.
- `BookImporter` creates the `Book` + `Chapter` records and attaches the cover.
- `BookStitcher` downloads the included chapters and concatenates them with `ffmpeg`.
- `StitchBookJob` runs the stitch in the background from the web form.
- Every public page ends with the studio-engine site footer (engine ≥ 0.84,
  `studio_site_footer` in the layout). Its facts live in
  `config/initializers/studio.rb`: wordmark, logo, tagline and the navbar's links,
  with no address, map, phone, email, social profiles or legal line.

Only public-domain works are supported by design.

## Deployment (production)

Live at **https://karenmcritchie.com** — a public family site (signup closed) on Heroku,
reusing the app the domain already pointed at.

| | |
|---|---|
| Heroku app | `moms-app` · stack `heroku-24` · Basic web dyno |
| Add-on | `heroku-postgresql:essential-0` (a single database) |
| Buildpack | `heroku/ruby` (ffmpeg deferred — see follow-ups) |
| Storage | ActiveStorage → S3 bucket `moms-app-production` (`us-east-2`); moving to Cloudflare R2 by `ACTIVE_STORAGE_BACKEND` stages (`config/initializers/00_storage_backend.rb`) |
| Domain / SSL | name.com CNAMEs (apex + `www`) → the app's `*.herokudns.com` targets; Heroku ACM cert |

**Config vars (Heroku):** `RAILS_MASTER_KEY`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION=us-east-2`, `S3_BUCKET=moms-app-production`, and
`DATABASE_URL` (set by the add-on). AWS creds come from 1Password (`agent.aws`).
The R2 move adds `ACTIVE_STORAGE_BACKEND` (`s3` default → `mirror_to_r2` →
`mirror_to_s3` → `r2`) and, for any stage but `s3`, `R2_ENDPOINT`,
`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` (1Password `r2.moms-app`). Boot raises if
a non-`s3` stage lacks them, so unset `ACTIVE_STORAGE_BACKEND` in the same
`config:unset` as any `R2_*` var.

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
- **Only an admin can digest a book.** Browsing and listening are public; `/books/new`
  and `POST /books` sit behind `require_admin`.
