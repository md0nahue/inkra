#!/usr/bin/env python3
"""
Quantum Interference Audio Visualizer
Creates quantum-inspired wave interference patterns, probability clouds, and dimensional rifts
"""

import bpy
import bmesh
import mathutils
import random
import math
from mathutils import Vector

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_quantum_wave_field():
    """Create wave interference field using geometry nodes"""
    
    # Create base plane for wave field
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    wave_field = bpy.context.object
    wave_field.name = "QuantumWaveField"
    
    # Add subdivision for wave detail
    bpy.context.view_layer.objects.active = wave_field
    bpy.ops.object.mode_set(mode='EDIT')
    
    # High subdivision for smooth waves
    for _ in range(6):  # 6 levels of subdivision
        bpy.ops.mesh.subdivide()
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Add Geometry Nodes modifier
    geo_modifier = wave_field.modifiers.new(name="QuantumWaves", type='NODES')
    
    # Create node tree
    node_tree = bpy.data.node_groups.new(name="QuantumWaveGeometry", type='GeometryNodeTree')
    geo_modifier.node_group = node_tree
    
    # Input and Output nodes
    input_node = node_tree.nodes.new('NodeGroupInput')
    output_node = node_tree.nodes.new('NodeGroupOutput')
    input_node.location = (-800, 0)
    output_node.location = (800, 0)
    
    # Position input
    position = node_tree.nodes.new('GeometryNodeInputPosition')
    position.location = (-600, 200)
    
    # Multiple wave textures for interference
    wave1 = node_tree.nodes.new('ShaderNodeTexWave')
    wave1.location = (-400, 300)
    wave1.inputs['Scale'].default_value = 5.0
    wave1.inputs['Distortion'].default_value = 2.0
    
    wave2 = node_tree.nodes.new('ShaderNodeTexWave')
    wave2.location = (-400, 100)
    wave2.inputs['Scale'].default_value = 3.0
    wave2.inputs['Distortion'].default_value = 1.5
    wave2.wave_type = 'RINGS'
    
    wave3 = node_tree.nodes.new('ShaderNodeTexWave')
    wave3.location = (-400, -100)
    wave3.inputs['Scale'].default_value = 7.0
    wave3.inputs['Distortion'].default_value = 3.0
    
    # Mix waves for interference pattern
    mix1 = node_tree.nodes.new('ShaderNodeMix')
    mix1.location = (-200, 200)
    mix1.data_type = 'RGBA'
    mix1.inputs['Fac'].default_value = 0.5
    
    mix2 = node_tree.nodes.new('ShaderNodeMix')
    mix2.location = (-200, 0)
    mix2.data_type = 'RGBA'
    mix2.inputs['Fac'].default_value = 0.3
    
    # Set Position node for displacement
    set_position = node_tree.nodes.new('GeometryNodeSetPosition')
    set_position.location = (600, 0)
    
    # Combine XYZ for displacement vector
    combine_xyz = node_tree.nodes.new('ShaderNodeCombineXYZ')
    combine_xyz.location = (400, 0)
    combine_xyz.inputs['X'].default_value = 0.0
    combine_xyz.inputs['Y'].default_value = 0.0
    
    # Color ramp for wave amplitude
    color_ramp = node_tree.nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (200, 0)
    
    # Links
    node_tree.links.new(position.outputs['Position'], wave1.inputs['Vector'])
    node_tree.links.new(position.outputs['Position'], wave2.inputs['Vector'])
    node_tree.links.new(position.outputs['Position'], wave3.inputs['Vector'])
    
    node_tree.links.new(wave1.outputs['Color'], mix1.inputs[1])
    node_tree.links.new(wave2.outputs['Color'], mix1.inputs[2])
    node_tree.links.new(mix1.outputs['Result'], mix2.inputs[1])
    node_tree.links.new(wave3.outputs['Color'], mix2.inputs[2])
    
    node_tree.links.new(mix2.outputs['Result'], color_ramp.inputs['Fac'])
    node_tree.links.new(color_ramp.outputs['Color'], combine_xyz.inputs['Z'])
    
    node_tree.links.new(input_node.outputs['Geometry'], set_position.inputs['Geometry'])
    node_tree.links.new(combine_xyz.outputs['Vector'], set_position.inputs['Offset'])
    node_tree.links.new(set_position.outputs['Geometry'], output_node.inputs['Geometry'])
    
    return wave_field

def create_probability_cloud():
    """Create quantum probability cloud using volume rendering"""
    
    # Create volume cube
    bpy.ops.mesh.primitive_cube_add(size=15, location=(0, 0, 3))
    prob_cloud = bpy.context.object
    prob_cloud.name = "ProbabilityCloud"
    
    # Create quantum probability material
    prob_mat = bpy.data.materials.new(name="ProbabilityMaterial")
    prob_mat.use_nodes = True
    nodes = prob_mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (1000, 0)
    
    # Principled Volume
    volume = nodes.new('ShaderNodeVolumePrincipled')
    volume.location = (800, 0)
    volume.inputs['Density'].default_value = 0.03
    volume.inputs['Emission Strength'].default_value = 0.8
    
    # Multiple noise textures for quantum uncertainty
    noise1 = nodes.new('ShaderNodeTexNoise')
    noise1.location = (0, 200)
    noise1.inputs['Scale'].default_value = 4.0
    noise1.inputs['Detail'].default_value = 15.0
    
    noise2 = nodes.new('ShaderNodeTexNoise')
    noise2.location = (0, 0)
    noise2.inputs['Scale'].default_value = 8.0
    noise2.inputs['Detail'].default_value = 8.0
    
    noise3 = nodes.new('ShaderNodeTexNoise')
    noise3.location = (0, -200)
    noise3.inputs['Scale'].default_value = 2.0
    noise3.inputs['Detail'].default_value = 20.0
    
    # Voronoi for cellular quantum states
    voronoi = nodes.new('ShaderNodeTexVoronoi')
    voronoi.location = (0, 400)
    voronoi.inputs['Scale'].default_value = 6.0
    voronoi.feature = 'F1'
    
    # Mix textures
    mix_noise = nodes.new('ShaderNodeMix')
    mix_noise.location = (200, 100)
    mix_noise.data_type = 'RGBA'
    mix_noise.inputs['Fac'].default_value = 0.4
    
    mix_voronoi = nodes.new('ShaderNodeMix')
    mix_voronoi.location = (400, 200)
    mix_voronoi.data_type = 'RGBA'
    mix_voronoi.inputs['Fac'].default_value = 0.3
    
    # Texture coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Color ramp for quantum states
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (600, 200)
    
    # Quantum color palette (purple, blue, cyan, green)
    color_ramp.color_ramp.elements.new(0.25)
    color_ramp.color_ramp.elements.new(0.75)
    
    color_ramp.color_ramp.elements[0].color = (0.3, 0.0, 0.8, 1.0)  # Deep purple
    color_ramp.color_ramp.elements[1].color = (0.0, 0.5, 1.0, 1.0)  # Blue
    color_ramp.color_ramp.elements[2].color = (0.0, 1.0, 1.0, 1.0)  # Cyan
    color_ramp.color_ramp.elements[3].color = (0.2, 1.0, 0.3, 1.0)  # Green
    
    # Math node for intensity variation
    multiply = nodes.new('ShaderNodeMath')
    multiply.location = (600, 0)
    multiply.operation = 'MULTIPLY'
    multiply.inputs[1].default_value = 3.0
    
    # Links
    prob_mat.node_tree.links.new(tex_coord.outputs['Generated'], noise1.inputs['Vector'])
    prob_mat.node_tree.links.new(tex_coord.outputs['Generated'], noise2.inputs['Vector'])
    prob_mat.node_tree.links.new(tex_coord.outputs['Generated'], noise3.inputs['Vector'])
    prob_mat.node_tree.links.new(tex_coord.outputs['Generated'], voronoi.inputs['Vector'])
    
    prob_mat.node_tree.links.new(noise1.outputs['Color'], mix_noise.inputs[1])
    prob_mat.node_tree.links.new(noise2.outputs['Color'], mix_noise.inputs[2])
    prob_mat.node_tree.links.new(mix_noise.outputs['Result'], mix_voronoi.inputs[1])
    prob_mat.node_tree.links.new(voronoi.outputs['Color'], mix_voronoi.inputs[2])
    
    prob_mat.node_tree.links.new(mix_voronoi.outputs['Result'], color_ramp.inputs['Fac'])
    prob_mat.node_tree.links.new(mix_voronoi.outputs['Result'], multiply.inputs[0])
    
    prob_mat.node_tree.links.new(color_ramp.outputs['Color'], volume.inputs['Color'])
    prob_mat.node_tree.links.new(multiply.outputs['Value'], volume.inputs['Density'])
    prob_mat.node_tree.links.new(volume.outputs['Volume'], output.inputs['Volume'])
    
    prob_cloud.data.materials.append(prob_mat)
    
    return prob_cloud

def create_dimensional_rifts():
    """Create dimensional rift portals"""
    
    rifts = []
    
    # Create 3 rifts at different positions
    rift_positions = [
        (4, 2, 1),
        (-3, -4, 2),
        (1, 5, 3)
    ]
    
    for i, pos in enumerate(rift_positions):
        # Create torus for rift ring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.5,
            minor_radius=0.1,
            location=pos
        )
        rift = bpy.context.object
        rift.name = f"DimensionalRift_{i}"
        
        # Random rotation
        rift.rotation_euler = (
            random.uniform(0, math.pi),
            random.uniform(0, math.pi),
            random.uniform(0, 2 * math.pi)
        )
        
        # Create rift material
        rift_mat = create_rift_material(i)
        rift.data.materials.append(rift_mat)
        
        # Create inner portal plane
        bpy.ops.mesh.primitive_circle_add(radius=1.4, location=pos)
        portal = bpy.context.object
        portal.name = f"Portal_{i}"
        
        # Match rotation
        portal.rotation_euler = rift.rotation_euler
        
        # Create portal material
        portal_mat = create_portal_material(i)
        portal.data.materials.append(portal_mat)
        
        rifts.extend([rift, portal])
    
    return rifts

def create_rift_material(rift_id):
    """Create material for dimensional rift rings"""
    
    mat = bpy.data.materials.new(name=f"RiftMaterial_{rift_id}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    # Emission shader
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (200, 0)
    emission.inputs['Strength'].default_value = 5.0
    
    # Color based on rift ID
    colors = [
        (1.0, 0.0, 0.5),  # Magenta
        (0.0, 1.0, 0.8),  # Cyan
        (0.8, 0.2, 1.0)   # Purple
    ]
    
    emission.inputs['Color'].default_value = colors[rift_id] + (1.0,)
    
    # Links
    mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])
    
    return mat

def create_portal_material(portal_id):
    """Create material for portal interiors"""
    
    mat = bpy.data.materials.new(name=f"PortalMaterial_{portal_id}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)
    
    # Mix shader for portal effect
    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (400, 0)
    
    # Emission for glow
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (200, 100)
    emission.inputs['Strength'].default_value = 2.0
    
    # Transparent for see-through effect
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    transparent.location = (200, -100)
    
    # Fresnel for mixing
    fresnel = nodes.new('ShaderNodeFresnel')
    fresnel.location = (200, 0)
    fresnel.inputs['IOR'].default_value = 1.8
    
    # Noise texture for portal distortion
    noise = nodes.new('ShaderNodeTexNoise')
    noise.location = (-200, 0)
    noise.inputs['Scale'].default_value = 15.0
    noise.inputs['Detail'].default_value = 10.0
    
    # Texture coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-400, 0)
    
    # Color ramp
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (0, 100)
    
    # Portal colors
    portal_colors = [
        [(0.8, 0.1, 0.4, 1.0), (1.0, 0.6, 0.8, 1.0)],  # Red-pink
        [(0.1, 0.8, 0.6, 1.0), (0.6, 1.0, 0.9, 1.0)],  # Cyan-green  
        [(0.6, 0.2, 0.9, 1.0), (0.9, 0.7, 1.0, 1.0)]   # Purple-lavender
    ]
    
    color_ramp.color_ramp.elements[0].color = portal_colors[portal_id][0]
    color_ramp.color_ramp.elements[1].color = portal_colors[portal_id][1]
    
    # Links
    mat.node_tree.links.new(tex_coord.outputs['Generated'], noise.inputs['Vector'])
    mat.node_tree.links.new(noise.outputs['Fac'], color_ramp.inputs['Fac'])
    mat.node_tree.links.new(color_ramp.outputs['Color'], emission.inputs['Color'])
    mat.node_tree.links.new(fresnel.outputs['Fac'], mix_shader.inputs['Fac'])
    mat.node_tree.links.new(emission.outputs['Emission'], mix_shader.inputs[1])
    mat.node_tree.links.new(transparent.outputs['BSDF'], mix_shader.inputs[2])
    mat.node_tree.links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])
    
    return mat

def create_quantum_particles():
    """Create quantum particle effects"""
    
    # Create particle emitter
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.05, location=(0, 0, 0))
    emitter = bpy.context.object
    emitter.name = "QuantumParticleEmitter"
    
    # Add particle system
    particle_mod = emitter.modifiers.new(name="QuantumParticles", type='PARTICLE_SYSTEM')
    particles = particle_mod.particle_system
    
    # Configure particles for quantum behavior
    particles.settings.count = 10000
    particles.settings.frame_start = 1
    particles.settings.frame_end = 300
    particles.settings.lifetime = 200
    particles.settings.random_lifetime = 0.9
    
    # Physics
    particles.settings.physics_type = 'NEWTON'
    particles.settings.particle_size = 0.005
    particles.settings.size_random = 0.8
    
    # Emission
    particles.settings.emit_from = 'VOLUME'
    particles.settings.distribution = 'RAND'
    particles.settings.normal_factor = 0.0
    particles.settings.factor_random = 5.0
    
    # Quantum uncertainty motion
    particles.settings.effector_weights.gravity = 0.0
    particles.settings.effector_weights.force = 0.3
    particles.settings.brownian_factor = 2.0  # Random motion
    
    return emitter

def create_wave_material():
    """Create material for quantum wave field"""
    
    mat = bpy.data.materials.new(name="QuantumWaveMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    
    # Get principled BSDF
    bsdf = nodes.get("Principled BSDF")
    
    # Base material setup
    bsdf.inputs['Base Color'].default_value = (0.1, 0.3, 0.9, 1.0)
    bsdf.inputs['Metallic'].default_value = 0.8
    bsdf.inputs['Roughness'].default_value = 0.2
    bsdf.inputs['Specular IOR Level'].default_value = 1.5
    
    # Add emission for glow
    bsdf.inputs['Emission Color'].default_value = (0.2, 0.6, 1.0, 1.0)
    bsdf.inputs['Emission Strength'].default_value = 0.5
    
    # Add wave texture for animation
    wave_tex = nodes.new('ShaderNodeTexWave')
    wave_tex.location = (-200, 0)
    wave_tex.inputs['Scale'].default_value = 10.0
    
    # Texture coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-400, 0)
    
    # Links
    mat.node_tree.links.new(tex_coord.outputs['Generated'], wave_tex.inputs['Vector'])
    mat.node_tree.links.new(wave_tex.outputs['Color'], bsdf.inputs['Emission Color'])
    
    return mat

def animate_quantum_system(wave_field, prob_cloud, rifts, particles, frame_count=300):
    """Animate the quantum interference system"""
    
    for frame in range(1, frame_count + 1, 5):
        bpy.context.scene.frame_set(frame)
        
        # Animate wave field geometry nodes
        if wave_field.modifiers.get("QuantumWaves"):
            geo_modifier = wave_field.modifiers["QuantumWaves"]
            node_tree = geo_modifier.node_group
            
            if node_tree:
                # Animate wave parameters
                for node in node_tree.nodes:
                    if node.type == 'TEX_WAVE':
                        if 'Scale' in node.inputs:
                            base_scale = 5.0 if node.inputs['Scale'].default_value == 5.0 else 3.0
                            wave_scale = base_scale + 2.0 * math.sin(frame * 0.1)
                            node.inputs['Scale'].default_value = wave_scale
                            node.inputs['Scale'].keyframe_insert("default_value", frame=frame)
        
        # Animate probability cloud
        if prob_cloud.data.materials:
            prob_mat = prob_cloud.data.materials[0]
            if prob_mat.use_nodes:
                for node in prob_mat.node_tree.nodes:
                    if node.type == 'TEX_NOISE':
                        # Animate noise for quantum uncertainty
                        noise_scale = node.inputs['Scale'].default_value
                        variation = 1.0 * math.sin(frame * 0.08 + noise_scale)
                        node.inputs['Scale'].default_value = noise_scale + variation
                        node.inputs['Scale'].keyframe_insert("default_value", frame=frame)
        
        # Animate dimensional rifts
        for i, rift in enumerate(rifts):
            if "Rift" in rift.name:
                # Rotation
                rift.rotation_euler.z = frame * 0.05 * (i + 1)
                rift.keyframe_insert(data_path="rotation_euler", frame=frame)
                
                # Pulsing scale
                pulse = 1.0 + 0.2 * math.sin(frame * 0.12 + i)
                rift.scale = (pulse, pulse, pulse)
                rift.keyframe_insert(data_path="scale", frame=frame)

def setup_quantum_lighting():
    """Setup lighting for quantum scene"""
    
    # Area light with quantum colors
    bpy.ops.object.light_add(type='AREA', location=(0, 0, 10))
    area_light = bpy.context.object
    area_light.data.energy = 5.0
    area_light.data.color = (0.7, 0.9, 1.0)
    area_light.data.size = 8.0
    
    # Point lights for accents
    accent_positions = [(5, 5, 5), (-5, -5, 5), (5, -5, 3)]
    accent_colors = [(1.0, 0.2, 0.8), (0.2, 1.0, 0.8), (0.8, 0.2, 1.0)]
    
    for i, (pos, color) in enumerate(zip(accent_positions, accent_colors)):
        bpy.ops.object.light_add(type='POINT', location=pos)
        light = bpy.context.object
        light.data.energy = 3.0
        light.data.color = color
        light.name = f"QuantumAccent_{i}"
    
    # World shader
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    
    bg_node = world_nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.01, 0.01, 0.03, 1.0)  # Deep space
        bg_node.inputs['Strength'].default_value = 0.05

def setup_camera():
    """Setup camera with smooth movement"""
    
    bpy.ops.object.camera_add(location=(8, -8, 6))
    camera = bpy.context.object
    
    # Create camera track
    bpy.ops.object.empty_add(location=(0, 0, 2))
    target = bpy.context.object
    target.name = "CameraTarget"
    
    # Track constraint
    constraint = camera.constraints.new(type='TRACK_TO')
    constraint.target = target
    constraint.track_axis = 'TRACK_NEGATIVE_Z'
    constraint.up_axis = 'UP_Y'
    
    # Animate camera orbit
    for frame in range(1, 301, 10):
        bpy.context.scene.frame_set(frame)
        
        angle = frame * 0.02
        radius = 8 + 2 * math.sin(frame * 0.01)
        height = 6 + math.sin(frame * 0.015) * 2
        
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)
        
        camera.location = (x, y, height)
        camera.keyframe_insert(data_path="location", frame=frame)
    
    return camera

def setup_render_settings():
    """Configure render settings"""
    scene = bpy.context.scene
    
    # Use Cycles for volumetrics
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1024
    scene.cycles.use_denoising = True
    
    # Enable motion blur
    scene.render.motion_blur_shutter = 0.8
    
    # Resolution
    scene.render.resolution_x = 2560
    scene.render.resolution_y = 1440
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 300

def main():
    """Create quantum interference audio visualizer"""
    
    print("Creating Quantum Interference Audio Visualizer...")
    
    # Clear scene
    clear_scene()
    
    # Create quantum components
    wave_field = create_quantum_wave_field()
    prob_cloud = create_probability_cloud()
    rifts = create_dimensional_rifts()
    particles = create_quantum_particles()
    
    # Apply materials
    wave_mat = create_wave_material()
    wave_field.data.materials.append(wave_mat)
    
    # Setup environment
    setup_quantum_lighting()
    camera = setup_camera()
    
    # Animate system
    animate_quantum_system(wave_field, prob_cloud, rifts, particles)
    
    # Configure rendering
    setup_render_settings()
    
    print("Quantum Interference Audio Visualizer created!")
    print("Components:")
    print(f"- Quantum wave interference field")
    print(f"- Probability cloud volume")
    print(f"- {len(rifts)} dimensional rifts")
    print(f"- 10,000 quantum particles")
    print("- Dynamic camera orbit")

if __name__ == "__main__":
    main()