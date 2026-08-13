$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = (Get-ChildItem -LiteralPath $root -Filter "relay_v1*.txt" | Select-Object -First 1).FullName
if (-not $sourcePath) {
    throw "Cannot find RelayBot source file."
}
$source = Get-Content -Raw -LiteralPath $sourcePath

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text.Contains($Pattern)) {
        throw $Message
    }
}

Assert-Contains `
    -Text $source `
    -Pattern 'const VERSION = "V1\.0";' `
    -Message "RelayBot must carry the V1.0 version label only."

Assert-Contains `
    -Text $source `
    -Pattern 'if\s*\(!KV\)\s*\{\s*return new Response\("KV binding missing", \{ status: 500 \}\);\s*\}' `
    -Message "RelayBot must fail fast with HTTP 500 when the KV binding is missing."

if (
    $source -notmatch 'throw new Error' -or
    $source -notmatch 'heal retry forward not delivered' -or
    $source -notmatch 'retryErr\.desc'
) {
    throw "RelayBot must not silently stamp an update as done after a non-ok heal retry forward."
}

if (
    -not $source.Contains('const verifyPromptRes = await tg("sendMessage"') -or
    -not $source.Contains('verify code send failed')
) {
    throw "RelayBot must fail the update when sending the verification code fails."
}

if (
    -not $source.Contains('function errorLogPrefix()') -or
    -not $source.Contains('await KV.put(errorLogEntryKey(level, text), entry') -or
    -not $source.Contains('await KV.list({ prefix: errorLogPrefix()')
) {
    throw "RelayBot must store each error log entry in its own KV key."
}

if (
    -not $source.Contains('export function verifyTextWithCode') -or
    -not $source.Contains('if (codeAt < 0)') -or
    -not $source.Contains('type: "code"')
) {
    throw "RelayBot must provide a code-entity helper for the verification code."
}

if (
    -not $source.Contains('const raw = await res.text();') -or
    -not $source.Contains('JSON.parse(raw)') -or
    -not $source.Contains('Telegram 非 JSON 响应')
) {
    throw "RelayBot must tolerate non-JSON Telegram responses."
}

$removed = @(
    "1701",
    "NAV_ITEMS",
    "NAV_PANEL_TEXT",
    "ADMIN_NAV",
    "panel_nav",
    "811730.com",
    "私人导航"
)
foreach ($item in $removed) {
    Assert-NotContains `
        -Text $source `
        -Pattern $item `
        -Message "RelayBot must not contain removed private/branded code: $item"
}

$helpAt = $source.IndexOf('callback_data: "panel_help"')
$errorsAt = $source.IndexOf('callback_data: "panel_errors"')
$statusAt = $source.IndexOf('callback_data: "panel_status"')
if ($helpAt -lt 0 -or $errorsAt -lt 0 -or $statusAt -lt 0) {
    throw "RelayBot control panel must keep help, errors and status buttons."
}
if ($helpAt -ge $errorsAt) {
    throw "RelayBot control panel must put help before errors."
}
if ($statusAt -le $errorsAt) {
    throw "RelayBot control panel must put status as the bottom button."
}

Write-Host "RelayBot v1 static checks passed."
