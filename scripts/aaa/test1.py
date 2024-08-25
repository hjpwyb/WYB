import os
import requests
from bs4 import BeautifulSoup
import re
import logging

# 配置日志
logging.basicConfig(filename='/volume1/docker/python_scripts/aaa/script.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# 删除指定文件夹中的所有 .m3u 文件
def delete_old_m3u_files(folder_path):
    try:
        for file_name in os.listdir(folder_path):
            if file_name.endswith('.m3u'):
                file_path = os.path.join(folder_path, file_name)
                os.remove(file_path)
                logging.info(f"Deleted old file: {file_path}")
    except Exception as e:
        logging.error(f"Error deleting old .m3u files: {e}")

# 获取子页面链接
def get_subpage_links(main_url):
    try:
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
        logging.info(f"Found {len(subpage_urls)} subpage links from {main_url}")
        return subpage_urls
    except Exception as e:
        logging.error(f"Error fetching subpage links from {main_url}: {e}")
        return []

# 从子页面提取 M3U8 链接及其他信息
def extract_m3u8_links(url):
    try:
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

        logging.info(f"Extracted {len(m3u8_links)} M3U8 links from {url}")
        return filename, m3u8_links
    except Exception as e:
        logging.error(f"Error extracting M3U8 links from {url}: {e}")
        return "default_title.m3u", []

# 保存 M3U8 链接到文件
def save_m3u8_links_to_file(filename, m3u8_links):
    try:
        with open(filename, 'w', encoding='utf-8') as file:
            file.write("#EXTM3U\n")
            for episode_title, link in m3u8_links:
                cleaned_title = episode_title.split('$')[0]
                file.write(f"#EXTINF:-1,{cleaned_title}\n")
                file.write(f"{link}\n")
        logging.info(f"M3U8 links successfully written to {filename}")
    except Exception as e:
        logging.error(f"Error saving M3U8 links to {filename}: {e}")

# 主函数
def main():
    # 删除旧的 .m3u 文件
    folder_path = '/volume1/docker/python_scripts/aaa'  # 指定你要删除文件的文件夹路径
    delete_old_m3u_files(folder_path)
    
    # 更新后的页面链接
    base_urls = [
        "https://huyazy.com/index.php/vod/type/id/20/page/1.html?ac=detail",
        "https://huyazy.com/index.php/vod/type/id/20/page/2.html?ac=detail"
    ]
    
    for main_url in base_urls:
        subpage_urls = get_subpage_links(main_url)
        for url in subpage_urls:
            logging.info(f"Processing {url}...")
            filename, m3u8_links = extract_m3u8_links(url)
            if m3u8_links:
                save_m3u8_links_to_file(os.path.join(folder_path, filename), m3u8_links)
            else:
                logging.info(f"No M3U8 links found for {url}")

if __name__ == "__main__":
    main()
