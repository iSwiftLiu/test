#!/usr/bin/env python3
"""
CDN Log Processor Script

This script processes CDN logs by:
1. Calculating time range (2 days ago to 1 day ago)
2. Fetching CDN log links
3. Downloading, extracting, and processing log files
4. Extracting CSS and JS file paths using Python native methods
5. Generating final sorted and deduplicated output files
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta


def get_time_range():
    """
    Calculate start_time and end_time in milliseconds.
    start_time: 2 days ago at 00:00:00
    end_time: 1 day ago at 00:00:00
    """
    now = datetime.now()
    
    two_days_ago = (now - timedelta(days=2)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    start_time = int(two_days_ago.timestamp() * 1000)
    
    one_day_ago = (now - timedelta(days=1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    end_time = int(one_day_ago.timestamp() * 1000)
    
    date_str = two_days_ago.strftime("%Y%m%d")
    
    return start_time, end_time, date_str


def get_cdn_log_links(domain, project_id, start_time, end_time):
    """
    Fetch CDN log links using hcloud CLI command.
    """
    cmd = [
        "hcloud",
        "CDN",
        "ShowLogs/v2",
        "--cli-region=cn-north-1",
        f"--domain_name={domain}",
        f"--enterprise_project_id={project_id}",
        f"--start_time={start_time}",
        f"--end_time={end_time}"
    ]
    
    try:
        print(f"Executing command: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        
        data = json.loads(result.stdout)
        
        links = []
        if "logs" in data and isinstance(data["logs"], list):
            for log_entry in data["logs"]:
                if "link" in log_entry:
                    links.append(log_entry["link"])
        
        print(f"Found {len(links)} log files")
        return links
    
    except subprocess.CalledProcessError as e:
        print(f"Error executing hcloud command: {e}", file=sys.stderr)
        print(f"stderr: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON output: {e}", file=sys.stderr)
        sys.exit(1)


def download_file(url, output_filename):
    """
    Download a file using wget or curl.
    """
    try:
        subprocess.run(
            ["wget", "-O", output_filename, url],
            check=True,
            capture_output=True
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    try:
        subprocess.run(
            ["curl", "-o", output_filename, url],
            check=True,
            capture_output=True
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"Error: Could not download {url}. Neither wget nor curl available.", file=sys.stderr)
        return False


def decompress_file(gz_filename):
    """
    Decompress .gz file using gzip.
    The .gz file will be automatically deleted after decompression.
    """
    try:
        subprocess.run(
            ["gzip", "-d", gz_filename],
            check=True,
            capture_output=True
        )
        return gz_filename[:-3] if gz_filename.endswith(".gz") else gz_filename
    except subprocess.CalledProcessError as e:
        print(f"Error decompressing {gz_filename}: {e}", file=sys.stderr)
        return None


def process_log_content(log_file, domain):
    """
    Process log file content using Python native methods.
    Returns tuple of (js_paths_set, css_paths_set)
    
    Steps:
    1. Read file line by line
    2. Use regex to match lines containing "app." or "chunk-"
    3. Extract path after domain (quote-delimited)
    4. Filter paths ending with .js or .css
    5. Filter paths containing "lottery" or "chunk"
    6. Collect JS and CSS paths separately
    """
    js_paths = set()
    css_paths = set()
    
    pattern_app_chunk = re.compile(r'app\.|chunk-')
    pattern_js_css = re.compile(r'\.(js|css)$')
    pattern_lottery_chunk = re.compile(r'lottery|chunk')
    
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                if not pattern_app_chunk.search(line):
                    continue
                
                domain_parts = line.split(f'"{domain}"')
                if len(domain_parts) < 2:
                    continue
                
                after_domain = domain_parts[1]
                
                quote_parts = after_domain.split('"')
                if len(quote_parts) < 2:
                    continue
                
                path = quote_parts[1]
                
                if not pattern_js_css.search(path):
                    continue
                
                if not pattern_lottery_chunk.search(path):
                    continue
                
                if path.endswith('.css'):
                    css_paths.add(path)
                elif path.endswith('.js'):
                    js_paths.add(path)
        
        return js_paths, css_paths
    
    except Exception as e:
        print(f"Error processing log file {log_file}: {e}", file=sys.stderr)
        return set(), set()


def process_log_file(link, domain, all_js_paths, all_css_paths):
    """
    Process a single log file:
    1. Download
    2. Decompress
    3. Extract CSS and JS paths using Python native methods
    4. Add to collections
    5. Clean up
    """
    filename = link.split("/")[-1]
    
    print(f"Processing {filename}...")
    
    if not download_file(link, filename):
        return False
    
    decompressed_file = decompress_file(filename)
    if not decompressed_file or not os.path.exists(decompressed_file):
        print(f"Failed to decompress {filename}", file=sys.stderr)
        return False
    
    js_paths, css_paths = process_log_content(decompressed_file, domain)
    
    all_js_paths.update(js_paths)
    all_css_paths.update(css_paths)
    
    print(f"  Found {len(js_paths)} JS paths and {len(css_paths)} CSS paths")
    
    try:
        os.remove(decompressed_file)
    except Exception as e:
        print(f"Warning: Could not delete {decompressed_file}: {e}", file=sys.stderr)
    
    return True


def save_output_files(all_js_paths, all_css_paths, date_str):
    """
    Sort, deduplicate, and save output files.
    """
    final_css_file = f"cssall-{date_str}"
    final_js_file = f"jsall-{date_str}"
    
    if all_css_paths:
        sorted_css = sorted(all_css_paths)
        with open(final_css_file, "w") as f:
            for path in sorted_css:
                f.write(path + "\n")
        print(f"Created {final_css_file} with {len(sorted_css)} unique CSS paths")
    else:
        print("No CSS paths found")
    
    if all_js_paths:
        sorted_js = sorted(all_js_paths)
        with open(final_js_file, "w") as f:
            for path in sorted_js:
                f.write(path + "\n")
        print(f"Created {final_js_file} with {len(sorted_js)} unique JS paths")
    else:
        print("No JS paths found")


def main():
    parser = argparse.ArgumentParser(
        description="Process CDN logs and extract CSS/JS file paths"
    )
    parser.add_argument(
        "--domain",
        required=True,
        help="CDN domain name"
    )
    parser.add_argument(
        "--project_id",
        required=True,
        help="Enterprise project ID"
    )
    
    args = parser.parse_args()
    
    start_time, end_time, date_str = get_time_range()
    print(f"Time range: {start_time} to {end_time}")
    print(f"Date string: {date_str}")
    
    links = get_cdn_log_links(args.domain, args.project_id, start_time, end_time)
    
    if not links:
        print("No log files found")
        return
    
    all_js_paths = set()
    all_css_paths = set()
    
    for link in links:
        process_log_file(link, args.domain, all_js_paths, all_css_paths)
    
    save_output_files(all_js_paths, all_css_paths, date_str)
    
    print("Processing complete!")


if __name__ == "__main__":
    main()
