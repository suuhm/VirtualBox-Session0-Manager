<#
.SYNOPSIS
    VirtualBox Service Dashboard (Session 0 Management)
.DESCRIPTION
    A lightweight PowerShell-based web interface to manage VirtualBox VMs running 
    in a different user context (e.g., Local Service / Session 0).
.AUTHOR
    suuhm - (c) 2026
#>

Add-Type -AssemblyName System.Web

# --- CONFIGURATION ---
$PORT = 8080
$VBOX_MANAGE_EXE = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
# Set current user HOME Path
$loggedInUser = (Get-CimInstance Win32_ComputerSystem).UserName.Split('\')[-1]
$env:VBOX_USER_HOME = "C:\Users\$loggedInUser\.VirtualBox"
# ---------------------

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$PORT/")

try {
    $listener.Start()
    Write-Host "Dashboard active at http://localhost:$PORT" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop."
} catch {
    Write-Host "ERROR: Could not start listener. Check permissions (netsh) or if port is in use." -ForegroundColor Red
    exit
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response
        
        # Parse Parameters
        $params = @{}
        if ($req.Url.Query) {
            $req.Url.Query.Trim('?').Split('&') | ForEach-Object {
                $p = $_.Split('='); if($p.Count -eq 2) { $params[$p[0]] = [System.Web.HttpUtility]::UrlDecode($p[1]) }
            }
        }
        
        $vm = $params["vm"]
        $action = $params["action"]
        $target = $params["target"]
        $statusMsg = ""

        # --- ACTIONS ---
        if ($vm) {
            if ($action -eq "snapshot") {
                $sName = "Manual_$(Get-Date -Format 'yyyyMMdd_HHmm')"
                $statusMsg = & $VBOX_MANAGE_EXE snapshot $vm take $sName --live 2>&1 | Out-String
            }
            elseif ($action -eq "delete" -and $target) {
                $statusMsg = "Deleting snapshot $target (Merging)...`n"
                $statusMsg += & $VBOX_MANAGE_EXE snapshot $vm delete $target 2>&1 | Out-String
            }
        }

        # --- DATA COLLECTION ---
        $allVMs = & $VBOX_MANAGE_EXE list vms
        $runningVMs = & $VBOX_MANAGE_EXE list runningvms
        $snapRows = ""

        if ($vm) {
            $rawSnaps = & $VBOX_MANAGE_EXE snapshot $vm list 2>&1
            if ($rawSnaps -match "does not have any snapshots" -or $rawSnaps.Count -lt 1) {
                $snapRows = "<tr><td colspan='2'>No snapshots found.</td></tr>"
            } else {
                foreach ($line in $rawSnaps) {
                    if ($line -match 'Name: (.*) \(UUID') {
                        $sName = $matches[1].Trim()
                        $vEnc = [System.Web.HttpUtility]::UrlEncode($vm)
                        $tEnc = [System.Web.HttpUtility]::UrlEncode($sName)
                        $snapRows += "<tr><td>$sName</td><td><a class='btn btn-danger' href='?vm=$vEnc&action=delete&target=$tEnc' onclick='return confirm(`"Delete snapshot $sName?`")'>Delete</a></td></tr>"
                    }
                }
            }
        }

        # --- UI DESIGN ---
        $html = @"
<!DOCTYPE html>
<html><head><title>VBox Manager</title><meta charset='UTF-8'><style>
    body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #111; color: #eee; margin: 0; display: flex; height: 100vh; }
    .sidebar { width: 280px; background: #1e1e1e; padding: 20px; border-right: 1px solid #333; overflow-y: auto; }
    .main { flex-grow: 1; padding: 40px; overflow-y: auto; }
    .vm-item { padding: 12px; margin: 8px 0; border-radius: 6px; background: #2d2d2d; text-decoration: none; color: #ccc; display: block; border-left: 4px solid transparent; transition: 0.2s; }
    .vm-item:hover { background: #3d3d3d; color: #fff; }
    .vm-item.active { border-left-color: #0078d4; background: #333; color: #fff; }
    .dot { height: 10px; width: 10px; border-radius: 50%; display: inline-block; margin-right: 10px; }
    .online { background: #28a745; box-shadow: 0 0 8px #28a745; }
    .offline { background: #555; }
    .btn { padding: 8px 16px; text-decoration: none; border-radius: 4px; color: #fff; font-size: 13px; display: inline-block; cursor: pointer; border: none; }
    .btn-primary { background: #0078d4; } .btn-danger { background: #a4262c; }
    table { width: 100%; margin-top: 20px; background: #252526; border-radius: 8px; border-collapse: collapse; }
    th { background: #333; padding: 12px; text-align: left; }
    td { padding: 12px; border-top: 1px solid #333; }
    .output { background: #000; color: #0f0; padding: 15px; border-radius: 6px; font-family: 'Consolas', monospace; margin-top: 20px; border: 1px solid #444; white-space: pre-wrap; }
</style></head><body>
    <div class='sidebar'>
        <h3 style='color:#f4f2dd'>VirtualBox Session0 Manager v.0.1 (c) 2026 suuhm</h3>
        <h2 style='color:#0078d4'>VBox Services:</h2>
        $( $allVMs | ForEach-Object {
            $n = $_.Split('"')[1]
            $dot = if ($runningVMs -match [regex]::Escape($n)) { "online" } else { "offline" }
            $act = if ($vm -eq $n) { "active" } else { "" }
            "<a class='vm-item $act' href='?vm=$([System.Web.HttpUtility]::UrlEncode($n))'><span class='dot $dot'></span>$n</a>"
        } | Out-String )
    </div>
    <div class='main'>
        $( if ($vm) {
            "<h1>VM: $vm</h1>
             <a class='btn btn-primary' href='?vm=$([System.Web.HttpUtility]::UrlEncode($vm))&action=snapshot'>+ Create Live Snapshot</a>
             <table><thead><tr><th>Snapshot Name</th><th>Action</th></tr></thead>
             <tbody>$snapRows</tbody></table>"
        } else { "<h1>Welcome</h1><p>Select a VM from the sidebar to manage snapshots.</p>" } )
        $( if ($statusMsg) { "<h3>Execution Result:</h3><div class='output'>$statusMsg</div>" } )
    </div>
</body></html>
"@
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.Close()
    } catch { 
        Write-Host "Error processing request: $($_.Exception.Message)" 
    }
}
