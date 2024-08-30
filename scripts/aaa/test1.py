import os
import requests
from bs4 import BeautifulSoup
import re
import logging

# 设置日志配置
logging.basicConfig(filename='script.log', level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')

# 删除指定文件夹中的所有 .m3u 文件
def delete_old_m3u_files(folder_path):
    for file_name in os.listdir(folder_path):
        if file_name.endswith('.m3u'):
            file_path = os.path.join(folder_path, file_name)
            os.remove(file_path)
            logging.info(f"已删除旧文件: {file_path}")

# 获取子页面链接
def get_subpage_links(main_url):
    response = requests.get(main_url)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, 'html.parser')
    links = soup.find_all('a', href=True)

    subpage_urls = []
    for link in links:
        href = link.get('href')
        if href and href.startswith('/index.php/vod/detail/id/'):
            full_url = f"https://huyazy.com{href}"
            subpage_urls.append(full_url)
    
    return subpage_urls

# 从子页面提取 M3U8 链接及其他信息
def extract_m3u8_links(url):
    response = requests.get(url)
    response.raise_for_status()

    soup = BeautifulSoup(response.content, 'html.parser')

    # 提取标题、集数和评分
    info_div = soup.find('div', class_='vodInfo')
    if info_div:
        title_tag = info_div.find('h2')
        title = title_tag.get_text(strip=True) if title_tag else "default_title"
        
        span_tag = info_div.find('span')
        episode_info = span_tag.get_text(strip=True) if span_tag else "未知集数"
        
        label_tag = info_div.find('label')
        rating_info = label_tag.get_text(strip=True) if label_tag else "未知评分"

        # 自动递增集数
        episode_number = re.search(r'第(\d+)集', episode_info)
        if episode_number:
            new_episode = int(episode_number.group(1)) + 1
            episode_info = f"第{new_episode}集"

        # 生成文件名
        safe_title = re.sub(r'[<>:"/\\|?*]', '', title)
        filename = f"{safe_title}_{episode_info}_{rating_info}.m3u"
    else:
        filename = "default_title.m3u"

    # 查找所有 <a> 标签内的播放链接
    m3u8_links = []
    for a_tag in soup.select('#play_2 a'):
        href = a_tag.get('href')
        if href and href.endswith('.m3u8'):
            full_link = href if href.startswith('http') else f"https://huyazy.com{href}"
            episode_title = a_tag.get_text(strip=True)
            m3u8_links.append((episode_title, full_link))

    return filename, m3u8_links

# 保存 M3U8 链接到文件
def save_m3u8_links_to_file(filename, m3u8_links):
    if not m3u8_links:
        logging.warning(f"No M3U8 links found, skipping file {filename}")
        return

    with open(filename, 'w') as file:
        file.write("#EXTM3U\n")
        for episode_title, link in m3u8_links:
            cleaned_title = episode_title.split('$')[0]
            file.write(f"#EXTINF:-1,{cleaned_title}\n")
            file.write(f"{link}\n")
    
    logging.info(f"M3U8 链接已成功写入 {filename} 文件中")

# 检查页面是否有变动
def has_page_changed(main_url, last_content):
    response = requests.get(main_url)
    response.raise_for_status()
    current_content = response.text
    return current_content != last_content, current_content

# 主函数
def main():
    # 删除旧的 .m3u 文件
    folder_path = '.'  # 这里可以指定你要删除文件的文件夹路径
    delete_old_m3u_files(folder_path)

    # 更新后的页面链接
    base_urls = [
        "https://huyazy.com/index.php/vod/type/id/20/page/1.html?ac=detail",
        "https://huyazy.com/index.php/vod/type/id/20/page/2.html?ac=detail"
    ]

    last_content = ""
    for main_url in base_urls:
        page_changed, current_content = has_page_changed(main_url, last_content)
        if not page_changed:
            logging.info(f"No changes detected for {main_url}, skipping...")
            continue

        last_content = current_content
        subpage_urls = get_subpage_links(main_url)
        for url in subpage_urls:
            logging.info(f"Processing {url}...")
            filename, m3u8_links = extract_m3u8_links(url)
            save_m3u8_links_to_file(filename, m3u8_links)

if __name__ == "__main__":
    main()