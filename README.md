# CDN Log Processor

Python script for processing CDN logs and extracting CSS/JS file paths.

## Features

- Automatically calculates time range (2 days ago to 1 day ago)
- Fetches CDN log links using hcloud CLI
- Downloads and processes log files
- Extracts CSS and JS file paths matching specific patterns
- Generates deduplicated and sorted output files

## Prerequisites

- Python 3.6+
- hcloud CLI tool configured with proper credentials
- wget or curl for downloading files
- gzip for decompression

## Usage

```bash
python3 cdn_log_processor.py --domain <CDN_DOMAIN> --project_id <PROJECT_ID>
```

Or make it executable and run directly:

```bash
chmod +x cdn_log_processor.py
./cdn_log_processor.py --domain <CDN_DOMAIN> --project_id <PROJECT_ID>
```

### Example

```bash
./cdn_log_processor.py --domain h5.baidu.com --project_id abc123
```

## Output

The script generates two files:

- `cssall-YYYYMMDD`: Sorted and deduplicated CSS file paths
- `jsall-YYYYMMDD`: Sorted and deduplicated JS file paths

Where `YYYYMMDD` is the date from 2 days ago.

## How It Works

1. **Calculate Time Range**: Computes millisecond timestamps for 2 days ago (00:00:00) to 1 day ago (00:00:00)

2. **Fetch Log Links**: Uses hcloud CLI to retrieve CDN log URLs

3. **Process Each Log File**:
   - Download the .gz file
   - Decompress it (automatically removes .gz)
   - Process using Python native methods:
     - Read file line by line
     - Use regex to match lines containing "app." or "chunk-"
     - Extract paths after domain (quote-delimited)
     - Filter for .js or .css extensions
     - Filter for paths containing "lottery" or "chunk"
   - Delete decompressed file

4. **Generate Final Output**: Sort and deduplicate all extracted paths, then save with date-based filenames

## Pattern Matching

The script filters log entries for:
- Lines containing "app." or "chunk-"
- Files ending in .js or .css
- Paths containing "lottery" or "chunk"
- Separates final output by file extension (.css or .js)
