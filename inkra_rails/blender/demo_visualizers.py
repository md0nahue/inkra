#!/usr/bin/env python3
"""
Demo script to showcase the cutting-edge audio visualizers
"""

import os
import sys
from pathlib import Path

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent / "scripts"
sys.path.append(str(scripts_dir))

from master_visualizer_generator import VISUALIZERS, AUDIO_FILES, list_visualizers

def show_project_overview():
    """Show comprehensive project overview"""
    
    print("🎨 CUTTING-EDGE BLENDER AUDIO VISUALIZERS")
    print("=" * 60)
    print()
    print("🚀 PROJECT OVERVIEW")
    print("-" * 20)
    print("✨ 6 stunning, original visualizers")
    print("🎵 5 remastered audio files ready to use")
    print("📚 13 tutorial transcripts analyzed")
    print("🔬 Advanced Blender techniques implemented")
    print("🎬 Cinema-quality render settings")
    print()
    
    print("🎯 NO BASIC SPECTRUM BARS HERE!")
    print("-" * 35)
    print("Every visualizer uses cutting-edge techniques:")
    print("• Procedural Geometry Nodes")
    print("• Fluid Physics Simulation") 
    print("• Volumetric Rendering")
    print("• Fractal Mathematics")
    print("• Quantum-Inspired Effects")
    print("• Organic Growth Algorithms")
    print()

def show_technical_features():
    """Show advanced technical features"""
    
    print("🔧 ADVANCED TECHNICAL FEATURES")
    print("-" * 35)
    print()
    
    features = {
        "Geometry Nodes": [
            "Procedural waveform generation",
            "Dynamic particle distribution", 
            "Real-time mesh deformation",
            "Complex branching systems"
        ],
        "Volumetric Rendering": [
            "Quantum probability clouds",
            "Nebula formations", 
            "Energy field visualization",
            "Atmospheric scattering"
        ],
        "Physics Simulation": [
            "Mantaflow fluid dynamics",
            "Particle force fields",
            "Rigid body interactions",
            "Turbulence modeling"
        ],
        "Procedural Materials": [
            "Node-based shaders",
            "Caustic refractions",
            "Subsurface scattering",
            "Emission animations"
        ],
        "Camera Systems": [
            "Orbital tracking",
            "Dynamic focal points",
            "Motion blur effects",
            "Cinematic framing"
        ]
    }
    
    for category, items in features.items():
        print(f"📦 {category}:")
        for item in items:
            print(f"   • {item}")
        print()

def show_render_specs():
    """Show render specifications"""
    
    print("🎬 RENDER SPECIFICATIONS")
    print("-" * 28)
    print()
    print("Engine: Cycles (GPU accelerated)")
    print("Resolution: 1920x1080 to 2560x1440")
    print("Samples: 512-1024 (quality optimized)")
    print("Features: Motion blur, denoising, caustics")
    print("Format: H.264 MP4 output")
    print("Duration: 250-300 frames (~10-12 seconds)")
    print()

def show_audio_files():
    """Show available audio files"""
    
    print("🎵 AVAILABLE REMASTERED AUDIO")
    print("-" * 32)
    print()
    
    for i, audio_file in enumerate(AUDIO_FILES, 1):
        filename = os.path.basename(audio_file)
        name = filename.replace('remastered_', '').replace('.m4a', '')
        
        # Check if file exists
        exists = "✅" if os.path.exists(audio_file) else "❌"
        
        print(f"{i}. {name.upper()} {exists}")
        
        # Show file size if exists
        if os.path.exists(audio_file):
            size_mb = os.path.getsize(audio_file) / (1024 * 1024)
            print(f"   Size: {size_mb:.1f}MB")
    print()

def show_file_structure():
    """Show project file structure"""
    
    print("📁 PROJECT STRUCTURE")
    print("-" * 20)
    print()
    
    base_path = Path(__file__).parent
    
    print("blender/")
    print("├── scripts/")
    
    scripts_path = base_path / "scripts"
    if scripts_path.exists():
        py_files = list(scripts_path.glob("*.py"))
        for i, py_file in enumerate(py_files):
            prefix = "├──" if i < len(py_files) - 1 else "└──"
            print(f"│   {prefix} {py_file.name}")
    
    print("├── tutorials/")
    tutorials_path = base_path / "tutorials" 
    if tutorials_path.exists():
        vtt_files = list(tutorials_path.glob("*.vtt"))
        txt_files = list(tutorials_path.glob("*transcript.txt"))
        print(f"│   ├── {len(vtt_files)} VTT subtitle files")
        print(f"│   └── {len(txt_files)} transcript files")
    
    print("├── output/ (renders will appear here)")
    print("├── assets/")
    print("├── techniques_analysis.md")
    print("└── README.md")
    print()

def main():
    """Main demo function"""
    
    show_project_overview()
    show_technical_features()
    show_render_specs()
    
    # Show visualizers
    list_visualizers()
    
    show_audio_files()
    show_file_structure()
    
    print("🚀 READY TO CREATE STUNNING VISUALS!")
    print("=" * 40)
    print()
    print("Next steps:")
    print("1. Run: python3 scripts/master_visualizer_generator.py")
    print("2. Select visualizer from interactive menu")
    print("3. Choose your remastered audio file")
    print("4. Watch Blender create cutting-edge art!")
    print()
    print("Or run all visualizers with:")
    print("python3 scripts/master_visualizer_generator.py all")

if __name__ == "__main__":
    main()