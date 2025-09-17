#!/usr/bin/env python3
"""
Convert VTT subtitle files to clean text for analysis
"""
import os
import re
import glob

def clean_vtt_text(vtt_content):
    """Convert VTT content to clean text"""
    lines = vtt_content.split('\n')
    text_lines = []
    
    for line in lines:
        line = line.strip()
        # Skip VTT headers and timestamps
        if (line.startswith('WEBVTT') or 
            line.startswith('NOTE') or 
            '-->' in line or 
            line.isdigit() or
            not line):
            continue
            
        # Remove HTML tags and styling
        line = re.sub(r'<[^>]+>', '', line)
        line = re.sub(r'&amp;', '&', line)
        line = re.sub(r'&lt;', '<', line)
        line = re.sub(r'&gt;', '>', line)
        
        if line and not line.startswith('align:'):
            text_lines.append(line)
    
    return ' '.join(text_lines)

def main():
    vtt_files = glob.glob('blender/tutorials/*.vtt')
    
    for vtt_file in vtt_files:
        print(f"Processing: {vtt_file}")
        
        with open(vtt_file, 'r', encoding='utf-8') as f:
            vtt_content = f.read()
        
        clean_text = clean_vtt_text(vtt_content)
        
        # Create output filename
        base_name = os.path.splitext(os.path.basename(vtt_file))[0]
        base_name = base_name.replace('.en', '')  # Remove .en suffix
        output_file = f'blender/tutorials/{base_name}_transcript.txt'
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(clean_text)
        
        print(f"Saved to: {output_file}")

if __name__ == "__main__":
    main()