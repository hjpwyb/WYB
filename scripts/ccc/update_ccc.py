import requests
import os
from datetime import datetime

# GitHub 用户名和仓库名
GITHUB_USER = "xinyex"
GITHUB_REPO = "ks"

# GitHub API URL
commits_url = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/commits"

def fetch_latest_commit():
    try:
        response = requests.get(commits_url)
        response.raise_for_status()
        commits = response.json()
        
        # 获取最近的提交信息
        latest_commit = commits[0]
        commit_message = latest_commit["commit"]["message"]
        commit_date = latest_commit["commit"]["committer"]["date"]

        # 确保 scripts/ccc 文件夹存在
        os.makedirs("scripts/ccc", exist_ok=True)

        # 将信息写入 ccc.txt 文件
        with open("scripts/ccc/ccc.txt", "w") as file:
            file.write(f"Latest commit message: {commit_message}\n")
            file.write(f"Commit date: {commit_date}\n")
            file.write(f"Fetched on: {datetime.now().isoformat()}\n")

        print("ccc.txt file updated successfully.")
    except requests.RequestException as e:
        print("Failed to fetch commits:", e)

if __name__ == "__main__":
    fetch_latest_commit()
