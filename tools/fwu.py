#!/usr/bin/python3

import subprocess
import os
import getpass
import requests
import zipfile
import json
from io import BytesIO
import shutil
import datetime
import sys
import colorama
import platform
from colorama import Fore, Style
from dotenv import load_dotenv

colorama.init()

# Create a simpler directory structure
FWU_DIR = os.path.join(os.path.expanduser("~"), "fwu")
CONTENT_DIR = os.path.join(FWU_DIR, "content")
SCRIPTS_DIR = os.path.join(FWU_DIR, "scripts")
OUTPUT_DIR = os.path.join(FWU_DIR, "output")
WINDOWS_DIR = os.path.join(CONTENT_DIR, "Retr0Mine_Windows")
LINUX_DIR = os.path.join(CONTENT_DIR, "Retr0Mine_Linux")
CACHE_FILE = os.path.join(FWU_DIR, "current.json")

# Create necessary directories
for directory in [FWU_DIR, CONTENT_DIR, SCRIPTS_DIR, OUTPUT_DIR]:
    os.makedirs(directory, exist_ok=True)

def get_env_path():
    """Return path to .env file in user's home directory"""
    return os.path.join(FWU_DIR, ".retr0mine.env")

def show_progress_bar(downloaded, total, action="Downloading"):
    progress = downloaded / total
    bar_length = 40
    block = int(round(bar_length * progress))
    if progress < 0.33:
        color = Fore.RED 
    elif progress < 0.66:
        color = Fore.YELLOW 
    else:
        color = Fore.GREEN 
    progress_str = (
        f"\r{action} [{color}{'#' * block}{'-' * (bar_length - block)}{Fore.RESET}] {round(progress * 100, 2)}%"
    )
    sys.stdout.write(progress_str)
    sys.stdout.flush()
    
    if progress >= 1.0:
        sys.stdout.write("\n")

def is_windows():
    """Check if running on Windows"""
    return platform.system() == "Windows"

def get_cached_info():
    """Get cached information about the latest build"""
    if not os.path.exists(CACHE_FILE):
        return None
    
    try:
        with open(CACHE_FILE, "r") as f:
            return json.load(f)
    except:
        return None

def update_cached_info(commit_info, success=False, windows_exe=None, linux_exe=None, drm_applied=False):
    """Update the cache file with latest build information"""
    cache_data = {
        "commit_id": commit_info["sha"],
        "commit_message": commit_info["message"],
        "commit_author": commit_info["author"],
        "commit_date": commit_info["date"],
        "date_formatted": commit_info["date_formatted"],
        "success": success,
        "windows_exe": windows_exe,
        "linux_exe": linux_exe,
        "drm_applied": drm_applied,
        "last_updated": datetime.datetime.now().isoformat()
    }
    
    with open(CACHE_FILE, "w") as f:
        json.dump(cache_data, f, indent=2)

def download_github_artifacts(github_token, force_download=False):
    repo_owner = "Odizinne"
    repo_name = "Retr0Mine"
    
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    print(Fore.CYAN + "Fetching latest workflow runs..." + Style.RESET_ALL)
    runs_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/actions/runs"
    runs_response = requests.get(runs_url, headers=headers)
    
    if runs_response.status_code != 200:
        print(Fore.RED + f"Failed to fetch workflow runs: {runs_response.status_code}" + Style.RESET_ALL)
        print(runs_response.text)
        return None, None, None
    
    workflow_runs = runs_response.json()["workflow_runs"]
    latest_successful_run = None
    commit_info = None
    
    for run in workflow_runs:
        if run["conclusion"] == "success":
            latest_successful_run = run
            
            commit_sha = run["head_sha"]
            commit_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/commits/{commit_sha}"
            commit_response = requests.get(commit_url, headers=headers)
            
            if commit_response.status_code == 200:
                commit_data = commit_response.json()
                commit_info = {
                    "sha": commit_sha[:7],
                    "message": commit_data["commit"]["message"].split("\n")[0], 
                    "author": commit_data["commit"]["author"]["name"],
                    "date": commit_data["commit"]["author"]["date"]
                }
                
                commit_date = datetime.datetime.fromisoformat(commit_info["date"].replace("Z", "+00:00"))
                commit_info["date_formatted"] = commit_date.strftime("%Y-%m-%d %H:%M:%S")
                
                print(Fore.GREEN + f"Commit: {commit_info['sha']} - {commit_info['message']} by {commit_info['author']} on {commit_info['date_formatted']}" + Style.RESET_ALL)
            break
    
    if not latest_successful_run:
        print(Fore.RED + "No successful workflow runs found" + Style.RESET_ALL)
        return None, None, None
    
    # Check cache before downloading
    cached_info = get_cached_info()
    if not force_download and cached_info and cached_info.get("success") and cached_info.get("commit_id") == commit_info["sha"]:
        print(Fore.GREEN + "Cache hit! Using cached builds..." + Style.RESET_ALL)
        windows_exe = cached_info.get("windows_exe")
        linux_exe = cached_info.get("linux_exe")
        
        if os.path.exists(windows_exe) and os.path.exists(linux_exe):
            print(Fore.GREEN + f"Using cached Windows EXE: {windows_exe}" + Style.RESET_ALL)
            print(Fore.GREEN + f"Using cached Linux binary: {linux_exe}" + Style.RESET_ALL)
            return windows_exe, linux_exe, commit_info
        else:
            print(Fore.YELLOW + "Cached paths don't exist, downloading fresh builds..." + Style.RESET_ALL)
    else:
        if force_download:
            print(Fore.YELLOW + "Forced download, ignoring cache..." + Style.RESET_ALL)
        elif not cached_info:
            print(Fore.YELLOW + "No cache file found..." + Style.RESET_ALL)
        elif cached_info.get("commit_id") != commit_info["sha"]:
            print(Fore.YELLOW + "New commit detected, downloading fresh builds..." + Style.RESET_ALL)
        else:
            print(Fore.YELLOW + "Previous download was unsuccessful, trying again..." + Style.RESET_ALL)
    
    # Update cache with new commit info (download not yet successful)
    update_cached_info(commit_info, success=False)
    
    run_id = latest_successful_run["id"]
    print(Fore.GREEN + f"Found latest successful run: {run_id}" + Style.RESET_ALL)
    
    artifacts_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/actions/runs/{run_id}/artifacts"
    artifacts_response = requests.get(artifacts_url, headers=headers)
    
    if artifacts_response.status_code != 200:
        print(Fore.RED + f"Failed to fetch artifacts: {artifacts_response.status_code}" + Style.RESET_ALL)
        return None, None, None
    
    artifacts = artifacts_response.json()["artifacts"]

    # Clear existing content
    if os.path.exists(WINDOWS_DIR):
        shutil.rmtree(WINDOWS_DIR)
    if os.path.exists(LINUX_DIR):
        shutil.rmtree(LINUX_DIR)
        
    os.makedirs(WINDOWS_DIR, exist_ok=True)
    os.makedirs(LINUX_DIR, exist_ok=True)

    windows_artifact_path = None
    linux_artifact_path = None
    
    for artifact in artifacts:
        artifact_name = artifact["name"]
        download_url = artifact["archive_download_url"]
        size_in_bytes = artifact["size_in_bytes"]
                
        response = requests.get(download_url, headers=headers, stream=True)
        
        if response.status_code != 200:
            print(Fore.RED + f"Failed to download {artifact_name}" + Style.RESET_ALL)
            continue
            
        total_size = int(response.headers.get('content-length', size_in_bytes))
        
        content = BytesIO()
        downloaded = 0
        
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                content.write(chunk)
                downloaded += len(chunk)
                show_progress_bar(downloaded, total_size, f"Downloading {artifact_name}")
        
        content.seek(0)
        
        if artifact_name == "Retr0Mine_Windows":
            target_dir = WINDOWS_DIR
            
            with zipfile.ZipFile(content) as z:
                file_list = z.namelist()
                total_files = len(file_list)
                
                for i, file in enumerate(file_list):
                    z.extract(file, target_dir)
                    show_progress_bar(i + 1, total_files, "Extracting Windows files")
                    
            windows_artifact_path = os.path.join(target_dir, "bin", "Retr0Mine.exe")
            
        elif artifact_name == "Retr0Mine_Linux":
            target_dir = LINUX_DIR
            
            with zipfile.ZipFile(content) as z:
                file_list = z.namelist()
                total_files = len(file_list)
                
                for i, file in enumerate(file_list):
                    z.extract(file, target_dir)
                    show_progress_bar(i + 1, total_files, "Extracting Linux files")
                    
            linux_artifact_path = os.path.join(target_dir, "bin", "Retr0Mine")
            # Ensure Linux executable has execute permissions
            if os.path.exists(linux_artifact_path):
                os.chmod(linux_artifact_path, 0o755)
    
    # Update cache with successful download (but DRM not yet applied)
    if windows_artifact_path and linux_artifact_path:
        if os.path.exists(windows_artifact_path) and os.path.exists(linux_artifact_path):
            # Preserve drm_applied status if it exists
            drm_applied = cached_info.get("drm_applied", False) if cached_info else False
            update_cached_info(commit_info, success=True, 
                             windows_exe=windows_artifact_path, 
                             linux_exe=linux_artifact_path,
                             drm_applied=drm_applied)
    
    return windows_artifact_path, linux_artifact_path, commit_info

def update_env_variable(variable_name, value):
    """Update a variable in the .env file"""
    env_path = get_env_path()
    
    # Create or read existing content
    env_content = ""
    if os.path.exists(env_path):
        with open(env_path, "r") as env_file:
            env_content = env_file.read()
    
    # Update or add the variable
    if f"{variable_name}=" in env_content:
        lines = env_content.split("\n")
        updated_lines = []
        for line in lines:
            if line.startswith(f"{variable_name}="):
                updated_lines.append(f"{variable_name}={value}")
            else:
                updated_lines.append(line)
        env_content = "\n".join(updated_lines)
    else:
        if env_content and not env_content.endswith("\n"):
            env_content += "\n"
        env_content += f"{variable_name}={value}"
        
    with open(env_path, "w") as env_file:
        env_file.write(env_content)
    
    return env_path

def get_username_from_env():
    load_dotenv(get_env_path())
    username = os.getenv("STEAM_USERNAME")
    
    if not username:
        print(Fore.YELLOW + "Steam username not found in .env file" + Style.RESET_ALL)
        username = input("Enter your Steam username: ")
        env_path = update_env_variable("STEAM_USERNAME", username)
        print(Fore.GREEN + f"Username saved to .env file: {env_path}" + Style.RESET_ALL)
    
    return username

def get_password_from_env():
    load_dotenv(get_env_path())
    password = os.getenv("STEAM_PASSWORD")

    if not password:
        print(Fore.YELLOW + "Steam password not found in .env file" + Style.RESET_ALL)
        password = getpass.getpass("Enter your Steam password: ")
        env_path = update_env_variable("STEAM_PASSWORD", password)
        print(Fore.GREEN + f"Password saved to .env file: {env_path}" + Style.RESET_ALL)

    return password

def get_github_token_from_env():
    load_dotenv(get_env_path())
    token = os.getenv("GITHUB_TOKEN")
    
    if not token:
        print(Fore.YELLOW + "Github token not found in .env file" + Style.RESET_ALL)
        token = input("Enter your github token: ")
        env_path = update_env_variable("GITHUB_TOKEN", token)
        print(Fore.GREEN + f"Github token saved to .env file: {env_path}" + Style.RESET_ALL)
    
    return token

def find_steamcmd():
    """Check if steamcmd is in the system PATH or use platform-specific paths."""
    try:
        subprocess.run(["steamcmd", "+quit"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return "steamcmd"  # steamcmd found in PATH
    except FileNotFoundError:
        # Platform-specific default paths
        if is_windows():
            return "C:\\Program Files (x86)\\Steam\\steamcmd.exe"
        else:
            for path in [
                "/usr/bin/steamcmd",
                "/usr/games/steamcmd",
                os.path.expanduser("~/.steam/steam/steamcmd/steamcmd.sh"),
                os.path.expanduser("~/.steam/steamcmd/steamcmd.sh")
            ]:
                if os.path.exists(path):
                    return path
            
            try:
                subprocess.run(["steamcmd.sh", "+quit"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return "steamcmd.sh"
            except FileNotFoundError:
                print(Fore.RED + "Could not find steamcmd. Please install it or add it to your PATH." + Style.RESET_ALL)
                sys.exit(1)

def create_vdf_files():
    """Create VDF configuration files if they don't exist."""
    
    # File paths for VDF files
    WINDOWS_DEPOT = os.path.join(SCRIPTS_DIR, "depot_3478031.vdf")
    LINUX_DEPOT = os.path.join(SCRIPTS_DIR, "depot_3478032.vdf")
    APP_BUILD = os.path.join(SCRIPTS_DIR, "app_3478030.vdf")
    
    # Create Windows depot config
    windows_depot_content = f'''"DepotBuildConfig"
{{
	"DepotID" "3478031"
	"contentroot" "{WINDOWS_DIR.replace(os.sep, '/')}"
	"FileMapping"
	{{
		"LocalPath" "*"
		"DepotPath" "."
		"recursive" "1"
	}}
	"FileExclusion" "*.pdb"
}}'''
    
    with open(WINDOWS_DEPOT, "w") as f:
        f.write(windows_depot_content)
    
    # Create Linux depot config
    linux_depot_content = f'''"DepotBuildConfig"
{{
	"DepotID" "3478032"
	"contentroot" "{LINUX_DIR.replace(os.sep, '/')}"
	"FileMapping"
	{{
		"LocalPath" "*"
		"DepotPath" "."
		"recursive" "1"
	}}
	"FileExclusion" "*.pdb"
}}'''
    
    with open(LINUX_DEPOT, "w") as f:
        f.write(linux_depot_content)
    
    # Create app build config
    app_content = f'''"appbuild"
{{
	"appid" "3478030"
	"desc" ""
	"buildoutput" "{OUTPUT_DIR.replace(os.sep, '/')}"
	"contentroot" ""
	"setlive" ""
	"preview" "0"
	"local" ""
	"depots"
	{{
		"3478031" "{WINDOWS_DEPOT.replace(os.sep, '/')}"
		"3478032" "{LINUX_DEPOT.replace(os.sep, '/')}"
	}}
}}'''
    
    with open(APP_BUILD, "w") as f:
        f.write(app_content)
    
    return APP_BUILD

def run_process_with_output(command):
    """Run a process and display its output in real time"""
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,  # Line buffered
        universal_newlines=True
    )
    
    # Read and display output in real time
    drm_success = False
    for line in iter(process.stdout.readline, ''):
        print(line, end='')
        
        # Check for DRM success message
        if "DRM wrap completed" in line:
            drm_success = True
    
    process.stdout.close()
    return_code = process.wait()
    return return_code, drm_success

def apply_drm_and_upload(windows_exe, username, password, commit_info=None, force_drm=False):
    # Check cache for DRM status
    cached_info = get_cached_info()
    drm_already_applied = False
    
    if not force_drm and cached_info and cached_info.get("drm_applied"):
        if cached_info.get("commit_id") == commit_info["sha"]:
            drm_already_applied = True
            print(Fore.GREEN + "DRM already applied to this build. Skipping DRM wrap." + Style.RESET_ALL)
    
    # Create VDF files
    app_build = create_vdf_files()
    
    steamcmd_path = find_steamcmd()
    
    # Create build description based on commit info
    build_desc = "Auto upload"
    if commit_info:
        build_desc = f"{commit_info['sha']} - {commit_info['message']}"
        # Steam has a limit on description length
        if len(build_desc) > 50:
            build_desc = build_desc[:47] + "..."
    
    # Build the command
    if drm_already_applied:
        # Skip DRM wrapping, just run app build
        upload_command = [
            steamcmd_path,
            "+login", username, password,
            "+run_app_build", "-desc", build_desc, app_build,
            "+quit"
        ]
        print(Fore.YELLOW + f"Uploading to Steam (DRM already applied)..." + Style.RESET_ALL)
    else:
        # Apply DRM and upload
        upload_command = [
            steamcmd_path,
            "+login", username, password,
            "+drm_wrap", "3478030", windows_exe, windows_exe, "drmtoolp", "0",
            "+run_app_build", "-desc", build_desc, app_build,
            "+quit"
        ]
        print(Fore.YELLOW + f"Applying DRM to Windows build and uploading to Steam..." + Style.RESET_ALL)
    
    print(Fore.YELLOW + f"Build description: {build_desc}" + Style.RESET_ALL)
    
    try:
        return_code, drm_success = run_process_with_output(upload_command)
        
        if return_code != 0:
            print(Fore.RED + f"Upload failed with error code: {return_code}" + Style.RESET_ALL)
            return False
        else:
            print(Fore.GREEN + "Upload completed successfully!" + Style.RESET_ALL)
            
            # Update cache with DRM status if it was just applied successfully
            if (not drm_already_applied and drm_success) or (drm_already_applied):
                # Update the cache file to indicate DRM has been applied
                if cached_info:
                    update_cached_info(
                        commit_info, 
                        success=cached_info.get("success", True),
                        windows_exe=cached_info.get("windows_exe"),
                        linux_exe=cached_info.get("linux_exe"),
                        drm_applied=True
                    )
            
            return True
            
    except Exception as e:
        print(Fore.RED + f"Error during upload: {str(e)}" + Style.RESET_ALL)
        return False

if __name__ == "__main__":
    print(Fore.MAGENTA + "Retr0Mine FWU - Fetch / Wrap / Upload" + Style.RESET_ALL)
    
    # Parse command line arguments
    force_download = "--force" in sys.argv or "-f" in sys.argv
    force_drm = "--force-drm" in sys.argv or "-fd" in sys.argv
    
    token = get_github_token_from_env()
    username = get_username_from_env()
    password = get_password_from_env()

    print(Fore.MAGENTA + "Starting GitHub artifacts download..." + Style.RESET_ALL)
    windows_exe, linux_exe, commit_info = download_github_artifacts(token, force_download)
    
    if windows_exe and os.path.exists(windows_exe) and linux_exe and os.path.exists(linux_exe):
        print(Fore.GREEN + "Content ready!" + Style.RESET_ALL)
        
        if password != "skip":
            print(Fore.MAGENTA + "Starting Steam wrap and upload..." + Style.RESET_ALL)
            apply_drm_and_upload(windows_exe, username, password, commit_info, force_drm)
        else:
            print(Fore.YELLOW + "Password skipped, no steam upload." + Style.RESET_ALL)
    else:
        print(Fore.RED + "Content missing or download failed!!" + Style.RESET_ALL)