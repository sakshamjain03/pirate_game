param (
    [string]$PageName = "page_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)
$adb = "C:\Users\saksham\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb shell screencap -p /sdcard/temp_screen.png
& $adb pull /sdcard/temp_screen.png "D:\Pirate-game\screenshots\$PageName.png"
Write-Host "Screenshot saved as $PageName.png"
