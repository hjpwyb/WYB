import socket

# 从文件读取 IP 地址列表，忽略带有注释的部分
def read_ip_list(file_path):
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
            return True
    except (socket.timeout, socket.error) as e:
        print(f"IP {ip} is not accessible. Error: {e}")
        return False

def main():
    ip_list = read_ip_list("scripts/bbb/port.txt")  # 假设文件路径是这个
    accessible_ips = []

    # 遍历 IP 地址，进行连接测试
    for ip in ip_list:
        if check_ip(ip):
            accessible_ips.append(ip)

    # 将可访问的 IP 保存回文件
    with open("scripts/bbb/port.txt", "w") as file:
        for ip in accessible_ips:
            file.write(f"{ip}\n")
    
    print(f"Total {len(accessible_ips)} accessible IPs.")

if __name__ == "__main__":
    main()
