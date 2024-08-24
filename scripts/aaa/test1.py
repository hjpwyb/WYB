name: Run Python Script

on:
  schedule:
    - cron: '0 0 * * *'  # 每天午夜 12 点执行一次
  workflow_dispatch:  # 允许手动触发

jobs:
  run-script:
    runs-on: ubuntu-latest  # 使用最新的 Ubuntu 虚拟环境
    steps:
      - name: Checkout code
        uses: actions/checkout@v4  # 更新到最新版本

      - name: Set up Python
        uses: actions/setup-python@v5  # 更新到最新版本
        with:
          python-version: '3.9'

      - name: Install dependencies
        run: |
          pip install requests beautifulsoup4

      - name: Run Python script
        run: |
          python scripts/aaa/test1.py  # 替换为实际的脚本路径

      - name: Commit generated m3u files
        run: |
          git config --global user.name 'github-actions'
          git config --global user.email 'actions@github.com'
          git add scripts/aaa/*.m3u  # 确保路径与实际文件位置匹配
          git commit -m 'Add generated m3u files'
          git push
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
