import requests
from datetime import datetime, timedelta
import os

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
        
        # 计算两天前的时间
        two_days_ago = datetime.utcnow() - timedelta(days=2)
        
        # 存储已下载的文件
        downloaded_files = []

        for commit in commits:
            commit_date = datetime.strptime(commit["commit"]["committer"]["date"], "%Y-%m-%dT%H:%M:%SZ")
            if commit_date >= two_days_ago:
                # 获取此提交中更改的文件
                files_url = commit["url"]
                files_response = requests.get(files_url)
                files_response.raise_for_status()
                files = files_response.json().get("files", [])
                
                # 下载每个文件内容
                for file_info in files:
                    filename = file_info["filename"]
                    raw_url = file_info["raw_url"]

                    # 请求文件的原始内容
                    file_content = requests.get(raw_url).text
                    file_path = os.path.join(files_save_path, os.path.basename(filename))
                    
                    # 将文件内容写入本地
                    with open(file_path, "w") as file:
                        file.write(file_content)
                    
                    downloaded_files.append(filename)
                    print(f"Downloaded and saved: {filename}")

        if downloaded_files:
            print("All recent files downloaded and saved successfully.")
        else:
            print("No recent files updated in the last 2 days.")
    except requests.RequestException as e:
        print("Failed to fetch or download files:", e)

if __name__ == "__main__":
    fetch_and_save_recent_files()
