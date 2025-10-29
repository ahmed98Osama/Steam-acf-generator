# Steam ACF Generator

[![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ahmed98Osama/Steam-acf-generator/blob/master/GenerateACF_Colab.ipynb)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ahmed98Osama/Steam-acf-generator)

A powerful PowerShell script and Google Colab Python script for generating Steam App Configuration Files (ACF) using SKSAppManifestGenerator.

## 📋 Table of Contents

- [Features](#features)
- [Use Cases](#use-cases)
- [Which File Do I Use?](#which-file-do-i-use)
- [Run Options (Buttons)](#run-options-buttons)
- [Prerequisites](#prerequisites)
- [PowerShell Script Usage](#powershell-script-usage)
  - [Quick Start](#quick-start)
  - [Interactive Mode](#interactive-mode)
  - [Command Line Parameters](#command-line-parameters)
  - [Examples](#examples)
- [Google Colab Script](#google-colab-script)
- [Parameters](#parameters)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

## ✨ Features

- **Automatic Tool Management**: Automatically downloads `SKSAppManifestGenerator` if not found, with fallback to secondary source
- **Interactive & Command-Line Modes**: Choose between user-friendly interactive prompts or direct command-line parameters
- **Batch Processing**: Generate ACF files for multiple App IDs at once
- **Flexible Configuration**: Configure generator path, debug mode, and working directory
- **Error Handling**: Robust error handling with clear user feedback
- **File Verification**: Automatically verifies generated ACF files

## 🧰 Use Cases

- **Offline preparation**: Prepare manifests and folder structures in limited-connectivity environments so Steam recognizes titles when brought online.
- **Repair missing/corrupted manifests**: Regenerate broken `appmanifest_<appid>.acf` files to help Steam re-detect installs or resolve launch issues without full re-downloads.
- **Avoid re-download/re-allocation when files already exist**: If you already have the game files, generate a ready ACF file so Steam can validate or start the game without allocating duplicate space or re-downloading content.

## ❓ Which File Do I Use?

- `GenerateACF.ps1` (PowerShell, Windows)
  - Best for Windows users. Fully supports the Windows-only generator.
  - Run locally in PowerShell and follow prompts.
  - File path: [`GenerateACF.ps1`](./GenerateACF.ps1)

- `GenerateACF_Colab.ipynb` (Google Colab Notebook)
  - Best for running in the browser without local setup.
  - Provides a form UI (widgets). Attempts to use Wine for the Windows executable on Linux.
  - Open in Colab: [Open Notebook](https://colab.research.google.com/github/ahmed98Osama/Steam-acf-generator/blob/master/GenerateACF_Colab.ipynb)
  - File path: [`GenerateACF_Colab.ipynb`](./GenerateACF_Colab.ipynb)

- `generate_acf_colab.py` (Python script)
  - Same logic as the notebook but as a Python file.
  - Useful for cloud IDEs or local Python. Note: Running the Windows `.exe` on Linux requires Wine.
  - File path: [`generate_acf_colab.py`](./generate_acf_colab.py)

## 🚀 Run Options (Buttons)

- Open the self-contained Colab notebook: [Open in Colab](https://colab.research.google.com/github/ahmed98Osama/Steam-acf-generator/blob/master/GenerateACF_Colab.ipynb)
- Launch an online dev environment via Codespaces: [Open in Codespaces](https://codespaces.new/ahmed98Osama/Steam-acf-generator)

> Notes:
> - Colab/Linux runs the generator via Wine when possible; the tool itself is Windows-only.
> - For the smoothest experience, use `GenerateACF.ps1` on Windows.

## 🔧 Prerequisites

- **PowerShell 5.1 or later** (for Windows usage of `GenerateACF.ps1`)
- **Python 3.8+** (for `generate_acf_colab.py` if running locally)
- **Internet connection** (for automatic tool download)

## 🚀 PowerShell Script Usage

Target file: [`GenerateACF.ps1`](./GenerateACF.ps1)

### Quick Start

1. **Clone or download this repository**
   ```powershell
   git clone https://github.com/ahmed98Osama/Steam-acf-generator.git
   cd Steam-acf-generator
   ```

2. **Run the script**
   ```powershell
   .\GenerateACF.ps1
   ```

3. **Follow the prompts**:
   - Choose configuration mode (default or custom)
   - Enter one or more Steam App IDs (e.g., `570 730 440` or `570,730,440`)

### Interactive Mode

When running without parameters, the script enters interactive mode:

```
========================================
  Steam ACF File Generator
========================================

Configuration Options:
1. Use default settings (recommended for first-time users)
2. Configure custom parameters
```

**Option 1: Default Settings**
- Uses default generator path
- Debug mode disabled
- Current directory as working directory

**Option 2: Custom Configuration**
- Set custom generator path
- Enable/disable debug mode
- Set custom working directory

### Command Line Parameters

You can bypass interactive mode by providing parameters directly:

```powershell
.\GenerateACF.ps1 [-GeneratorPath <path>] [-Debug] [-WorkingDirectory <path>]
```

#### Available Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-GeneratorPath` | String | Path to `SKSAppManifestGenerator_x64.exe` | `tools\\SKSAppManifestGenerator\\SKSAppManifestGenerator_x64.exe` |
| `-Debug` | Switch | Enable debug output | Disabled |
| `-WorkingDirectory` | String | Directory where ACF files will be generated | Current directory |

### Examples

#### Example 1: Simple Usage (Interactive Mode)
```powershell
.\GenerateACF.ps1
# Follow the prompts
```

#### Example 2: Enable Debug Mode
```powershell
.\GenerateACF.ps1 -Debug
```

#### Example 3: Custom Generator Path and Working Directory
```powershell
.\GenerateACF.ps1 -GeneratorPath "C:\\Tools\\SKSAppManifestGenerator\\SKSAppManifestGenerator_x64.exe" -WorkingDirectory "C:\\Steam\\ACF"
```

#### Example 4: Complete Example with Multiple Options
```powershell
.\GenerateACF.ps1 -Debug -WorkingDirectory "D:\\Steam\\AppManifests"
# When prompted, enter: 570, 730, 440
```

#### Example 5: Using PowerShell Help
```powershell
Get-Help .\GenerateACF.ps1 -Detailed
Get-Help .\GenerateACF.ps1 -Examples
```

## 📱 Google Colab Script

Target notebook: [`GenerateACF_Colab.ipynb`](./GenerateACF_Colab.ipynb)  
Open it in Colab: [Open in Colab](https://colab.research.google.com/github/ahmed98Osama/Steam-acf-generator/blob/master/GenerateACF_Colab.ipynb)

What you get:
- A clean, form-based UI with input widgets (App IDs, Debug, Working Directory)
- Hidden code; users only interact with the form and output
- Automatic tool download with fallback
- Optional Wine support to attempt running the Windows executable in Colab/Linux

## 🐍 Python Script (Alternative to the Notebook)

Target script: [`generate_acf_colab.py`](./generate_acf_colab.py)

Run locally:
```bash
python generate_acf_colab.py
```
Notes:
- The generator is a Windows executable. On Linux/macOS, install Wine or prefer the PowerShell script on Windows.
- Behavior matches the notebook (same download logic, validation, and execution).

## 📦 Upstream Tool Capabilities (SKSAppManifestGenerator)

This project wraps the upstream SKSAppManifestGenerator tool. For detailed history, fixes, and behavior changes, see the official changelog:

- Changelog: [SKSAppManifestGenerator CHANGELOG.md](https://github.com/Sak32009/SKSAppManifestGenerator/blob/main/CHANGELOG.md)

### CLI usage (summarized)

```
SKSAppManifestGenerator_x64.exe [-h] [-d] appid [appid ...]

positional arguments:
  appid            One or more Steam App IDs

optional arguments:
  -h, --help       Show help message and exit
  -d, --debug      Enable debug output (default: False)
```

### Behavior notes
- Accepts one or more App IDs at once; the wrapper passes multiple IDs in batch.
- When `--debug` is enabled, additional diagnostic output is printed; the wrapper exposes this as `-Debug` (PowerShell) and a checkbox (Colab).
- Output file naming typically follows `appmanifest_<appid>.acf` (the wrapper post-checks with this and `<appid>.acf`).
- The upstream repository is archived/read-only as of 2025, but binaries remain available and functional; see changelog for historical updates and changes.

If you rely on a specific upstream behavior or version, consult the changelog entry for that release and pin your environment accordingly. The wrapper scripts are designed to be forward-compatible with the documented CLI surface.

## 📖 Parameters

### GeneratorPath

Specifies the path to the `SKSAppManifestGenerator_x64.exe` file.

- **Default**: `tools\\SKSAppManifestGenerator\\SKSAppManifestGenerator_x64.exe` (relative to script directory)
- **Interactive**: Can be set during interactive configuration
- **Command Line**: `-GeneratorPath "C:\\Path\\To\\generator.exe"`

If the generator is not found:
- Script will prompt to download automatically
- Primary source: Official GitHub release
- Fallback source: This repository's backup

### Debug

Enables verbose debug output during ACF generation.

- **Default**: Disabled
- **Interactive**: Y/N prompt in custom configuration
- **Command Line**: `-Debug` (switch, no value needed)

When enabled, passes `-d` flag to SKSAppManifestGenerator.

### WorkingDirectory

Specifies where generated ACF files will be saved.

- **Default**: Current PowerShell working directory
- **Interactive**: Can be customized during interactive configuration
- **Command Line**: `-WorkingDirectory "C:\\Path\\To\\Output"`

The directory will be created if it doesn't exist (for custom paths).

## 🔍 Troubleshooting

### Issue: "Generator not found"

**Solution**: The script will automatically prompt to download. Press Enter (Y) to proceed with automatic download.

### Issue: Download fails

**Solution**: The script has two download sources:
1. Primary: Official GitHub release
2. Fallback: This repository

If both fail, you can manually download and specify the path with `-GeneratorPath`.

### Issue: "No valid App IDs provided"

**Solution**: Ensure App IDs are numeric and separated by spaces or commas.

### Issue: PowerShell Execution Policy Error

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: ACF files not generated

**Try**:
1. Enable debug mode: `.\GenerateACF.ps1 -Debug`
2. Check App IDs are valid
3. Review generator output
4. Ensure write permissions

## 🤝 Credits

### Original Tool

This project wraps **SKSAppManifestGenerator** by **[Sak32009](https://github.com/Sak32009/SKSAppManifestGenerator)**.

- Original Repository: [https://github.com/Sak32009/SKSAppManifestGenerator](https://github.com/Sak32009/SKSAppManifestGenerator)
- Download Link: [SKSAppManifestGenerator v2.0.3](https://github.com/Sak32009/SKSAppManifestGenerator/releases/download/v2.0.3/SKSAppManifestGenerator_x64_v2.0.3.zip)

We extend our gratitude to Sak32009 for creating and maintaining this excellent tool.

### This Repository

This wrapper script and Google Colab implementation provide:
- Enhanced user experience with interactive prompts
- Automatic tool management
- Cross-platform entry points (Windows PowerShell + Colab)
- Better error handling and user feedback

## 📝 License

This project is provided as-is for educational and utility purposes. Please refer to the original SKSAppManifestGenerator project for its license terms.

## 🐛 Issues & Contributions

Found a bug or have a feature request? Please open an issue on GitHub!

Contributions are welcome! Feel free to submit pull requests.

## 📚 Additional Resources

- [Steam App IDs Database](https://steamdb.info/apps/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Google Colab Documentation](https://colab.research.google.com/)

---

**Happy ACF Generating! 🎮**

