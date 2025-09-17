#!/usr/bin/env python3
"""
TikTok-Style Crystalline Resonance Audio Visualizer
Creates vertical 1080x1920 videos with fractal crystals
"""

import bpy
import bmesh
import mathutils
import random
import math
import os
from mathutils import Vector

# Audio file path
AUDIO_FILE = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_final.m4a"
OUTPUT_PATH = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def setup_tiktok_render():
    """Configure render settings for TikTok format (9:16)"""
    scene = bpy.context.scene
    
    # TikTok dimensions - vertical
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    
    # Use Cycles for quality
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 256  # Optimized for speed
    scene.cycles.use_denoising = True
    
    # Frame settings for 15-second TikTok
    scene.frame_start = 1
    scene.frame_end = 360  # 15 seconds at 24fps
    
    # Output settings
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.audio_codec = 'AAC'
    
    # Ensure output directory exists
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    scene.render.filepath = os.path.join(OUTPUT_PATH, "tiktok_crystalline_")
    
    print(f"✅ Render configured for TikTok: 1080x1920, 360 frames")

def create_tiktok_crystals():
    """Create crystals optimized for vertical TikTok format"""
    crystals = []
    
    # Create main crystal cluster - positioned for vertical format
    for level in range(3):  # Fewer levels for TikTok performance
        crystal_count = 8 - level * 2
        
        for i in range(crystal_count):
            # Position for vertical frame
            golden_angle = 2.399963229728653
            radius = (level + 1) * 0.8  # Smaller radius for mobile viewing
            angle = i * golden_angle
            height = level * 0.8 - 1  # Center vertically
            
            x = radius * math.cos(angle)
            y = radius * math.sin(angle)
            z = height
            
            # Create crystal
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1,  # Lower subdivision for performance
                location=(x, y, z)
            )
            crystal = bpy.context.object
            crystal.name = f"TikTokCrystal_L{level}_{i}"
            
            # Scale for mobile viewing
            scale = 0.6 - level * 0.15
            crystal.scale = (scale, scale, scale * 2)  # Elongated for drama
            
            # Random rotation
            crystal.rotation_euler = (
                random.uniform(0, math.pi),
                random.uniform(0, math.pi),
                random.uniform(0, 2 * math.pi)
            )
            
            crystals.append(crystal)
    
    return crystals

def create_tiktok_crystal_material():
    """Create crystal material optimized for mobile viewing"""
    mat = bpy.data.materials.new(name="TikTokCrystalMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    # Principled BSDF for easier setup
    principled = nodes.new('ShaderNodeBsdfPrincipled')
    principled.location = (200, 0)
    
    # TikTok-friendly colors (vibrant for mobile)
    principled.inputs['Base Color'].default_value = (0.1, 0.8, 1.0, 1.0)  # Bright cyan
    principled.inputs['Metallic'].default_value = 0.9
    principled.inputs['Roughness'].default_value = 0.1
    principled.inputs['Transmission Weight'].default_value = 0.8
    principled.inputs['IOR'].default_value = 2.4
    
    # Strong emission for mobile visibility
    principled.inputs['Emission Color'].default_value = (0.5, 1.0, 1.0, 1.0)
    principled.inputs['Emission Strength'].default_value = 2.0
    
    # Links
    mat.node_tree.links.new(principled.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

def create_tiktok_background():
    """Create dramatic background for TikTok"""
    # Create background plane
    bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, -5))
    bg_plane = bpy.context.object
    bg_plane.name = "TikTokBackground"
    
    # Scale for vertical format
    bg_plane.scale = (2, 4, 1)  # Wider and taller for 9:16
    
    # Create gradient material
    bg_mat = bpy.data.materials.new(name="TikTokBackground")
    bg_mat.use_nodes = True
    nodes = bg_mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    # Emission for glow
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (200, 0)
    emission.inputs['Strength'].default_value = 0.5
    
    # Gradient texture
    gradient = nodes.new('ShaderNodeTexGradient')
    gradient.location = (0, 0)
    gradient.gradient_type = 'LINEAR'
    
    # Texture coordinate
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Color ramp for TikTok-style gradient
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (0, -200)
    color_ramp.color_ramp.elements[0].color = (0.1, 0.0, 0.3, 1.0)  # Deep purple
    color_ramp.color_ramp.elements[1].color = (0.0, 0.2, 0.8, 1.0)  # Deep blue
    
    # Links
    bg_mat.node_tree.links.new(tex_coord.outputs['Generated'], gradient.inputs['Vector'])
    bg_mat.node_tree.links.new(gradient.outputs['Fac'], color_ramp.inputs['Fac'])
    bg_mat.node_tree.links.new(color_ramp.outputs['Color'], emission.inputs['Color'])
    bg_mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])
    
    bg_plane.data.materials.append(bg_mat)
    
    return bg_plane

def setup_tiktok_camera():
    """Setup camera for TikTok vertical format"""
    bpy.ops.object.camera_add(location=(0, -6, 1))
    camera = bpy.context.object
    camera.name = "TikTokCamera"
    
    # Camera settings for vertical format
    camera.data.lens = 35  # Wide angle for more content
    camera.data.clip_start = 0.1
    camera.data.clip_end = 100
    
    # Point towards crystals
    camera.rotation_euler = (math.radians(90), 0, 0)
    
    # Animate camera for TikTok engagement
    for frame in range(1, 361, 10):
        bpy.context.scene.frame_set(frame)
        
        # Subtle camera movement
        angle = frame * 0.01
        radius = 6 + math.sin(frame * 0.02) * 0.5
        
        camera.location.x = radius * math.sin(angle) * 0.2
        camera.location.y = -radius + math.cos(frame * 0.015) * 0.3
        camera.location.z = 1 + math.sin(frame * 0.025) * 0.2
        
        camera.keyframe_insert(data_path="location", frame=frame)
    
    return camera

def setup_tiktok_lighting():
    """Setup dramatic lighting for TikTok"""
    # Key light (strong, colorful)
    bpy.ops.object.light_add(type='SPOT', location=(3, -3, 5))
    key_light = bpy.context.object
    key_light.data.energy = 100.0
    key_light.data.color = (1.0, 0.8, 1.0)  # Pink-white
    key_light.data.spot_size = math.radians(60)
    
    # Fill light (contrasting color)
    bpy.ops.object.light_add(type='AREA', location=(-2, -4, 3))
    fill_light = bpy.context.object
    fill_light.data.energy = 20.0
    fill_light.data.color = (0.2, 1.0, 1.0)  # Cyan
    fill_light.data.size = 3.0
    
    # Rim light for crystal edges
    bpy.ops.object.light_add(type='SUN', location=(0, 5, 2))
    rim_light = bpy.context.object
    rim_light.data.energy = 5.0
    rim_light.data.color = (0.8, 0.4, 1.0)  # Purple
    
    print("✅ TikTok lighting setup complete")

def animate_tiktok_crystals(crystals):
    """Animate crystals for TikTok engagement"""
    
    for frame in range(1, 361, 5):  # Every 5 frames for performance
        bpy.context.scene.frame_set(frame)
        
        for i, crystal in enumerate(crystals):
            # Fast rotation for visual impact
            rotation_speed = 0.1 + (i % 4) * 0.05
            crystal.rotation_euler.z = frame * rotation_speed
            crystal.rotation_euler.x = math.sin(frame * 0.05 + i) * 0.3
            crystal.keyframe_insert(data_path="rotation_euler", frame=frame)
            
            # Pulsing scale synchronized to "beat"
            beat_freq = 0.15  # Simulate beat frequency
            pulse = 1.0 + 0.4 * math.sin(frame * beat_freq + i * 0.3)
            crystal.scale = (pulse, pulse, pulse * 1.5)  # Emphasize vertical
            crystal.keyframe_insert(data_path="scale", frame=frame)
            
            # Vertical floating motion (TikTok style)
            base_z = crystal.location.z
            float_motion = 0.3 * math.sin(frame * 0.08 + i)
            crystal.location.z = base_z + float_motion
            crystal.keyframe_insert(data_path="location", frame=frame)

def setup_audio_in_blender():
    """Setup audio strip in Blender for rendering"""
    
    if not os.path.exists(AUDIO_FILE):
        print(f"❌ Audio file not found: {AUDIO_FILE}")
        return None
    
    # Ensure we have a sequence editor
    if not bpy.context.scene.sequence_editor:
        bpy.context.scene.sequence_editor_create()
    
    seq_editor = bpy.context.scene.sequence_editor
    
    # Clear existing strips
    for strip in seq_editor.sequences:
        seq_editor.sequences.remove(strip)
    
    # Add audio strip
    try:
        audio_strip = seq_editor.sequences.new_sound(
            name="TikTokAudio",
            filepath=AUDIO_FILE,
            channel=1,
            frame_start=1
        )
        print(f"✅ Audio loaded: {os.path.basename(AUDIO_FILE)}")
        return audio_strip
        
    except Exception as e:
        print(f"❌ Error loading audio: {e}")
        return None

def main():
    """Create TikTok-style crystalline visualizer"""
    
    print("🎨 Creating TikTok Crystalline Visualizer...")
    print("=" * 50)
    
    # Clear and setup
    clear_scene()
    setup_tiktok_render()
    
    # Create scene elements
    crystals = create_tiktok_crystals()
    background = create_tiktok_background()
    
    # Apply materials
    crystal_mat = create_tiktok_crystal_material()
    for crystal in crystals:
        crystal.data.materials.append(crystal_mat)
    
    # Setup environment
    camera = setup_tiktok_camera()
    setup_tiktok_lighting()
    
    # Setup audio
    audio_strip = setup_audio_in_blender()
    
    # Animate for TikTok
    animate_tiktok_crystals(crystals)
    
    print(f"✅ TikTok Crystalline Visualizer created!")
    print(f"📱 Format: 1080x1920 (9:16 aspect ratio)")
    print(f"🎵 Audio: {os.path.basename(AUDIO_FILE)}")
    print(f"🎬 Duration: 15 seconds (360 frames)")
    print(f"💎 Crystals: {len(crystals)} fractal formations")
    print()
    print("🚀 Ready to render!")
    print("Render will be saved to:", OUTPUT_PATH)

if __name__ == "__main__":
    main()