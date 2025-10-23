#!/usr/bin/env python3
"""
CDN Log Processor Script

This script processes CDN logs by:
1. Calculating time range (2 days ago to 1 day ago)
2. Fetching CDN log links
3. Downloading, extracting, and processing log files
4. Extracting CSS and JS file paths
5. Generating final sorted and deduplicated output files
"""

import argparse
import json
import os
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


def extract_css_paths(log_file, domain):
    r"""
    Extract CSS file paths from log file.
    Equivalent bash command:
    egrep "app\.|chunk-" <file> | awk -F '"${domain}"' '{print $2}' | egrep "\.js|\.css" | awk -F '"' '{print $2}' | sort | uniq | egrep 'lottery|chunk' | grep '\.css$'
    """
    try:
        p1 = subprocess.Popen(
            ["egrep", "app\\.|chunk-", log_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        
        p2 = subprocess.Popen(
            ["awk", "-F", f'"{domain}"', "{print $2}"],
            stdin=p1.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p1.stdout.close()
        
        p3 = subprocess.Popen(
            ["egrep", "\\.js|\\.css"],
            stdin=p2.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p2.stdout.close()
        
        p4 = subprocess.Popen(
            ["awk", "-F", '"', "{print $2}"],
            stdin=p3.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p3.stdout.close()
        
        p5 = subprocess.Popen(
            ["sort"],
            stdin=p4.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p4.stdout.close()
        
        p6 = subprocess.Popen(
            ["uniq"],
            stdin=p5.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p5.stdout.close()
        
        p7 = subprocess.Popen(
            ["egrep", "lottery|chunk"],
            stdin=p6.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p6.stdout.close()
        
        p8 = subprocess.Popen(
            ["grep", "\\.css$"],
            stdin=p7.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p7.stdout.close()
        
        output, _ = p8.communicate()
        return output.decode("utf-8").strip().split("\n") if output else []
    
    except Exception as e:
        print(f"Error extracting CSS paths: {e}", file=sys.stderr)
        return []


def extract_js_paths(log_file, domain):
    r"""
    Extract JS file paths from log file.
    Equivalent bash command:
    egrep "app\.|chunk-" <file> | awk -F '"${domain}"' '{print $2}' | egrep "\.js|\.css" | awk -F '"' '{print $2}' | sort | uniq | egrep 'lottery|chunk' | grep '\.js$'
    """
    try:
        p1 = subprocess.Popen(
            ["egrep", "app\\.|chunk-", log_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        
        p2 = subprocess.Popen(
            ["awk", "-F", f'"{domain}"', "{print $2}"],
            stdin=p1.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p1.stdout.close()
        
        p3 = subprocess.Popen(
            ["egrep", "\\.js|\\.css"],
            stdin=p2.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p2.stdout.close()
        
        p4 = subprocess.Popen(
            ["awk", "-F", '"', "{print $2}"],
            stdin=p3.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p3.stdout.close()
        
        p5 = subprocess.Popen(
            ["sort"],
            stdin=p4.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p4.stdout.close()
        
        p6 = subprocess.Popen(
            ["uniq"],
            stdin=p5.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p5.stdout.close()
        
        p7 = subprocess.Popen(
            ["egrep", "lottery|chunk"],
            stdin=p6.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p6.stdout.close()
        
        p8 = subprocess.Popen(
            ["grep", "\\.js$"],
            stdin=p7.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        p7.stdout.close()
        
        output, _ = p8.communicate()
        return output.decode("utf-8").strip().split("\n") if output else []
    
    except Exception as e:
        print(f"Error extracting JS paths: {e}", file=sys.stderr)
        return []


def process_log_file(link, domain, css_output_file, js_output_file):
    """
    Process a single log file:
    1. Download
    2. Decompress
    3. Extract CSS and JS paths
    4. Append to output files
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
    
    css_paths = extract_css_paths(decompressed_file, domain)
    if css_paths and css_paths[0]:
        with open(css_output_file, "a") as f:
            for path in css_paths:
                if path:
                    f.write(path + "\n")
    
    js_paths = extract_js_paths(decompressed_file, domain)
    if js_paths and js_paths[0]:
        with open(js_output_file, "a") as f:
            for path in js_paths:
                if path:
                    f.write(path + "\n")
    
    try:
        os.remove(decompressed_file)
    except Exception as e:
        print(f"Warning: Could not delete {decompressed_file}: {e}", file=sys.stderr)
    
    return True


def finalize_output_files(temp_css_file, temp_js_file, date_str):
    """
    Sort, deduplicate, and rename output files.
    """
    final_css_file = f"cssall-{date_str}"
    final_js_file = f"jsall-{date_str}"
    
    if os.path.exists(temp_css_file):
        try:
            with open(temp_css_file, "r") as f:
                lines = f.readlines()
            
            unique_lines = sorted(set(line.strip() for line in lines if line.strip()))
            
            with open(final_css_file, "w") as f:
                for line in unique_lines:
                    f.write(line + "\n")
            
            os.remove(temp_css_file)
            print(f"Created {final_css_file} with {len(unique_lines)} unique CSS paths")
        except Exception as e:
            print(f"Error processing CSS file: {e}", file=sys.stderr)
    else:
        print("No CSS paths found")
    
    if os.path.exists(temp_js_file):
        try:
            with open(temp_js_file, "r") as f:
                lines = f.readlines()
            
            unique_lines = sorted(set(line.strip() for line in lines if line.strip()))
            
            with open(final_js_file, "w") as f:
                for line in unique_lines:
                    f.write(line + "\n")
            
            os.remove(temp_js_file)
            print(f"Created {final_js_file} with {len(unique_lines)} unique JS paths")
        except Exception as e:
            print(f"Error processing JS file: {e}", file=sys.stderr)
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
    
    temp_css_file = "cssall"
    temp_js_file = "jsall"
    
    for temp_file in [temp_css_file, temp_js_file]:
        if os.path.exists(temp_file):
            os.remove(temp_file)
    
    for link in links:
        process_log_file(link, args.domain, temp_css_file, temp_js_file)
    
    finalize_output_files(temp_css_file, temp_js_file, date_str)
    
    print("Processing complete!")


if __name__ == "__main__":
    main()
