import requests
from bs4 import BeautifulSoup
import re

# 获取子页面链接
def get_subpage_links(main_url):
    response = requests.get(main_url)
    response.raise_for_status()  # 确保请求成功

    soup = BeautifulSoup(response.text, 'html.parser')

    # 查找所有包含链接的 <a> 标签
    links = soup.find_all('a', href=True)

    # 提取子网页链接
    subpage_urls = []
    for link in links:
        href = link.get('href')
        if href and href.startswith('/voddetail/'):
            full_url = f"https://www.wujinzy.net{href}"
            subpage_urls.append(full_url)
    
    return subpage_urls

# 从子页面提取 M3U8 链接及其他信息
def extract_m3u8_links(url):
    response = requests.get(url)
    response.raise_for_status()  # 确保请求成功

    soup = BeautifulSoup(response.content, 'html.parser')

    # 提取标题
    title_tag = soup.find('h2')
    title = title_tag.get_text(strip=True) if title_tag else "default_title"

    # 查找所有 <span> 标签并打印它们的内容
    spans = soup.find_all('span')
    print("所有 <span> 标签的内容:")
    for span in spans:
        print(span.get_text(strip=True))

    # 尝试找到包含更新信息的 <span> 标签
    update_info_tag = None
    for span in spans:
        text = span.get_text(strip=True)
        if '更新至' in text or '全' in text:
            update_info_tag = text
            break

    update_info = update_info_tag if update_info_tag else "未知"

    # 提取网页中的文本内容
    source_text = soup.get_text()
    
    # 使用正则表达式提取 M3U8 链接及其对应的集数
    m3u8_pattern = re.compile(r'第(\d{2})集\$(https://[^\s]+?\.m3u8)')
    matches = m3u8_pattern.findall(source_text)
    
    return title, update_info, matches

# 保存 M3U8 链接到文件
def save_m3u8_links_to_file(title, update_info, m3u8_links):
    # 文件名不能包含非法字符
    safe_title = re.sub(r'[<>:"/\\|?*]', '', title)
    safe_update_info = re.sub(r'[<>:"/\\|?*]', '', update_info)
    filename = f"{safe_title}_{safe_update_info}.m3u"
    
    with open(filename, 'w') as file:
        file.write("#EXTM3U\n")
        for episode, link in m3u8_links:
            file.write(f"#EXTINF:-1,第{episode}集\n")
            file.write(f"{link}\n")
    
    print(f"M3U8 链接已成功写入 {filename} 文件中")

# 主函数
def main():
    main_url = "https://www.wujinzy.net/vodtype/13.html"
    subpage_urls = get_subpage_links(main_url)
    
    for url in subpage_urls:
        print(f"Processing {url}...")
        title, update_info, m3u8_links = extract_m3u8_links(url)
        save_m3u8_links_to_file(title, update_info, m3u8_links)

if __name__ == "__main__":
    main()
