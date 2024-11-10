import socket
import concurrent.futures

# 从文件读取 IP 地址列表，保留原始行内容以便写回
def read_ip_list(file_path):
    with open(file_path, "r") as file:
        ip_list = []
        for line in file:
            clean_line = line.split('#')[0].strip()
            if clean_line:  # 如果不是空行
                ip_list.append(line.strip().replace(" ", ""))  # 去掉空格，保留原始行
    return ip_list

# 测试连接每个 IP
def check_ip(line):
    # 去掉端口后的注释部分，只保留IP和端口
    ip_with_comment = line.strip().replace(" ", "")
    ip = line.split('#')[0].strip()
    
    # 分割IP和端口
    if ":" in ip:
        host, port = ip.split(":")
        try:
            port = int(port)
        except ValueError:
            print(f"Invalid port value: {port} in IP {ip}")
            return None  # 返回 None 如果端口无效

        try:
            # 尝试连接目标 IP 和端口
            with socket.create_connection((host, port), timeout=5) as sock:
                print(f"IP {ip} is accessible.")
                return ip_with_comment  # 返回包含注释的原始行内容
        except (socket.timeout, socket.error) as e:
            print(f"IP {ip} is not accessible. Error: {e}")
            return None  # 返回 None 如果不可访问
    else:
        return None  # 返回 None 如果格式不正确

def main():
    ip_list = read_ip_list("scripts/bbb/port.txt")  # 假设文件路径是这个
    accessible_ips = []

    # 使用 ThreadPoolExecutor 进行并行连接测试
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        # 使用 map 来并行执行 check_ip 函数
        results = executor.map(check_ip, ip_list)
        
        # 收集所有可访问的 IP
        accessible_ips = [ip for ip in results if ip is not None]

    # 将可访问的 IP 保存回文件
    with open("scripts/bbb/port.txt", "w") as file:
        for ip in accessible_ips:
            file.write(f"{ip}\n")  # 保留注释紧跟在IP和端口后

    print(f"Total {len(accessible_ips)} accessible IPs.")

if __name__ == "__main__":
    main()
