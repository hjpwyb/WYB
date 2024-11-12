import requests
from datetime import datetime, timedelta, timezone
import os
import subprocess

# 配置 GitHub 用户和仓库信息
GITHUB_USER = "xinyex"
GITHUB_REPO = "ks"

# GitHub API URL
commits_url = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/commits"
files_save_path = "scripts/ccc/"  # 文件保存目录

# 确保保存路径存在
os.makedirs(files_save_path, exist_ok=True)

def fetch_and_save_recent_files():
    try:
        # 请求 GitHub API 获取最近的提交
        response = requests.get(commits_url)
        response.raise_for_status()
        commits = response.json()
        
        # 计算一天前的时间
        one_day_ago = datetime.now(timezone.utc) - timedelta(days=1)
        print(f"One day ago: {one_day_ago}")
        
        # 存储文件内容的列表
        file_contents = []
        
        # 遍历提交记录，找到最近一天内的更改
        for commit in commits:                                              
            commit_date = datetime.strptime(commit["commit"]["committer"]["date"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            print(f"Commit date: {commit_date}")
            if commit_date >= one_day_ago:
                # 获取此提交中更改的文件
                files_url = commit["url"]
                files_response = requests.get(files_url)
                files_response.raise_for_status()
                files = files_response.json().get("files", [])
                
                # 下载每个文件的内容
                for file_info in files:
                    raw_url = file_info["raw_url"]
                    file_content = requests.get(raw_url).text
                    file_contents.append(file_content)
                
                # 如果找到了两个文件内容，停止继续查找
                if len(file_contents) >= 2:
                    break

        # 将内容保存到固定文件 kxwl.txt 和 kxwl.yaml
        if len(file_contents) >= 2:
            with open(os.path.join(files_save_path, "kxwl.txt"), "w") as txt_file:
                txt_file.write(file_contents[0])

            with open(os.path.join(files_save_path, "kxwl.yaml"), "w") as yaml_file:
                yaml_file.write(file_contents[1])

            print("kxwl.txt and kxwl.yaml files updated successfully.")
        else:
            print("Less than 2 files found for the last day.")

    except requests.RequestException as e:
        print("Failed to fetch or download files:", e)

def push_to_github():
    try:
        # Configure Git
        subprocess.run(["git", "config", "--global", "user.name", "GitHub Actions"], check=True)
        subprocess.run(["git", "config", "--global", "user.email", "actions@github.com"], check=True)
        
        # Add changes to git
        subprocess.run(["git", "add", "scripts/ccc/kxwl.txt", "scripts/ccc/kxwl.yaml"], check=True)
        
        # Commit the changes
        subprocess.run(["git", "commit", "-m", "Update kxwl files with recent content"], check=True)
        
        # Pull latest changes from remote to avoid conflicts
        subprocess.run(["git", "pull", "--rebase", "origin", "main"], check=True)
        
        # Push changes to GitHub
        subprocess.run(["git", "push", "origin", "main"], check=True)
        
        print("Changes pushed to GitHub successfully.")
    
    except subprocess.CalledProcessError as e:
        print("Failed to push changes:", e)

if __name__ == "__main__":
    fetch_and_save_recent_files()
    push_to_github()
