import socket
import concurrent.futures

# 从文件读取 IP 地址列表，忽略带有注释的部分
def read_ip_list(file_path):
    with open(file_path, "r") as file:
        ip_list = []
        for line in file:
            # 将 IP 和注释分开处理
            clean_line = line.split('#')[0].strip()
            comment = "#" + line.split('#')[1].strip() if "#" in line else ""
            if clean_line:  # 如果不是空行
                ip_list.append((clean_line, comment))
    return ip_list

# 测试连接每个 IP
def check_ip(ip_tuple):
    ip, comment = ip_tuple
    host, port = ip.split(":")
    port = int(port)
    
    try:
        # 尝试连接目标 IP 和端口
        with socket.create_connection((host, port), timeout=5) as sock:
            print(f"IP {ip} is accessible.")
            return (ip, comment)  # 返回可访问的 IP 和注释
    except (socket.timeout, socket.error) as e:
        print(f"IP {ip} is not accessible. Error: {e}")
        return None  # 返回 None 如果不可访问

def main():
    ip_list = read_ip_list("scripts/bbb/port.txt")  # 假设文件路径是这个
    accessible_ips = []

    # 使用 ThreadPoolExecutor 进行并行连接测试
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        # 使用 map 来并行执行 check_ip 函数
        results = executor.map(check_ip, ip_list)
        
        # 收集所有可访问的 IP
        accessible_ips = [ip_tuple for ip_tuple in results if ip_tuple is not None]

    # 将可访问的 IP 和注释保存回文件
    with open("scripts/bbb/port.txt", "w") as file:
        for ip, comment in accessible_ips:
            file.write(f"{ip} {comment}\n")
    
    print(f"Total {len(accessible_ips)} accessible IPs.")

if __name__ == "__main__":
    main()
