# Desired state of tbxkit/sapling.
#
# Imported, not created: values read from the live repository via
# `gh api repos/tbxkit/sapling` on 2026-10-18.

resource "github_repository" "sapling" {
  name        = "sapling"
  description = "Sapling, the twig inspired engine"
  visibility  = "public"

  topics = [] # live repo has no topics set

  has_issues      = true
  has_projects    = true
  has_wiki        = false
  has_discussions = false

  allow_forking               = true
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
  to = github_repository.sapling
  id = "sapling"
}

resource "github_branch_default" "sapling" {
  repository = github_repository.sapling.name
  branch     = "main"
}

import {
  to = github_branch_default.sapling
  id = "sapling"
}
