import os

# 确定当前脚本所在目录
script_dir = os.path.dirname(os.path.abspath(__file__))

# 定义文件路径
input_file = os.path.join(script_dir, 'ip.txt')
output_file = os.path.join(script_dir, 'hao.txt')

# 确保 ip.txt 存在
if not os.path.exists(input_file):
    raise FileNotFoundError(f"Input file '{input_file}' does not exist.")

# 读取 ip.txt 并处理
try:
    with open(input_file, 'r', encoding='utf-8') as infile:
        lines = infile.readlines()

    # 节点模板
    template = (
        "vless://90cd4a77-141a-43c9-991b-08263cfe9c10@27.50.49.181:2053?encryption=none&security=tls&sni=tlsjiedian.linyubo216.filegear-sg.me&allowInsecure=1&type=ws&host=tlsjiedian.linyubo216.filegear-sg.me&path=%2F%3Fed%3D2560#HK"
    )

    # 生成节点信息
    nodes = []
    for line in lines:
        ip = line.split(',')[0].strip()
        if ip:  # 确保 IP 不为空
            nodes.append(template.format(ip=ip))

    # 写入 hao.txt
    with open(output_file, 'w', encoding='utf-8') as outfile:
        outfile.write('\n'.join(nodes))

    print(f"Nodes saved to '{output_file}'. Total nodes: {len(nodes)}")

except Exception as e:
    print(f"Error processing file: {e}")

