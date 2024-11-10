import requests
from bs4 import BeautifulSoup

# 网页 URL
url = "https://cf.090227.xyz/"

# 获取网页内容
response = requests.get(url)
response.raise_for_status()  # 如果请求失败，抛出异常

# 解析网页
soup = BeautifulSoup(response.text, 'html.parser')

# 找到表格
table = soup.find('table')

# 找到所有表格行
rows = table.find_all('tr')

# 打开文件并写入数据
with open('scripts/bbb/port_data.txt', mode='w', encoding='utf-8') as file:
    # 遍历表格行并提取 IP 数据
    for row in rows[1:]:  # 跳过表头
        columns = row.find_all('td')
        if len(columns) == 5:  # 确保该行有 5 列
            ip = columns[1].text.strip()  # 获取第二列（IP列）
            file.write(f"{ip}\n")  # 将 IP 写入文件，每个 IP 占一行

print("IP data fetched and saved to scripts/bbb/port_data.txt")
