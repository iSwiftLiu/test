#!/usr/bin/env python3
"""
CDN Logs Comparison Script - High Performance Version

This script compares and analyzes CDN log processing results:
1. Aggregates all daily generated jsall-YYYYMMDD and cssall-YYYYMMDD files
2. Compares with reference files (js_all and css_all)
3. Generates intersection and difference files for both JS and CSS
4. Optimized for high performance with memory and CPU efficiency

Output files:
- js_common.txt: JS files present in both logs and reference
- js_only_in_reference.txt: JS files only in reference file
- css_common.txt: CSS files present in both logs and reference  
- css_only_in_reference.txt: CSS files only in reference file
"""

import argparse
import glob
import os
import sys
from pathlib import Path


def read_file_lines_as_set(filepath):
    """
    Memory-optimized file reader that returns a set of non-empty lines.
    Reads file line by line to avoid loading entire file into memory.
    
    Args:
        filepath (str): Path to the file to read
        
    Returns:
        set: Set of cleaned lines from the file
    """
    lines_set = set()
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as file:
            for line in file:
                cleaned_line = line.strip()
                if cleaned_line:  # Skip empty lines
                    lines_set.add(cleaned_line)
    except FileNotFoundError:
        print(f"Warning: File not found: {filepath}", file=sys.stderr)
    except Exception as e:
        print(f"Error reading file {filepath}: {e}", file=sys.stderr)
    
    return lines_set


def aggregate_files(pattern):
    """
    Aggregate and deduplicate content from multiple files matching the pattern.
    Uses glob to find files and set operations for deduplication.
    
    Args:
        pattern (str): Glob pattern to match files
        
    Returns:
        set: Deduplicated set of all lines from matching files
    """
    aggregated_set = set()
    matching_files = glob.glob(pattern)
    
    if not matching_files:
        print(f"Warning: No files found matching pattern: {pattern}", file=sys.stderr)
        return aggregated_set
    
    print(f"Found {len(matching_files)} files matching pattern: {pattern}")
    
    for filepath in matching_files:
        print(f"  Processing: {filepath}")
        file_lines = read_file_lines_as_set(filepath)
        aggregated_set.update(file_lines)  # Union operation, O(n) complexity
        print(f"    Added {len(file_lines)} unique lines")
    
    print(f"Total unique lines from {len(matching_files)} files: {len(aggregated_set)}")
    return aggregated_set


def write_set_to_file(data_set, filepath, description=""):
    """
    Write a set of strings to a file, one per line, sorted for consistency.
    
    Args:
        data_set (set): Set of strings to write
        filepath (str): Output file path
        description (str): Description for logging purposes
    """
    try:
        # Sort for consistent output and easier debugging
        sorted_data = sorted(data_set)
        
        with open(filepath, 'w', encoding='utf-8') as file:
            for item in sorted_data:
                file.write(item + '\n')
        
        print(f"Created {filepath} with {len(sorted_data)} entries{f' ({description})' if description else ''}")
    
    except Exception as e:
        print(f"Error writing to file {filepath}: {e}", file=sys.stderr)


def compare_and_analyze(log_files_pattern, reference_file, output_prefix, file_type):
    """
    Compare aggregated log files with reference file and generate analysis results.
    
    Args:
        log_files_pattern (str): Glob pattern for log files
        reference_file (str): Path to reference file
        output_prefix (str): Prefix for output files (js or css)
        file_type (str): Type description for logging (JS or CSS)
    """
    print(f"\n=== Processing {file_type} Files ===")
    
    # Step 1: Aggregate and deduplicate log files
    print(f"1. Aggregating {file_type} log files...")
    log_files_set = aggregate_files(log_files_pattern)
    
    if not log_files_set:
        print(f"No {file_type} entries found in log files")
        return
    
    # Step 2: Read reference file
    print(f"2. Reading {file_type} reference file: {reference_file}")
    reference_set = read_file_lines_as_set(reference_file)
    
    if not reference_set:
        print(f"No {file_type} entries found in reference file")
        return
    
    print(f"   Reference file contains {len(reference_set)} unique entries")
    
    # Step 3: Perform set operations (O(n) complexity)
    print(f"3. Performing set operations...")
    
    # Intersection: files present in both log and reference
    common_set = log_files_set & reference_set
    
    # Difference: files only in reference (not in logs)
    only_in_reference_set = reference_set - log_files_set
    
    print(f"   Common entries (intersection): {len(common_set)}")
    print(f"   Only in reference (difference): {len(only_in_reference_set)}")
    
    # Step 4: Write output files
    print(f"4. Writing output files...")
    write_set_to_file(
        common_set, 
        f"{output_prefix}_common.txt",
        f"{file_type} files present in both logs and reference"
    )
    
    write_set_to_file(
        only_in_reference_set, 
        f"{output_prefix}_only_in_reference.txt",
        f"{file_type} files only in reference"
    )


def main():
    """
    Main function to orchestrate the comparison process.
    """
    parser = argparse.ArgumentParser(
        description="Compare CDN log files with reference files and generate analysis reports",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python compare_cdn_logs.py
  python compare_cdn_logs.py --js-reference my_js_all --css-reference my_css_all
  python compare_cdn_logs.py --working-dir /path/to/files

Output Files:
  js_common.txt                - JS files in both logs and reference
  js_only_in_reference.txt     - JS files only in reference file  
  css_common.txt               - CSS files in both logs and reference
  css_only_in_reference.txt    - CSS files only in reference file
        """
    )
    
    parser.add_argument(
        "--js-reference",
        default="js_all",
        help="Path to JS reference file (default: js_all)"
    )
    
    parser.add_argument(
        "--css-reference", 
        default="css_all",
        help="Path to CSS reference file (default: css_all)"
    )
    
    parser.add_argument(
        "--working-dir",
        default=".",
        help="Working directory containing the files (default: current directory)"
    )
    
    args = parser.parse_args()
    
    # Change to working directory
    original_dir = os.getcwd()
    try:
        os.chdir(args.working_dir)
        print(f"Working directory: {os.getcwd()}")
        
        # Define file patterns
        js_log_pattern = "jsall-*"
        css_log_pattern = "cssall-*"
        
        # Process JS files
        compare_and_analyze(
            js_log_pattern,
            args.js_reference, 
            "js",
            "JS"
        )
        
        # Process CSS files  
        compare_and_analyze(
            css_log_pattern,
            args.css_reference,
            "css", 
            "CSS"
        )
        
        print("\n=== Analysis Complete ===")
        print("Generated output files:")
        print("  - js_common.txt")
        print("  - js_only_in_reference.txt") 
        print("  - css_common.txt")
        print("  - css_only_in_reference.txt")
        
    except FileNotFoundError:
        print(f"Error: Working directory not found: {args.working_dir}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        os.chdir(original_dir)


if __name__ == "__main__":
    main()
