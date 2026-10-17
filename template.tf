# Desired state of tbxkit/template.
#
# Imported, not created: values read from the live repository via
# `gh api repos/tbxkit/template` on 2026-10-18.

resource "github_repository" "template" {
  name = "template"
  # TODO(damian): GitHub returns description = null (no description set
  # on the live repo). Leaving unset here rather than guessing a value —
  # set one on GitHub first, then fill this in.
  visibility = "public"

  topics = [] # live repo has no topics set

  has_issues      = true
  has_projects    = true
  has_wiki        = true # live repo has the wiki enabled, unlike the others
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
  to = github_repository.template
  id = "template"
}

resource "github_branch_default" "template" {
  repository = github_repository.template.name
  branch     = "main"
}

import {
  to = github_branch_default.template
  id = "template"
}
