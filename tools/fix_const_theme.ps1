# Removes the `const` keywords that a runtime-switchable theme made invalid.
#
# SparkColors used to be `static const`; it now resolves at runtime, so every
# `const` expression reading it reports "Invalid constant value". Dropping a
# `const` never changes semantics (it only loses compile-time evaluation), so
# this only has to find the right ones.
#
# For each reported position it removes the `const` of EVERY enclosing bracket
# pair that has one: the outermost const is as invalid as the innermost, so
# fixing only the inner one would leave the outer one broken.
param(
    [string]$Workspace = 'D:\workspace\Spark',
    [int]$MaxIterations = 8
)

$ErrorActionPreference = 'Continue'
Set-Location $Workspace

function Get-BracketPairs {
    param([string]$Text)
    $pairs = [System.Collections.Generic.List[object]]::new()
    $stack = [System.Collections.Generic.Stack[int]]::new()
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') {
            $stack.Push($i)
        }
        elseif ($c -eq ')' -or $c -eq ']' -or $c -eq '}') {
            if ($stack.Count -gt 0) {
                $open = $stack.Pop()
                # `const` sits before an identifier (`const BoxDecoration(`), so
                # scan the text preceding the bracket rather than a fixed-width
                # window: everything between the keyword and the bracket must be
                # identifier/generic/whitespace only.
                $windowStart = [Math]::Max(0, $open - 160)
                $prefix = $Text.Substring($windowStart, $open - $windowStart)
                $m = [regex]::Matches($prefix, '\bconst\b[^;:(){}]*$')
                if ($m.Count -gt 0) {
                    $last = $m[$m.Count - 1]
                    $pairs.Add([pscustomobject]@{
                        Open  = $open
                        Close = $i
                        At    = $windowStart + $last.Index
                    })
                }
            }
        }
    }
    return $pairs
}

for ($iter = 1; $iter -le $MaxIterations; $iter++) {
    $out = flutter analyze --no-fatal-warnings 2>&1
    $errs = @($out | Select-String -Pattern 'Invalid constant value')
    if ($errs.Count -eq 0) {
        Write-Output "iteration $iter : no invalid_constant errors remain"
        break
    }

    # Group error positions by file.
    $byFile = @{}
    foreach ($e in $errs) {
        if ($e.Line -match ' - ([^ ]+\.dart):(\d+):(\d+) - ') {
            $rel = $matches[1] -replace '/', '\'
            if (-not $byFile.ContainsKey($rel)) {
                $byFile[$rel] = [System.Collections.Generic.List[object]]::new()
            }
            $byFile[$rel].Add([pscustomobject]@{
                Line = [int]$matches[2]
                Col  = [int]$matches[3]
            })
        }
    }

    Write-Output "iteration $iter : $($errs.Count) error(s) across $($byFile.Count) file(s)"

    foreach ($rel in @($byFile.Keys)) {
        $full = Join-Path $Workspace $rel
        $text = Get-Content -Raw -LiteralPath $full

        $starts = [System.Collections.Generic.List[int]]::new()
        $starts.Add(0)
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($text[$i] -eq "`n") { $starts.Add($i + 1) }
        }

        $pairs = Get-BracketPairs -Text $text

        $removeAt = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($err in $byFile[$rel]) {
            if ($err.Line - 1 -ge $starts.Count) { continue }
            $pos = $starts[$err.Line - 1] + ($err.Col - 1)
            foreach ($p in $pairs) {
                if ($p.Open -lt $pos -and $pos -lt $p.Close) {
                    [void]$removeAt.Add($p.At)
                }
            }
        }

        if ($removeAt.Count -eq 0) {
            Write-Output "  (no enclosing const found in $rel)"
            continue
        }

        $ordered = @($removeAt) | Sort-Object -Descending
        foreach ($at in $ordered) {
            $text = $text.Remove($at, 6)
        }
        Set-Content -LiteralPath $full -Value $text -NoNewline
        Write-Output "  patched $rel ($($ordered.Count) const keyword(s))"
    }
}
