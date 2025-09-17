#!/usr/bin/env python3
"""
Analyze Blender audio visualizer transcripts to extract techniques
"""
import os
import glob
import re
from collections import defaultdict

def extract_techniques(text):
    """Extract key techniques and methods from transcript text"""
    techniques = []
    
    # Common Blender audio visualizer keywords and patterns
    patterns = {
        'geometry_nodes': r'geometry\s*node[s]?',
        'sound_input': r'sound\s*input',
        'bake_sound': r'bake\s*sound',
        'spectral_analysis': r'spectral|frequency|spectrum',
        'audio_animation': r'audio\s*animation',
        'drivers': r'driver[s]?',
        'modifiers': r'modifier[s]?',
        'particle_systems': r'particle[s]?\s*system[s]?',
        'material_nodes': r'material\s*node[s]?',
        'vertex_groups': r'vertex\s*group[s]?',
        'curve_objects': r'curve[s]?\s*object[s]?',
        'displacement': r'displacement',
        'scale_animation': r'scale\s*animation',
        'emission_shader': r'emission\s*shader',
        'wave_texture': r'wave\s*texture',
        'noise_texture': r'noise\s*texture',
        'mix_shader': r'mix\s*shader',
        'add_shader': r'add\s*shader'
    }
    
    for technique, pattern in patterns.items():
        matches = re.findall(pattern, text, re.IGNORECASE)
        if matches:
            techniques.append((technique, len(matches)))
    
    return techniques

def extract_steps(text):
    """Extract step-by-step instructions"""
    steps = []
    
    # Look for numbered steps or procedural language
    step_patterns = [
        r'step\s*\d+[:\-]?\s*([^\.]+)',
        r'first[,\s]+([^\.]+)',
        r'next[,\s]+([^\.]+)', 
        r'then[,\s]+([^\.]+)',
        r'finally[,\s]+([^\.]+)',
        r'now[,\s]+([^\.]+)',
        r'after\s*that[,\s]+([^\.]+)'
    ]
    
    for pattern in step_patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        steps.extend(matches)
    
    return steps[:10]  # Return first 10 steps to avoid clutter

def main():
    transcript_files = glob.glob('blender/tutorials/*_transcript.txt')
    
    all_techniques = defaultdict(int)
    tutorial_summaries = []
    
    for transcript_file in transcript_files:
        print(f"Analyzing: {transcript_file}")
        
        with open(transcript_file, 'r', encoding='utf-8') as f:
            text = f.read()
        
        # Extract filename for reference
        filename = os.path.basename(transcript_file).replace('_transcript.txt', '')
        
        # Extract techniques
        techniques = extract_techniques(text)
        steps = extract_steps(text)
        
        # Count total technique occurrences
        for technique, count in techniques:
            all_techniques[technique] += count
        
        # Create summary for this tutorial
        summary = {
            'title': filename,
            'techniques': techniques,
            'key_steps': steps[:5],  # Top 5 steps
            'word_count': len(text.split())
        }
        tutorial_summaries.append(summary)
    
    # Generate analysis report
    report = f"""# Blender Audio Visualizer Techniques Analysis

## Most Common Techniques (across all tutorials)
"""
    
    # Sort techniques by frequency
    sorted_techniques = sorted(all_techniques.items(), key=lambda x: x[1], reverse=True)
    
    for technique, count in sorted_techniques:
        report += f"- **{technique.replace('_', ' ').title()}**: {count} mentions\n"
    
    report += "\n## Tutorial Summaries\n\n"
    
    # Sort tutorials by word count (longer = more detailed)
    tutorial_summaries.sort(key=lambda x: x['word_count'], reverse=True)
    
    for summary in tutorial_summaries:
        report += f"### {summary['title']}\n"
        report += f"**Length**: {summary['word_count']} words\n\n"
        
        if summary['techniques']:
            report += "**Key Techniques**:\n"
            for technique, count in summary['techniques']:
                report += f"- {technique.replace('_', ' ').title()}: {count}x\n"
            report += "\n"
        
        if summary['key_steps']:
            report += "**Key Steps**:\n"
            for i, step in enumerate(summary['key_steps'], 1):
                step = step.strip()[:100]  # Truncate long steps
                report += f"{i}. {step}...\n"
        
        report += "\n---\n\n"
    
    # Save analysis
    with open('blender/techniques_analysis.md', 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"\nAnalysis complete! Report saved to blender/techniques_analysis.md")
    print(f"Total tutorials analyzed: {len(tutorial_summaries)}")
    print(f"Most common technique: {sorted_techniques[0][0] if sorted_techniques else 'None'}")

if __name__ == "__main__":
    main()