#!/usr/bin/env python3
"""
Render TikTok Crystalline Visualizer
"""

import bpy
import os

# Import the main visualizer
exec(open("/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/scripts/tiktok_crystalline_visualizer.py").read())

def render_tiktok_video():
    """Render the TikTok video"""
    
    print("\n🎬 STARTING RENDER...")
    print("=" * 30)
    
    # Set output path
    output_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"
    os.makedirs(output_path, exist_ok=True)
    
    # Set filename
    bpy.context.scene.render.filepath = os.path.join(output_path, "tiktok_crystalline_final")
    
    # Render animation
    try:
        print("🎥 Rendering 360 frames at 1080x1920...")
        print("⏱️  This will take several minutes...")
        
        bpy.ops.render.render(animation=True)
        
        print("✅ RENDER COMPLETE!")
        print(f"📁 Video saved to: {output_path}")
        print("🎉 Your TikTok crystalline visualizer is ready!")
        
    except Exception as e:
        print(f"❌ Render failed: {e}")

# Run the render
if __name__ == "__main__":
    render_tiktok_video()