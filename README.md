# Moms App

A small personal audiobook library. Digest a **public-domain** audiobook from the
Internet Archive / LibriVox into a tidy record — cover, metadata, and its chapters
stitched into one file — then play it in the browser with chapter-jump markers.

Built as a Studio-engine satellite (passwordless auth, theme, error logging).

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

Open http://localhost:3600 and sign in at `/login` (magic link — captured locally
at `/_studio/local_emails` in development).

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
