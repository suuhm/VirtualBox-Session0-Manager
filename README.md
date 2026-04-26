## VirtualBox-Session0-Manager
A lightweight PowerShell-based web dashboard designed to bridge the gap between Windows Session 0 (Services) and your interactive desktop.
## 🚀 The Problem: Session 0 Isolation
Windows isolates services in Session 0 for security reasons. When VirtualBox runs as a service (e.g., via Local Service), its management process (VBoxSVC.exe) is invisible to your user desktop (Session 1).
The result: Your VirtualBox GUI shows VMs as "Powered Off", even though they are running. Managing snapshots or checking the status becomes a nightmare of command-line tools and permission errors.
## 🛠 The Solution
The VirtualBox-Session0-Manager runs as a tiny web server within the same context as your service. It talks directly to the "hidden" VirtualBox instance and provides a clean, web-based dashboard to:

* Monitor real-time status of all VMs.
* Create Live-Snapshots (including RAM state).
* Delete/Merge snapshots safely.
* Stay Secure: Run everything under the restricted Local Service account.

<img width="1437" height="608" alt="grafik" src="https://github.com/user-attachments/assets/049bd124-756b-4b17-82fa-3e60d7b64ac0" />


------------------------------
## 💻 Installation & Deployment

## 1. Reserve the HTTP Port
Windows prevents service accounts from hosting web servers by default. Open CMD as Administrator and run:

```bash
:: For English Windows:
netsh http add urlacl url=http://+:8080/ user="NT AUTHORITY\LOCAL SERVICE"
```

```bash
:: For German Windows:
netsh http add urlacl url=http://+:8080/ user="NT-AUTORITÄT\LOKALER DIENST"
```

## 2. Setup as a Scheduled Task (Recommended)
To keep the dashboard always available, set it up as a background task:

   1. Create a new Task in Task Scheduler.
   2. User: Set to LOCAL SERVICE.
   3. Trigger: At system startup.
   4. Action: Start a program
   * Program: powershell.exe
      * Arguments: `-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\vbox-session0-manager.ps1"`
   5. Privileges: Enable "Run with highest privileges".

### Oneliner for the ScheduleTask
```bash
schtasks /create /tn "VirtualBox-Session0-Manager" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\vbox-session0-manager.ps1'" /sc onstart /ru "NT AUTHORITY\LOCAL SERVICE" /rl highest /f
```

## Optional: Manual Start (via PsExec)
For debugging or temporary use, you can start the manager manually:

```bash
psexec -s -u "NT AUTHORITY\LOCAL SERVICE" powershell -ExecutionPolicy Bypass -File "C:\vbox-session0-manager.ps1"
```

## Alternative: Service (NSSM)
```powershell
New-Service -Name "VBoxWebDashboard" `
            -BinaryPathName 'powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\vbox-session0-manager.ps1"' `
            -DisplayName "VirtualBox Web Dashboard" `
            -StartupType Automatic `
            -Credential "NT AUTHORITY\Local Service"
```

### NSSM
```bash
nssm install VBoxWebDashboard "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-ExecutionPolicy Bypass -File \"C:\Path\To\vbox-session0-manager.ps1\""
nssm set VBoxWebDashboard ObjectName "NT AUTHORITY\Local Service"
nssm start VBoxWebDashboard
```

## Start and Access via your Browser

`http://127.0.0.1:8080`


------------------------------
## ⚙️ Configuration
The script features an Auto-Discovery mode for your VirtualBox configuration. It scans the C:\Users directory for existing .VirtualBox folders.
If you have a non-standard setup, simply adjust the variable in the script:

```bash
$env:VBOX_USER_HOME = "C:\Custom\Path\.VirtualBox"
```

## 🔒 Security Note
The dashboard listens on port 8080 by default. If your server is exposed to a network, ensure your Windows Firewall only allows trusted IPs to access this port. This tool does not include built-in authentication yet.


