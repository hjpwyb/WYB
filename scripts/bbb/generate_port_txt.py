import socket
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

# 从文件读取 IP 地址列表，忽略带有注释的部分
def read_ip_list(file_path):
    if not os.path.exists(file_path):
        print(f"Error: {file_path} does not exist.")
        return []
    
    with open(file_path, "r") as file:
        ip_list = []
        for line in file:
            # 清理行并去掉注释部分
            clean_line = line.split('#')[0].strip()
            if clean_line:  # 如果不是空行
                ip_list.append(clean_line)
    return ip_list

# 测试连接每个 IP
def check_ip(ip):
    host, port = ip.split(":")
    port = int(port)
    
    try:
        # 尝试连接目标 IP 和端口
        with socket.create_connection((host, port), timeout=5) as sock:
            print(f"IP {ip} is accessible.")
            return f"{ip}#优选443"  # 保留原格式
    except (socket.timeout, socket.error) as e:
        print(f"IP {ip} is not accessible. Error: {e}")
        return None

# 生成符合原格式的 port.txt 文件
def generate_port_txt(input_file, output_file):
    ip_list = read_ip_list(input_file)  # 读取原始 IP 列表
    accessible_ips = []

    # 并行处理每个 IP
    with ThreadPoolExecutor(max_workers=10) as executor:  # 可以调整 max_workers
        future_to_ip = {executor.submit(check_ip, ip): ip for ip in ip_list}
        for future in as_completed(future_to_ip):
            result = future.result()
            if result:  # 仅添加可访问的 IP
                accessible_ips.append(result)

    # 将可访问的 IP 保存回文件
    with open(output_file, "w") as file:
        for ip in accessible_ips:
            file.write(f"{ip}\n")
    
    print(f"Total {len(accessible_ips)} accessible IPs written to {output_file}.")

# 执行函数
if __name__ == "__main__":
    input_file = "scripts/bbb/port.txt"  # 原始 port.txt 路径
    output_file = input_file  # 直接覆盖原文件
    generate_port_txt(input_file, output_file)  # 生成新的 port.txt
