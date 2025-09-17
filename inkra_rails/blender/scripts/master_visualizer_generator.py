#!/usr/bin/env python3
"""
Master Audio Visualizer Generator
Runs multiple cutting-edge Blender visualizers with your remastered audio
"""

import os
import subprocess
import sys
from pathlib import Path

# Available visualizers
VISUALIZERS = {
    'geometry_nodes_waveform': {
        'name': 'Advanced Geometry Nodes Waveform',
        'description': 'Complex waveform using procedural geometry nodes with particle systems',
        'script': 'geometry_nodes_waveform.py'
    },
    'fluid_audio': {
        'name': 'Fluid Simulation Audio Reactive',
        'description': 'Ocean-like fluid simulation that responds to audio frequencies',
        'script': 'fluid_audio_visualizer.py'
    },
    'procedural_space': {
        'name': 'Procedural Space Visualizer',
        'description': 'Cosmic environment with stars, nebulae, and audio-reactive planets',
        'script': 'procedural_space_visualizer.py'
    },
    'organic_growth': {
        'name': 'Organic Growth Visualizer',
        'description': 'Plant-like growth patterns with L-systems and procedural animation',
        'script': 'organic_growth_visualizer.py'
    },
    'crystalline_resonance': {
        'name': 'Crystalline Resonance Visualizer',
        'description': 'Fractal crystals that shatter and reform with audio resonance',
        'script': 'crystalline_resonance_visualizer.py'
    },
    'quantum_interference': {
        'name': 'Quantum Interference Visualizer',
        'description': 'Wave interference patterns with probability clouds and dimensional rifts',
        'script': 'quantum_interference_visualizer.py'
    }
}

# Audio files from your remastered collection
AUDIO_FILES = [
    "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_final.m4a",
    "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_adaptive.m4a",
    "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_balanced.m4a",
    "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_concise.m4a",
    "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_storytelling.m4a"
]

def get_script_path():
    """Get the path to the scripts directory"""
    return Path(__file__).parent

def get_blender_executable():
    """Find Blender executable on the system"""
    possible_paths = [
        "/Applications/Blender.app/Contents/MacOS/Blender",
        "/usr/local/bin/blender",
        "/usr/bin/blender",
        "blender"  # In PATH
    ]
    
    for path in possible_paths:
        if os.path.exists(path) or path == "blender":
            return path
    
    print("❌ Blender not found! Please install Blender or add it to your PATH.")
    return None

def run_visualizer(visualizer_key, audio_file=None, output_dir=None):
    """Run a specific visualizer"""
    
    if visualizer_key not in VISUALIZERS:
        print(f"❌ Unknown visualizer: {visualizer_key}")
        return False
    
    visualizer = VISUALIZERS[visualizer_key]
    script_path = get_script_path() / visualizer['script']
    
    if not script_path.exists():
        print(f"❌ Script not found: {script_path}")
        return False
    
    blender_exe = get_blender_executable()
    if not blender_exe:
        return False
    
    print(f"🚀 Running {visualizer['name']}...")
    print(f"📄 Description: {visualizer['description']}")
    
    # Use default audio if none specified
    if not audio_file:
        audio_file = AUDIO_FILES[0]
    
    if not output_dir:
        output_dir = get_script_path().parent / "output"
        output_dir.mkdir(exist_ok=True)
    
    # Construct Blender command
    cmd = [
        blender_exe,
        "--background",
        "--python", str(script_path)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            print(f"✅ {visualizer['name']} completed successfully!")
            return True
        else:
            print(f"❌ {visualizer['name']} failed:")
            print(result.stderr)
            return False
            
    except subprocess.TimeoutExpired:
        print(f"⏰ {visualizer['name']} timed out (5 minutes)")
        return False
    except Exception as e:
        print(f"❌ Error running {visualizer['name']}: {e}")
        return False

def run_all_visualizers():
    """Run all available visualizers"""
    
    print("🎨 MASTER AUDIO VISUALIZER GENERATOR")
    print("=" * 50)
    print(f"Found {len(VISUALIZERS)} cutting-edge visualizers")
    print(f"Found {len(AUDIO_FILES)} remastered audio files")
    print()
    
    results = {}
    
    for viz_key in VISUALIZERS:
        print(f"🎬 Processing {viz_key}...")
        success = run_visualizer(viz_key)
        results[viz_key] = success
        print()
    
    # Summary
    print("📊 RESULTS SUMMARY")
    print("=" * 30)
    
    successful = sum(1 for success in results.values() if success)
    total = len(results)
    
    for viz_key, success in results.items():
        status = "✅ SUCCESS" if success else "❌ FAILED"
        print(f"{VISUALIZERS[viz_key]['name']}: {status}")
    
    print(f"\n🎯 Overall: {successful}/{total} visualizers completed successfully")

def create_render_batch(audio_file=None):
    """Create batch render files for all visualizers"""
    
    if not audio_file:
        audio_file = AUDIO_FILES[0]
    
    output_dir = get_script_path().parent / "output"
    output_dir.mkdir(exist_ok=True)
    
    # Create shell script for batch rendering
    batch_script = get_script_path() / "render_all_visualizers.sh"
    
    blender_exe = get_blender_executable()
    if not blender_exe:
        return
    
    with open(batch_script, 'w') as f:
        f.write("#!/bin/bash\n")
        f.write("# Auto-generated batch render script\n")
        f.write("# Renders all audio visualizers\n\n")
        
        f.write(f'echo "🎨 Starting batch render of {len(VISUALIZERS)} visualizers..."\n\n')
        
        for viz_key, visualizer in VISUALIZERS.items():
            script_path = get_script_path() / visualizer['script']
            output_path = output_dir / f"{viz_key}_render"
            
            f.write(f'echo "🎬 Rendering {visualizer["name"]}..."\n')
            f.write(f'"{blender_exe}" --background --python "{script_path}"\n')
            f.write('if [ $? -eq 0 ]; then\n')
            f.write(f'    echo "✅ {visualizer["name"]} completed"\n')
            f.write('else\n')
            f.write(f'    echo "❌ {visualizer["name"]} failed"\n')
            f.write('fi\n\n')
        
        f.write('echo "🎯 Batch render complete!"\n')
    
    # Make executable
    os.chmod(batch_script, 0o755)
    
    print(f"📝 Created batch render script: {batch_script}")
    print(f"Run with: {batch_script}")

def list_visualizers():
    """List all available visualizers"""
    
    print("🎨 AVAILABLE CUTTING-EDGE VISUALIZERS")
    print("=" * 50)
    
    for i, (viz_key, visualizer) in enumerate(VISUALIZERS.items(), 1):
        print(f"{i}. {visualizer['name']}")
        print(f"   Key: {viz_key}")
        print(f"   Description: {visualizer['description']}")
        print()

def interactive_menu():
    """Interactive menu for selecting visualizers"""
    
    while True:
        print("\n🎨 MASTER VISUALIZER GENERATOR")
        print("=" * 40)
        print("1. List all visualizers")
        print("2. Run single visualizer")
        print("3. Run all visualizers")
        print("4. Create batch render script")
        print("5. Exit")
        print()
        
        choice = input("Choose an option (1-5): ").strip()
        
        if choice == "1":
            list_visualizers()
            
        elif choice == "2":
            list_visualizers()
            viz_key = input("\nEnter visualizer key: ").strip()
            
            if viz_key in VISUALIZERS:
                print(f"\nAvailable audio files:")
                for i, audio in enumerate(AUDIO_FILES, 1):
                    filename = os.path.basename(audio)
                    print(f"{i}. {filename}")
                
                audio_choice = input(f"\nChoose audio file (1-{len(AUDIO_FILES)}, or Enter for default): ").strip()
                
                if audio_choice and audio_choice.isdigit():
                    audio_idx = int(audio_choice) - 1
                    if 0 <= audio_idx < len(AUDIO_FILES):
                        selected_audio = AUDIO_FILES[audio_idx]
                    else:
                        selected_audio = None
                else:
                    selected_audio = None
                
                run_visualizer(viz_key, selected_audio)
            else:
                print(f"❌ Unknown visualizer: {viz_key}")
                
        elif choice == "3":
            run_all_visualizers()
            
        elif choice == "4":
            create_render_batch()
            
        elif choice == "5":
            print("👋 Goodbye!")
            break
            
        else:
            print("❌ Invalid choice. Please enter 1-5.")

def main():
    """Main function"""
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "list":
            list_visualizers()
            
        elif command == "all":
            run_all_visualizers()
            
        elif command == "batch":
            create_render_batch()
            
        elif command in VISUALIZERS:
            audio_file = sys.argv[2] if len(sys.argv) > 2 else None
            run_visualizer(command, audio_file)
            
        else:
            print(f"❌ Unknown command: {command}")
            print("Available commands: list, all, batch, or visualizer key")
            
    else:
        interactive_menu()

if __name__ == "__main__":
    main()