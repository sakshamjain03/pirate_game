$adb = "C:\Users\saksham\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$pkg = "com.sakshamjain03.pirateempire"

# Clear old screenshots
Remove-Item -Path "D:\Pirate-game\screenshots\*.png" -Force

function Restart-To-Main {
    & $adb shell am force-stop $pkg
    Start-Sleep -Seconds 1
    & $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
    Start-Sleep -Seconds 6
    # Dismiss Crash Dialog
    & $adb shell input tap 1170 520
    Start-Sleep -Seconds 2
}

function Restart-To-Game {
    Restart-To-Main
    & $adb shell input tap 1170 370 # NEW GAME
    Start-Sleep -Seconds 6
}

# 1. MAIN MENU
Restart-To-Main
& $adb shell screencap -p /sdcard/screen_main.png
& $adb pull /sdcard/screen_main.png "D:\Pirate-game\screenshots\screen_main.png"

# 2. SETTINGS
& $adb shell input tap 1170 470
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_settings.png
& $adb pull /sdcard/screen_settings.png "D:\Pirate-game\screenshots\screen_settings.png"
# Controls
& $adb shell input tap 230 110
Start-Sleep -Seconds 2
& $adb shell screencap -p /sdcard/screen_settings_controls.png
& $adb pull /sdcard/screen_settings_controls.png "D:\Pirate-game\screenshots\screen_settings_controls.png"
# Account
& $adb shell input tap 310 110
Start-Sleep -Seconds 2
& $adb shell screencap -p /sdcard/screen_settings_account.png
& $adb pull /sdcard/screen_settings_account.png "D:\Pirate-game\screenshots\screen_settings_account.png"

# 3. STORE
Restart-To-Main
& $adb shell input tap 1170 570
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_store.png
& $adb pull /sdcard/screen_store.png "D:\Pirate-game\screenshots\screen_store.png"

# 4. CREDITS
Restart-To-Main
& $adb shell input tap 1170 670
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_credits.png
& $adb pull /sdcard/screen_credits.png "D:\Pirate-game\screenshots\screen_credits.png"

# 5. IN-GAME
Restart-To-Game
& $adb shell screencap -p /sdcard/screen_game.png
& $adb pull /sdcard/screen_game.png "D:\Pirate-game\screenshots\screen_game.png"

# 6. MAP
Restart-To-Game
& $adb shell input tap 2250 170
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_map.png
& $adb pull /sdcard/screen_map.png "D:\Pirate-game\screenshots\screen_map.png"

# 7. LOG
Restart-To-Game
& $adb shell input tap 2250 120
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_log.png
& $adb pull /sdcard/screen_log.png "D:\Pirate-game\screenshots\screen_log.png"

# 8. CODEX
Restart-To-Game
& $adb shell input tap 2250 220
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_codex.png
& $adb pull /sdcard/screen_codex.png "D:\Pirate-game\screenshots\screen_codex.png"

# 9. NEW
Restart-To-Game
& $adb shell input tap 2250 275
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_new.png
& $adb pull /sdcard/screen_new.png "D:\Pirate-game\screenshots\screen_new.png"

# 10. WARDROBE
Restart-To-Game
& $adb shell input tap 2250 330
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_wardrobe.png
& $adb pull /sdcard/screen_wardrobe.png "D:\Pirate-game\screenshots\screen_wardrobe.png"

# 11. PAUSE
Restart-To-Game
& $adb shell input tap 600 700
Start-Sleep -Seconds 3
& $adb shell screencap -p /sdcard/screen_pause.png
& $adb pull /sdcard/screen_pause.png "D:\Pirate-game\screenshots\screen_pause.png"
