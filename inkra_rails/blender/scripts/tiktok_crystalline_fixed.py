#!/usr/bin/env python3
"""
TikTok Crystalline Visualizer - Fixed Version
Creates and renders vertical 1080x1920 videos with your audio
"""

import bpy
import mathutils
import random
import math
import os
from mathutils import Vector

# Audio file
AUDIO_FILE = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_final.m4a"
OUTPUT_PATH = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"

def clear_scene():
    """Clear everything"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_tiktok_scene():
    """Create complete TikTok scene with crystals"""
    
    print("💎 Creating crystals...")
    
    # Create main crystal cluster
    crystals = []
    for i in range(12):  # 12 crystals for TikTok
        # Position in circle
        angle = (i / 12.0) * 2 * math.pi
        radius = 2.0
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        z = random.uniform(-1, 1)
        
        # Create crystal
        bpy.ops.mesh.primitive_ico_sphere_add(location=(x, y, z))
        crystal = bpy.context.object
        crystal.name = f"Crystal_{i}"
        
        # Scale and rotate
        scale = random.uniform(0.3, 0.8)
        crystal.scale = (scale, scale, scale * 2)  # Tall crystals
        crystal.rotation_euler = (
            random.uniform(0, math.pi),
            random.uniform(0, math.pi), 
            random.uniform(0, 2 * math.pi)
        )
        
        crystals.append(crystal)
    
    return crystals

def create_crystal_materials(crystals):
    """Create glowing materials for crystals"""
    
    print("🎨 Creating materials...")
    
    # Create vibrant crystal material
    mat = bpy.data.materials.new(name="TikTokCrystal")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    
    # Get principled BSDF
    principled = nodes.get("Principled BSDF")
    principled.inputs['Base Color'].default_value = (0.2, 0.8, 1.0, 1.0)  # Cyan
    principled.inputs['Metallic'].default_value = 0.9
    principled.inputs['Roughness'].default_value = 0.1
    principled.inputs['Transmission Weight'].default_value = 0.8
    principled.inputs['IOR'].default_value = 1.5
    
    # Emission for glow
    principled.inputs['Emission Color'].default_value = (0.5, 1.0, 1.0, 1.0)
    principled.inputs['Emission Strength'].default_value = 2.0
    
    # Apply to all crystals
    for crystal in crystals:
        crystal.data.materials.append(mat)
    
    print(f"✅ Applied materials to {len(crystals)} crystals")

def setup_camera():
    """Setup TikTok camera"""
    
    print("📱 Setting up TikTok camera...")
    
    # Create camera
    bpy.ops.object.camera_add(location=(0, -6, 1))
    camera = bpy.context.object
    camera.name = "TikTokCamera"
    
    # Point at crystals
    camera.rotation_euler = (math.radians(90), 0, 0)
    
    # Set as active camera
    bpy.context.scene.camera = camera
    
    print(f"✅ Camera set: {camera.name}")
    return camera

def setup_lighting():
    """Setup dramatic lighting"""
    
    print("💡 Setting up lighting...")
    
    # Key light
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 8))
    key_light = bpy.context.object
    key_light.data.energy = 5.0
    key_light.data.color = (1.0, 0.9, 1.0)
    
    # Fill light  
    bpy.ops.object.light_add(type='AREA', location=(-3, -3, 4))
    fill_light = bpy.context.object
    fill_light.data.energy = 3.0
    fill_light.data.color = (0.7, 1.0, 1.0)
    fill_light.data.size = 4.0
    
    # Dark background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.05, 0.05, 0.15, 1.0)
        bg_node.inputs['Strength'].default_value = 0.2
    
    print("✅ Lighting complete")

def animate_crystals(crystals):
    """Animate crystals for TikTok"""
    
    print("🎬 Animating crystals...")
    
    frame_count = 360  # 15 seconds at 24fps
    
    for frame in range(1, frame_count + 1, 10):
        bpy.context.scene.frame_set(frame)
        
        for i, crystal in enumerate(crystals):
            # Rotation
            rotation_speed = 0.05 + (i % 3) * 0.02
            crystal.rotation_euler.z = frame * rotation_speed
            crystal.rotation_euler.x = math.sin(frame * 0.03 + i) * 0.2
            crystal.keyframe_insert(data_path="rotation_euler", frame=frame)
            
            # Pulsing scale (simulating audio reactivity)
            pulse = 1.0 + 0.3 * math.sin(frame * 0.1 + i * 0.5)
            crystal.scale = (pulse * 0.5, pulse * 0.5, pulse * 1.0)
            crystal.keyframe_insert(data_path="scale", frame=frame)
    
    print(f"✅ Animated {len(crystals)} crystals for {frame_count} frames")

def setup_audio():
    """Setup audio for video"""
    
    print("🎵 Setting up audio...")
    
    if not os.path.exists(AUDIO_FILE):
        print(f"❌ Audio file not found: {AUDIO_FILE}")
        return False
    
    # Video Sequence Editor
    if not bpy.context.scene.sequence_editor:
        bpy.context.scene.sequence_editor_create()
    
    seq_editor = bpy.context.scene.sequence_editor
    
    # Clear existing
    for strip in list(seq_editor.sequences):
        seq_editor.sequences.remove(strip)
    
    # Add audio
    try:
        audio_strip = seq_editor.sequences.new_sound(
            name="TikTokAudio",
            filepath=AUDIO_FILE,
            channel=1,
            frame_start=1
        )
        print(f"✅ Audio loaded: {os.path.basename(AUDIO_FILE)}")
        return True
    except Exception as e:
        print(f"❌ Audio error: {e}")
        return False

def setup_render():
    """Setup TikTok render settings"""
    
    print("🎬 Configuring TikTok render...")
    
    scene = bpy.context.scene
    
    # TikTok dimensions (9:16 aspect ratio)
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    
    # Render settings
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 128  # Balanced quality/speed
    scene.cycles.use_denoising = True
    
    # Animation settings
    scene.frame_start = 1
    scene.frame_end = 360  # 15 seconds at 24fps
    scene.frame_set(1)
    
    # Output settings
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.audio_codec = 'AAC'
    
    # Ensure output directory
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    output_file = os.path.join(OUTPUT_PATH, "tiktok_crystalline_final")
    scene.render.filepath = output_file
    
    print(f"✅ Render configured: 1080x1920, 360 frames")
    print(f"📁 Output: {output_file}")
    
    return output_file

def main():
    """Create and render TikTok crystalline visualizer"""
    
    print("🎨 TIKTOK CRYSTALLINE VISUALIZER")
    print("=" * 50)
    
    # Clear scene
    clear_scene()
    
    # Create scene elements
    crystals = create_tiktok_scene()
    create_crystal_materials(crystals)
    camera = setup_camera()
    setup_lighting()
    
    # Setup animation and audio
    animate_crystals(crystals)
    audio_loaded = setup_audio()
    
    # Configure render
    output_file = setup_render()
    
    # Verify camera is set
    if not bpy.context.scene.camera:
        print("❌ No camera set!")
        return
    
    print(f"✅ Scene ready with {len(crystals)} animated crystals")
    print(f"📹 Camera: {bpy.context.scene.camera.name}")
    print(f"🎵 Audio: {'✅' if audio_loaded else '❌'}")
    
    # RENDER
    print("\n🎬 STARTING RENDER...")
    print("⏱️  This will take 10-15 minutes...")
    
    try:
        bpy.ops.render.render(animation=True)
        print("\n✅ RENDER COMPLETE!")
        print(f"🎉 Your TikTok video is ready: {output_file}")
        
    except Exception as e:
        print(f"\n❌ Render failed: {e}")

if __name__ == "__main__":
    main()