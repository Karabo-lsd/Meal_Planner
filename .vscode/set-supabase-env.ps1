$ErrorActionPreference = 'Stop'

Write-Host 'Set Supabase environment variables (user scope + current shell)'
Write-Host ''

$url = Read-Host 'Enter SUPABASE_URL (example: https://your-project-ref.supabase.co)'
if ([string]::IsNullOrWhiteSpace($url)) {
  throw 'SUPABASE_URL cannot be empty.'
}

try {
  $uri = [Uri]$url
  if (-not ($uri.Scheme -in @('https', 'http')) -or [string]::IsNullOrWhiteSpace($uri.Host)) {
    throw 'Invalid URL format.'
  }
} catch {
  throw 'Invalid SUPABASE_URL. Expected format: https://<project-ref>.supabase.co'
}

$secureAnon = Read-Host 'Enter SUPABASE_ANON_KEY' -AsSecureString
$anonPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureAnon)
try {
  $anon = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($anonPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($anonPtr)
}

if ([string]::IsNullOrWhiteSpace($anon)) {
  throw 'SUPABASE_ANON_KEY cannot be empty.'
}

$secureLocalAnon = Read-Host 'Enter SUPABASE_LOCAL_ANON_KEY (optional, press Enter to reuse cloud key)' -AsSecureString
$localAnonPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureLocalAnon)
try {
  $localAnon = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($localAnonPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($localAnonPtr)
}

if ([string]::IsNullOrWhiteSpace($localAnon)) {
  $localAnon = $anon
}

$secureSpoonacular = Read-Host 'Enter SPOONACULAR_API_KEY (optional, press Enter to skip)' -AsSecureString
$spoonPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSpoonacular)
try {
  $spoon = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($spoonPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($spoonPtr)
}

# Set for current shell
$env:SUPABASE_URL = $url
$env:SUPABASE_ANON_KEY = $anon
$env:SUPABASE_LOCAL_ANON_KEY = $localAnon
if (-not [string]::IsNullOrWhiteSpace($spoon)) {
  $env:SPOONACULAR_API_KEY = $spoon
}

# Persist for future shells (user profile)
setx SUPABASE_URL $url | Out-Null
setx SUPABASE_ANON_KEY $anon | Out-Null
setx SUPABASE_LOCAL_ANON_KEY $localAnon | Out-Null
if (-not [string]::IsNullOrWhiteSpace($spoon)) {
  setx SPOONACULAR_API_KEY $spoon | Out-Null
}

Write-Host ''
Write-Host 'Done. Environment variables are set for this shell and future sessions.'
Write-Host 'Restart VS Code to ensure launch configs pick up new values.'
