import requests

# 源文件的 GitHub 原始地址列表
source_urls = [
    "https://raw.githubusercontent.com/ymyuuu/IPDB/main/bestproxy.txt",
    "https://raw.githubusercontent.com/ymyuuu/IPDB/main/bestcf.txt",
    "https://raw.githubusercontent.com/ymyuuu/IPDB/main/proxy.txt"
]

# 目标文件路径
destination_file = "scripts/bbb/port.txt"

def format_ip_with_port(ip_list):
    """为每个 IP 地址添加格式 '<IP地址>:443 #优选443'"""
    return [f"{ip}:443#优选443" for ip in ip_list]

def main():
    combined_ip_list = []

    # 下载每个源文件内容并合并
    for url in source_urls:
        response = requests.get(url)
        if response.status_code == 200:
            ip_list = response.text.splitlines()
            combined_ip_list.extend(ip_list)  # 将所有 IP 地址合并到一起
        else:
            print(f"Failed to download the file from {url}")

    # 为每个 IP 地址添加格式化内容
    updated_ip_list = format_ip_with_port(combined_ip_list)

    # 保存到目标文件
    with open(destination_file, "w") as f:
        f.write("\n".join(updated_ip_list))

    print(f"Updated IP list with port 443 saved to {destination_file}")

if __name__ == "__main__":
    main()
