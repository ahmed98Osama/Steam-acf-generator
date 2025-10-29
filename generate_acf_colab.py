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

# Configuration
PRIMARY_URL = 'https://github.com/Sak32009/SKSAppManifestGenerator/releases/download/v2.0.3/SKSAppManifestGenerator_x64_v2.0.3.zip'
FALLBACK_URL = 'https://github.com/ahmed98Osama/Steam-acf-generator/raw/master/SKSAppManifestGenerator_x64.exe'
TOOL_DIR = './tools/SKSAppManifestGenerator'
TOOL_NAME = 'SKSAppManifestGenerator_x64.exe'
TOOL_PATH = os.path.join(TOOL_DIR, TOOL_NAME)

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

def download_file(url, output_path):
    """Download a file from URL"""
    try:
        print_info(f"Downloading from: {url}")
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\r  Progress: {percent:.1f}%", end='', flush=True)
        print()  # New line after progress
        return True
    except Exception as e:
        print_warn(f"Download failed: {str(e)}")
        return False

def extract_zip(zip_path, extract_to):
    """Extract ZIP file"""
    try:
        print_info(f"Extracting {zip_path} to {extract_to}")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
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

def setup_tool():
    """Download and setup SKSAppManifestGenerator"""
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
        if extract_zip(temp_zip, temp_extract):
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

def validate_app_ids(app_ids_input):
    """Validate and normalize App IDs"""
    if not app_ids_input or not app_ids_input.strip():
        return []
    
    # Split by space or comma
    tokens = app_ids_input.replace(',', ' ').split()
    app_ids = []
    
    for token in tokens:
        token = token.strip()
        if token.isdigit():
            app_ids.append(token)
        elif token:
            print_warn(f"Skipping invalid App ID: {token}")
    
    return app_ids

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
        
        # Check if Wine is available (for Linux/Colab)
        wine_available = shutil.which('wine') is not None
        
        if wine_available:
            print_info("Wine detected. Using Wine to run Windows executable.")
            cmd = ['wine'] + cmd
        
        # Attempt to run
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if result.returncode == 0:
                print_success("ACF files generated successfully!")
                print(result.stdout)
            else:
                print_warn(f"Generator returned code {result.returncode}")
                print(result.stderr)
        except FileNotFoundError:
            print_err("Cannot execute Windows executable on Linux.")
            print_info("Please use the PowerShell script on Windows, or install Wine.")
        except subprocess.TimeoutExpired:
            print_err("Generator timed out")
    
    finally:
        os.chdir(original_dir)
    
    # Check for generated files
    found_files = []
    for app_id in app_ids:
        candidates = [
            os.path.join(working_dir, f"appmanifest_{app_id}.acf"),
            os.path.join(working_dir, f"{app_id}.acf")
        ]
        for candidate in candidates:
            if os.path.exists(candidate):
                found_files.append(candidate)
                break
    
    if found_files:
        print_success(f"Found {len(found_files)} generated file(s):")
        for f in found_files:
            print(f"  - {f}")
    else:
        print_warn("No ACF files detected. Check generator output above.")

def main():
    """Main function"""
    show_welcome()
    
    # Setup tool
    tool_path = setup_tool()
    if not tool_path:
        print_err("Could not setup SKSAppManifestGenerator. Exiting.")
        sys.exit(1)
    
    # Get user input
    print("\n" + "=" * 50)
    print(f"{Colors.YELLOW}Configuration{Colors.RESET}")
    print("=" * 50)
    
    # Debug mode
    debug_input = input("\nEnable debug output? (Y/n): ").strip().lower()
    debug = debug_input in ('y', 'yes', '')
    
    # Working directory
    working_dir_input = input(f"\nWorking directory (current: {os.getcwd()}, press Enter to keep): ").strip()
    working_dir = working_dir_input if working_dir_input else os.getcwd()
    
    # App IDs
    print("\n" + "=" * 50)
    app_ids_input = input("Enter one or more App IDs (space or comma separated): ")
    app_ids = validate_app_ids(app_ids_input)
    
    if not app_ids:
        print_err("No valid App IDs provided. Exiting.")
        sys.exit(1)
    
    print(f"\n{Colors.GREEN}Valid App IDs:{Colors.RESET} {', '.join(app_ids)}")
    
    # Generate files
    print("\n" + "=" * 50)
    generate_acf_files(tool_path, app_ids, debug, working_dir)
    
    print("\n" + "=" * 50)
    print_success("Process completed!")
    print("=" * 50 + "\n")

if __name__ == "__main__":
    main()

