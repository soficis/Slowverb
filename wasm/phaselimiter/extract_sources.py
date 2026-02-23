import xml.etree.ElementTree as ET
import os

# Path to the XML file
xml_path = r'v:\Slowverb\docs\slowverb-mastering-toggle-plan-v3\phaselimiter-master\phaselimiter-repomix-output.xml'
# Target directory for extraction
target_dir = r'v:\Slowverb\wasm\phaselimiter\src_original'

if not os.path.exists(target_dir):
    os.makedirs(target_dir)

try:
    print(f"Parsing {xml_path}...")
    # Parse the XML file
    # Note: Using iterparse might be better for huge files, but standard parse is simpler if it fits in memory
    tree = ET.parse(xml_path)
    root = tree.getroot()

    print("Extracting files...")
    count = 0
    # Iterate through all 'file' elements
    for file_elem in root.findall('.//file'):
        path = file_elem.get('path')
        if not path:
            continue
            
        # Skip unrelated files or json resources to save time/space if needed
        # For now, let's extract cpp/h files primarily
        if not (path.endswith('.cpp') or path.endswith('.h') or path.endswith('.hpp')):
            continue

        # Construct full output path
        # The paths in XML are relative to repo root. We map them to target_dir.
        full_path = os.path.join(target_dir, path)
        
        # Ensure directories exist
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        
        # Write content
        content = file_elem.text
        if content:
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
            count += 1
            print(f"Extracted: {path}")

    print(f"Done. Extracted {count} files.")

except Exception as e:
    print(f"Error: {e}")
