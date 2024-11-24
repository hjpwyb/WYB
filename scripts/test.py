import os
import requests
from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin
import shutil
import time
import random
import logging

# 日志配置
logging.basicConfig(filename='crawler_errors.log', level=logging.ERROR)

def log_error(message):
    """记录错误日志"""
    logging.error(message)

# 删除指定文件夹及其所有内容
def clear_folder(folder_path):
    """删除指定文件夹及其内容"""
    if os.path.exists(folder_path):
        shutil.rmtree(folder_path)
        print(f"已删除文件夹: {folder_path}")
    os.makedirs(folder_path)
    print(f"已创建新文件夹: {folder_path}")

# 确保目录存在
def ensure_directory_exists(path):
    """确保指定路径的目录存在，如果不存在则创建"""
    if not os.path.exists(path):
        os.makedirs(path)
        print(f"已创建目录: {path}")

# 下载封面图片
def download_poster_image(image_url, folder_path):
    """下载封面图片并保存为 poster.jpg"""
    try:
        response = request_with_retries(image_url)
        if response is None:
            raise Exception("封面图片下载失败: 无法请求图片 URL")

        image_path = os.path.join(folder_path, 'poster.jpg')
        with open(image_path, 'wb') as f:
            f.write(response.content)
        print(f"封面图片已下载到: {image_path}")
    except Exception as e:
        print(f"封面图片下载失败: {e}")
        log_error(f"封面图片下载失败: {e}")

# 请求指定网址，若失败则重试
def request_with_retries(url, max_retries=3, delay=5):
    """请求指定网址，若失败则进行重试"""
    for attempt in range(max_retries):
        try:
            response = requests.get(url)
            response.raise_for_status()
            return response
        except requests.RequestException as e:
            print(f"请求失败 (尝试 {attempt+1}/{max_retries}): {e}")
            log_error(f"请求失败 (尝试 {attempt+1}/{max_retries}): {e}")
            if attempt + 1 < max_retries:
                print(f"等待 {delay} 秒后重试...")
                time.sleep(delay)
            else:
                print(f"请求失败，已达最大重试次数: {url}")
                return None

# 获取子页面链接
def get_subpage_links(main_url):
    """从主页面中提取子页面的链接"""
    try:
        response = request_with_retries(main_url)
        if response is None:
            return []

        soup = BeautifulSoup(response.text, 'html.parser')
        links = soup.find_all('a', href=True)

        subpage_urls = []
        for link in links:
            href = link.get('href')
            if href and href.startswith('/index.php/vod/detail/id/'):
                full_url = urljoin(main_url, href)
                subpage_urls.append(full_url)
        
        return subpage_urls
    except requests.RequestException as e:
        print(f"请求失败: {e}")
        log_error(f"请求失败: {e}")
        return []

# 随机延迟
def random_delay(min_delay=2, max_delay=5):
    """随机延迟"""
    delay = random.uniform(min_delay, max_delay)
    print(f"随机延迟 {delay:.2f} 秒")
    time.sleep(delay)

# 从子页面提取 M3U8 链接及其他信息
def extract_m3u8_links_and_poster(url):
    """从子页面提取 M3U8 视频链接及封面图片"""
    try:
        response = request_with_retries(url)
        if response is None:
            return "default_title", None, []

        soup = BeautifulSoup(response.content, 'html.parser')

        # 输出网页内容以便调试
        with open('debug_page.html', 'w', encoding='utf-8') as f:
            f.write(soup.prettify())

        # 提取标题和封面图片链接
        title_div = soup.find('div', class_='vodInfo')
        if title_div:
            title = title_div.find('h2').get_text(strip=True)
            poster_img_tag = soup.find('div', class_='vodImg').find('img')
            poster_url = poster_img_tag['src'] if poster_img_tag else None
        else:
            title = "default_title"
            poster_url = None

        # 查找所有 <script> 标签内的 m3u8 链接
        m3u8_links = []
        script_tags = soup.find_all('script')
        for script in script_tags:
            if '.m3u8' in script.get_text():
                m3u8_match = re.findall(r'(http[s]?://[^\s]+\.m3u8)', script.get_text())
                for m3u8_url in m3u8_match:
                    m3u8_links.append(('Episode', m3u8_url))  # 使用通用的 "Episode" 作为标题

        # 如果找不到 m3u8，在页面中搜索常规 <a> 标签
        if not m3u8_links:
            for tag in soup.find_all(['a', 'iframe', 'source']):
                href = tag.get('href') or tag.get('src')
                if href and '.m3u8' in href:
                    full_link = href if href.startswith('http') else urljoin("https://huyazy.com", href)
                    episode_title = tag.get_text(strip=True) or "Episode"
                    m3u8_links.append((episode_title, full_link))

        return title, poster_url, m3u8_links

    except Exception as e:
        print(f"解析失败: {e}")
        log_error(f"解析失败: {e}")
        return "default_title", None, []

# 保存 M3U8 链接到文件
def save_m3u8_files_for_each_episode(folder_path, title, m3u8_links):
    """为每一集保存单独的 .m3u 文件，保留 $ 前的原始信息"""
    for idx, (episode_title, link) in enumerate(m3u8_links, start=1):
        # 只保留 $ 前的标题部分
        raw_title = episode_title.split('$')[0].strip()
        
        # 生成每集的 .m3u 文件名，移除特殊字符
        cleaned_title = re.sub(r'[<>:"/\\|?*]', '', raw_title).replace(" ", "")
        filename = f"{title}_{cleaned_title}.m3u"
        filepath = os.path.join(folder_path, filename)
        
        with open(filepath, 'w') as file:
            file.write("#EXTM3U\n")
            file.write(f"#EXTINF:-1,{raw_title}\n")  # 保留 $ 前的原始标题
            file.write(f"{link}\n")
        
        print(f"M3U8 链接已成功写入 {filepath} 文件中")

# 主函数
def main():
    # 基础文件夹路径
    base_folder = '/opt/scripts/aaa/综艺'  # 修改为你的目标文件夹路径

    # 清空文件夹
    clear_folder(base_folder)

    # 更新后的页面链接
    base_urls = [
        "https://huyazy.com/index.php/vod/type/id/27/page/1.html?ac=detail",
        "https://huyazy.com/index.php/vod/type/id/27/page/2.html?ac=detail"
    ]
    
    for main_url in base_urls:
        subpage_urls = get_subpage_links(main_url)
        for url in subpage_urls:
            random_delay()  # 每次处理新的页面时随机延迟
            print(f"处理 {url}...")
            title, poster_url, m3u8_links = extract_m3u8_links_and_poster(url)

            if m3u8_links:
                # 为该综艺创建文件夹
                show_folder = os.path.join(base_folder, title)
                ensure_directory_exists(show_folder)

                # 下载封面图片
                if poster_url:
                    download_poster_image(poster_url, show_folder)
                else:
                    print(f"未找到封面图片链接: {url}")

                # 保存每集的 .m3u 文件，保留 $ 前的原始信息
                save_m3u8_files_for_each_episode(show_folder, title, m3u8_links)
            else:
                print(f"未找到 M3U8 链接: {url}")
                log_error(f"未找到 M3U8 链接: {url}")

if __name__ == "__main__":
    main()
