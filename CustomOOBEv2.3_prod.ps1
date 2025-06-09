<#
 Purpose: Create Custom Windows user OOBE
 Version: 2.3 - May 29, 2025

 Author - Anton Savchenko
#>

$ErrorActionPreference = 'Stop'

# === Logging and registry settings ===
$logPath = "C:\ProgramData\CustomOOBE\CustomOOBE.log"
$regPath = "HKLM:\Software\CustomOOBE"
$regName = "CustomOOBEv2.3Complete"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# === Create log folder if it doesn't exist ===
$logDir = Split-Path $logPath
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logPath -Value $line
    Write-Host $line
}

Log "=== CustomOOBE script started ==="

# Copy lottie animations
$source = Join-Path $PSScriptRoot "lottie"
$target = "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\images"
if (Test-Path "$source\*") {    
    Copy-Item -Path "$source\*" -Destination $target -Recurse -Force
}

# === Set ownership and permissions ===
$paths = @(
    "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\data\prod\navigation.json",
    "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\webapps\inclusiveOobe\js",
    "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\webapps\inclusiveOobe\view",
    "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\images"
)

foreach ($path in $paths) {
    Log "Processing: $path"
    takeown /F $path /A /R /D Y | Out-Null

    try {
        $acl = Get-Acl -Path $path
        $adminGroup = New-Object System.Security.Principal.NTAccount("Administrators")
        $acl.SetOwner($adminGroup)
        Set-Acl -Path $path -AclObject $acl
        Log "Ownership assigned to 'Administrators'"
    } catch {
        Log "Failed to set ownership: $_"
        exit 1
    }

    try {
        $acl = Get-Acl -Path $path
        $inheritance = if ((Test-Path $path -PathType Container)) { "ContainerInherit,ObjectInherit" } else { "None" }

        $ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", $inheritance, "None", "Allow")
        $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", $inheritance, "None", "Allow")

        $acl.SetAccessRule($ruleSystem)
        $acl.SetAccessRule($ruleAdmins)
        Set-Acl -Path $path -AclObject $acl

        Log "FullControl permissions assigned to SYSTEM and Administrators"
    } catch {
        Log "Failed to set permissions: $_"
        exit 1
    }
}

# === Paths ===
$navigationPath = "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\data\prod\navigation.json"
$inclusiveOobe = "C:\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy\webapps\inclusiveOobe"
$configurationPath = Join-Path $PSScriptRoot "configuration.json"

if (!(Test-Path $configurationPath)) {
    Log "configuration.json not found in $PSScriptRoot"
    exit 1
}

$config = Get-Content $configurationPath -Raw | ConvertFrom-Json
$utf8bom = [System.Text.UTF8Encoding]::new($true)

# === Templates ===
$pageTemplate = @"
(() => {
    WinJS.UI.Pages.define("/webapps/inclusiveOobe/view/{HTML_FILE}", {
        init: (element, options) => {
            require.config(new RequirePathConfig('/webapps/inclusiveOobe'));

            let loadCssPromise = requireAsync(['legacy/uiHelpers', 'legacy/bridge']).then((result) => {
                return result.legacy_uiHelpers.LoadCssPromise(document.head, "", result.legacy_bridge);
            });

            let langAndDirPromise = requireAsync(['legacy/uiHelpers', 'legacy/bridge']).then((result) => {
                return result.legacy_uiHelpers.LangAndDirPromise(document.documentElement, result.legacy_bridge);
            });

            let getLocalizedStringsPromise = requireAsync(['legacy/bridge']).then((result) => {
                return result.legacy_bridge.invoke("CloudExperienceHost.StringResources.makeResourceObject", "oobeNetworkLossError");
            }).then((result) => {
                this.resourceStrings = JSON.parse(result);
            });

            return WinJS.Promise.join({ loadCssPromise, langAndDirPromise, getLocalizedStringsPromise });
        },
        error: (e) => {
            require(['legacy/bridge', 'legacy/events'], (bridge, constants) => {
                bridge.fireEvent(constants.Events.done, constants.AppResult.error);
            });
        },
        ready: (element, options) => {
            require(['lib/knockout', 'corejs/knockouthelpers', 'legacy/bridge', 'legacy/events', '{VM_NAME}', 'lib/knockout-winjs'], (ko, KoHelpers, bridge, constants, NetworkLossErrorViewModel) => {
                koHelpers = new KoHelpers();
                koHelpers.registerComponents(CloudExperienceHost.RegisterComponentsScenarioMode.InclusiveOobe);
                window.KoHelpers = KoHelpers;

                let vm = new NetworkLossErrorViewModel(this.resourceStrings);
                ko.applyBindings(vm);
                KoHelpers.waitForInitialComponentLoadAsync().then(() => {
                    WinJS.Utilities.addClass(document.body, "pageLoaded");
                    bridge.fireEvent(constants.Events.visible, true);
                    KoHelpers.setFocusOnAutofocusElement();
                });
            });
        }
    });
})();
"@

$vmTemplate = @"
define(['lib/knockout', 'legacy/bridge', 'legacy/events', 'legacy/core'], (ko, bridge, constants, core) => {
    class NetworkLossErrorViewModel {
        constructor(resourceStrings) {
            this.resourceStrings = resourceStrings;
            this.title = 'title';
            this.subHeaderText = 'subHeaderText';

            this.disableButton = ko.observable(true);
            this.countdownText = ko.observable("10");

            let seconds = 10;
            const timer = setInterval(() => {
                seconds--;
                if (seconds > 0) {
                    this.countdownText(seconds.toString());
                } else {
                    clearInterval(timer);
                    this.countdownText("Next");
                    this.disableButton(false);
                }
            }, 1000);

            this.processingFlag = ko.observable(false);

            this.flexEndButtons = [{
                buttonText: this.countdownText,
                buttonType: "button",
                isPrimaryButton: true,
                autoFocus: true,
                disableControl: this.disableButton,
                buttonClickHandler: (() => this.onRetry())
            }];
        }

        onRetry() {
            if (!this.processingFlag()) {
                this.processingFlag(true);
                bridge.invoke("CloudExperienceHost.Telemetry.logUserInteractionEvent", "RetryButtonClicked");
                bridge.fireEvent(constants.Events.done, constants.AppResult.success);
            }
        }
    }

    return NetworkLossErrorViewModel;
});
"@

$htmlTemplate = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <link rel="stylesheet" href="../css/inclusive-common.css" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="/Microsoft.WinJS-reduced/js/base.js"></script>
    <script src="/core/js/require-helpers.js"></script>
    <script src="/core/js/requirePath-config-core.js"></script>
    <script data-main="/webapps/inclusiveOobe/js/{PAGE_FILE}" src="/lib/require.js"></script>
    <style>
        .custom-title { font-size: 30px; font-weight: 600; margin-top: 20px; color: #1f1f1f; }
        .custom-content { font-size: 16px; line-height: 1.5; color: #5f5f5f; }
    </style>
</head>
<body class="webapp-inner">
    <div class="body-container">
        <div class="container-content">
            <h1 class="custom-title">{TITLE}</h1>
            <p class="custom-content">{CONTENT}</p>
        </div>
        <oobe-footer params="flexEndButtons: flexEndButtons"></oobe-footer>
    </div>
</body>
</html>
"@

# === File generation ===
$config.PSObject.Properties | ForEach-Object {
    $pageName = $_.Name
    $pageData = $_.Value
    if (![string]::IsNullOrWhiteSpace($pageData.Title) -and $pageName -match 'Page(\d+)') {
        $n = $matches[1]
        $base = "custompage$n"
        $html = "$base.html"
        $vm   = "$base-vm"
        $page = "$base-page.js"

        $pageOut = $pageTemplate -replace '{HTML_FILE}', $html -replace '{VM_NAME}', $vm
        $htmlOut = $htmlTemplate -replace '{PAGE_FILE}', $page -replace '{TITLE}', $pageData.Title -replace '{CONTENT}', $pageData.Content

        [System.IO.File]::WriteAllText((Join-Path "$inclusiveOobe\js" $page), $pageOut, $utf8bom)
        [System.IO.File]::WriteAllText((Join-Path "$inclusiveOobe\js" "$vm.js"), $vmTemplate, $utf8bom)
        [System.IO.File]::WriteAllText((Join-Path "$inclusiveOobe\view" $html), $htmlOut, $utf8bom)

        Log "Created: $html, $page, $vm.js"
    }
}

# === Load navigation.json ===
$navText = Get-Content -Raw $navigationPath
$match = [regex]::Match($navText, '"NTHAADORMDM"\s*:\s*\{')
if (!$match.Success) {
    Write-Error "Block 'NTHAADORMDM' not found"
    exit 1
}

# === NTHAADORMDM block extraction ===
$startIndex = $match.Index + $match.Length - 1
$brace = 1; $end = $startIndex
while ($brace -gt 0) {
    $c = $navText[$end]
    if ($c -eq '{') { $brace++ }
    elseif ($c -eq '}') { $brace-- }
    $end++
}
$block = $navText.Substring($match.Index, $end - $match.Index)

# === MDMProgressRefactored update
$block = $block -replace '("MDMProgressRefactored"\s*:\s*\{[^}]*?"successID"\s*:\s*")([^"]+)(")', '${1}CustomPage1${3}'
$block = $block -replace '("MDMProgressRefactored"\s*:\s*\{[^}]*?"failID"\s*:\s*")([^"]+)(")', '${1}CustomPage1${3}'
$block = $block -replace '("MDMProgressRefactored"\s*:\s*\{[^}]*?"action2ID"\s*:\s*")([^"]+)(")', '${1}CustomPage1${3}'

# === Creation of CustomOOBE blocks
$CustomPageBlocks = @()
$lastCustomPage = ""
for ($i = 1; $i -le 10; $i++) {
    $p = $config."Page$i"
    if ($p -and $p.Title) {
        $next = "AADHello"
        for ($j = $i + 1; $j -le 10; $j++) {
            if ($config."Page$j" -and $config."Page$j".Title) {
                $next = "CustomPage$j"
                break
            }
        }

        $g = @"
    "CustomPage$i": {
        "cxid": "CustomPage$i",
        "frameAnimation": "$($p.Lottie)",
        "url": "ms-appx-web:///webapps/inclusiveOobe/view/CustomPage$i.html",
        "successID": "$next",
        "failID": "$next",
        "cancelID": "$next",
        "abortID": "$next",
        "visibility": false
    }
"@
        if ($CustomPageBlocks.Count -gt 0) { $g = "," + $g }
        $CustomPageBlocks += $g
        $lastCustomPage = "CustomPage$i"
    }
}
$inserted = ($CustomPageBlocks -join "`n")

# === Insertion between MDMProgressRefactored and AADHello
$mdmIndex = [regex]::Match($block, '"MDMProgressRefactored"\s*:\s*\{').Index
$aadIndex = [regex]::Match($block, '"AADHello"\s*:\s*\{').Index
$before = $block.Substring(0, $aadIndex)
$after  = $block.Substring($aadIndex)

# === Combining and saving
$finalBlock = "$before`n$inserted`n,$after"
$finalNav = $navText.Substring(0, $match.Index) + $finalBlock + $navText.Substring($end)

[System.IO.File]::WriteAllText($navigationPath, $finalNav, $utf8bom)
Write-Host "navigation.json updated between MDMProgressRefactored and AADHello"

# === Write registry marker ===
try {
    if (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name $regName -Value $timestamp -PropertyType String -Force | Out-Null
    Log "Registry key created: $regPath\$regName = $timestamp"
} catch {
    Log "Failed to write registry key: $_"
    exit 1
}

Log "CustomOOBE script completed successfully"
exit 0
