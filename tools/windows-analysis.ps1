# Windows Fingerprint Scanner Analysis Script
# Run this script as Administrator on your Windows system

Write-Host "=== Windows Fingerprint Scanner Analysis ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date)"
Write-Host "System: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "This script should be run as Administrator for complete information"
}

Write-Host "=== Device Manager Information ===" -ForegroundColor Yellow
try {
    # Get biometric devices - focus on FPC fingerprint scanners
    $biometricDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -match "fingerprint|biometric|FPC" -or
        $_.DeviceID -match "VID_10A5.*PID_9201"
    }
    
    if ($biometricDevices) {
        foreach ($device in $biometricDevices) {
            Write-Host "Device: $($device.Name)" -ForegroundColor Cyan
            Write-Host "  Device ID: $($device.DeviceID)"
            Write-Host "  Hardware ID: $($device.HardwareID)"
            Write-Host "  Status: $($device.Status)"
            Write-Host "  Manufacturer: $($device.Manufacturer)"
            Write-Host ""
        }
    } else {
        Write-Host "No fingerprint devices found in WMI. Checking alternative methods..." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Error querying WMI: $($_.Exception.Message)"
}

Write-Host "=== USB Device Information ===" -ForegroundColor Yellow
try {
    # Get USB devices that might be fingerprint scanners
    $usbDevices = Get-WmiObject -Class Win32_USBHub | Where-Object { 
        $_.Description -match "fingerprint|biometric" 
    }
    
    if ($usbDevices) {
        foreach ($device in $usbDevices) {
            Write-Host "USB Device: $($device.Description)"
            Write-Host "  Device ID: $($device.DeviceID)"
            Write-Host ""
        }
    }
} catch {
    Write-Error "Error querying USB devices: $($_.Exception.Message)"
}

Write-Host "=== Driver File Analysis ===" -ForegroundColor Yellow
$driverPaths = @(
    "C:\Windows\System32\drivers\",
    "C:\Windows\System32\DriverStore\FileRepository\"
)

$fingerprintDrivers = @()
foreach ($path in $driverPaths) {
    if (Test-Path $path) {
        $drivers = Get-ChildItem -Path $path -Recurse -Include "*.sys", "*.inf" -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Name -match "fpc|finger|bio" }
        
        foreach ($driver in $drivers) {
            $fingerprintDrivers += $driver
            Write-Host "Found driver: $($driver.FullName)"
            Write-Host "  Size: $($driver.Length) bytes"
            Write-Host "  Modified: $($driver.LastWriteTime)"
            
            # Try to get version info
            try {
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($driver.FullName)
                if ($versionInfo.FileDescription) {
                    Write-Host "  Description: $($versionInfo.FileDescription)"
                    Write-Host "  Version: $($versionInfo.FileVersion)"
                    Write-Host "  Company: $($versionInfo.CompanyName)"
                }
            } catch {
                # Version info not available for this file
            }
            Write-Host ""
        }
    }
}

Write-Host "=== Registry Analysis ===" -ForegroundColor Yellow
$registryPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\",
    "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\"
)

foreach ($regPath in $registryPaths) {
    try {
        if (Test-Path $regPath) {
            $keys = Get-ChildItem -Path $regPath -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -match "fingerprint|biometric|fpc" }
            
            foreach ($key in $keys) {
                Write-Host "Registry Key: $($key.Name)"
                try {
                    $values = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                    foreach ($prop in $values.PSObject.Properties) {
                        if ($prop.Name -notmatch "^PS") {
                            Write-Host "  $($prop.Name): $($prop.Value)"
                        }
                    }
                } catch {
                    # Skip if can't read values
                }
                Write-Host ""
            }
        }
    } catch {
        # Skip if can't access registry path
    }
}

Write-Host "=== Windows Hello Configuration ===" -ForegroundColor Yellow
try {
    # Check Windows Hello status
    $helloStatus = Get-WmiObject -Namespace "root\cimv2\mdm\dmmap" -Class "MDM_PassportForWork_Policies01" -ErrorAction SilentlyContinue
    if ($helloStatus) {
        Write-Host "Windows Hello is configured"
    } else {
        Write-Host "Windows Hello status unknown or not configured"
    }
} catch {
    Write-Host "Could not determine Windows Hello status"
}

Write-Host "=== Installed Software ===" -ForegroundColor Yellow
$software = Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.Name -match "fingerprint|biometric|fpc" 
}

if ($software) {
    foreach ($app in $software) {
        Write-Host "Software: $($app.Name)"
        Write-Host "  Version: $($app.Version)"
        Write-Host "  Vendor: $($app.Vendor)"
        Write-Host ""
    }
} else {
    Write-Host "No fingerprint-related software found in WMI"
}

Write-Host "=== System Information Summary ===" -ForegroundColor Green
Write-Host "Windows Version: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Version)"
Write-Host "Architecture: $($env:PROCESSOR_ARCHITECTURE)"
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host ""

Write-Host "=== Next Steps ===" -ForegroundColor Green
Write-Host "1. Save this output to a file: windows-analysis.txt"
Write-Host "2. Copy any identified driver files to a safe location"
Write-Host "3. If USB device, prepare to capture USB traffic with Wireshark"
Write-Host "4. Note the exact VID:PID from Device Manager"
Write-Host ""
Write-Host "=== Manual Steps Required ===" -ForegroundColor Yellow
Write-Host "1. Open Device Manager (devmgmt.msc)"
Write-Host "2. Find your fingerprint device (usually under 'Biometric devices')"
Write-Host "3. Right-click -> Properties -> Details"
Write-Host "4. Select 'Hardware Ids' from dropdown"
Write-Host "5. Copy all Hardware IDs (they contain VID and PID)"
Write-Host "6. Also check 'Compatible Ids' and 'Device Instance Path'"