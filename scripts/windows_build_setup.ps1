#---------------------------------------------------------------------
# Configures a build envrionment for nim-status-client on windows.
#---------------------------------------------------------------------

# Helpers
function Install-Scoop {
    if ((Get-Command scoop -ErrorAction SilentlyContinue) -ne $null) {
        Write-Host "Scoop already installed!"
    } else {
        Write-Host "Installing Scoop package manager..."
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
    }
}

# Install Git and other dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..."
    scoop install --global 7zip git dos2unix findutils wget make cmake gcc go rcedit inno-setup
    scoop bucket add extras
    scoop install --global vcredist2017
}

function Install-Qt-SDK {
    Write-Host "Installing Qt $QtVersion SDK..."
    pip install aqtinstall
    aqt install --output "C:\Qt" $QtVersion windows desktop win64_msvc2017_64 -m qtwebengine
}

# Install Microsoft Visual C++ Build Tools 15.8.9
function Install-VC-BuildTools {
    $VCBuildToolsUrl = "https://download.visualstudio.microsoft.com/download/pr/e286f66e-4366-425f-bcc5-c88627c6e95a/0401d4decb00884a7d50f69732e1d680/vs_buildtools.exe"
    $VCBuildToolsExe = "$HOME\Downloads\vs_BuildTools.exe"

    Write-Host "Downloading Microsoft Visual C++ Build Tools..."
    (New-Object System.Net.WebClient).DownloadFile($VCBuildToolsUrl, $VCBuildToolsExe)

    Write-Host "Installing Microsoft Visual C++ Build Tools..."
    $VCBuildToolsArgs = $(
        "--installPath", "C:\BuildTools",
        "--quiet", "--wait", "--norestart", "--nocache",
        "--add", "Microsoft.VisualStudio.Workload.MSBuildTools",
        "--add", "Microsoft.VisualStudio.Workload.VCTools",
        "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "--add", "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
        "--add", "Microsoft.VisualStudio.Component.Windows10SDK.10240",
        "--add", "Microsoft.VisualStudio.Component.Windows10SDK.14393",
        "--add", "Microsoft.VisualStudio.Component.Windows81SDK",
        "--add", "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Win81"
    )
    Start-Process -Wait -PassThru -FilePath $VCBuildToolsExe -ArgumentList $VCBuildToolsArgs
}

function Show-Success-Message {
    Write-Host @"

SUCCESS!

Before you attempt to build nim-status-client you'll need a few environment variables set:

export QTDIR="/c/Qt/$QtVersion/msvc2017_64"
export Qt5_DIR="/c/Qt/$QtVersion/msvc2017_64"
export VCINSTALLDIR="/c/BuildTools/VC"

You might also have to include the following paths in your `$PATH:

export PATH=`"/c/BuildTools/MSBuild/Current/Bin:`$PATH`"
export PATH=`"/c/BuildTools/VC/Tools/MSVC/14.27.29110/bin:`$PATH`"
export PATH=`"/c/ProgramData/scoop/apps/inno-setup/current:`$PATH`"
"@
}

#---------------------------------------------------------------------

# Stop the script after first error
$ErrorActionPreference = 'Stop'
# Version of Qt SDK available form aqt
$QtVersion = "5.14.2"

# Don't run when sourcing script
If ($MyInvocation.InvocationName -ne ".") {
    Install-Scoop
    Install-Dependencies
    Install-Qt-SDK
    Install-VC-BuildTools
    Show-Success-Message
}

#---------------------------------------------------------------------
