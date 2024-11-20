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
    # 读取现有内容（如文件不存在，则视为内容为空）
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as outfile:
            old_content = outfile.read()
    else:
        old_content = ""

    # 读取 ip.txt 的内容
    with open(input_file, 'r', encoding='utf-8') as infile:
        lines = infile.readlines()

    # 节点模板
    template = (
        "vless://90cd4a77-141a-43c9-991b-08263cfe9c10@{ip}:443"
        "?encryption=none&security=tls&sni=tlsjiedian.linyu230.us.kg"
        "&fp=random&allowInsecure=1&type=ws&host=tlsjiedian.linyu230.us.kg"
        "&path=%2FproxyIP%3Dproxyip.aliyun.fxxk.dedyn.io#hao"
    )
    
    # 生成新的节点信息
    nodes = []
    for line in lines:
        ip = line.split(',')[0].strip()
        if ip:  # 确保 IP 不为空
            nodes.append(template.format(ip=ip))
    
    new_content = '\n'.join(nodes)

    # 写入 hao.txt（只有内容变更时才更新）
    if old_content.strip() != new_content.strip():
        with open(output_file, 'w', encoding='utf-8') as outfile:
            outfile.write(new_content)
        print(f"Nodes saved to '{output_file}'. Total nodes: {len(nodes)}")
        
        # 提交文件更改
        os.system("git config --global user.name 'GitHub Actions'")
        os.system("git config --global user.email 'actions@github.com'")
        os.system(f"git add {output_file}")
        commit_message = "Update IP list with port and tag"
        result = os.system(f"git commit -m '{commit_message}'")
        
        if result == 0:
            os.system("git push origin main")
        else:
            print("No changes to commit (unexpected).")
    else:
        print("No changes detected in 'hao.txt', skipping update.")

    # 返回成功退出码
    exit(0)

except Exception as e:
    print(f"Error processing file: {e}")
    exit(1)
