import requests

# 源文件的 GitHub 原始地址
source_url = "https://raw.githubusercontent.com/ymyuuu/IPDB/main/bestproxy.txt"

# 目标文件路径
destination_file = "bestproxy_with_port.txt"

def add_port_to_ip(ip_list):
    return [f"{ip}:443" for ip in ip_list]

def main():
    # 下载源文件内容
    response = requests.get(source_url)
    if response.status_code == 200:
        ip_list = response.text.splitlines()

        # 为每个 IP 地址加上端口号 443
        updated_ip_list = add_port_to_ip(ip_list)

        # 保存到目标文件
        with open(destination_file, "w") as f:
            f.write("\n".join(updated_ip_list))

        print(f"Updated IP list with port 443 saved to {destination_file}")
    else:
        print(f"Failed to download the file from {source_url}")

if __name__ == "__main__":
    main()
