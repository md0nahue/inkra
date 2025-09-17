#!/usr/bin/env python3
"""
TikTok Fluid Audio Visualizer
Creates flowing, organic shapes for vertical video
"""

import bpy
import mathutils
import random
import math
import os
from mathutils import Vector

# Audio file
AUDIO_FILE = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_storytelling.m4a"
OUTPUT_PATH = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_fluid_waves():
    """Create flowing wave objects for TikTok"""
    
    print("🌊 Creating fluid waves...")
    
    waves = []
    
    # Create multiple wave planes at different heights
    for i in range(5):
        z_pos = i * 0.8 - 2  # Stack vertically
        
        # Create plane
        bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, z_pos))
        wave = bpy.context.object
        wave.name = f"FluidWave_{i}"
        
        # Add subdivision for smooth waves
        bpy.context.view_layer.objects.active = wave
        bpy.ops.object.mode_set(mode='EDIT')
        for _ in range(3):
            bpy.ops.mesh.subdivide()
        bpy.ops.object.mode_set(mode='OBJECT')
        
        # Add wave modifier
        wave_mod = wave.modifiers.new(name=f"Wave_{i}", type='WAVE')
        wave_mod.use_x = True
        wave_mod.use_y = True
        wave_mod.height = 0.3 + i * 0.1
        wave_mod.width = 1.2 - i * 0.1
        wave_mod.speed = 1.0 + i * 0.2
        wave_mod.offset = -math.pi * i / 2
        
        waves.append(wave)
    
    return waves

def create_fluid_materials(waves):
    """Create flowing, iridescent materials"""
    
    print("🎨 Creating fluid materials...")
    
    for i, wave in enumerate(waves):
        # Create unique material for each wave
        mat = bpy.data.materials.new(name=f"FluidMat_{i}")
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.clear()
        
        # Output
        output = nodes.new('ShaderNodeOutputMaterial')
        output.location = (400, 0)
        
        # Principled BSDF
        principled = nodes.new('ShaderNodeBsdfPrincipled')
        principled.location = (200, 0)
        
        # Colors that flow through spectrum
        hue = i / 5.0  # Different hue for each wave
        color = mathutils.Color()
        color.hsv = (hue, 0.8, 1.0)
        
        principled.inputs['Base Color'].default_value = (*color, 1.0)
        principled.inputs['Metallic'].default_value = 0.7
        principled.inputs['Roughness'].default_value = 0.2
        principled.inputs['Transmission Weight'].default_value = 0.5
        
        # Emission for glow
        principled.inputs['Emission Color'].default_value = (*color, 1.0)
        principled.inputs['Emission Strength'].default_value = 1.0 + i * 0.3
        
        # Apply material
        wave.data.materials.append(mat)
    
    print(f"✅ Created {len(waves)} fluid materials")

def create_particle_streams():
    """Create particle streams flowing upward"""
    
    print("✨ Creating particle streams...")
    
    # Create emitter
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -3))
    emitter = bpy.context.object
    emitter.name = "ParticleEmitter"
    
    # Particle system
    particle_mod = emitter.modifiers.new(name="FluidParticles", type='PARTICLE_SYSTEM')
    particles = particle_mod.particle_system
    
    # Configure for TikTok viewing
    particles.settings.count = 1500  # Optimized count
    particles.settings.frame_start = 1
    particles.settings.frame_end = 360
    particles.settings.lifetime = 180
    
    # Physics
    particles.settings.physics_type = 'NEWTON'
    particles.settings.particle_size = 0.03
    particles.settings.size_random = 0.7
    
    # Upward flow motion
    particles.settings.normal_factor = 2.0  # Strong upward velocity
    particles.settings.factor_random = 1.0
    particles.settings.effector_weights.gravity = -0.3  # Light upward force
    
    # Emission settings
    particles.settings.emit_from = 'FACE'
    particles.settings.distribution = 'RAND'
    
    return emitter

def setup_tiktok_camera():
    """Setup camera for vertical TikTok format"""
    
    print("📱 Setting up TikTok camera...")
    
    # Create camera
    bpy.ops.object.camera_add(location=(0, -7, 0))
    camera = bpy.context.object
    camera.name = "TikTokFluidCamera"
    
    # Point at waves
    camera.rotation_euler = (math.radians(90), 0, 0)
    
    # Set as active
    bpy.context.scene.camera = camera
    
    print(f"✅ Camera set: {camera.name}")
    return camera

def setup_fluid_lighting():
    """Setup colorful lighting for fluid scene"""
    
    print("💡 Setting up fluid lighting...")
    
    # Main light (animated color)
    bpy.ops.object.light_add(type='AREA', location=(3, -5, 4))
    main_light = bpy.context.object
    main_light.data.energy = 30.0
    main_light.data.color = (0.8, 1.0, 1.0)  # Cyan
    main_light.data.size = 6.0
    
    # Side light (warm)
    bpy.ops.object.light_add(type='SPOT', location=(-4, -4, 2))
    side_light = bpy.context.object
    side_light.data.energy = 20.0
    side_light.data.color = (1.0, 0.6, 0.8)  # Pink
    side_light.data.spot_size = math.radians(60)
    
    # Rim light
    bpy.ops.object.light_add(type='SUN', location=(0, 8, 3))
    rim_light = bpy.context.object
    rim_light.data.energy = 3.0
    rim_light.data.color = (0.9, 0.9, 1.0)
    
    # Gradient background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.1, 0.05, 0.2, 1.0)  # Deep purple
        bg_node.inputs['Strength'].default_value = 0.4
    
    print("✅ Fluid lighting complete")

def animate_fluid_system(waves, emitter):
    """Animate the fluid system for TikTok"""
    
    print("🎬 Animating fluid system...")
    
    for frame in range(1, 361, 8):  # Every 8 frames for performance
        bpy.context.scene.frame_set(frame)
        
        # Animate waves
        for i, wave in enumerate(waves):
            # Wave motion
            if wave.modifiers.get(f"Wave_{i}"):
                wave_mod = wave.modifiers[f"Wave_{i}"]
                wave_mod.offset = -math.pi * i / 2 + frame * 0.05
                wave_mod.keyframe_insert(data_path="offset", frame=frame)
            
            # Vertical floating
            base_z = (i * 0.8 - 2)
            float_offset = 0.2 * math.sin(frame * 0.03 + i)
            wave.location.z = base_z + float_offset
            wave.keyframe_insert(data_path="location", frame=frame)
            
            # Scale pulsing (audio simulation)
            pulse = 1.0 + 0.15 * math.sin(frame * 0.12 + i * 0.7)
            wave.scale = (pulse, pulse, 1.0)
            wave.keyframe_insert(data_path="scale", frame=frame)
    
    print("✅ Fluid animation complete")

def setup_audio():
    """Setup audio track"""
    
    print("🎵 Setting up audio...")
    
    if not os.path.exists(AUDIO_FILE):
        print(f"❌ Audio not found: {AUDIO_FILE}")
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
            name="FluidAudio",
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
    
    print("🎬 Setting up TikTok render...")
    
    scene = bpy.context.scene
    
    # TikTok format
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    
    # Render engine
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 96  # Lower samples for fluid motion
    scene.cycles.use_denoising = True
    
    # Animation
    scene.frame_start = 1
    scene.frame_end = 360
    scene.frame_set(1)
    
    # Output
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.audio_codec = 'AAC'
    
    # File path
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    output_file = os.path.join(OUTPUT_PATH, "tiktok_fluid_final")
    scene.render.filepath = output_file
    
    print(f"✅ Render setup: 1080x1920, 360 frames")
    print(f"📁 Output: {output_file}")
    
    return output_file

def main():
    """Create and render TikTok fluid visualizer"""
    
    print("🌊 TIKTOK FLUID VISUALIZER")
    print("=" * 50)
    
    # Clear scene
    clear_scene()
    
    # Create elements
    waves = create_fluid_waves()
    create_fluid_materials(waves)
    emitter = create_particle_streams()
    
    # Setup environment
    camera = setup_tiktok_camera()
    setup_fluid_lighting()
    
    # Animation and audio
    animate_fluid_system(waves, emitter)
    audio_loaded = setup_audio()
    
    # Render setup
    output_file = setup_render()
    
    # Verify setup
    if not bpy.context.scene.camera:
        print("❌ No camera!")
        return
    
    print(f"✅ Scene ready:")
    print(f"🌊 Waves: {len(waves)}")
    print(f"✨ Particles: 1500")
    print(f"📹 Camera: {bpy.context.scene.camera.name}")
    print(f"🎵 Audio: {'✅' if audio_loaded else '❌'}")
    
    # RENDER
    print("\n🎬 STARTING FLUID RENDER...")
    print("⏱️  Rendering 15-second TikTok video...")
    
    try:
        bpy.ops.render.render(animation=True)
        print("\n✅ FLUID RENDER COMPLETE!")
        print(f"🎉 TikTok fluid video ready: {output_file}")
        
    except Exception as e:
        print(f"\n❌ Render failed: {e}")

if __name__ == "__main__":
    main()