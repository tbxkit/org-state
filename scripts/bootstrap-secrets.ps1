#Requires -Version 5.1
<#
  Bootstrap secrets for tbxkit/org-state.

  Run this yourself -- it is NOT meant to be run by Hermes. Prompts for
  each secret with Read-Host -AsSecureString (nothing echoed to the
  screen, nothing written to disk or shell history) and sends it
  straight to the repo with `gh secret set`. Requires `gh` to be
  authenticated already (`gh auth status`).
#>

$ErrorActionPreference = "Stop"
$repo = "tbxkit/org-state"

function Set-RepoSecret {
    param(
        [string]$Name,
        [string]$What,
        [string]$Where
    )

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
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

    $plain | gh secret set $Name --repo $repo
    Write-Host "Set $Name." -ForegroundColor Green

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

Set-RepoSecret -Name "GH_READ_TOKEN" `
    -What "Fine-grained GitHub PAT, read-only. Used by the PR 'plan' job to read live repo settings." `
    -Where "github.com -> Settings -> Developer settings -> Fine-grained tokens -> Generate new token. Resource owner: tbxkit. Repository access: All repositories (current and future). Permissions: Administration = Read-only, Metadata = Read-only."

Set-RepoSecret -Name "GH_APPLY_TOKEN" `
    -What "Fine-grained GitHub PAT, read+write. Used by the 'apply' job on main to actually change repo settings." `
    -Where "Same place as above, a SEPARATE token. Resource owner: tbxkit. Repository access: All repositories (current and future). Permissions: Administration = Read and write, Metadata = Read-only."

Set-RepoSecret -Name "TOFU_STATE_PASSPHRASE" `
    -What "Passphrase OpenTofu uses to encrypt state and plan files (AES-GCM via pbkdf2). Lose it and the state becomes unreadable." `
    -Where "Generate it yourself -- at least 16 characters, e.g. from a password manager's generator. Save a copy in your password manager before pasting it here; it is never stored anywhere else."

Set-RepoSecret -Name "R2_ENDPOINT" `
    -What "The S3-compatible endpoint URL for your Cloudflare R2 account." `
    -Where "https://37714ea3e61c0dab57a5197edd48ecbd.r2.cloudflarestorage.com -- your account ID from 'wrangler whoami', already known from today's bucket creation."

Set-RepoSecret -Name "R2_READ_ACCESS_KEY_ID" `
    -What "Access key ID for a READ-ONLY R2 API token, used by PR plan jobs." `
    -Where "Cloudflare dashboard -> R2 -> Manage API tokens -> Create API token. Permissions: Object Read only. Scope to the 'tbxkit-tofu-state' bucket specifically, not account-wide, if the dashboard offers that option."

Set-RepoSecret -Name "R2_READ_SECRET_ACCESS_KEY" `
    -What "Secret access key for the SAME read-only R2 token as above -- shown once at creation time." `
    -Where "Same Cloudflare dashboard screen as R2_READ_ACCESS_KEY_ID; copy both at the same time, you won't see the secret again."

Set-RepoSecret -Name "R2_WRITE_ACCESS_KEY_ID" `
    -What "Access key ID for a READ+WRITE R2 API token, used by the apply job on main." `
    -Where "Cloudflare dashboard -> R2 -> Manage API tokens -> Create API token (a SEPARATE token from the read one). Permissions: Object Read & Write. Scope to 'tbxkit-tofu-state' if possible."

Set-RepoSecret -Name "R2_WRITE_SECRET_ACCESS_KEY" `
    -What "Secret access key for the SAME read+write R2 token as above." `
    -Where "Same Cloudflare dashboard screen as R2_WRITE_ACCESS_KEY_ID."

Write-Host ""
Write-Host "Done. Verify with: gh secret list --repo $repo" -ForegroundColor Magenta
