import os
import re

# Path to the XML file
# Using raw string for Windows path avoiding escape issues
xml_path = r'v:\Slowverb\docs\slowverb-mastering-toggle-plan-v3\phaselimiter-master\phaselimiter-repomix-output.xml'
# Target directory for extraction
target_dir = r'v:\Slowverb\wasm\phaselimiter\src_original'

if not os.path.exists(target_dir):
    os.makedirs(target_dir)

def extract_files():
    print(f"Reading {xml_path}...")
    
    current_file = None
    file_count = 0
    # simple regex to match <file path="...">
    # Note: repomix might use double or single quotes
    file_start_pattern = re.compile(r'^\s*<file path="([^"]+)">')
    file_end_pattern = re.compile(r'^\s*</file>\s*$')

    try:
        with open(xml_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                if current_file:
                    if file_end_pattern.match(line):
                        current_file.close()
                        current_file = None
                    else:
                        current_file.write(line)
                else:
                    match = file_start_pattern.match(line)
                    if match:
                        rel_path = match.group(1)
                        # Filter to only relevant source files
                        # Extracting main logic, stubs, bakeuage lib
                        if any(rel_path.endswith(ext) for ext in ['.cpp', '.h', '.hpp', '.c', '.txt', '.cmake', '.json']):
                            full_path = os.path.join(target_dir, rel_path)
                            
                            # Skip if path traversal attempt (basic check)
                            if '..' in rel_path:
                                continue
                                
                            os.makedirs(os.path.dirname(full_path), exist_ok=True)
                            current_file = open(full_path, 'w', encoding='utf-8')
                            file_count += 1
                            if file_count % 50 == 0:
                                print(f"Extracted {file_count} files... (last: {rel_path})")

        print(f"Extraction complete. {file_count} files extracted.")
        
    except Exception as e:
        print(f"Error during extraction: {e}")
        if current_file:
            current_file.close()

if __name__ == "__main__":
    extract_files()
