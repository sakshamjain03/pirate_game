# Pirate Empire: Build, Deployment & Testing Workflow

This document outlines the complete step-by-step process used to build the game, push it to an Android device, launch it, and capture standardized screenshots for both Mobile and PC. 

## 1. Connecting the Android Device

Before building, ensure your phone is connected and recognized by ADB (Android Debug Bridge).

1. Enable **Developer Options** and **USB Debugging** on your Android device.
2. Connect your device to your PC via USB.
3. Open a terminal and run:
   ```powershell
   $adb = "C:\Users\saksham\AppData\Local\Android\Sdk\platform-tools\adb.exe"
   & $adb devices
   ```
   You should see your device listed (e.g., `RF8N... device`).

## 2. Building the APK

To compile the latest code into an APK for Android, we use Godot's headless export feature via the console executable.

> **IMPORTANT**
> Always use `Godot_v4.3-stable_win64_console.exe` when building from the command line, and do NOT use `--check-only` as it will boot the game and hang forever.

```powershell
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.3-stable_win64_console.exe"
& $godot --headless --path . --export-debug "Android" "builds/pirate_empire_debug.apk"
```
*Note: The first time Gradle builds the Android project, it may take 2-3 minutes. Subsequent builds will be faster.*

## 3. Pushing & Launching the Build

Once the APK is built (verify it exists at `builds/pirate_empire_debug.apk`), push it to the connected phone and launch the game cleanly:

```powershell
# 1. Install / Update the APK on the phone
& $adb install -r -d builds/pirate_empire_debug.apk

# 2. Force Launch the Game
& $adb shell am start -n com.sakshamjain03.pirateempire/com.godot.game.GodotApp
```

## 4. Screenshot Capture Workflow

To maintain a consistent catalog of UI flows and game states, screenshots are separated into Mobile and PC directories.

### Directory Structure
```
D:\Pirate-game\screenshots\
├── mobile\      # Screenshots captured directly from the Android device
└── pc\          # Screenshots captured from the Windows build
```

### Capturing Mobile Screenshots
We use an automated ADB script to navigate the game and pull raw, uncompressed PNG screenshots directly from the Android frame buffer.

**Example Sequence (Navigating to Pause Menu & Capturing):**
```powershell
# 1. Tap the Pause button (Coordinates: X=2250, Y=120)
& $adb shell input tap 2250 120

# 2. Wait for the modal animation
Start-Sleep -Seconds 2

# 3. Capture the screen and save to device storage
& $adb shell screencap -p /sdcard/screen_manual_pause.png

# 4. Pull the screenshot to the PC's mobile folder
& $adb pull /sdcard/screen_manual_pause.png "D:\Pirate-game\screenshots\mobile\screen_manual_pause.png"
```

### Capturing PC Screenshots
To capture screenshots on the PC, the game must be run using the standard Godot executable (not headless). PC screenshots are saved directly to the `screenshots/pc/` directory.

To run the game locally on PC and capture the screen:
```powershell
# 1. Launch Godot headful
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.3-stable_win64.exe"
Start-Process $godot -ArgumentList "--path ."

# 2. Take a screenshot using Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$bmp.Save("D:\Pirate-game\screenshots\pc\screen_pc_1.png")
$graphics.Dispose(); $bmp.Dispose()
```

## 5. Troubleshooting

> **WARNING**
> **Black Screen on Boot:** If the game launches to a black screen but the Android status bar is visible, the Godot engine may have crashed during the initial scene load (often due to syntax errors). Check `adb logcat -s godot` for stack traces.
> 
> **Build Hangs:** If the Godot export hangs indefinitely, use `Stop-Process -Name "Godot*"` and check for lock files. Ensure you are using the `_console.exe` binary.
