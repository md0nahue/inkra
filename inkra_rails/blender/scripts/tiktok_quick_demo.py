#!/usr/bin/env python3
"""
Quick TikTok Demo Visualizer
Fast-rendering preview with your remastered audio
"""

import bpy
import mathutils
import random
import math
import os

# Audio file
AUDIO_FILE = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_concise.m4a"
OUTPUT_PATH = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_quick_visualizer():
    """Create fast-rendering visualizer elements"""
    
    print("⚡ Creating quick demo elements...")
    
    objects = []
    
    # Create colorful spheres in a pattern
    for i in range(8):
        angle = (i / 8.0) * 2 * math.pi
        radius = 2.5
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        z = 0
        
        # Create sphere
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(x, y, z))
        sphere = bpy.context.object
        sphere.name = f"DemoSphere_{i}"
        
        # Create vibrant material
        mat = bpy.data.materials.new(name=f"DemoMat_{i}")
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        
        # Rainbow colors
        hue = i / 8.0
        color = mathutils.Color()
        color.hsv = (hue, 1.0, 1.0)
        
        principled.inputs['Base Color'].default_value = (*color, 1.0)
        principled.inputs['Emission Color'].default_value = (*color, 1.0)
        principled.inputs['Emission Strength'].default_value = 2.0
        principled.inputs['Roughness'].default_value = 0.1
        
        sphere.data.materials.append(mat)
        objects.append(sphere)
    
    return objects

def setup_quick_camera():
    """Setup camera for quick demo"""
    
    print("📱 Setting up demo camera...")
    
    bpy.ops.object.camera_add(location=(0, -6, 2))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(70), 0, 0)
    bpy.context.scene.camera = camera
    
    return camera

def setup_quick_lighting():
    """Simple lighting setup"""
    
    print("💡 Setting up demo lighting...")
    
    # Single area light
    bpy.ops.object.light_add(type='AREA', location=(0, -3, 5))
    light = bpy.context.object
    light.data.energy = 20.0
    light.data.size = 8.0
    
    # Dark background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.02, 0.02, 0.08, 1.0)
        bg_node.inputs['Strength'].default_value = 0.1

def animate_quick_demo(objects):
    """Fast animation for demo"""
    
    print("🎬 Creating demo animation...")
    
    # Short 5-second demo (120 frames)
    for frame in range(1, 121, 5):
        bpy.context.scene.frame_set(frame)
        
        for i, obj in enumerate(objects):
            # Rotation
            obj.rotation_euler.z = frame * 0.1 * (i + 1)
            obj.keyframe_insert(data_path="rotation_euler", frame=frame)
            
            # Scale pulsing
            pulse = 1.0 + 0.5 * math.sin(frame * 0.2 + i)
            obj.scale = (pulse, pulse, pulse)
            obj.keyframe_insert(data_path="scale", frame=frame)
            
            # Vertical movement
            base_z = 0
            float_motion = math.sin(frame * 0.15 + i * 0.5)
            obj.location.z = base_z + float_motion
            obj.keyframe_insert(data_path="location", frame=frame)

def setup_quick_audio():
    """Setup audio for demo"""
    
    print("🎵 Setting up demo audio...")
    
    if not os.path.exists(AUDIO_FILE):
        print(f"❌ Audio not found: {AUDIO_FILE}")
        return False
    
    if not bpy.context.scene.sequence_editor:
        bpy.context.scene.sequence_editor_create()
    
    seq_editor = bpy.context.scene.sequence_editor
    for strip in list(seq_editor.sequences):
        seq_editor.sequences.remove(strip)
    
    try:
        audio_strip = seq_editor.sequences.new_sound(
            name="DemoAudio",
            filepath=AUDIO_FILE,
            channel=1,
            frame_start=1
        )
        print(f"✅ Audio loaded: {os.path.basename(AUDIO_FILE)}")
        return True
    except Exception as e:
        print(f"❌ Audio error: {e}")
        return False

def setup_quick_render():
    """Fast render settings"""
    
    print("🎬 Setting up quick render...")
    
    scene = bpy.context.scene
    
    # TikTok dimensions but lower resolution for speed
    scene.render.resolution_x = 540  # Half resolution
    scene.render.resolution_y = 960  # Half resolution
    scene.render.resolution_percentage = 100
    
    # Fast render settings
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32  # Very low samples
    scene.cycles.use_denoising = True
    
    # Short animation
    scene.frame_start = 1
    scene.frame_end = 120  # 5 seconds
    scene.frame_set(1)
    
    # Output
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.audio_codec = 'AAC'
    
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    output_file = os.path.join(OUTPUT_PATH, "tiktok_quick_demo")
    scene.render.filepath = output_file
    
    print(f"✅ Quick render setup: 540x960, 120 frames, 32 samples")
    return output_file

def main():
    """Create and render quick TikTok demo"""
    
    print("⚡ QUICK TIKTOK DEMO VISUALIZER")
    print("=" * 40)
    
    clear_scene()
    
    # Create scene
    objects = create_quick_visualizer()
    camera = setup_quick_camera()
    setup_quick_lighting()
    
    # Animation and audio
    animate_quick_demo(objects)
    audio_loaded = setup_quick_audio()
    
    # Render setup
    output_file = setup_quick_render()
    
    print(f"✅ Quick demo ready:")
    print(f"🎨 Objects: {len(objects)} rainbow spheres")
    print(f"📱 Format: 540x960 (fast preview)")
    print(f"🎵 Audio: {os.path.basename(AUDIO_FILE)}")
    print(f"⚡ Samples: 32 (very fast)")
    
    # QUICK RENDER
    print("\n⚡ QUICK RENDER STARTING...")
    print("🚀 This should complete in 2-3 minutes!")
    
    try:
        bpy.ops.render.render(animation=True)
        print("\n✅ QUICK DEMO COMPLETE!")
        print(f"🎉 Preview video: {output_file}")
        print("\n📱 This shows your remastered audio with:")
        print("• TikTok vertical format")
        print("• Synchronized animation")
        print("• Vibrant colors")
        print("• Quick preview quality")
        
    except Exception as e:
        print(f"\n❌ Quick render failed: {e}")

if __name__ == "__main__":
    main()