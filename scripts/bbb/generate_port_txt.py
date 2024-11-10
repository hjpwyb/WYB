import os
import socket
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

# 设置日志配置
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def read_ip_list(file_path):
    if not os.path.exists(file_path):
        logging.error(f"Error: {file_path} does not exist.")
        return []
    
    with open(file_path, "r") as file:
        ip_list = set()
        for line in file:
            clean_line = line.split('#')[0].strip()
            if clean_line:
                ip_list.add(clean_line)  # 使用集合去重
    return list(ip_list)  # 转回列表

def check_ip(ip):
    host, port = ip.split(":")
    port = int(port)
    
    try:
        with socket.create_connection((host, port), timeout=5) as sock:
            logging.info(f"IP {ip} is accessible.")
            return f"{ip}#优选443"  # 保留原格式
    except (socket.timeout, socket.error) as e:
        logging.error(f"IP {ip} is not accessible. Error: {e}")
        return None

def generate_addresses_file(input_file, output_file):
    ip_list = read_ip_list(input_file)
    accessible_ips = []

    with ThreadPoolExecutor(max_workers=10) as executor:
        future_to_ip = {executor.submit(check_ip, ip): ip for ip in ip_list}
        for future in as_completed(future_to_ip):
            result = future.result()
            if result:
                accessible_ips.append(result)

    logging.debug(f"Accessible IPs found: {accessible_ips}")
    logging.debug(f"Total accessible IPs: {len(accessible_ips)}")

    if len(accessible_ips) == 0:
        logging.warning("No accessible IPs found. The file will not be written.")
        return

    # 打印输出路径以确认是否正确
    output_file_abs_path = os.path.abspath(output_file)
    logging.debug(f"Output file path: {output_file_abs_path}")

    try:
        # 先确认目录是否存在
        directory = os.path.dirname(output_file_abs_path)
        if not os.path.exists(directory):
            logging.warning(f"Directory {directory} does not exist. Attempting to create it.")
            os.makedirs(directory, exist_ok=True)

        with open(output_file, "w") as file:
            logging.debug(f"Writing {len(accessible_ips)} IPs to {output_file}")
            for ip in accessible_ips:
                file.write(f"{ip}\n")
            file.flush()
            os.fsync(file.fileno())  # 确保写入磁盘
        logging.info(f"Total {len(accessible_ips)} accessible IPs written to {output_file_abs_path}.")
    except Exception as e:
        logging.error(f"Error writing to {output_file_abs_path}: {e}")

if __name__ == "__main__":
    input_file = "scripts/bbb/port.txt"
    output_file = "scripts/bbb/addressesapi.txt"  # 输出到新文件
    generate_addresses_file(input_file, output_file)
