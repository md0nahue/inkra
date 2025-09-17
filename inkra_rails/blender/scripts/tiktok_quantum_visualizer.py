#!/usr/bin/env python3
"""
TikTok-Style Quantum Interference Audio Visualizer
Creates vertical 1080x1920 videos with quantum wave patterns
"""

import bpy
import bmesh
import mathutils
import random
import math
import os
from mathutils import Vector

# Audio file path
AUDIO_FILE = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_balanced.m4a"
OUTPUT_PATH = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/output/"

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def setup_tiktok_render():
    """Configure render settings for TikTok format"""
    scene = bpy.context.scene
    
    # TikTok dimensions
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    
    # Cycles for volumetrics
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 128  # Lower for speed
    scene.cycles.use_denoising = True
    
    # 15-second TikTok
    scene.frame_start = 1
    scene.frame_end = 360
    
    # Output
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.audio_codec = 'AAC'
    
    os.makedirs(OUTPUT_PATH, exist_ok=True)
    scene.render.filepath = os.path.join(OUTPUT_PATH, "tiktok_quantum_")

def create_quantum_wave_plane():
    """Create animated wave plane for TikTok"""
    
    # Create plane with high subdivision for waves
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
    wave_plane = bpy.context.object
    wave_plane.name = "QuantumWaves"
    
    # Scale for vertical format
    wave_plane.scale = (1, 2, 1)  # Stretch vertically
    
    # Add subdivision
    bpy.context.view_layer.objects.active = wave_plane
    bpy.ops.object.mode_set(mode='EDIT')
    for _ in range(4):  # 4 levels of subdivision
        bpy.ops.mesh.subdivide()
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Add displacement modifier for waves
    displace_mod = wave_plane.modifiers.new(name="QuantumWaves", type='DISPLACE')
    
    # Create wave texture
    wave_texture = bpy.data.textures.new(name="QuantumWaveTexture", type='DISTORTED_NOISE')
    wave_texture.noise_distortion = 'VORONOI_CRACKLE'
    wave_texture.distortion = 2.0
    wave_texture.noise_scale = 3.0
    
    displace_mod.texture = wave_texture
    displace_mod.strength = 0.8
    displace_mod.mid_level = 0.5
    
    return wave_plane

def create_quantum_material():
    """Create quantum-inspired material"""
    
    mat = bpy.data.materials.new(name="QuantumMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)
    
    # Principled BSDF
    principled = nodes.new('ShaderNodeBsdfPrincipled')
    principled.location = (400, 0)
    
    # Quantum colors (iridescent)
    principled.inputs['Base Color'].default_value = (0.2, 0.8, 1.0, 1.0)
    principled.inputs['Metallic'].default_value = 0.8
    principled.inputs['Roughness'].default_value = 0.1
    principled.inputs['Emission Color'].default_value = (0.5, 1.0, 1.0, 1.0)
    principled.inputs['Emission Strength'].default_value = 1.5
    
    # Wave texture for animation
    wave_tex = nodes.new('ShaderNodeTexWave')
    wave_tex.location = (0, 0)
    wave_tex.inputs['Scale'].default_value = 5.0
    wave_tex.inputs['Distortion'].default_value = 2.0
    
    # Noise for complexity
    noise_tex = nodes.new('ShaderNodeTexNoise')
    noise_tex.location = (0, -200)
    noise_tex.inputs['Scale'].default_value = 8.0
    
    # Mix for interference
    mix_node = nodes.new('ShaderNodeMix')
    mix_node.location = (200, 0)
    mix_node.data_type = 'RGBA'
    
    # Texture coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Links
    mat.node_tree.links.new(tex_coord.outputs['Generated'], wave_tex.inputs['Vector'])
    mat.node_tree.links.new(tex_coord.outputs['Generated'], noise_tex.inputs['Vector'])
    mat.node_tree.links.new(wave_tex.outputs['Color'], mix_node.inputs[1])
    mat.node_tree.links.new(noise_tex.outputs['Color'], mix_node.inputs[2])
    mat.node_tree.links.new(mix_node.outputs['Result'], principled.inputs['Base Color'])
    mat.node_tree.links.new(principled.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

def create_quantum_particles():
    """Create quantum particles for TikTok"""
    
    # Particle emitter
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.1, location=(0, 0, 2))
    emitter = bpy.context.object
    emitter.name = "QuantumParticleEmitter"
    
    # Particle system
    particle_mod = emitter.modifiers.new(name="QuantumParticles", type='PARTICLE_SYSTEM')
    particles = particle_mod.particle_system
    
    # Optimize for TikTok
    particles.settings.count = 2000  # Reduced for mobile
    particles.settings.frame_start = 1
    particles.settings.frame_end = 360
    particles.settings.lifetime = 120
    
    # Physics for quantum behavior
    particles.settings.physics_type = 'NEWTON'
    particles.settings.particle_size = 0.02
    particles.settings.size_random = 0.8
    
    # Emission
    particles.settings.emit_from = 'VOLUME'
    particles.settings.normal_factor = 0.0
    particles.settings.factor_random = 8.0
    
    # No gravity - quantum floating
    particles.settings.effector_weights.gravity = 0.0
    particles.settings.brownian_factor = 3.0  # Random quantum motion
    
    return emitter

def create_dimensional_rifts_tiktok():
    """Create dimensional rifts optimized for TikTok viewing"""
    
    rifts = []
    
    # Create 2 rifts positioned for vertical format
    positions = [(0, 1, 2), (0, -1, -1)]
    colors = [(1.0, 0.2, 0.8), (0.2, 1.0, 0.8)]  # Pink and cyan
    
    for i, (pos, color) in enumerate(zip(positions, colors)):
        # Create torus ring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=2.0,
            minor_radius=0.2,
            location=pos
        )
        rift = bpy.context.object
        rift.name = f"TikTokRift_{i}"
        
        # Create rift material
        rift_mat = bpy.data.materials.new(name=f"RiftMat_{i}")
        rift_mat.use_nodes = True
        nodes = rift_mat.node_tree.nodes
        
        # Simple emission for TikTok
        emission = nodes.get("Principled BSDF")
        emission.inputs['Emission Color'].default_value = color + (1.0,)
        emission.inputs['Emission Strength'].default_value = 5.0
        
        rift.data.materials.append(rift_mat)
        rifts.append(rift)
    
    return rifts

def setup_tiktok_camera():
    """Setup camera for TikTok vertical format"""
    
    bpy.ops.object.camera_add(location=(0, -8, 1))
    camera = bpy.context.object
    
    # Camera settings
    camera.data.lens = 28  # Wide for more content
    camera.rotation_euler = (math.radians(85), 0, 0)  # Slight tilt
    
    # Animate camera for engagement
    for frame in range(1, 361, 15):
        bpy.context.scene.frame_set(frame)
        
        # Smooth camera movement
        angle = frame * 0.005
        camera.location.x = 2 * math.sin(angle)
        camera.location.y = -8 + math.cos(angle) * 0.5
        camera.location.z = 1 + math.sin(frame * 0.01) * 0.3
        
        camera.keyframe_insert(data_path="location", frame=frame)
    
    return camera

def setup_tiktok_lighting():
    """Setup dramatic lighting for TikTok quantum scene"""
    
    # Key light (colorful)
    bpy.ops.object.light_add(type='AREA', location=(2, -5, 4))
    key_light = bpy.context.object
    key_light.data.energy = 50.0
    key_light.data.color = (0.8, 0.9, 1.0)
    key_light.data.size = 4.0
    
    # Fill light (contrasting)
    bpy.ops.object.light_add(type='SPOT', location=(-3, -6, 3))
    fill_light = bpy.context.object
    fill_light.data.energy = 30.0
    fill_light.data.color = (1.0, 0.5, 0.8)
    fill_light.data.spot_size = math.radians(45)
    
    # World background
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    
    bg_node = world_nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.05, 0.05, 0.15, 1.0)
        bg_node.inputs['Strength'].default_value = 0.3

def animate_quantum_system(wave_plane, particles, rifts):
    """Animate quantum elements for TikTok"""
    
    for frame in range(1, 361, 10):
        bpy.context.scene.frame_set(frame)
        
        # Animate wave displacement
        if wave_plane.modifiers.get("QuantumWaves"):
            # Animate texture offset (simulating wave motion)
            wave_plane.location.z = 0.2 * math.sin(frame * 0.1)
            wave_plane.keyframe_insert(data_path="location", frame=frame)
        
        # Animate rifts
        for i, rift in enumerate(rifts):
            if "Rift" in rift.name:
                # Rotation
                rift.rotation_euler.z = frame * 0.08 * (i + 1)
                rift.keyframe_insert(data_path="rotation_euler", frame=frame)
                
                # Scale pulsing
                pulse = 1.0 + 0.3 * math.sin(frame * 0.15 + i * math.pi)
                rift.scale = (pulse, pulse, pulse)
                rift.keyframe_insert(data_path="scale", frame=frame)

def setup_audio():
    """Setup audio for TikTok video"""
    
    if not os.path.exists(AUDIO_FILE):
        print(f"❌ Audio file not found: {AUDIO_FILE}")
        return None
    
    if not bpy.context.scene.sequence_editor:
        bpy.context.scene.sequence_editor_create()
    
    seq_editor = bpy.context.scene.sequence_editor
    
    # Clear existing
    for strip in seq_editor.sequences:
        seq_editor.sequences.remove(strip)
    
    # Add audio
    try:
        audio_strip = seq_editor.sequences.new_sound(
            name="TikTokQuantumAudio",
            filepath=AUDIO_FILE,
            channel=1,
            frame_start=1
        )
        print(f"✅ Audio loaded: {os.path.basename(AUDIO_FILE)}")
        return audio_strip
    except Exception as e:
        print(f"❌ Audio error: {e}")
        return None

def main():
    """Create TikTok quantum visualizer"""
    
    print("⚛️  Creating TikTok Quantum Visualizer...")
    print("=" * 50)
    
    # Setup
    clear_scene()
    setup_tiktok_render()
    
    # Create elements
    wave_plane = create_quantum_wave_plane()
    particles = create_quantum_particles()
    rifts = create_dimensional_rifts_tiktok()
    
    # Materials
    quantum_mat = create_quantum_material()
    wave_plane.data.materials.append(quantum_mat)
    
    # Environment
    camera = setup_tiktok_camera()
    setup_tiktok_lighting()
    
    # Audio
    audio_strip = setup_audio()
    
    # Animate
    animate_quantum_system(wave_plane, particles, rifts)
    
    print("✅ TikTok Quantum Visualizer created!")
    print("📱 Format: 1080x1920 (9:16)")
    print(f"🎵 Audio: {os.path.basename(AUDIO_FILE)}")
    print("⚛️  Features: Quantum waves, particles, dimensional rifts")
    print()
    
    # Auto-render
    print("🎬 Starting render...")
    bpy.ops.render.render(animation=True)
    print("✅ Quantum TikTok video complete!")

if __name__ == "__main__":
    main()