# Desired state of tbxkit/org-state — this repository.
#
# Bootstrapping note (mirrors hephaistos-rs/org-state's own org-state.tf):
# the repository was created manually first (`gh repo create
# tbxkit/org-state --private --add-readme`), as a one-time Git-rules
# exception, because OpenTofu can't create the repository its own config
# is pushed to. From here on it's managed exactly like the others: changes
# go through this file, reviewed the same way.
#
# Imported, not created: values read from the live repository via
# `gh api repos/tbxkit/org-state` on 2026-10-18.

resource "github_repository" "org_state" {
  name = "org-state"
  # TODO(damian): GitHub returns description = null even though
  # `gh repo create` was given a --description string at creation time —
  # worth checking whether it actually took; set explicitly on GitHub and
  # fill in here if not.
  visibility = "public" # made public 2026-10-18 to use a GitHub Environment
  # for a required-reviewer apply gate -- see README "CI". Matches
  # hephaistos-rs/org-state, which is public for the same reason.

  topics = []

  has_issues      = true
  has_projects    = true
  has_wiki        = false
  has_discussions = false

  allow_forking               = true # GitHub sets this true automatically on a public repo
  web_commit_signoff_required = false

  allow_merge_commit = true
  allow_squash_merge = true
  allow_rebase_merge = true
  allow_auto_merge   = false

  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"

  delete_branch_on_merge = false
  allow_update_branch    = false

  archived           = false
  archive_on_destroy = true # if this resource is ever destroyed, archive rather than delete

  lifecycle {
    prevent_destroy = true # see README.md "Lifecycle safety policy" before removing
  }
}

import {
  to = github_repository.org_state
  id = "org-state"
}

resource "github_branch_default" "org_state" {
  repository = github_repository.org_state.name
  branch     = "main"
}

import {
  to = github_branch_default.org_state
  id = "org-state"
}
