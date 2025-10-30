"""
Steam ACF Generator for Google Colab
=====================================

This script generates Steam App Configuration Files (ACF) using SKSAppManifestGenerator.

Note: Google Colab runs on Linux, so we'll download the tool and use appropriate methods
to execute it. This script attempts to handle cross-platform compatibility.

Credits: Uses SKSAppManifestGenerator by Sak32009
Original: https://github.com/Sak32009/SKSAppManifestGenerator
"""

import os
import sys
import requests
import zipfile
import subprocess
import shutil
from pathlib import Path
import argparse
import unicodedata
import platform

# Configuration
PRIMARY_URL = 'https://github.com/Sak32009/SKSAppManifestGenerator/releases/download/v2.0.3/SKSAppManifestGenerator_x64_v2.0.3.zip'
FALLBACK_URL = 'https://github.com/ahmed98Osama/Steam-acf-generator/raw/master/SKSAppManifestGenerator_x64.exe'
TOOL_DIR = './tools/SKSAppManifestGenerator'
TOOL_NAME = 'SKSAppManifestGenerator_x64.exe'
TOOL_PATH = os.path.join(TOOL_DIR, TOOL_NAME)
ZIP_PASSWORD = b'cs.rin.ru'

# Colors for output
class Colors:
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    GRAY = '\033[90m'
    RESET = '\033[0m'

def print_info(msg):
    print(f"{Colors.CYAN}[INFO]{Colors.RESET} {msg}")

def print_warn(msg):
    print(f"{Colors.YELLOW}[WARN]{Colors.RESET} {msg}")

def print_err(msg):
    print(f"{Colors.RED}[ERROR]{Colors.RESET} {msg}")

def print_success(msg):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.RESET} {msg}")

def _progress_bar(pct: float, width: int = 30) -> str:
    pct = max(0.0, min(100.0, pct))
    filled = int(round((pct / 100.0) * width))
    return '[' + ('#' * filled) + ('-' * (width - filled)) + ']'

def show_welcome():
    """Display welcome message"""
    print("\n" + "=" * 50)
    print(f"{Colors.CYAN}  Steam ACF File Generator (Google Colab){Colors.RESET}")
    print("=" * 50)
    print("\nThis script generates ACF files for Steam App IDs using SKSAppManifestGenerator.")
    print(f"\n{Colors.YELLOW}Credits:{Colors.RESET}")
    print("  Original tool: SKSAppManifestGenerator by Sak32009")
    print("  Repository: https://github.com/Sak32009/SKSAppManifestGenerator")
    print("=" * 50 + "\n")

def download_file(url, output_path, timeout=600):
    """Download a file from URL with multiple strategies (wget, curl, then requests)."""
    try:
        print_info(f"Downloading from: {url}")
        # 1) Try wget
        wget = shutil.which('wget') or shutil.which('wget.exe')
        if wget:
            tmp_out = output_path + '.part'
            args = [
                '--tries=3', '--timeout=20', '--read-timeout=20', '--no-verbose',
                '-O', tmp_out, url
            ]
            proc = subprocess.run([wget] + args, capture_output=True, text=False)
            if proc.returncode == 0 and os.path.exists(tmp_out) and os.path.getsize(tmp_out) > 0:
                os.replace(tmp_out, output_path)
                return True
            else:
                if os.path.exists(tmp_out):
                    try:
                        os.remove(tmp_out)
                    except Exception:
                        pass
                print_warn(f"wget failed (code {proc.returncode if proc else 'N/A'}); trying curl...")

        # 2) Try curl
        curl = shutil.which('curl') or shutil.which('curl.exe')
        if curl:
            tmp_out = output_path + '.part'
            args = [
                '-fL', '--retry', '3', '--retry-delay', '2',
                '--connect-timeout', '20', '--max-time', str(timeout),
                '-A', 'Python-ACFDownloader/1.0',
                '-o', tmp_out, url
            ]
            proc = subprocess.run([curl] + args, capture_output=True, text=False)
            if proc.returncode == 0 and os.path.exists(tmp_out) and os.path.getsize(tmp_out) > 0:
                os.replace(tmp_out, output_path)
                return True
            else:
                if os.path.exists(tmp_out):
                    try:
                        os.remove(tmp_out)
                    except Exception:
                        pass
                print_warn(f"curl failed (code {proc.returncode if proc else 'N/A'}); falling back to Python HTTP.")

        # 3) Fallback: requests streaming
        headers = {"User-Agent": "Python-ACFDownloader/1.0"}
        response = requests.get(url, stream=True, headers=headers, timeout=timeout)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0

        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        bar = _progress_bar(percent)
                        print(f"\r  {bar} {percent:5.1f}%", end='', flush=True)
        if total_size > 0:
            print(f"\r  {_progress_bar(100)} {100:5.1f}%", end='', flush=True)
        print()
        return True
    except Exception as e:
        print_warn(f"Download failed: {str(e)}")
        return False

def extract_zip(zip_path, extract_to, password: bytes | None = None):
    """Extract ZIP file"""
    try:
        print_info(f"Extracting {zip_path} to {extract_to}")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            if password:
                try:
                    zip_ref.extractall(extract_to, pwd=password)
                except RuntimeError as re:
                    print_warn(f"Passworded extraction failed ({re}); retrying without password...")
                    zip_ref.extractall(extract_to)
            else:
                zip_ref.extractall(extract_to)
        return True
    except Exception as e:
        print_warn(f"Extraction failed: {str(e)}")
        return False

def find_executable(directory):
    """Find the executable in extracted directory"""
    for root, dirs, files in os.walk(directory):
        if TOOL_NAME in files:
            return os.path.join(root, TOOL_NAME)
    return None

def ensure_wine() -> str | None:
    """Ensure Wine is available on Linux environments. Returns command name (wine/wine64) or None."""
    system = platform.system().lower()
    if 'windows' in system:
        return None
    # Check existing
    for candidate in ('wine', 'wine64'):
        if shutil.which(candidate):
            return candidate
    # Try to install via apt-get when available
    print_info("Wine not detected. Attempting to install Wine...")
    apt = shutil.which('apt-get')
    try:
        if apt:
            subprocess.run([apt, 'update'], check=True)
            subprocess.run([apt, 'install', '-y', 'wine', 'wine64'], check=True)
    except Exception as e:
        print_warn(f"Automatic Wine installation failed: {e}")
    # Re-check
    for candidate in ('wine', 'wine64'):
        if shutil.which(candidate):
            print_success(f"Wine installed: {candidate}")
            return candidate
    print_err("Wine is not available; cannot run Windows executables on this platform without Wine.")
    return None

def setup_tool():
    """Download and setup SKSAppManifestGenerator"""
    # Ensure Wine is installed first on non-Windows systems before any downloads
    if platform.system().lower() != 'windows':
        ensure_wine()

    # Check if tool already exists
    if os.path.exists(TOOL_PATH):
        print_info(f"Tool found at: {TOOL_PATH}")
        return TOOL_PATH
    
    print_warn(f"Tool not found at: {TOOL_PATH}")
    
    # Create tools directory
    os.makedirs(TOOL_DIR, exist_ok=True)
    
    # Try primary source (ZIP)
    temp_zip = '/tmp/sks_generator.zip'
    temp_extract = '/tmp/sks_generator_extract'
    
    print_info("Attempting download from primary source...")
    if download_file(PRIMARY_URL, temp_zip):
        os.makedirs(temp_extract, exist_ok=True)
        if extract_zip(temp_zip, temp_extract, password=ZIP_PASSWORD):
            # Find the executable
            exe_path = find_executable(temp_extract)
            if exe_path:
                shutil.copy2(exe_path, TOOL_PATH)
                os.chmod(TOOL_PATH, 0o755)
                os.remove(temp_zip)
                shutil.rmtree(temp_extract, ignore_errors=True)
                print_success(f"Tool installed at: {TOOL_PATH}")
                return TOOL_PATH
    
    # Try fallback source (direct EXE)
    print_info("Primary download failed. Attempting fallback source...")
    if download_file(FALLBACK_URL, TOOL_PATH):
        os.chmod(TOOL_PATH, 0o755)
        print_success(f"Tool installed from fallback at: {TOOL_PATH}")
        return TOOL_PATH
    
    print_err("Failed to download tool from both sources")
    return None

def convert_to_ascii_digits(text: str) -> str:
    """Normalize any locale-specific digits to ASCII 0-9."""
    if not text:
        return text
    normalized = []
    for ch in text:
        try:
            dec = unicodedata.decimal(ch)
            normalized.append(chr(ord('0') + int(dec)))
        except Exception:
            normalized.append(ch)
    return ''.join(normalized)


def extract_digits_only(text: str):
    """Extract numeric sequences as tokens from text (drops non-digits)."""
    if not text:
        return []
    text = convert_to_ascii_digits(text)
    tokens = []
    current = []
    for ch in text:
        if '0' <= ch <= '9':
            current.append(ch)
        elif current:
            tokens.append(''.join(current))
            current = []
    if current:
        tokens.append(''.join(current))
    return tokens


def validate_app_ids(app_ids_input):
    """Validate and normalize App IDs"""
    if not app_ids_input or not app_ids_input.strip():
        return []
    return extract_digits_only(app_ids_input)

def generate_acf_files(tool_path, app_ids, debug=False, working_dir=None):
    """Generate ACF files for given App IDs"""
    if working_dir is None:
        working_dir = os.getcwd()
    
    # Ensure working directory exists
    os.makedirs(working_dir, exist_ok=True)
    
    # Build command
    cmd = [tool_path]
    if debug:
        cmd.append('-d')
    cmd.extend(app_ids)
    
    print_info(f"Generating ACF files for App IDs: {', '.join(app_ids)}")
    print_info(f"Working directory: {working_dir}")
    print_info(f"Command: {' '.join(cmd)}")
    
    # Change to working directory
    original_dir = os.getcwd()
    try:
        os.chdir(working_dir)
        
        # Note: SKSAppManifestGenerator is a Windows executable
        # On Linux/Colab, we'll attempt to use Wine if available
        # Otherwise, this will demonstrate the limitation
        print_info("Attempting to execute generator...")
        wine_cmd = None
        if platform.system().lower() != 'windows':
            # Ensure Wine on non-Windows systems
            wine_cmd = ensure_wine()
        
        if wine_cmd:
            print_info(f"Using {wine_cmd} to run Windows executable.")
            cmd = [wine_cmd] + cmd
        # Show the final command for transparency
        try:
            printable_cmd = ' '.join(cmd)
        except Exception:
            printable_cmd = str(cmd)
        print_info(f"Command: {printable_cmd}")
        
        # Attempt to run
        try:
            result = subprocess.run(cmd, capture_output=True, text=False, timeout=600)
            stdout_text = (result.stdout or b'').decode('utf-8', errors='replace')
            stderr_text = (result.stderr or b'').decode('utf-8', errors='replace')
            if result.returncode == 0:
                print_success("ACF files generated successfully!")
                print(stdout_text)
            else:
                print_warn(f"Generator returned code {result.returncode}")
                print(stderr_text)
        except FileNotFoundError:
            print_err("Cannot execute Windows executable on Linux.")
            print_info("Please use the PowerShell script on Windows, or install Wine.")
        except OSError as e:
            msg = str(e)
            if ('Exec format error' in msg or 'format error' in msg) and (not wine_cmd) and platform.system().lower() != 'windows':
                # Retry with wine if not already used
                for candidate in ('wine', 'wine64'):
                    if shutil.which(candidate):
                        try:
                            result = subprocess.run([candidate] + cmd, capture_output=True, text=False, timeout=600)
                            stdout_text = (result.stdout or b'').decode('utf-8', errors='replace')
                            stderr_text = (result.stderr or b'').decode('utf-8', errors='replace')
                            if result.returncode == 0:
                                print_success("ACF files generated successfully!")
                                print(stdout_text)
                            else:
                                print_warn(f"Generator returned code {result.returncode}")
                                print(stderr_text)
                            break
                        except Exception as e2:
                            print_err(f"Retry with {candidate} failed: {e2}")
                else:
                    print_err("Wine not available; cannot run Windows executable on this platform.")
            else:
                raise
        except subprocess.TimeoutExpired:
            print_err("Generator timed out")
    
    finally:
        os.chdir(original_dir)
    
    # Check for generated files (search recursively to catch Wine subfolders)
    found_files = []
    for app_id in app_ids:
        target_names = {f"appmanifest_{app_id}.acf", f"{app_id}.acf"}
        found_for_app = None
        for root, dirs, files in os.walk(working_dir):
            for name in files:
                if name in target_names:
                    found_for_app = os.path.join(root, name)
                    break
            if found_for_app:
                found_files.append(found_for_app)
                break
    
    if found_files:
        print_success(f"Found {len(found_files)} generated file(s):")
        for f in found_files:
            print(f"  - {f}")
    else:
        print_warn("No ACF files detected. Check generator output above.")

def parse_args():
    parser = argparse.ArgumentParser(description="Steam ACF Generator wrapper for SKSAppManifestGenerator")
    parser.add_argument("--GeneratorPath", dest="generator_path", help="Path to SKSAppManifestGenerator_x64.exe")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output")
    parser.add_argument("--WorkingDirectory", dest="working_dir", help="Directory to output ACF files")
    parser.add_argument("--AppId", dest="app_id", help="App IDs string; accepts spaces/commas/mixed separators and non-ASCII digits")
    return parser.parse_args()


def main():
    """Main function"""
    show_welcome()

    args = parse_args()

    global TOOL_PATH
    if args.generator_path:
        TOOL_PATH = args.generator_path

    tool_path = setup_tool()
    if not tool_path:
        print_err("Could not setup SKSAppManifestGenerator. Exiting.")
        sys.exit(1)

    has_cli = any([args.app_id, args.working_dir, args.debug, args.generator_path])

    if has_cli:
        debug = bool(args.debug)
        working_dir = args.working_dir if args.working_dir else os.getcwd()
        app_ids = validate_app_ids(args.app_id or "")
        if not app_ids:
            print_err("No valid App IDs provided via --AppId.")
            sys.exit(1)
        print(f"\n{Colors.GREEN}Valid App IDs:{Colors.RESET} {', '.join(app_ids)}")
        print("\n" + "=" * 50)
        generate_acf_files(tool_path, app_ids, debug, working_dir)
        print("\n" + "=" * 50)
        print_success("Process completed!")
        print("=" * 50 + "\n")
        return

    print("\n" + "=" * 50)
    print(f"{Colors.YELLOW}Configuration{Colors.RESET}")
    print("=" * 50)

    debug_input = input("\nEnable debug output? (Y/n): ").strip().lower()
    debug = debug_input in ('y', 'yes', '')

    working_dir_input = input(f"\nWorking directory (current: {os.getcwd()}, press Enter to keep): ").strip()
    working_dir = working_dir_input if working_dir_input else os.getcwd()

    print("\n" + "=" * 50)
    app_ids_input = input("Enter one or more App IDs (space/comma/mixed separators allowed): ")
    app_ids = validate_app_ids(app_ids_input)

    if not app_ids:
        print_err("No valid App IDs provided. Exiting.")
        sys.exit(1)

    print(f"\n{Colors.GREEN}Valid App IDs:{Colors.RESET} {', '.join(app_ids)}")

    print("\n" + "=" * 50)
    generate_acf_files(tool_path, app_ids, debug, working_dir)

    print("\n" + "=" * 50)
    print_success("Process completed!")
    print("=" * 50 + "\n")

if __name__ == "__main__":
    main()

