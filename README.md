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
`wrangler r2 bucket create`. Everything else runs in GitHub Actions now,
not locally:

1. **Create two fine-grained GitHub PATs and four R2 API tokens' worth of
   values** — see "Secrets" below for exactly which ones and what
   permissions each needs.
2. **Run `scripts/bootstrap-secrets.ps1` yourself** (not Hermes — it
   prompts with hidden input and sends each value straight to
   `gh secret set`). It tells you what each secret is and where to get
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
5. **Merge.** The `apply` job runs on push to `main` and applies exactly
   the plan it just generated (same destroy/replace safeguard as the PR
   job). After the first successful apply, `import` blocks can be
   removed in a follow-up — state remembers what it adopted.

## Secrets

All plain repository secrets (see "CI" below for why, not environment
secrets). Set with `scripts/bootstrap-secrets.ps1`, verify names only with
`gh secret list --repo tbxkit/org-state`:

| Secret | What | Where |
|---|---|---|
| `GH_READ_TOKEN` | Fine-grained PAT, read-only | GitHub web UI, fine-grained token: Administration = Read-only, Metadata = Read-only, all tbxkit repos |
| `GH_APPLY_TOKEN` | Fine-grained PAT, read+write, separate from the above | Same place: Administration = Read and write, Metadata = Read-only |
| `TOFU_STATE_PASSPHRASE` | 16+ character passphrase, state/plan encryption | You generate it (password manager) |
| `R2_ENDPOINT` | R2 S3-compatible endpoint URL | `https://<account-id>.r2.cloudflarestorage.com` |
| `R2_READ_ACCESS_KEY_ID` / `R2_READ_SECRET_ACCESS_KEY` | R2 token, Object Read only | Cloudflare dashboard -> R2 -> Manage API tokens |
| `R2_WRITE_ACCESS_KEY_ID` / `R2_WRITE_SECRET_ACCESS_KEY` | R2 token, Object Read & Write, separate token from the read one | Same place |

## CI

`.github/workflows/tofu.yml`: `fmt`/`validate` always (no credentials),
`plan` on same-repo PRs (posts the summary comment above), `apply` on
push to `main`. Both `plan` and `apply` refuse to proceed if the plan
would destroy or replace a `github_repository` — that always needs a
human running `tofu apply` locally after explicit review, never a green
check.

**No GitHub Environment gates `apply`.** This repo is private, and the
`tbxkit` org is on GitHub's Free plan — Environments (environment
secrets, required reviewers, wait timers) for a private repository need
GitHub Pro, Team, or Enterprise; Free doesn't offer them at all, not even
an unprotected one. `hephaistos-rs/org-state`'s own `apply` environment
works there because that repo is *public*, where Environments are
available on every plan. Current protection on `apply` here is only:
`main`-only trigger + branch protection (PR + check required to reach
`main`). If this repo is ever made public, or the org upgrades, revisit
adding a real `apply` environment with required-reviewer approval.

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