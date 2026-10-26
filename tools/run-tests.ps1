[CmdletBinding()]
param(
    [string]$GodotPath,
    [string]$Suite,
    [string]$Test,
    [switch]$ShowWindow,
    [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$projectRoot = Split-Path -Parent $PSScriptRoot
$previousLocation = Get-Location
$savedEnvironment = @{}
foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'KKU_TEST_SANDBOX', 'KKU_TEST_RESULTS')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$exitCode = 2

function Encode-Html([object]$value) {
    [System.Net.WebUtility]::HtmlEncode([string]$value)
}

try {
    Set-Location -LiteralPath $projectRoot
    if (-not $GodotPath) {
        $candidates = @($env:GODOT_EXE, (Join-Path $projectRoot 'tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'))
        foreach ($command in @('godot', 'godot4', 'godot_console')) {
            $found = Get-Command $command -ErrorAction SilentlyContinue
            if ($found) { $candidates += $found.Source }
        }
        $GodotPath = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    }
    if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw 'Godot was not found. Run with -GodotPath "C:\path\Godot_console.exe" or set GODOT_EXE.'
    }
    $GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
    $version = (& $GodotPath --version | Select-Object -First 1)
    if ($version -notmatch '^4\.(\d+)' -or [int]$Matches[1] -lt 7) {
        throw "This project uses Godot 4.7 scene files. Select Godot 4.7+ with -GodotPath. Found: $version"
    }
    $resultsRoot = Join-Path $projectRoot 'test-results'
    $resultsRoot = Join-Path $resultsRoot 'player-flow'
    New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $resultsRoot '.gdignore') -Value '' -Encoding UTF8
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $runPath = Join-Path $resultsRoot $stamp
    $sandbox = Join-Path $runPath 'sandbox'
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    $env:APPDATA = $sandbox
    $env:LOCALAPPDATA = $sandbox
    $env:KKU_TEST_SANDBOX = $sandbox
    $env:KKU_TEST_RESULTS = $runPath
    Write-Host "Engine: $GodotPath"
    Write-Host "Results: $runPath"
    Write-Host 'Test data is isolated from your normal game saves.' -ForegroundColor Cyan
    # PowerShell 5.1 treats native stderr as error records; Godot writes engine
    # diagnostics there. Preserve them in the log and use exit codes + reports.
    $ErrorActionPreference = 'Continue'
    & $GodotPath --headless --path $projectRoot --editor --import --quit 2>&1 |
        Tee-Object -FilePath (Join-Path $runPath 'import.log') | Out-Null
    $importExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($importExit -ne 0) { throw "Godot import failed ($importExit). See import.log." }

    $arguments = @('--path', $projectRoot, '--script', 'res://addons/gut/gut_cmdln.gd', '-gexit', ('-gjunit_xml_file=' + (Join-Path $runPath 'junit.xml')))
    $arguments += '-gconfig=res://.gutconfig.json'
    if ($ShowWindow) { $arguments += @('--windowed', '--resolution', '1100x720', '--rendering-method', 'gl_compatibility') }
    else { $arguments += '--headless' }
    if ($Suite) { $arguments += "-gselect=$Suite" }
    if ($Test) { $arguments += "-gunit_test_name=$Test" }
    $ErrorActionPreference = 'Continue'
    & $GodotPath @arguments 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -FilePath (Join-Path $runPath 'console.log')
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $logPath = Join-Path $runPath 'console.log'
    $utf8Log = Get-Content -LiteralPath $logPath -Raw
    Set-Content -LiteralPath $logPath -Value $utf8Log -Encoding UTF8
    $jsonPath = Join-Path $runPath 'results.json'
    if (-not (Test-Path -LiteralPath $jsonPath)) { throw 'No test report was produced. Check import.log and console.log; this run is not a pass.' }
    $result = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $totals = $result.test_scripts.props
    $expectedCount = 0
    foreach ($sourceFile in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests\play') -Filter 'test_*.gd') {
        if ($Suite -and -not $sourceFile.Name.Contains($Suite)) { continue }
        $source = Get-Content -LiteralPath $sourceFile.FullName -Raw -Encoding UTF8
        foreach ($match in [regex]::Matches($source, '(?m)^func (test_[A-Za-z0-9_]+)\(')) {
            if (-not $Test -or $match.Groups[1].Value.Contains($Test)) { $expectedCount++ }
        }
    }
    $consoleText = Get-Content -LiteralPath (Join-Path $runPath 'console.log') -Raw -Encoding UTF8
    $scriptErrors = @([regex]::Matches($consoleText, '(?m)^SCRIPT ERROR:.*$') | ForEach-Object { $_.Value })
    $engineErrors = @([regex]::Matches($consoleText, '(?m)^ERROR:.*$') | ForEach-Object { $_.Value })
    $engineWarnings = @([regex]::Matches($consoleText, '(?m)^WARNING:.*$') | ForEach-Object { $_.Value })
    if ($scriptErrors.Count -gt 0 -or $engineErrors.Count -gt 0) { $exitCode = 2 }
    if ($totals.tests -eq 0 -or $totals.tests -ne $expectedCount) { $exitCode = 2 }
    if ($totals.failures -gt 0 -or $totals.errors -gt 0 -or $totals.risky -gt 0 -or $totals.pending -gt 0) { $exitCode = 1 }
    $catalog = @{}
    $coverageNote = ''
    # Report labels and the guide are optional; the test runner also works
    # when only test scripts, runner and result files are checked out.
    $planPath = Join-Path $projectRoot 'docs/testing/player-flow-test-plan.json'
    if (Test-Path -LiteralPath $planPath) {
        $planData = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($planned in $planData.cases) { $catalog[$planned.id.Replace('-', '_')] = $planned }
    }
    $guidePath = Join-Path $projectRoot 'tests/README.md'
    if (Test-Path -LiteralPath $guidePath) {
        Copy-Item -LiteralPath $guidePath -Destination (Join-Path $runPath 'coverage.md')
        Copy-Item -LiteralPath (Join-Path $runPath 'coverage.md') -Destination (Join-Path $resultsRoot 'coverage.md')
    }
    $coverageNote = '<p>ชุด 68 กรณีจากเส้นทางเล่นจริง ผล pass ยืนยันส่วนอัตโนมัติ ใช้ GUT เรียกสัญญาณปุ่มและตัวจัดการอินพุตของฉากจริง ควบคุมระยะเข้าใช้สถานที่ เวลา และ seed เพื่อรันซ้ำได้ การตรวจการเดินหลบสิ่งกีดขวาง ภาพ เสียงที่ได้ยิน และโหมดจอจริงอยู่นอกขอบเขตชุดนี้ ไม่มีกรณีรอตรวจด้วยคน</p>'
    if (Test-Path -LiteralPath (Join-Path $runPath 'coverage.md')) {
        $coverageNote += '<p><a href="coverage.md">ขอบเขตและวิธีตรวจเพิ่มเติม</a></p>'
    }
    $rows = New-Object System.Text.StringBuilder
    foreach ($script in $result.test_scripts.scripts.PSObject.Properties) {
        foreach ($case in $script.Value.tests.PSObject.Properties) {
            $testResult = $case.Value
            $details = @($testResult.failing) + @($testResult.pending)
            $class = if ($testResult.status -eq 'pass') { 'pass' } elseif ($testResult.pending.Count -gt 0) { 'pending' } else { 'fail' }
            $displayName = $case.Name
            $displayGroup = $script.Name -replace '.*/',''
            if ($case.Name -match '^test_(PLAY_[A-Z]+_[0-9]+)_') {
                $key = $Matches[1]
                if ($catalog.ContainsKey($key)) {
                    $displayName = $key.Replace('_', '-') + ' — ' + $catalog[$key].title + ' (' + $case.Name + ')'
                    $displayGroup = $catalog[$key].group
                }
            }
            [void]$rows.Append("<tr class='$class'><td>$(Encode-Html $displayGroup)</td><td>$(Encode-Html $displayName)</td><td>$(Encode-Html $testResult.status)</td><td>$(Encode-Html ($details -join "`n"))</td></tr>")
        }
    }
    $summary = "Tests: $($totals.tests)/$expectedCount | Passed: $($totals.passing) | Failed: $($totals.failures) | Script errors: $($scriptErrors.Count) | Engine error lines: $($engineErrors.Count) | Pending: $($totals.pending)"
    $html = @"
    <!doctype html><html lang="th"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>KKU Clash — ผลทดสอบ</title><style>
    body{font:16px Tahoma,sans-serif;background:#faf6ed;color:#33251b;margin:32px}h1{color:#743522}.summary{padding:20px;background:white;border:1px solid #ccbba5;border-radius:12px;font-weight:bold}table{border-collapse:collapse;width:100%;margin-top:20px;background:white}th,td{padding:12px;text-align:left;border:1px solid #ddd;vertical-align:top}td:last-child{white-space:pre-wrap}.fail{background:#ffe7e1}.pending{background:#fff2c6}.pass td:nth-child(3){color:#217342}input{padding:12px;width:min(500px,90%);margin-top:20px}small{color:#665747}a{color:#743522}
    </style><h1>KKU Clash — ผลทดสอบระบบหลัก</h1><div class="summary">$(Encode-Html $summary)</div>
    $coverageNote
    <p>Godot $(Encode-Html $result.engine_version) · Seed $($result.seed) · $(Encode-Html $stamp)</p>
    <p>$(Encode-Html ($scriptErrors -join "`n"))</p>
    <details><summary>ข้อความเตือนและข้อผิดพลาดจาก Godot ($($engineErrors.Count) errors / $($engineWarnings.Count) warnings)</summary><pre>$(Encode-Html ((@($engineErrors) + @($engineWarnings)) -join "`n"))</pre><p>ข้อความระหว่างโหลดฉากหรือปิดโปรแกรมอาจอยู่นอกช่วงนับของ GUT จึงแสดงแยกไว้ตรงนี้ ดูบริบทเต็มใน console.log</p></details>
    <p>ค้นหาชื่อกรณีทดสอบ หรือพิมพ์ fail เพื่อดูรายการที่ไม่ผ่าน รายการไม่ผ่านยังคงไว้ให้รันซ้ำก่อนคุยเรื่องแก้ไข pending หมายถึงยังไม่ได้ตรวจอัตโนมัติ ไม่ใช่ผลผ่าน</p>
    <input id="filter" placeholder="ค้นหากรณีทดสอบ / fail" oninput="document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(this.value.toLowerCase()))">
    <table><thead><tr><th>หมวด</th><th>กรณีทดสอบ</th><th>ผล</th><th>รายละเอียดข้อผิดพลาด / ค่าที่คาดหวังและค่าจริง</th></tr></thead><tbody>$rows</tbody></table>
    <p><a href="console.log">ผลรันฉบับเต็ม</a> · <a href="junit.xml">JUnit XML</a> · <a href="results.json">JSON รวมข้อความ assertion</a></p>
    <small>เป็นการตรวจตรรกะและการทำงานร่วมกันของฉาก ไม่ใช่การรับรองภาพทุกความละเอียดหรือประสิทธิภาพทุกเครื่อง ข้อมูลทดสอบถูกเก็บแยกจากเซฟเกมจริง</small></html>
"@
    $report = Join-Path $runPath 'report.html'
    Set-Content -LiteralPath $report -Value $html -Encoding UTF8
    Copy-Item -LiteralPath $report -Destination (Join-Path $resultsRoot 'latest.html')
    # Keep the latest report's relative links valid.
    foreach ($name in @('console.log', 'junit.xml', 'results.json')) {
        $source = Join-Path $runPath $name
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $resultsRoot $name) }
    }
    Write-Host "`n$summary" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "Report: $report"
    if ($OpenReport) { Start-Process -FilePath $report }
} catch {
    Write-Host "TEST RUN ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 2
} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    Set-Location -LiteralPath $previousLocation
}
exit $exitCode
