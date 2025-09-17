#!/usr/bin/env python3
"""
Advanced Geometry Nodes Audio Waveform Visualizer
Based on Blender Conference 2024 techniques
"""

import bpy
import bmesh
import os
import mathutils
import random

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def setup_camera_and_lighting():
    """Setup optimal camera and lighting for visualizer"""
    # Add camera
    bpy.ops.object.camera_add(location=(7, -7, 5))
    camera = bpy.context.object
    camera.rotation_euler = (1.1, 0, 0.785)
    
    # Add HDRI lighting
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    world_nodes.clear()
    
    # Environment texture
    env_tex = world_nodes.new('ShaderNodeTexEnvironment')
    world_output = world_nodes.new('ShaderNodeOutputWorld')
    world.node_tree.links.new(env_tex.outputs['Color'], world_output.inputs['Surface'])
    
    # Set strength
    env_tex.inputs['Strength'].default_value = 1.5
    
    return camera

def create_waveform_geometry_nodes(audio_file_path):
    """Create advanced waveform visualizer using Geometry Nodes"""
    
    # Create plane for waveform base
    bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, 0))
    plane = bpy.context.object
    plane.name = "WaveformBase"
    
    # Add Geometry Nodes modifier
    geo_nodes = plane.modifiers.new(name="WaveformNodes", type='NODES')
    
    # Create new node tree
    node_tree = bpy.data.node_groups.new(name="WaveformGeometry", type='GeometryNodeTree')
    geo_nodes.node_group = node_tree
    
    # Add input and output nodes
    input_node = node_tree.nodes.new('NodeGroupInput')
    output_node = node_tree.nodes.new('NodeGroupOutput')
    
    input_node.location = (-400, 0)
    output_node.location = (400, 0)
    
    # Create waveform using various nodes
    subdivide = node_tree.nodes.new('GeometryNodeSubdivisionSurface')
    subdivide.location = (-200, 0)
    
    # Displacement node for audio reactivity
    displace = node_tree.nodes.new('GeometryNodeDisplaceOnDomain')
    displace.location = (0, 0)
    
    # Noise texture for variation
    noise = node_tree.nodes.new('ShaderNodeTexNoise')
    noise.location = (-200, -200)
    noise.inputs['Scale'].default_value = 5.0
    
    # Position node
    position = node_tree.nodes.new('GeometryNodeInputPosition')
    position.location = (-400, -200)
    
    # Links
    node_tree.links.new(input_node.outputs['Geometry'], subdivide.inputs['Mesh'])
    node_tree.links.new(subdivide.outputs['Mesh'], displace.inputs['Geometry'])
    node_tree.links.new(position.outputs['Position'], noise.inputs['Vector'])
    node_tree.links.new(noise.outputs['Fac'], displace.inputs['Offset'])
    node_tree.links.new(displace.outputs['Geometry'], output_node.inputs['Geometry'])
    
    return plane

def create_particle_audio_reactive(audio_file_path):
    """Create particle system that reacts to audio"""
    
    # Create icosphere for particles
    bpy.ops.mesh.primitive_ico_sphere_add(location=(0, 3, 0))
    sphere = bpy.context.object
    sphere.name = "ParticleEmitter"
    
    # Add particle system
    particle_sys = sphere.modifiers.new(name="AudioParticles", type='PARTICLE_SYSTEM')
    particles = particle_sys.particle_system
    
    # Configure particle settings
    particles.settings.count = 1000
    particles.settings.frame_start = 1
    particles.settings.frame_end = 250
    particles.settings.lifetime = 50
    particles.settings.emit_from = 'VOLUME'
    
    # Physics settings
    particles.settings.physics_type = 'NEWTON'
    particles.settings.normal_factor = 0.1
    particles.settings.factor_random = 0.5
    
    return sphere

def create_curve_waveform(audio_file_path):
    """Create curve-based waveform visualizer"""
    
    # Create bezier curve
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, -3, 0))
    curve = bpy.context.object
    curve.name = "WaveformCurve"
    
    # Convert to mesh for geometry nodes
    bpy.context.view_layer.objects.active = curve
    bpy.ops.object.convert(target='MESH')
    
    # Add subdivision
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=50)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Add material with emission
    mat = bpy.data.materials.new(name="WaveformMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Emission shader
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value = (0, 0.8, 1, 1)
    emission.inputs['Strength'].default_value = 2.0
    
    output = nodes.new('ShaderNodeOutputMaterial')
    mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])
    
    curve.data.materials.append(mat)
    
    return curve

def create_spectral_analyzer_cubes(audio_file_path):
    """Create frequency band analyzer with cubes"""
    
    cubes = []
    for i in range(16):  # 16 frequency bands
        x_pos = (i - 7.5) * 0.5
        bpy.ops.mesh.primitive_cube_add(location=(x_pos, 0, 0), scale=(0.2, 0.2, 1))
        cube = bpy.context.object
        cube.name = f"FreqBand_{i}"
        cubes.append(cube)
        
        # Add colorful material
        mat = bpy.data.materials.new(name=f"FreqMat_{i}")
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        
        # HSV color based on frequency band
        hue = i / 16.0
        bsdf = nodes.get("Principled BSDF")
        bsdf.inputs['Base Color'].default_value = mathutils.Color((hue, 1.0, 1.0)).rgb + (1.0,)
        bsdf.inputs['Emission Color'].default_value = mathutils.Color((hue, 1.0, 1.0)).rgb + (1.0,)
        bsdf.inputs['Emission Strength'].default_value = 0.5
        
        cube.data.materials.append(mat)
    
    return cubes

def setup_sound_strips(audio_file_path):
    """Setup sound strips in Video Sequence Editor for audio analysis"""
    
    # Switch to Video Sequencer
    if not bpy.context.scene.sequence_editor:
        bpy.context.scene.sequence_editor_create()
    
    seq_editor = bpy.context.scene.sequence_editor
    
    # Clear existing strips
    if seq_editor.sequences:
        for seq in seq_editor.sequences:
            seq_editor.sequences.remove(seq)
    
    # Add sound strip
    sound_strip = seq_editor.sequences.new_sound(
        name="AudioStrip",
        filepath=audio_file_path,
        channel=1,
        frame_start=1
    )
    
    return sound_strip

def animate_visualizer(objects, frame_count=250):
    """Add keyframe animation to visualizer objects"""
    
    for frame in range(1, frame_count + 1, 10):
        bpy.context.scene.frame_set(frame)
        
        for obj in objects:
            if obj.name.startswith("FreqBand_"):
                # Animate frequency band cubes
                scale_z = random.uniform(0.5, 3.0)
                obj.scale.z = scale_z
                obj.keyframe_insert(data_path="scale", frame=frame)
            
            elif obj.name == "ParticleEmitter":
                # Animate particle emission
                rotation = frame * 0.1
                obj.rotation_euler.z = rotation
                obj.keyframe_insert(data_path="rotation_euler", frame=frame)

def setup_render_settings():
    """Configure render settings for high quality output"""
    scene = bpy.context.scene
    
    # Render engine
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'GPU' if bpy.context.preferences.addons['cycles'].preferences.has_active_device() else 'CPU'
    
    # Resolution
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 250
    
    # Output format
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'

def main():
    """Main function to create complete audio visualizer"""
    
    # Audio file path (adjust as needed)
    audio_file = "/Users/magnusfremont/Desktop/VibeWriter/audio_remaster/output/remastered_final.m4a"
    
    # Clear scene
    clear_scene()
    
    # Setup camera and lighting
    camera = setup_camera_and_lighting()
    
    # Create different visualizer components
    waveform = create_waveform_geometry_nodes(audio_file)
    particles = create_particle_audio_reactive(audio_file)
    curve = create_curve_waveform(audio_file)
    cubes = create_spectral_analyzer_cubes(audio_file)
    
    # Setup sound
    sound_strip = setup_sound_strips(audio_file)
    
    # Animate objects
    all_objects = [waveform, particles, curve] + cubes
    animate_visualizer(all_objects)
    
    # Setup render settings
    setup_render_settings()
    
    print("Advanced audio visualizer created!")
    print(f"Using audio file: {audio_file}")
    print("Ready to render!")

if __name__ == "__main__":
    main()