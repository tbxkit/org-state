#Requires -Version 5.1
<#
  Bootstrap secrets for tbxkit/org-state.

  Run this yourself -- it is NOT meant to be run by Hermes. Prompts for
  each secret with Read-Host -AsSecureString (nothing echoed to the
  screen, nothing written to disk or shell history) and sends it
  straight to the repo or the "apply" environment with `gh secret set`.
  Requires `gh` to be authenticated already (`gh auth status`).

  Level matters here:
    - Repo secrets  -> readable by the PR 'plan' job (same-repo PRs only).
    - "apply" environment secrets -> only readable by the 'apply' job,
      which additionally requires your approval (required reviewer) and
      only runs on main. Put write-capable credentials here, not at the
      repo level, so a PR can never read them.
#>

$ErrorActionPreference = "Stop"
$repo = "tbxkit/org-state"
$applyEnv = "apply"

function Set-GhSecret {
    param(
        [string]$Name,
        [string]$What,
        [string]$Where,
        [string]$Level # "repo" or "environment"
    )

    Write-Host ""
    Write-Host "=== $Name ($Level) ===" -ForegroundColor Cyan
    Write-Host "What it is: $What"
    Write-Host "Where to get it: $Where"

    $secure = Read-Host -Prompt "Paste value for $Name" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    if ([string]::IsNullOrWhiteSpace($plain)) {
        Write-Host "Empty value, skipping $Name." -ForegroundColor Yellow
        return
    }

    if ($Level -eq "environment") {
        $plain | gh secret set $Name --repo $repo --env $applyEnv
    } else {
        $plain | gh secret set $Name --repo $repo
    }
    Write-Host "Set $Name at $Level level." -ForegroundColor Green

    # Best-effort scrub of the plaintext variable. PowerShell strings are
    # immutable so this doesn't guarantee the memory is overwritten, but
    # it drops the only reference to it as soon as possible.
    $plain = $null
}

Write-Host "Bootstrapping secrets for $repo" -ForegroundColor Magenta
Write-Host "Checking gh auth..."
gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "gh is not authenticated. Run 'gh auth login' first."
}

Write-Host ""
Write-Host "--- Repo secrets (used by 'plan' on PRs) ---" -ForegroundColor Magenta

Set-GhSecret -Name "GH_READ_TOKEN" -Level "repo" `
    -What "Fine-grained GitHub PAT, read-only. Used by the PR 'plan' job to read live repo settings." `
    -Where "github.com -> Settings -> Developer settings -> Fine-grained tokens -> Generate new token. Resource owner: tbxkit. Repository access: All repositories (current and future). Permissions: Administration = Read-only, Metadata = Read-only."

Set-GhSecret -Name "R2_READ_ACCESS_KEY_ID" -Level "repo" `
    -What "Access key ID for the R2 API token (Object Read & Write). Same value goes into R2_WRITE_ACCESS_KEY_ID below -- one token, reused, matching hephaistos-rs/org-state. See backend.tf for the trade-off." `
    -Where "Cloudflare dashboard -> R2 -> Manage API tokens -> Create API token. Permissions: Object Read & Write. Scope to the 'tbxkit-tofu-state' bucket specifically, not account-wide, if the dashboard offers that option."

Set-GhSecret -Name "R2_READ_SECRET_ACCESS_KEY" -Level "repo" `
    -What "Secret access key for the SAME token as above -- shown once at creation time. Same value also goes into R2_WRITE_SECRET_ACCESS_KEY below." `
    -Where "Same Cloudflare dashboard screen as R2_READ_ACCESS_KEY_ID; copy both at the same time, you won't see the secret again."

Write-Host ""
Write-Host "Note: R2_ENDPOINT and TOFU_STATE_PASSPHRASE were already set directly." -ForegroundColor Yellow
Write-Host "If either is missing, set it the same way as the others above (repo level)." -ForegroundColor Yellow

Write-Host ""
Write-Host "--- `"apply`" environment secrets (only the gated apply job, requires your approval) ---" -ForegroundColor Magenta

Set-GhSecret -Name "GH_APPLY_TOKEN" -Level "environment" `
    -What "Fine-grained GitHub PAT, read+write. Used by the 'apply' job on main to actually change repo settings." `
    -Where "Same place as GH_READ_TOKEN, a SEPARATE token. Resource owner: tbxkit. Repository access: All repositories (current and future). Permissions: Administration = Read and write, Metadata = Read-only."

Set-GhSecret -Name "R2_WRITE_ACCESS_KEY_ID" -Level "environment" `
    -What "Same R2 API token's access key ID as R2_READ_ACCESS_KEY_ID above -- paste the identical value here." `
    -Where "The same Cloudflare R2 token you already created above (Object Read & Write, scoped to 'tbxkit-tofu-state'). Not a separate token."

Set-GhSecret -Name "R2_WRITE_SECRET_ACCESS_KEY" -Level "environment" `
    -What "Same R2 API token's secret access key as R2_READ_SECRET_ACCESS_KEY above -- paste the identical value here." `
    -Where "Same token, same values as R2_READ_SECRET_ACCESS_KEY."

Write-Host ""
Write-Host "Done. Verify with:" -ForegroundColor Magenta
Write-Host "  gh secret list --repo $repo"
Write-Host "  gh secret list --repo $repo --env $applyEnv"
