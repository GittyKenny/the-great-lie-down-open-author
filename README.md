# Instant Author — The Great Lie Down

This deployable prototype wraps the original story in a reusable Instant Author reader.

## What works

- The original finished HTML remains unchanged in `works/the-great-lie-down/original.html`.
- Approved authors appear in an end section beneath the book.
- **Become an author** asks for one name and sends it for owner approval.
- Character name and one combined dedication field update live.
- **Copy edition link** produces a reading link containing the edition values.
- Reaching the end of the story reveals a small **Make your edition** invitation.
- The story is isolated in one iframe, while the reusable interface lives in `instant-author.js`.

## Run locally

Serve this directory with any static web server and open `index.html`. Opening it directly as a `file:` URL is not supported because browsers restrict communication and clipboard features for local files.

## Deploy

Deploy this directory as a static site. No build step is required. The copied edition URL will automatically use the deployed domain.

## Current storage model

Without Supabase configuration, edition values fall back to the shared URL for local testing. With Supabase connected, author requests and editions persist and edition links use short generated identifiers.

## Connect Supabase

1. Run `supabase/instant-author.sql` in the existing Supabase project's SQL editor.
2. At the bottom of that file, replace the example email and run the two commented seed statements.
3. Put the project's URL and public anonymous key in `supabase-config.js`.
4. Use `/admin.html` to sign in as the publication owner and approve, reject or remove names.

The public key is intended for browser use. Row-level security prevents it from accessing owner controls. Never put the service-role key in this project.

## Next phase

1. Add persistent edition routes such as `/the-great-lie-down/e/<slug>`.
2. Add open or approval-based authorship requests.
3. Give each author a private management link or account-based ownership.
4. Add AI reader reviews through a server function. The page should send a work or edition ID and chosen critic persona to the server; API credentials must remain server-side. Saved reviews can be reused instead of paying to regenerate them on every visit.

