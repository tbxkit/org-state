# org-state

**The tbxkit org's GitHub repos, declared in OpenTofu.**

Same pattern as `hephaistos-rs/org-state`: flat `.tf` files at the repo
root (one per managed repository), OpenTofu + the `integrations/github`
provider, state in Cloudflare R2, state and plan encryption enforced. See
the vault note `10-repos/hephaistos-rs/org-state.md` for the full pattern
this was copied from, and what differs here.

## Scope of this PR

**Repositories only.** `headless.tf`, `sapling.tf`, `template.tf`,
`tbxkit.tf`, and `org-state.tf` (this repo manages itself) each declare a
`github_repository` + `github_branch_default`, adopted via `import`
blocks, matching live GitHub settings exactly. This PR changes nothing —
applying it should show only imports, `0 to add, 0 to change, 0 to
destroy`.

**Deliberately not managed yet:** members, teams, reviewers, and
`github_repository_ruleset` (branch protection). hephaistos-rs's pattern
computes required PR approvals from `teams.tf`/`reviewers.tf`, which don't
exist here yet — adding a ruleset without that would mean guessing a
review requirement. This is **PR 2**, not this one: it adds branch
protection to every repository and removes the `import` blocks (once
applied, state remembers what it created, so there's nothing left to
import).

## Bootstrap (do this once)

The R2 bucket (`tbxkit-tofu-state`) already exists, created directly with
`wrangler r2 bucket create`. This repo is public (since 2026-10-18,
specifically to use a GitHub Environment the same way
`hephaistos-rs/org-state` does) and has an `apply` environment requiring
Damian's approval, deployable from `main` only.

1. **Create two fine-grained GitHub PATs and four R2 API tokens' worth of
   values** — see "Secrets" below for exactly which ones, what
   permissions each needs, and which level (repo vs. the `apply`
   environment) each goes at.
2. **Run `scripts/bootstrap-secrets.ps1` yourself** (not Hermes — it
   prompts with hidden input and sends each value to `gh secret set` at
   the right level). It tells you what each secret is and where to get
   it as it goes.
3. **Open a PR** touching any `.tf` file (or just re-run the workflow on
   this one). The `plan` job posts a summary comment: import/add/change/
   destroy/replace counts, plus the full plan in a collapsible block. It
   fails the check outright if the plan would destroy or replace any
   `github_repository`.
4. **Read the plan comment.** The first real plan should show only
   imports — `0 add, 0 change, 0 destroy, 0 replace`. If it shows a real
   change, something in a `.tf` file doesn't match live GitHub; fix the
   file, not the expectation.
5. **Merge.** The `apply` job runs on push to `main`, waits for Damian's
   approval on the `apply` environment, then applies exactly the plan it
   generated (same destroy/replace safeguard as the PR job). After the
   first successful apply, `import` blocks can be removed in a
   follow-up — state remembers what it adopted.

## Secrets

Split by level — see "CI" below for why. Set with
`scripts/bootstrap-secrets.ps1`, verify names only with:
```
gh secret list --repo tbxkit/org-state
gh secret list --repo tbxkit/org-state --env apply
```

**Repo secrets** (readable by the `plan` job on same-repo PRs):

| Secret | What | Where |
|---|---|---|
| `GH_READ_TOKEN` | Fine-grained PAT, read-only | GitHub web UI, fine-grained token: Administration = Read-only, Metadata = Read-only, all tbxkit repos |
| `TOFU_STATE_PASSPHRASE` | 32-character passphrase, state/plan encryption | Generated once, shown to Damian once, saved in his password manager |
| `R2_ENDPOINT` | R2 S3-compatible endpoint URL | `https://<account-id>.r2.cloudflarestorage.com` |
| `R2_READ_ACCESS_KEY_ID` / `R2_READ_SECRET_ACCESS_KEY` | R2 token, Object Read & Write (same token as `R2_WRITE_*` below — see backend.tf) | Cloudflare dashboard -> R2 -> Manage API tokens |

**`apply` environment secrets** (only readable by the gated `apply` job):

| Secret | What | Where |
|---|---|---|
| `GH_APPLY_TOKEN` | Fine-grained PAT, read+write, separate from `GH_READ_TOKEN` | Same place: Administration = Read and write, Metadata = Read-only |
| `R2_WRITE_ACCESS_KEY_ID` / `R2_WRITE_SECRET_ACCESS_KEY` | R2 token, Object Read & Write, separate token from the read one | Cloudflare dashboard -> R2 -> Manage API tokens |

## CI

`.github/workflows/tofu.yml`: `fmt`/`validate` always (no credentials),
`plan` on same-repo PRs (posts the summary comment above), `apply` on
push to `main` behind the `apply` environment. Both `plan` and `apply`
refuse to proceed if the plan would destroy or replace a
`github_repository` — that always needs a human running `tofu apply`
locally after explicit review, never a green check or an approval click.

**`apply` runs behind a GitHub Environment named `apply`:** required
reviewer is Damian, deployable from `main` only. This only works because
the repo is public — GitHub Environments (environment secrets, required
reviewers) aren't available for a private repository below a
Pro/Team/Enterprise plan, and this org is on Free. `hephaistos-rs/org-
state`'s own `apply` environment works the same way, for the same
reason. The environment was created directly via the GitHub API as a
one-time bootstrap exception (same category as creating the repository
itself) — it isn't yet declared in this repo's own `.tf` files; a future
PR could adopt it the same way the repository resources were adopted,
with an `import` block.

## Follow-up (PR 2)

Once this PR is applied and the import blocks are removed:
- Add `members.tf`, `teams.tf`, `reviewers.tf` (tbxkit's own people and
  review requirements — none of hephaistos-rs's transfer).
- Add a `default-branch` `github_repository_ruleset` to every repository,
  computed from the above, same as hephaistos-rs.

## Adding a new repository later

Any new tbxkit repo Damian approves gets its own `<repo-name>.tf` file
here, following the same shape as the existing ones (see
`10-repos/hephaistos-rs/org-state.md` → "How a repo is added" for the
full checklist). New repos are only ever added with explicit permission —
this file doesn't create one speculatively.

## Lifecycle safety policy

Every `github_repository` resource sets:
```hcl
archive_on_destroy = true

lifecycle {
  prevent_destroy = true
}
```
Removing or renaming a resource block produces a blocked plan, not a
deletion — OpenTofu refuses to proceed.