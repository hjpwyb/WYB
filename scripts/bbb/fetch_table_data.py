import requests
from bs4 import BeautifulSoup
import csv

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
with open('scripts/bbb/port_data.csv', mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerow(["线路", "IP", "平均延迟", "丢包率", "速度"])  # 表头

    # 遍历表格行并提取数据
    for row in rows[1:]:  # 跳过表头
        columns = row.find_all('td')
        if len(columns) == 5:  # 确保该行有 5 列
            line = columns[0].text.strip()
            ip = columns[1].text.strip()
            latency = columns[2].text.strip()
            packet_loss = columns[3].text.strip()
            speed = columns[4].text.strip()
            writer.writerow([line, ip, latency, packet_loss, speed])

print("Data fetched and saved to scripts/bbb/port_data.csv")
