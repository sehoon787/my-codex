---
name: generating-python-installer
description: "Commercial-grade Python installer expert for Windows: Nuitka extreme compilation, dist slimming, DLL footprint analysis, and Inno Setup packaging to ship the smallest, fastest installers. Use when a Python app must ship as a minimal, fast-starting Windows installer; not for basic script-to-exe conversion. Relevant requests include Nuitka extreme optimization, commercial Python packaging, aggressive Python compilation, dist slimming, DLL analysis, minimal installers, fastest startup, and commercial-grade packaging."
---

# Generating Python Installer (Commercial-Grade)

You are a **Python commercial deployment expert**. Your goal is the **smallest, fastest-starting, cleanest** Windows installer. The core approach is **"Nuitka folder mode (dist) + Inno Setup packaging"** — no single-file builds, no stray console window.

## When to Activate

Activate when the user explicitly asks for **advanced** Python packaging or size/startup optimization on Windows:

- Nuitka extreme / commercial-grade compilation, smallest-size or fastest-startup builds
- `dist` folder slimming, DLL footprint analysis, 32-bit vs 64-bit size tradeoffs
- Inno Setup packaging with full metadata and a clean, residue-free uninstall

This skill targets advanced size/startup optimization — not basic one-file "script to exe" conversion.

## How It Works

1. **Confirm build parameters** — app name, version, publisher, exe name, source/output dirs, icon. Never auto-fill; ask the user.
2. **Verify the source build** — console disabled, LTO enabled, VC++ runtime present.
3. **Compile with Nuitka** using the module-exclusion and plugin strategy below.
4. **Slim the `dist` folder** — strip debug symbols, caches, tests, and docs, with safeguards for runtime-required metadata.
5. **Analyze DLLs** to find and trim the largest dependencies.
6. **Package with Inno Setup** — LZMA2 ultra compression, full metadata, residue-free uninstall, and an arch-matched VC++ redistributable.

## Examples

- A request in any language to package a PySide2 project as the smallest commercial installer with Nuitka → run the full workflow: recommend 32-bit, exclude WebEngine/3D/Charts, slim `dist`, and package with Inno Setup.
- A request in any language to reduce a 400 MB executable by half → analyze DLLs, switch to `opencv-python-headless`, remove `opengl32sw`, and apply `dist` slimming.
- A report in any language that the app does not start on a clean system after installation → ensure the matching-architecture VC++ redistributable is bundled in the Inno Setup script.

---

## Core Philosophy

Use the **"Nuitka folder mode (dist) + Inno Setup packaging"** approach. Do not use a single-file build, and do not allow a console window to appear.

---

## Practical Reference Case (Production PySide2 Desktop App, 323 MB, Including OpenCV / Playwright)

### Project Overview

- **Total size**: 323 MB
- **Packaging tool**: PyInstaller 4.7 (32-bit)
- **Main dependencies**: PySide2 (22.52 MB), OpenCV (62.38 MB), Playwright (76.74 MB)
- **Python version**: Python 3.8 (32-bit)
- **DLL count**: 71 files, totaling 93.23 MB

### Key Optimization Strategies

1. PASS: **Use 32-bit Python** → reduce size by 20-30%
2. PASS: **Compress the standard library into base_library.zip** → 0.74 MB
3. PASS: **Trim module exclusions** → no pytest/unittest/setuptools
4. PASS: **Trim Qt plugins** → retain only required plugins

### Size Distribution

| Component | Size | Share | Optimization Recommendation |
|-----------|------|-------|-----------------------------|
| playwright | 76.74 MB | 23.8% | Remove if unnecessary |
| OpenCV | 62.38 MB | 19.3% | Use opencv-python-headless |
| PySide2 | 22.52 MB | 7.0% | Exclude WebEngine/3D/Charts |
| Other dependencies | 161.36 MB | 49.9% | - |

### Expected Results

| Project Type | Original Nuitka Size | After Optimization | Measured Reference Project |
|--------------|----------------------|--------------------|----------------------------|
| Tkinter + standard library | 150-250 MB | **80-120 MB** | - |
| PyQt/PySide | 200-400 MB | **120-250 MB** | 323 MB (including OpenCV, etc.) |
| Including numpy/pandas | 300-600 MB | **180-350 MB** | - |

---

## Core Workflow - WARNING: Follow Strictly

When the user requests packaging, follow these steps:

**Step 1: Mandatory Parameter Confirmation (FAIL: Do Not Use Default Values)**

> **WARNING: Important rule: confirm every parameter below individually with the user. Never auto-fill or use default values.**

Ask the user for and confirm all of the following information. *Wait for an explicit response before continuing.*

| Parameter | Description | Example |
|-----------|-------------|---------|
| **App Name** | Display name of the application | `Red Ink Annotation` |
| **Version** | Semantic version number | `1.0.0` |
| **Publisher** | Publisher shown in Control Panel | `YourCompany` |
| **Exe Name** | Main executable filename | `RedInk.exe` |
| **Source Dir** | Absolute path to the Nuitka dist folder | `D:\project\dist` |
| **Output Dir** | Installer output location | `D:\project\output` |
| **Icon Path** | Absolute path to an .ico file (optional but recommended) | `D:\project\icon.ico` |
| **URL** | Optional website link for Control Panel | `https://example.com` |

**Question template:**

> "Please provide the following packaging parameters. I need you to confirm each one:
> 1. App name:
> 2. Version:
> 3. Publisher/company name:
> 4. Main executable filename (for example, xxx.exe):
> 5. Source path (Nuitka dist folder):
> 6. Output path (installer destination):
> 7. Icon path (.ico file; may be left blank):
> 8. Website URL (may be left blank):
>
> Fill in each item, or reply `skip` to use an empty value."

**Step 2: Source Quality and Compilation Checks (Critical)**

Before generating code, give the user the following **critical confirmation**, because Inno Setup only packages an application and cannot change its runtime properties:

> "WARNING: **Compilation parameter check**:
> 1. **No console window**: Confirm that the dist folder was compiled with `nuitka --windows-console-mode=disable`. Otherwise, a console window will still appear after installation.
> 2. **High performance**: Confirm whether `--lto=yes` was used. Otherwise, startup speed may be unsatisfactory.
> 3. **Runtime libraries**: Ensure that the dist folder contains the required VC++ runtime libraries so the app can run on a clean system.
>
> **Reply `confirmed` when the source files are ready; otherwise, recompile first.**"

**Step 3: Generate Code**

After the user confirms, output code that includes **complete metadata** and the **uninstall icon fix**.

---

## Extreme Nuitka Compilation Optimization (Based on Reference Project Experience)

### 1. 32-bit vs 64-bit Selection Strategy

**Why the reference project uses 32-bit Python**:

| Component | 64-bit Size | 32-bit Size | Savings |
|-----------|-------------|-------------|---------|
| python3x.dll | ~4.5 MB | ~3.8 MB | 15% |
| Qt5Core.dll | ~8 MB | ~5 MB | 37% |
| numpy | ~30 MB | ~20 MB | 33% |
| **Overall** | Baseline | **-20~30%** | - |

**Recommend 32-bit when**:

- PASS: The app uses less than 2 GB of memory
- PASS: The app does not process very large files (under 2 GB)
- PASS: Target users have ordinary office computers

**32-bit compilation method**:

```bash
# 1. Install 32-bit Python (it can coexist with 64-bit Python)
# Download: https://www.python.org/downloads/windows/

# 2. Install dependencies with 32-bit Python
py -3.12-32 -m pip install -r requirements.txt

# 3. Compile with 32-bit Python
py -3.12-32 -m nuitka --standalone ...your-options
```

### 2. Module Exclusion List (Validated by the Reference Project)

**Safe exclusion list** (not required at runtime):

```text
unittest,test,pytest,_pytest,doctest,pdb,pdbpp,
setuptools,pip,distutils,pkg_resources,
email.mime,http.server,xmlrpc,pydoc
```

**Expected result**: save **30-50 MB**

### 3. GUI Framework-Specific Optimizations

#### Extreme Tkinter Optimization (Recommended, Lightest)

```bash
nuitka --standalone --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=8 ^
    --enable-plugin=tk-inter ^
    --enable-plugin=anti-bloat ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=unittest,test,pytest,_pytest,doctest,pdb,pdbpp ^
    --nofollow-import-to=setuptools,pip,distutils,pkg_resources ^
    --nofollow-import-to=email.mime,http.server,xmlrpc,pydoc ^
    --python-flag=no_docstrings ^
    --output-dir=dist ^
    --windows-icon-from-ico=icon.ico ^
    --remove-output ^
    main.py
```

**Expected size**: 80-120 MB after optimization

#### PyQt5 / PySide2 Optimization

```bash
nuitka --standalone --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=8 ^
    --enable-plugin=pyqt5 ^
    --enable-plugin=anti-bloat ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=unittest,test,pytest,_pytest,doctest,pdb ^
    --nofollow-import-to=setuptools,pip,distutils,pkg_resources ^
    --nofollow-import-to=PyQt5.QtWebEngine,PyQt5.QtWebEngineWidgets ^
    --nofollow-import-to=PyQt5.Qt3D,PyQt5.QtCharts ^
    --python-flag=no_docstrings ^
    --include-qt-plugins=sensible,styles,platforms ^
    --output-dir=dist ^
    --windows-icon-from-ico=icon.ico ^
    --remove-output ^
    main.py
```

**Expected size**: 120-250 MB after optimization

### 4. One-Command Compilation Script Template

**Save as `build_optimized.bat` in the project root:**

```batch
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo Nuitka Extreme Optimization Build (Reference Project)
echo ========================================

REM === Configuration (replace with your actual values) ===
set APP_NAME=YourAppName
set MAIN_FILE=main.py
set ICON_FILE=icon.ico

REM === Detect the CPU core count automatically ===
REM Use the built-in Windows environment variable. WMIC was removed in Windows 11 22H2+;
REM failed detection would make --jobs=0 compile on a single thread.
set CPU_CORES=%NUMBER_OF_PROCESSORS%
if not defined CPU_CORES set CPU_CORES=4
set /a BUILD_JOBS=%CPU_CORES%

REM === Module exclusion list from the reference project ===
set EXCLUDE_MODULES=unittest,test,pytest,_pytest,doctest,pdb,pdbpp
set EXCLUDE_MODULES=%EXCLUDE_MODULES%,setuptools,pip,distutils,pkg_resources
set EXCLUDE_MODULES=%EXCLUDE_MODULES%,email.mime,http.server,xmlrpc,pydoc

echo.
echo [1/4] Cleaning previous builds...
if exist dist rd /s /q dist
if exist build rd /s /q build

echo.
echo [2/4] Compiling with Nuitka (applying reference-project optimizations)...
echo - CPU cores: %CPU_CORES% (using %BUILD_JOBS% threads)
echo - Excluded modules: %EXCLUDE_MODULES%
echo.

nuitka --standalone ^
    --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=%BUILD_JOBS% ^
    --enable-plugin=anti-bloat ^
    --enable-plugin=tk-inter ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=%EXCLUDE_MODULES% ^
    --python-flag=no_docstrings ^
    --output-dir=dist ^
    --windows-icon-from-ico=%ICON_FILE% ^
    --remove-output ^
    %MAIN_FILE%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Compilation failed!
    pause
    exit /b 1
)

echo.
echo [3/4] Measuring build output...
for /f %%a in ('powershell -NoProfile -Command "(Get-ChildItem -LiteralPath 'dist\%APP_NAME%.dist' -Recurse -File | Measure-Object -Property Length -Sum).Sum"') do set TOTAL_SIZE=%%a
set TOTAL_SIZE=%TOTAL_SIZE:,=%
set /a SIZE_MB=%TOTAL_SIZE% / 1048576
echo - Compiled size: %SIZE_MB% MB

echo.
echo [4/4] Running slimming cleanup (reference-project strategy)...
powershell -ExecutionPolicy Bypass -File slim_dist.ps1 -DistPath "dist\%APP_NAME%.dist"

echo.
echo ========================================
echo Compilation complete!
echo ========================================
pause
```

### 5. dist Slimming Script (Reference-Project-Level Cleanup)

**Save as `slim_dist.ps1` in the same directory as `build_optimized.bat`:**

```powershell
param(
    [string]$DistPath
)

$ErrorActionPreference = "Continue"  # Do not silently swallow errors; show deletion failures to avoid false success

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "dist Slimming Cleanup (Reference-Project Strategy)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not (Test-Path $DistPath)) {
    Write-Host "[ERROR] Directory not found: $DistPath" -ForegroundColor Red
    exit 1
}

# Measure initial size
$InitialSize = (Get-ChildItem -Path $DistPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "`nInitial size: $([math]::Round($InitialSize, 2)) MB" -ForegroundColor Yellow

# Reference-project characteristics: no .pdb, .pyi, __pycache__, test, and similar files
Write-Host "`n[Applying the reference project's cleanup strategy...]" -ForegroundColor Green

# 1. Delete debug symbols
Write-Host "`n[1/7] Deleting .pdb debug symbols..." -ForegroundColor Green
$pdbFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pdb -File
$pdbSize = ($pdbFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pdbFiles.Count -gt 0) {
    $pdbFiles | Remove-Item -Force
    Write-Host "  Deleted $($pdbFiles.Count) files, saving $([math]::Round($pdbSize, 2)) MB"
} else {
    Write-Host "  No .pdb files found (already optimized)" -ForegroundColor Gray
}

# 2. Delete type hints
Write-Host "`n[2/7] Deleting .pyi type hints..." -ForegroundColor Green
$pyiFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pyi -File
$pyiSize = ($pyiFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pyiFiles.Count -gt 0) {
    $pyiFiles | Remove-Item -Force
    Write-Host "  Deleted $($pyiFiles.Count) files, saving $([math]::Round($pyiSize, 2)) MB"
} else {
    Write-Host "  No .pyi files found (already optimized)" -ForegroundColor Gray
}

# 3. Delete __pycache__ directories
Write-Host "`n[3/7] Deleting __pycache__ directories..." -ForegroundColor Green
$pycacheDirs = Get-ChildItem -Path $DistPath -Recurse -Directory -Filter "__pycache__"
$pycacheSize = 0
foreach ($dir in $pycacheDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $pycacheSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($pycacheDirs.Count -gt 0) {
    Write-Host "  Deleted $($pycacheDirs.Count) directories, saving $([math]::Round($pycacheSize / 1MB, 2)) MB"
} else {
    Write-Host "  No __pycache__ directories found (already optimized)" -ForegroundColor Gray
}

# 4. Delete test directories
Write-Host "`n[4/7] Deleting test/tests directories..." -ForegroundColor Green
$testDirs = Get-ChildItem -Path $DistPath -Recurse -Directory | Where-Object { $_.Name -match '^tests?$' }
$testSize = 0
foreach ($dir in $testDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $testSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($testDirs.Count -gt 0) {
    Write-Host "  Deleted $($testDirs.Count) directories, saving $([math]::Round($testSize / 1MB, 2)) MB"
} else {
    Write-Host "  No test directories found (already optimized)" -ForegroundColor Gray
}

# 5. Delete documentation and examples
Write-Host "`n[5/7] Deleting docs/examples directories..." -ForegroundColor Green
$docDirs = Get-ChildItem -Path $DistPath -Recurse -Directory | Where-Object { $_.Name -match '^(docs|examples|samples|demo)$' }
$docSize = 0
foreach ($dir in $docDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $docSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($docDirs.Count -gt 0) {
    Write-Host "  Deleted $($docDirs.Count) directories, saving $([math]::Round($docSize / 1MB, 2)) MB"
} else {
    Write-Host "  No documentation directories found (already optimized)" -ForegroundColor Gray
}

# 6. Delete .pyc files
Write-Host "`n[6/7] Deleting .pyc bytecode..." -ForegroundColor Green
$pycFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pyc -File
$pycSize = ($pycFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pycFiles.Count -gt 0) {
    $pycFiles | Remove-Item -Force
    Write-Host "  Deleted $($pycFiles.Count) files, saving $([math]::Round($pycSize, 2)) MB"
} else {
    Write-Host "  No .pyc files found (already optimized)" -ForegroundColor Gray
}

# 7. Trim .dist-info metadata
Write-Host "`n[7/7] Trimming .dist-info metadata..." -ForegroundColor Green
$distInfoDirs = Get-ChildItem -Path $DistPath -Recurse -Directory -Filter "*.dist-info"
$removedCount = 0
$removedSize = 0
foreach ($infoDir in $distInfoDirs) {
    # Delete only installation-accounting files. Retain METADATA and entry_points.txt because
    # importlib.metadata reads them at runtime, and deleting them breaks plugin discovery.
    $filesToRemove = @("RECORD", "INSTALLER", "direct_url.json")
    foreach ($fileName in $filesToRemove) {
        $file = Join-Path $infoDir.FullName $fileName
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            $removedSize += $size
            Remove-Item $file -Force
            $removedCount++
        }
    }
}
if ($removedCount -gt 0) {
    Write-Host "  Deleted $removedCount metadata files, saving $([math]::Round($removedSize / 1MB, 2)) MB"
} else {
    Write-Host "  No removable metadata found (already optimized)" -ForegroundColor Gray
}

# Measure final size
$FinalSize = (Get-ChildItem -Path $DistPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
$SavedSize = $InitialSize - $FinalSize
$SavedPercent = if ($InitialSize -gt 0) { ($SavedSize / $InitialSize) * 100 } else { 0 }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Initial size: $([math]::Round($InitialSize, 2)) MB" -ForegroundColor Yellow
Write-Host "Final size: $([math]::Round($FinalSize, 2)) MB" -ForegroundColor Green
Write-Host "Space saved: $([math]::Round($SavedSize, 2)) MB ($([math]::Round($SavedPercent, 1))%)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Compare with the reference project
Write-Host "[Reference Comparison]" -ForegroundColor Yellow
Write-Host "Reference project total size: 323 MB (including heavyweight libraries such as PyQt, OpenCV, and Playwright)" -ForegroundColor Gray
Write-Host "For a pure Tkinter + standard-library project, target 80-150 MB" -ForegroundColor Gray
```

**Expected result**: save **15-30%**

### 6. DLL Dependency Analysis Tool

**Save as `analyze_dlls.py` to identify the largest files:**

```python
"""
DLL dependency analysis tool.
Uses the reference project's DLL management strategy to identify major size contributors
and provide optimization recommendations.
"""
import sys
from pathlib import Path


def analyze_dlls(dist_path: str):
    """Analyze DLL dependencies in the dist directory."""
    dist_dir = Path(dist_path)

    if not dist_dir.exists():
        print(f"[ERROR] Directory does not exist: {dist_path}")
        return

    print("=" * 70)
    print("DLL Dependency Analysis (Reference-Project Strategy)")
    print("=" * 70)

    # Collect all DLLs
    dll_files = list(dist_dir.rglob("*.dll"))

    if not dll_files:
        print("\nNo DLL files found")
        return

    # Sort by size
    dll_data = [(dll, dll.stat().st_size) for dll in dll_files]
    dll_data.sort(key=lambda x: x[1], reverse=True)

    total_size = sum(size for _, size in dll_data)

    print(f"\nTotal DLL count: {len(dll_files)}")
    print(f"Total DLL size: {total_size / 1024 / 1024:.2f} MB\n")

    # Reference-project comparison
    print("[Reference Comparison] Reference-project DLLs:")
    print("  - Total count: 71")
    print("  - Total size: 93.23 MB")
    print("  - Largest: libopenblas (26.85 MB), opengl32sw (15.25 MB)\n")

    # Analyze DLLs larger than 3 MB
    large_dlls = [(dll, size) for dll, size in dll_data if size > 3 * 1024 * 1024]

    if large_dlls:
        print("=" * 70)
        print("WARNING: DLLs larger than 3 MB (require close attention)")
        print("=" * 70)

        for dll, size in large_dlls:
            size_mb = size / 1024 / 1024
            relative_path = dll.relative_to(dist_dir)
            name_lower = dll.name.lower()

            print(f"\n{size_mb:8.2f} MB  {dll.name}")
            print(f"           Location: {relative_path.parent}")

            # Optimization recommendations
            suggestions = get_optimization_suggestion(name_lower)
            if suggestions:
                for suggestion in suggestions:
                    print(f"            {suggestion}")

    # Check for redundant DLLs
    print("\n" + "=" * 70)
    print(" Redundancy Check")
    print("=" * 70)

    # Check debug builds
    debug_dlls = [dll for dll, _ in dll_data if dll.stem.endswith('d')]
    if debug_dlls:
        print(f"\nWARNING: Found {len(debug_dlls)} debug DLLs (they can be deleted):")
        for dll in debug_dlls:
            print(f"  - {dll.name}")
    else:
        print("\nPASS: No debug DLLs found (already optimized)")

    # VC++ Runtime
    vc_runtimes = [dll for dll, _ in dll_data if 'vcruntime' in dll.name.lower() or 'msvcp' in dll.name.lower()]
    if vc_runtimes:
        print(f"\n[VC++ Runtime Libraries] Found {len(vc_runtimes)}:")
        for dll in vc_runtimes:
            size_mb = dll.stat().st_size / 1024 / 1024
            print(f"  - {dll.name} ({size_mb:.2f} MB)")
        print("   These are required; the reference project also includes them")

    # Complete DLL list
    print("\n" + "=" * 70)
    print(" Complete DLL List (Top 20 by Size)")
    print("=" * 70)
    print(f"\n{'Size (MB)':>10}  {'Filename':<30}  Location")
    print("-" * 70)

    for dll, size in dll_data[:20]:
        size_mb = size / 1024 / 1024
        relative_path = dll.relative_to(dist_dir)
        location = str(relative_path.parent) if relative_path.parent != Path('.') else "Root directory"
        print(f"{size_mb:10.2f}  {dll.name:<30}  {location}")

    if len(dll_data) > 20:
        remaining_size = sum(size for _, size in dll_data[20:]) / 1024 / 1024
        print(f"... {len(dll_data) - 20} more DLLs, totaling {remaining_size:.2f} MB")


def get_optimization_suggestion(dll_name: str) -> list:
    """Return optimization recommendations based on a DLL filename."""
    suggestions = []

    if "openblas" in dll_name or "mkl" in dll_name:
        suggestions.append("Math library; the reference project's libopenblas is 26.85 MB")
        suggestions.append("Consider a lightweight version if high-performance computing is unnecessary")

    elif "opencv" in dll_name or "ffmpeg" in dll_name:
        suggestions.append("OpenCV-related; the reference project's opencv_videoio_ffmpeg is 18.48 MB")
        suggestions.append("Consider using opencv-python-headless")

    elif "qt5" in dll_name or "qt6" in dll_name or "pyside" in dll_name:
        suggestions.append("Qt library; the reference project's Qt5Core is 5.13 MB")
        suggestions.append("Exclude unneeded modules (WebEngine, 3D, Charts)")

    elif "opengl" in dll_name and "sw" in dll_name:
        suggestions.append("OpenGL software renderer; the reference project retained 15.25 MB")
        suggestions.append("It can usually be removed when hardware rendering is used")

    elif "d3dcompiler" in dll_name:
        suggestions.append("DirectX compiler; the reference project contains 3.53 MB")

    elif "mfc140" in dll_name:
        suggestions.append("MFC library; the reference project contains 4.89 MB")

    return suggestions


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python analyze_dlls.py <dist-directory-path>")
        print("Example: python analyze_dlls.py dist/main.dist")
        sys.exit(1)

    analyze_dlls(sys.argv[1])
```

**Usage:**

```bash
python analyze_dlls.py dist/YourAppName.dist
```

---

## Complete Optimization Workflow

### Step 1: Update the Compilation Script Configuration

Edit `build_optimized.bat` and change these three lines:

```batch
set APP_NAME=YourAppName      REM Replace with the actual name
set MAIN_FILE=main.py         REM Your main program file
set ICON_FILE=icon.ico        REM Your icon file
```

### Step 2: Compile and Slim in One Command

```bash
# Run from the project root
build_optimized.bat
```

### Step 3: Analyze DLL Dependencies

```bash
python analyze_dlls.py dist/YourAppName.dist
```

### Step 4: Optimize Based on the Analysis

**If the app uses OpenCV** → switch to the headless version:

```bash
pip uninstall opencv-python
pip install opencv-python-headless
```

**If the app uses Qt** → exclude unneeded modules:

```batch
# Add to the compilation command
--nofollow-import-to=PyQt5.QtWebEngine,PyQt5.Qt3D,PyQt5.QtCharts
```

**Delete the software renderer** if it is unnecessary:

```powershell
# Run in the dist directory
Remove-Item "opengl32sw.dll" -Force
```

---

## VC++ Runtime Handling

### Option 1: Static Linking (Recommended)

```bash
nuitka --static-libpython=yes ...
```

### Option 2: Bundle the Runtime Installer (Recommended for Commercial Distribution)

Add the following to the Inno Setup script:

```iss
; WARNING: The VC++ runtime architecture must match the Python/Nuitka build architecture.
; This skill recommends 32-bit Python, so it bundles vc_redist.x86.exe by default.
; For a 64-bit Python build, change both occurrences below to vc_redist.x64.exe.
[Files]
Source: "{#MySourceDir}\..\vc_redist.x86.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{tmp}\vc_redist.x86.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing runtime libraries..."; Flags: waituntilterminated
```

> Download: [Microsoft Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)

---

## Inno Setup Script Template (Ultimate Commercial Version)

```iss
; =====================================================================
;  WARNING: Commercial-Grade Python Installer Script (Inno Setup 6.x)
;  Features: LZMA2 ultra compression | English UI | complete metadata | residue-free uninstall
;  Reference: Reference project (323 MB, LZMA2 compression)
; =====================================================================

; --- 1. Parameter definitions ---
#define MyAppName        "{{APP_NAME}}"
#define MyAppVersion     "{{APP_VERSION}}"
#define MyAppPublisher   "{{PUBLISHER}}"
#define MyAppURL         "{{APP_URL}}"
#define MyAppExeName     "{{EXE_NAME}}"
#define MySourceDir      "{{SOURCE_DIR}}"
#define MyOutputDir      "{{OUTPUT_DIR}}"
;#define MyIconPath      "{{ICON_PATH}}"

[Setup]
; --- Identity ---
AppId={{GENERATE_RANDOM_GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; --- Installation path and permissions ---
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=no
PrivilegesRequired=admin

; --- Output settings ---
OutputDir={#MyOutputDir}
OutputBaseFilename=Setup_{#MyAppName}_v{#MyAppVersion}

; --- Visual experience ---
WizardStyle=modern
#ifdef MyIconPath
SetupIconFile={#MyIconPath}
UninstallDisplayIcon={app}\{#MyAppExeName}
#endif

; --- Core compression (reference project) ---
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; --- Architecture ---
; Note: Set this only for a 64-bit Python build. This skill recommends 32-bit Python.
; Keep it commented for 32-bit builds so the app installs in 32-bit mode and matches
; the bundled vc_redist.x86.exe above. Uncomment only when compiling with 64-bit Python.
;ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*"

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
```

---

## Placeholder Reference

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `{{APP_NAME}}` | Application display name | `Red Ink Annotation` |
| `{{APP_VERSION}}` | Version number | `1.0.0` |
| `{{PUBLISHER}}` | Publisher/company name | `MyCompany` |
| `{{APP_URL}}` | Website URL | `https://example.com` |
| `{{EXE_NAME}}` | Main executable filename | `RedInk.exe` |
| `{{SOURCE_DIR}}` | Nuitka dist folder path | `D:\project\dist\RedInk.dist` |
| `{{OUTPUT_DIR}}` | Installer output path | `D:\project\output` |
| `{{ICON_PATH}}` | Icon file path | `D:\project\icon.ico` |
| `{{GENERATE_RANDOM_GUID}}` | **Generate a unique GUID** | Use Inno Setup `Tools > Generate GUID` |

---

## Frequently Asked Questions

### Q1: Nothing happens when I double-click the app after installation

1. Open Command Prompt and run the executable manually to see error output.
2. Check whether the VC++ runtime is missing.
3. Check whether Nuitka compilation succeeded.

### Q2: The installer is too large

**Optimization methods:**

1. Compile with 32-bit Python (save 20-30%).
2. Apply the reference project's module exclusion list.
3. Enable the Anti-Bloat plugin.
4. Run the dist-folder slimming script.
5. Analyze DLLs and remove unnecessary large files.

### Q3: Antivirus software reports a false positive

**Solutions:**

- Submit the application to major antivirus vendors for allowlisting.
- Purchase a code-signing certificate (recommended vendors: Sectigo, DigiCert).
- Avoid UPX compression.

### Q4: Windows says it protected the computer during installation

- Purchase an EV code-signing certificate for immediate reputation.
- A standard code-signing certificate gradually gains reputation as installation volume accumulates.

---

## Practical Issue Log (Updated 2026-02-07)

- **Missing python3xx.dll after installation**: Use Nuitka `--standalone`; confirm that the DLL exists in dist; do not use a single-file build.
- **Nothing happens after launch**: Heavy dependencies may block GUI startup; defer importing them until the user starts the export; add logs for diagnosis.
- **Nuitka + MinGW fails in a non-ASCII path**: Copy the source to an ASCII-only directory before compiling; set `PYTHONIOENCODING=utf-8`.
- **Inno Setup warns that `x64` is deprecated (only when a 64-bit build needs 64-bit installation mode)**: Change it to `ArchitecturesInstallIn64BitMode=x64compatible`; 32-bit builds do not need this setting.
- **`--disable-console` is deprecated**: Use `--windows-console-mode=disable`.
- **`_nuitka_temp.exe` appears in dist**: Exclude it in `[Files]`.

---

## Expected Optimization Results

| Optimization Combination | Size Reduction | Startup Improvement | Risk Level |
|--------------------------|----------------|---------------------|------------|
| Basic compilation | Baseline | Baseline | None |
| + `--lto=yes` | 5-10% | 10-20% | PASS: None |
| + anti-bloat | 15-25% | - | PASS: None |
| + module exclusions | 20-35% | 5% | PASS: None |
| + dist slimming | 25-40% | - | PASS: None |
| + 32-bit compilation | 40-60% | - | PASS: None |
| **All combined** | **45-65%** | **15-25%** | PASS: **No risk** |

> WARNING: **UPX compression is not recommended.** Although it can reduce size further, it is highly likely to trigger antivirus false positives.

---

**Optimized from practical reference-project experience to help you create a commercial-grade installer.**
