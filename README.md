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

## Bootstrap (do this once, before the first real `tofu plan`)

1. **Create the R2 bucket.** `backend.tf` currently points at a
   placeholder bucket name, `tbxkit-tofu-state` — create (or rename to)
   whatever bucket you actually want, and update `backend.tf` to match.
2. **R2 API token.** Needs Object Read & Write on that bucket. Set:
   ```
   AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
   AWS_ACCESS_KEY_ID=<R2 token access key>
   AWS_SECRET_ACCESS_KEY=<R2 token secret>
   ```
3. **GitHub token.** `providers.tf` takes no committed credentials — the
   provider resolves a token from `GITHUB_TOKEN`, a GitHub App, or
   `gh auth token` (see hephaistos-rs's pattern). For local use, an
   authenticated `gh` CLI with at least the `repo` scope is enough (you
   already have this — same token this survey used). Needs
   Administration **read** (read-only is enough until PR 2 needs write).
4. **State passphrase.** Set `TF_VAR_state_passphrase` to a passphrase of
   16+ characters, kept in a password manager. Lose it and the state
   becomes unreadable.
5. **Run the first plan:**
   ```bash
   tofu init
   tofu fmt -check
   tofu validate
   tofu plan -lock=false
   ```
   This plan **must show only imports** — `0 to add, 0 to change, 0 to
   destroy`. If it shows a real change, something in one of the `.tf`
   files doesn't match live GitHub; fix the file, not the expectation.
6. Once the plan is clean, apply it (locally this first time, since there's
   no CI yet): `tofu apply`. After this, the `import` blocks can be
   removed in a follow-up — state remembers what it adopted.

## Before the bootstrap: what was validated instead

No backend or token was available while writing this PR, so only
backend-free checks ran:
```bash
tofu init -backend=false
tofu fmt -check
tofu validate
```
No `tofu plan` was run — there's no backend configured yet and no R2
credentials in this environment. See the PR description for the actual
output.

## Follow-up (PR 2)

Once this PR is applied and the import blocks are removed:
- Add `members.tf`, `teams.tf`, `reviewers.tf` (tbxkit's own people and
  review requirements — none of hephaistos-rs's transfer).
- Add a `default-branch` `github_repository_ruleset` to every repository,
  computed from the above, same as hephaistos-rs.
- Add CI (`plan`/`apply` workflows) so applies happen on merge instead of
  locally.

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