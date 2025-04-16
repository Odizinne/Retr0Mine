#!/usr/bin/python3

import subprocess
import os
import getpass
import requests
import zipfile
from io import BytesIO
import shutil
import datetime
import sys
import colorama
from colorama import Fore, Style
from dotenv import load_dotenv

colorama.init()

def get_env_path():
    """Return path to .env file in user's home directory"""
    home_dir = os.path.expanduser("~")
    return os.path.join(home_dir, ".retr0mine.env")

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

def download_github_artifacts(github_token):
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
    
    run_id = latest_successful_run["id"]
    print(Fore.GREEN + f"Found latest successful run: {run_id}" + Style.RESET_ALL)
    
    artifacts_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/actions/runs/{run_id}/artifacts"
    artifacts_response = requests.get(artifacts_url, headers=headers)
    
    if artifacts_response.status_code != 200:
        print(Fore.RED + f"Failed to fetch artifacts: {artifacts_response.status_code}" + Style.RESET_ALL)
        return None, None, None
    
    artifacts = artifacts_response.json()["artifacts"]

    user_home = os.path.expanduser("~")
    base_cb_dir = os.path.join(user_home, "Documents", "ContentBuilder", "Content")
    windows_dir = os.path.join(base_cb_dir, "Retr0Mine_Windows")
    linux_dir = os.path.join(base_cb_dir, "Retr0Mine_Linux")

    for directory in [windows_dir, linux_dir]:
        if os.path.exists(directory):
            shutil.rmtree(directory)
        os.makedirs(directory, exist_ok=True)

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
            target_dir = windows_dir
            
            with zipfile.ZipFile(content) as z:
                file_list = z.namelist()
                total_files = len(file_list)
                
                for i, file in enumerate(file_list):
                    z.extract(file, target_dir)
                    show_progress_bar(i + 1, total_files, "Extracting Windows files")
                    
            windows_artifact_path = os.path.join(target_dir, "bin", "Retr0Mine.exe")
            
        elif artifact_name == "Retr0Mine_Linux":
            target_dir = linux_dir
            
            with zipfile.ZipFile(content) as z:
                file_list = z.namelist()
                total_files = len(file_list)
                
                for i, file in enumerate(file_list):
                    z.extract(file, target_dir)
                    show_progress_bar(i + 1, total_files, "Extracting Linux files")
                    
            linux_artifact_path = os.path.join(target_dir, "bin", "Retr0Mine")
    
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
    
    env_dir = os.path.dirname(env_path)
    if env_dir and not os.path.exists(env_dir):
        os.makedirs(env_dir)
        
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
    """Check if steamcmd is in the system PATH or use the hardcoded path."""
    try:
        subprocess.run(["steamcmd", "+quit"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return "steamcmd"  # steamcmd found in PATH
    except FileNotFoundError:
        # Fallback to the hardcoded path if not found in PATH
        return r"C:\Users\Flora\Documents\ContentBuilder\builder\steamcmd.exe"

def apply_drm_and_upload(windows_exe, username, password, commit_info=None):
    steamcmd_path = find_steamcmd()
    app_build = r"C:\Users\Flora\Documents\ContentBuilder\scripts\app_3478030.vdf"
    
    # Create build description based on commit info
    build_desc = "Auto upload"
    if commit_info:
        build_desc = f"{commit_info['sha']} - {commit_info['message']}"
        # Steam has a limit on description length
        if len(build_desc) > 50:
            build_desc = build_desc[:47] + "..."
    
    upload_command = [
        steamcmd_path,
        "+login", username, password,
        "+drm_wrap", "3478030", windows_exe, windows_exe, "drmtoolp", "0",
        "+run_app_build", "-desc", build_desc, app_build,
        "+quit"
    ]
   
    print(Fore.YELLOW + f"Applying DRM to Windows build and uploading to Steam..." + Style.RESET_ALL)
    print(Fore.YELLOW + f"Build description: {build_desc}" + Style.RESET_ALL)
    subprocess.run(upload_command)
   
    print(Fore.GREEN + "Process complete!" + Style.RESET_ALL)

if __name__ == "__main__":
    print(Fore.MAGENTA + "Retr0Mine FWU - Fetch / Wrap / Upload" + Style.RESET_ALL)
    token = get_github_token_from_env()
    username = get_username_from_env()
    password = get_password_from_env()

    print(Fore.MAGENTA + "Starting GitHub artifacts download..." + Style.RESET_ALL)
    windows_exe, linux_exe, commit_info = download_github_artifacts(token)
    
    if windows_exe and os.path.exists(windows_exe) and linux_exe and os.path.exists(linux_exe):
        print(Fore.GREEN + "Content ready!" + Style.RESET_ALL)
        if password != "skip":
            print(Fore.MAGENTA + "Starting Steam wrap and upload..." + Style.RESET_ALL)
            apply_drm_and_upload(windows_exe, username, password, commit_info)
        else:
            print(Fore.YELLOW + "Password skipped, no steam upload." + Style.RESET_ALL)
    else:
        print(Fore.RED + "Content missing or download failed!!" + Style.RESET_ALL)
