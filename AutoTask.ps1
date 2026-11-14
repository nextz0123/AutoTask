\xEF\xBB\xBF# ============================================================
#  AutoTask by Kanji  -  painel de instalação (Vencord + QuestSpoofer)
#  Uso:  powershell -ExecutionPolicy Bypass -File .\AutoTask.ps1
# ============================================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$esc = [char]27

# Ativa as cores ANSI também no PowerShell/conhost antigo
try {
    Add-Type -Namespace Win32 -Name Con -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@ -ErrorAction SilentlyContinue
    $h = [Win32.Con]::GetStdHandle(-11)
    [uint32]$mode = 0
    [void][Win32.Con]::GetConsoleMode($h, [ref]$mode)
    [void][Win32.Con]::SetConsoleMode($h, ($mode -bor 4))
} catch {}
$Host.UI.RawUI.WindowTitle = "AutoTask by Kanji"

# ---------- Configuração ----------
$PluginRepo  = "https://github.com/nextz0123/AutoTask.git"
$VencordDir  = Join-Path $HOME "Documents\Vencord"
$PluginName  = "completeQuests"
$PluginDir   = Join-Path $VencordDir "src\userplugins\$PluginName"
$PluginFiles = @("index.ts", "script.ts", "settings.ts", "updateChecker.ts")

# ---------- Cores (RGB) ----------
$cA     = @(168, 85, 247)    # roxo
$cB     = @(34, 211, 238)    # ciano
$cBord  = @(110, 90, 170)
$cDim   = @(140, 140, 165)
$cWhite = @(235, 235, 245)
$cOk    = @(74, 222, 128)
$cBad   = @(248, 113, 113)

$cw = $Host.UI.RawUI.WindowSize.Width
$W  = [Math]::Min(92, $cw - 2)

function C($rgb, [string]$text) { "$esc[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m$text$esc[0m" }
function Lerp($a, $b, $t) { [int]($a + ($b - $a) * $t) }
function Grad([string]$text, $c1, $c2, [double]$phase = -1) {
    $n = [Math]::Max($text.Length - 1, 1)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($ch -eq ' ') { [void]$sb.Append(' '); continue }
        $t = $i / $n
        if ($phase -ge 0) { $t = [Math]::Abs(2 * ((($i / $n) + $phase) % 1.0) - 1) }
        $r = Lerp $c1[0] $c2[0] $t; $g = Lerp $c1[1] $c2[1] $t; $b = Lerp $c1[2] $c2[2] $t
        [void]$sb.Append("$esc[38;2;$r;$g;${b}m$ch")
    }
    [void]$sb.Append("$esc[0m")
    $sb.ToString()
}
function Strip([string]$s) { [regex]::Replace($s, "$([char]27)\[[0-9;]*m", "") }

# ---------- Banner ----------
$font = @{
    A = @(" ███ ", "█   █", "█████", "█   █", "█   █")
    U = @("█   █", "█   █", "█   █", "█   █", " ███ ")
    T = @("█████", "  █  ", "  █  ", "  █  ", "  █  ")
    O = @(" ███ ", "█   █", "█   █", "█   █", " ███ ")
    S = @(" ████", "█    ", " ███ ", "    █", "████ ")
    K = @("█   █", "█  █ ", "███  ", "█  █ ", "█   █")
}
function Get-Banner([string]$word) {
    $rows = @()
    for ($r = 0; $r -lt 5; $r++) {
        $line = ""
        foreach ($ch in $word.ToCharArray()) {
            $px = $font["$ch"][$r].ToCharArray() | ForEach-Object { "$_$_" }
            $line += (($px -join "") + " ")
        }
        $rows += $line
    }
    $rows
}
$BannerRows = Get-Banner "AUTOTASK"

# Paleta de cores por coluna (efeito de degradê que se move)
function Get-Pal([int]$len, [double]$phase, [double]$dim) {
    $pal = New-Object 'string[]' $len
    $n = [Math]::Max($len - 1, 1)
    for ($i = 0; $i -lt $len; $i++) {
        $t = [Math]::Abs(2 * ((($i / $n) + $phase) % 1.0) - 1)
        $r = [int](($cA[0] + ($cB[0] - $cA[0]) * $t) * $dim)
        $g = [int](($cA[1] + ($cB[1] - $cA[1]) * $t) * $dim)
        $b = [int](($cA[2] + ($cB[2] - $cA[2]) * $t) * $dim)
        $pal[$i] = "$esc[38;2;$r;$g;${b}m"
    }
    , $pal
}
function Paint([string]$text, $pal) {
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($ch -eq ' ') { [void]$sb.Append(' ') } else { [void]$sb.Append($pal[$i]); [void]$sb.Append($ch) }
    }
    [void]$sb.Append("$esc[0m")
    $sb.ToString()
}

# Gotas a escorrer por baixo das letras (efeito "derretido")
function New-Drips {
    $rng = New-Object System.Random
    $bottom = $BannerRows[4]
    $glyph = @("▓", "▒", "░")
    $rows = 1..3 | ForEach-Object { , ((" " * $bottom.Length).ToCharArray()) }
    for ($x = 0; $x -lt $bottom.Length; $x++) {
        if ($bottom[$x] -eq '█' -and $rng.NextDouble() -lt 0.35) {
            $l = 1 + [int][Math]::Floor($rng.NextDouble() * 3)
            for ($d = 0; $d -lt $l; $d++) { $rows[$d][$x] = [char]$glyph[$d] }
        }
    }
    $script:Drips = @($rows | ForEach-Object { -join $_ })
}
New-Drips
$ShowBanner = ($W -ge 90)

# ---------- Desenho ----------
function Row([string]$colored, [switch]$Center) {
    $len = (Strip $colored).Length
    if ($Center) { $l = [Math]::Floor(($W - $len) / 2); $r = $W - $len - $l }
    else { $l = 2; $r = [Math]::Max($W - $len - 2, 0) }
    (C $cBord "│") + (" " * $l) + $colored + (" " * $r) + (C $cBord "│")
}
function Sep { (C $cBord "├") + (C $cBord ("─" * $W)) + (C $cBord "┤") }

function Get-Status {
    [pscustomobject]@{
        Vencord = (Test-Path (Join-Path $VencordDir ".git"))
        Plugin  = (Test-Path (Join-Path $PluginDir "index.ts"))
        Discord = [bool](Get-Process -Name "Discord*" -ErrorAction SilentlyContinue)
    }
}
function Dot($ok, $yes, $no) {
    if ($ok) { (C $cOk "●") + " " + (C $cWhite $yes) } else { (C $cBad "○") + " " + (C $cDim $no) }
}

$Items = @(
    @{ T = "Instalar tudo";          D = "1ª vez: Vencord + plugin + compilar + injetar" },
    @{ T = "Atualizar plugin";       D = "baixa do GitHub e recompila (sem injetar)" },
    @{ T = "Injetar no Discord";     D = "abre o instalador do Vencord" },
    @{ T = "Abrir pasta do plugin";  D = "mostra os ficheiros no Explorador" },
    @{ T = "Sair";                   D = "fecha o painel" }
)

function Draw([int]$sel, [double]$phase, $s) {
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add((C $cBord "╭") + (C $cBord ("─" * $W)) + (C $cBord "╮"))
    $L.Add((Row ""))
    if ($ShowBanner) {
        $len = $BannerRows[0].Length
        $pal = Get-Pal $len $phase 1.0
        foreach ($row in $BannerRows) { $L.Add((Row (Paint $row $pal) -Center)) }
        $dimLevels = @(0.75, 0.55, 0.35)
        for ($d = 0; $d -lt 3; $d++) {
            $palD = Get-Pal $len $phase $dimLevels[$d]
            $L.Add((Row (Paint $Drips[$d] $palD) -Center))
        }
    } else {
        $L.Add((Row (Grad "A U T O T A S K" $cA $cB $phase) -Center))
    }
    $L.Add((Row ""))
    $L.Add((Row ((C $cDim "─────  ") + (Grad "by Kanji" $cB $cA $phase) + (C $cDim "  ─────")) -Center))
    $L.Add((Row (C $cDim "Vencord + QuestSpoofer  ·  instalador automático") -Center))
    $L.Add((Row ""))
    $L.Add((Sep))
    $L.Add((Row ((C $cDim "Vencord ") + (Dot $s.Vencord "instalado" "em falta") + "     " +
                 (C $cDim "Plugin ")  + (Dot $s.Plugin  "instalado" "em falta") + "     " +
                 (C $cDim "Discord ") + (Dot $s.Discord "aberto" "fechado"))))
    $L.Add((Sep))
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $n = $i + 1
        $title = $Items[$i].T.PadRight(24)
        $desc = $Items[$i].D
        if ($i -eq $sel) {
            $plain = "  ▸ [$n] $title $desc"
            $plain = $plain.PadRight($W).Substring(0, $W)
            $L.Add((C $cBord "│") + "$esc[48;2;$($cA[0]);$($cA[1]);$($cA[2])m$esc[38;2;255;255;255m$plain$esc[0m" + (C $cBord "│"))
        } else {
            $L.Add((Row ("  " + (C $cDim "[$n]") + " " + (C $cWhite $title) + " " + (C $cDim $desc))))
        }
    }
    $L.Add((Sep))
    $left = "setas mover   enter escolher   1-5 atalho   esc sair"
    $right = "github.com/nextz0123/AutoTask"
    $gap = [Math]::Max($W - 4 - $left.Length - $right.Length, 1)
    $L.Add((Row ((C $cDim $left) + (" " * $gap) + (C $cB $right))))
    $L.Add((C $cBord "╰") + (C $cBord ("─" * $W)) + (C $cBord "╯"))
    Write-Host -NoNewline ("$esc[H" + ($L -join "`n") + "`n$esc[J")
}

# ---------- Ações ----------
function Step($m) { Write-Host ""; Write-Host (Grad "==> $m" $cA $cB) }
function Need($cmd, $hint) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "'$cmd' não encontrado. $hint" }
}
function Run($exe, $argList) {
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { throw "Falhou: $exe $($argList -join ' ')" }
}
function Need-Tools {
    Step "A verificar ferramentas (git, node, pnpm)"
    Need "git"  "Instale em https://git-scm.com/downloads e abra um novo PowerShell."
    Need "node" "Instale o LTS em https://nodejs.org e abra um novo PowerShell."
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Host "pnpm não encontrado, a instalar..."
        Run "npm" @("install", "-g", "pnpm")
    }
}
function Sync-Plugin {
    Step "A descarregar o plugin do GitHub"
    $tmp = Join-Path $env:TEMP "autotask_$(Get-Random)"
    Run "git" @("clone", "--depth", "1", $PluginRepo, $tmp)
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
    foreach ($f in $PluginFiles) {
        $src = Join-Path $tmp $f
        if (-not (Test-Path $src)) { throw "Falta o ficheiro '$f' no repositório." }
        Copy-Item $src $PluginDir -Force
    }
    Remove-Item $tmp -Recurse -Force
}
function Close-Discord {
    Step "A fechar o Discord"
    Get-Process -Name "Discord*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

function Do-InstallAll {
    Need-Tools
    if (Test-Path (Join-Path $VencordDir ".git")) {
        Step "Vencord já existe, a atualizar"
        Push-Location $VencordDir; Run "git" @("pull")
    } else {
        Step "A descarregar o Vencord"
        Run "git" @("clone", "https://github.com/Vendicated/Vencord", $VencordDir)
        Push-Location $VencordDir
    }
    try {
        Step "A instalar dependências (pode demorar uns minutos)"
        Run "pnpm" @("install", "--frozen-lockfile")
        Sync-Plugin
        Step "A compilar"
        Run "pnpm" @("build")
        Close-Discord
        Step "Instalador do Vencord: escolha o Discord e clique em Install"
        Run "pnpm" @("inject")
    } finally { Pop-Location }
    Write-Host ""
    Write-Host (C $cOk "Concluído! Abra o Discord → Definições → Vencord → Plugins → ative 'QuestSpoofer'.")
}
function Do-UpdatePlugin {
    if (-not (Test-Path (Join-Path $VencordDir ".git"))) { throw "Vencord não instalado. Use primeiro 'Instalar tudo'." }
    Need-Tools
    Sync-Plugin
    Push-Location $VencordDir
    try { Step "A compilar"; Run "pnpm" @("build") } finally { Pop-Location }
    Write-Host ""
    Write-Host (C $cOk "Plugin atualizado! No Discord, prima Ctrl+R para recarregar.")
}
function Do-Inject {
    if (-not (Test-Path (Join-Path $VencordDir ".git"))) { throw "Vencord não instalado. Use primeiro 'Instalar tudo'." }
    Need-Tools
    Close-Discord
    Push-Location $VencordDir
    try { Step "Instalador do Vencord: escolha o Discord e clique em Install"; Run "pnpm" @("inject") } finally { Pop-Location }
}
function Do-OpenFolder {
    if (-not (Test-Path $PluginDir)) { throw "A pasta do plugin ainda não existe." }
    Start-Process explorer.exe $PluginDir
}

function Invoke-Action([int]$i) {
    [Console]::CursorVisible = $true
    Clear-Host
    try {
        switch ($i) {
            0 { Do-InstallAll }
            1 { Do-UpdatePlugin }
            2 { Do-Inject }
            3 { Do-OpenFolder }
        }
    } catch {
        Write-Host ""
        Write-Host (C $cBad "Erro: $($_.Exception.Message)")
    }
    Write-Host ""
    Write-Host (C $cDim "Prima qualquer tecla para voltar ao painel...")
    [void][Console]::ReadKey($true)
    [Console]::CursorVisible = $false
    Clear-Host
}

# ---------- Loop principal ----------
[Console]::CursorVisible = $false
Clear-Host
$sel = 0
$phase = 0.0
$tick = 0
$status = Get-Status
:main while ($true) {
    if ($tick % 25 -eq 0) { $status = Get-Status }
    Draw $sel $phase $status
    $phase = ($phase + 0.015) % 1.0
    $tick++
    $act = -1
    if ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            "UpArrow"   { $sel = ($sel + $Items.Count - 1) % $Items.Count }
            "DownArrow" { $sel = ($sel + 1) % $Items.Count }
            "Enter"     { $act = $sel }
            "Escape"    { break main }
            default {
                $d = [string]$k.KeyChar
                if ($d -match '^[1-5]$') { $sel = [int]$d - 1; $act = $sel }
            }
        }
    } else {
        Start-Sleep -Milliseconds 70
    }
    if ($act -ge 0) {
        if ($act -eq 4) { break main }
        Invoke-Action $act
        $status = Get-Status
        New-Drips
    }
}
[Console]::CursorVisible = $true
Clear-Host
Write-Host (Grad "AutoTask by Kanji" $cA $cB)
