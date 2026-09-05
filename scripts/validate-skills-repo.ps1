$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path ".").Path
$searchRoots = @(
  $repoRoot,
  (Join-Path $repoRoot "skills"),
  (Join-Path $repoRoot ".skills")
)

$skillFiles = @()
foreach ($searchRoot in $searchRoots) {
  if (-not (Test-Path $searchRoot)) {
    continue
  }

  $skillFiles += Get-ChildItem -Path $searchRoot -Directory | ForEach-Object {
    $candidate = Join-Path $_.FullName "SKILL.md"
    if (Test-Path $candidate) {
      $candidate
    }
  }
}

$skillFiles = $skillFiles | Sort-Object -Unique

if (-not $skillFiles -or $skillFiles.Count -eq 0) {
  Write-Error "No skills discovered. Expected skill folders with SKILL.md at repo root, ./skills, or ./.skills."
  exit 1
}

$errors = @()
foreach ($skillFile in $skillFiles) {
  $content = Get-Content -Path $skillFile -Raw

  if ($content -notmatch "(?ms)^---\s*\r?\n.*?\bname\s*:") {
    $errors += "$skillFile is missing required frontmatter field: name"
  }

  if ($content -notmatch "(?ms)^---\s*\r?\n.*?\bdescription\s*:") {
    $errors += "$skillFile is missing required frontmatter field: description"
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host ("Validated {0} skills." -f $skillFiles.Count)
