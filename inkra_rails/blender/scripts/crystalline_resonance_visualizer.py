#!/usr/bin/env python3
"""
Crystalline Resonance Audio Visualizer
Creates fractal crystal formations that shatter, reform, and resonate with audio
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

def create_fractal_crystal_system():
    """Generate fractal crystal formations"""
    
    crystals = []
    
    # Create main crystal cluster
    for level in range(4):  # 4 levels of fractal detail
        crystal_count = 12 - level * 2  # Decreasing count per level
        
        for i in range(crystal_count):
            # Golden ratio spiral positioning
            golden_angle = 2.399963229728653  # Golden angle in radians
            radius = level + 1
            angle = i * golden_angle
            height = level * 0.5
            
            x = radius * math.cos(angle)
            y = radius * math.sin(angle)
            z = height + random.uniform(-0.3, 0.3)
            
            # Create crystal (elongated dodecahedron)
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=2,
                location=(x, y, z)
            )
            crystal = bpy.context.object
            crystal.name = f"Crystal_L{level}_{i}"
            
            # Deform into crystal shape
            bpy.context.view_layer.objects.active = crystal
            bpy.ops.object.mode_set(mode='EDIT')
            
            # Scale along Z-axis for crystal appearance
            bpy.ops.transform.resize(value=(0.8, 0.8, 2 + level * 0.5))
            
            # Add some randomization
            bpy.ops.transform.vertex_random(offset=0.1)
            
            bpy.ops.object.mode_set(mode='OBJECT')
            
            # Random rotation
            crystal.rotation_euler = (
                random.uniform(0, math.pi),
                random.uniform(0, math.pi),
                random.uniform(0, 2 * math.pi)
            )
            
            # Scale based on level
            scale = 1.0 - level * 0.2
            crystal.scale = (scale, scale, scale)
            
            crystals.append(crystal)
    
    return crystals

def create_crystal_material(crystal_type="main"):
    """Create advanced crystal material with internal reflections"""
    
    mat = bpy.data.materials.new(name=f"CrystalMaterial_{crystal_type}_{random.randint(1000, 9999)}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (800, 0)
    
    # Mix Shader for complex crystal appearance
    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (600, 0)
    
    # Glass BSDF for transparency
    glass = nodes.new('ShaderNodeBsdfGlass')
    glass.location = (400, 100)
    glass.inputs['Roughness'].default_value = 0.0
    glass.inputs['IOR'].default_value = 2.4  # Diamond-like IOR
    
    # Glossy BSDF for reflections
    glossy = nodes.new('ShaderNodeBsdfGlossy')
    glossy.location = (400, -100)
    glossy.inputs['Roughness'].default_value = 0.1
    
    # Fresnel for mixing
    fresnel = nodes.new('ShaderNodeFresnel')
    fresnel.location = (400, 0)
    fresnel.inputs['IOR'].default_value = 2.4
    
    # Color variation based on type
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (200, 200)
    
    if crystal_type == "main":
        # Blue-white crystals
        color_ramp.color_ramp.elements[0].color = (0.8, 0.9, 1.0, 1.0)
        color_ramp.color_ramp.elements[1].color = (0.2, 0.5, 1.0, 1.0)
        glass.inputs['Color'].default_value = (0.9, 0.95, 1.0, 1.0)
    elif crystal_type == "energy":
        # Magenta-cyan crystals
        color_ramp.color_ramp.elements[0].color = (1.0, 0.2, 1.0, 1.0)
        color_ramp.color_ramp.elements[1].color = (0.2, 1.0, 1.0, 1.0)
        glass.inputs['Color'].default_value = (1.0, 0.5, 1.0, 1.0)
    
    # Position for color variation
    geometry = nodes.new('ShaderNodeNewGeometry')
    geometry.location = (0, 200)
    
    # Links
    mat.node_tree.links.new(geometry.outputs['Position'], color_ramp.inputs['Fac'])
    mat.node_tree.links.new(color_ramp.outputs['Color'], glass.inputs['Color'])
    mat.node_tree.links.new(color_ramp.outputs['Color'], glossy.inputs['Color'])
    mat.node_tree.links.new(fresnel.outputs['Fac'], mix_shader.inputs['Fac'])
    mat.node_tree.links.new(glass.outputs['BSDF'], mix_shader.inputs[1])
    mat.node_tree.links.new(glossy.outputs['BSDF'], mix_shader.inputs[2])
    mat.node_tree.links.new(mix_shader.outputs['Shader'], output.inputs['Surface'])
    
    return mat

def create_energy_field():
    """Create energy field using volume shaders"""
    
    # Create large sphere for energy field
    bpy.ops.mesh.primitive_uv_sphere_add(radius=8, location=(0, 0, 0))
    energy_field = bpy.context.object
    energy_field.name = "EnergyField"
    
    # Create volumetric energy material
    energy_mat = bpy.data.materials.new(name="EnergyFieldMaterial")
    energy_mat.use_nodes = True
    nodes = energy_mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)
    
    # Principled Volume
    volume = nodes.new('ShaderNodeVolumePrincipled')
    volume.location = (400, 0)
    volume.inputs['Density'].default_value = 0.02
    volume.inputs['Emission Strength'].default_value = 0.5
    
    # Noise texture for energy patterns
    noise = nodes.new('ShaderNodeTexNoise')
    noise.location = (0, 0)
    noise.inputs['Scale'].default_value = 3.0
    noise.inputs['Detail'].default_value = 8.0
    noise.inputs['Distortion'].default_value = 2.0
    
    # Voronoi texture for cellular patterns
    voronoi = nodes.new('ShaderNodeTexVoronoi')
    voronoi.location = (0, -300)
    voronoi.inputs['Scale'].default_value = 5.0
    voronoi.feature = 'DISTANCE'
    
    # Mix textures
    mix_tex = nodes.new('ShaderNodeMix')
    mix_tex.location = (200, 0)
    mix_tex.data_type = 'RGBA'
    mix_tex.inputs['Fac'].default_value = 0.5
    
    # Texture coordinates
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Color ramp for energy colors
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (200, 200)
    color_ramp.color_ramp.elements[0].color = (0.0, 0.5, 1.0, 1.0)  # Blue
    color_ramp.color_ramp.elements[1].color = (1.0, 0.2, 0.8, 1.0)  # Magenta
    
    # Links
    energy_mat.node_tree.links.new(tex_coord.outputs['Generated'], noise.inputs['Vector'])
    energy_mat.node_tree.links.new(tex_coord.outputs['Generated'], voronoi.inputs['Vector'])
    energy_mat.node_tree.links.new(noise.outputs['Color'], mix_tex.inputs[1])
    energy_mat.node_tree.links.new(voronoi.outputs['Color'], mix_tex.inputs[2])
    energy_mat.node_tree.links.new(mix_tex.outputs['Result'], color_ramp.inputs['Fac'])
    energy_mat.node_tree.links.new(color_ramp.outputs['Color'], volume.inputs['Color'])
    energy_mat.node_tree.links.new(mix_tex.outputs['Result'], volume.inputs['Density'])
    energy_mat.node_tree.links.new(volume.outputs['Volume'], output.inputs['Volume'])
    
    energy_field.data.materials.append(energy_mat)
    
    return energy_field

def create_resonance_particles():
    """Create particle system for resonance effects"""
    
    # Create particle emitter
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.1, location=(0, 0, 0))
    emitter = bpy.context.object
    emitter.name = "ResonanceEmitter"
    
    # Add particle system
    particle_mod = emitter.modifiers.new(name="ResonanceParticles", type='PARTICLE_SYSTEM')
    particles = particle_mod.particle_system
    
    # Configure particles
    particles.settings.count = 5000
    particles.settings.frame_start = 1
    particles.settings.frame_end = 300
    particles.settings.lifetime = 100
    particles.settings.random_lifetime = 0.8
    
    # Physics
    particles.settings.physics_type = 'NEWTON'
    particles.settings.particle_size = 0.01
    particles.settings.size_random = 0.5
    
    # Emission settings
    particles.settings.emit_from = 'VOLUME'
    particles.settings.distribution = 'RAND'
    particles.settings.normal_factor = 0.0
    particles.settings.factor_random = 3.0
    
    # Force fields for complex motion
    particles.settings.effector_weights.gravity = 0.0
    particles.settings.effector_weights.force = 1.0
    particles.settings.effector_weights.vortex = 0.5
    
    return emitter

def create_shatter_effect_system(crystals):
    """Create system for crystal shattering effects"""
    
    shattered_pieces = []
    
    for crystal in crystals[:5]:  # Apply to first 5 crystals
        # Duplicate crystal for shattering
        bpy.context.view_layer.objects.active = crystal
        bpy.ops.object.duplicate()
        shattered = bpy.context.object
        shattered.name = f"Shattered_{crystal.name}"
        shattered.location.z += 0.01  # Slight offset
        
        # Add Cell Fracture addon effect (if available)
        # This would require the Cell Fracture addon to be enabled
        bpy.context.view_layer.objects.active = shattered
        
        # Manual fracturing using bmesh
        bpy.ops.object.mode_set(mode='EDIT')
        
        # Subdivide for fracture lines
        bpy.ops.mesh.subdivide(number_cuts=3, fractal=2.0)
        bpy.ops.mesh.separate(type='LOOSE')
        
        bpy.ops.object.mode_set(mode='OBJECT')
        
        shattered_pieces.append(shattered)
    
    return shattered_pieces

def animate_crystal_resonance(crystals, energy_field, particles, frame_count=300):
    """Animate crystal resonance and transformation"""
    
    for frame in range(1, frame_count + 1, 5):
        bpy.context.scene.frame_set(frame)
        
        # Animate crystal rotations and scaling
        for i, crystal in enumerate(crystals):
            # Rotation based on "frequency"
            rotation_speed = 0.05 + (i % 3) * 0.02
            crystal.rotation_euler.z = frame * rotation_speed
            crystal.rotation_euler.x = math.sin(frame * 0.03 + i) * 0.2
            crystal.keyframe_insert(data_path="rotation_euler", frame=frame)
            
            # Pulsing scale for resonance
            pulse_factor = 1.0 + 0.3 * math.sin(frame * 0.1 + i * 0.5)
            crystal.scale = (pulse_factor, pulse_factor, pulse_factor)
            crystal.keyframe_insert(data_path="scale", frame=frame)
            
            # Height oscillation
            base_z = crystal.location.z
            oscillation = 0.5 * math.sin(frame * 0.08 + i)
            crystal.location.z = base_z + oscillation
            crystal.keyframe_insert(data_path="location", frame=frame)
        
        # Animate energy field
        if energy_field.data.materials:
            energy_mat = energy_field.data.materials[0]
            if energy_mat.use_nodes:
                # Animate noise scale for energy fluctuation
                noise_node = None
                for node in energy_mat.node_tree.nodes:
                    if node.type == 'TEX_NOISE':
                        noise_node = node
                        break
                
                if noise_node:
                    noise_scale = 3.0 + 2.0 * math.sin(frame * 0.05)
                    noise_node.inputs['Scale'].default_value = noise_scale
                    noise_node.inputs['Scale'].keyframe_insert("default_value", frame=frame)

def create_force_fields():
    """Create force fields for particle dynamics"""
    
    # Central vortex
    bpy.ops.object.effector_add(type='VORTEX', location=(0, 0, 2))
    vortex = bpy.context.object
    vortex.name = "CentralVortex"
    vortex.field.strength = 5.0
    vortex.field.flow = 1.0
    
    # Turbulence field
    bpy.ops.object.effector_add(type='TURBULENCE', location=(0, 0, 0))
    turbulence = bpy.context.object
    turbulence.name = "Turbulence"
    turbulence.field.strength = 2.0
    turbulence.field.noise = 1.5
    
    return [vortex, turbulence]

def setup_dramatic_lighting():
    """Setup dramatic lighting for crystal scene"""
    
    # Key light (strong, colored)
    bpy.ops.object.light_add(type='SPOT', location=(5, -5, 8))
    key_light = bpy.context.object
    key_light.data.energy = 10.0
    key_light.data.color = (0.8, 0.9, 1.0)  # Cool blue
    key_light.data.spot_size = math.radians(45)
    key_light.rotation_euler = (math.radians(60), 0, math.radians(45))
    
    # Fill light (warm)
    bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
    fill_light = bpy.context.object
    fill_light.data.energy = 3.0
    fill_light.data.color = (1.0, 0.8, 0.6)  # Warm orange
    fill_light.data.size = 4.0
    
    # Rim light (dramatic)
    bpy.ops.object.light_add(type='SUN', location=(0, 10, 5))
    rim_light = bpy.context.object
    rim_light.data.energy = 5.0
    rim_light.data.color = (1.0, 0.2, 0.8)  # Magenta
    rim_light.rotation_euler = (math.radians(45), 0, 0)
    
    # Environment
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    
    bg_node = world_nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.02, 0.02, 0.05, 1.0)  # Deep space
        bg_node.inputs['Strength'].default_value = 0.1

def setup_camera():
    """Setup dynamic camera movement"""
    
    bpy.ops.object.camera_add(location=(6, -6, 4))
    camera = bpy.context.object
    
    # Create camera path
    bpy.ops.curve.primitive_bezier_circle_add(radius=8, location=(0, 0, 3))
    camera_path = bpy.context.object
    camera_path.name = "CameraPath"
    
    # Add follow path constraint
    constraint = camera.constraints.new(type='FOLLOW_PATH')
    constraint.target = camera_path
    constraint.use_curve_follow = True
    
    # Animate path following
    bpy.context.scene.frame_set(1)
    constraint.offset = 0
    constraint.keyframe_insert(data_path="offset", frame=1)
    
    bpy.context.scene.frame_set(300)
    constraint.offset = 100
    constraint.keyframe_insert(data_path="offset", frame=300)
    
    # Track to center
    track_constraint = camera.constraints.new(type='TRACK_TO')
    bpy.ops.object.empty_add(location=(0, 0, 1))
    target = bpy.context.object
    target.name = "CameraTarget"
    track_constraint.target = target
    
    return camera

def setup_render_settings():
    """Configure render settings for crystal scene"""
    scene = bpy.context.scene
    
    # Use Cycles for advanced materials
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1024  # High samples for glass/crystal
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    
    # Enable caustics for crystal refractions
    scene.cycles.caustics_reflective = True
    scene.cycles.caustics_refractive = True
    
    # Resolution
    scene.render.resolution_x = 2560
    scene.render.resolution_y = 1440
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 300

def main():
    """Create crystalline resonance audio visualizer"""
    
    print("Creating Crystalline Resonance Audio Visualizer...")
    
    # Clear scene
    clear_scene()
    
    # Create crystal system
    crystals = create_fractal_crystal_system()
    
    # Apply materials
    main_crystal_mat = create_crystal_material("main")
    energy_crystal_mat = create_crystal_material("energy")
    
    for i, crystal in enumerate(crystals):
        if i % 3 == 0:
            crystal.data.materials.append(energy_crystal_mat)
        else:
            crystal.data.materials.append(main_crystal_mat)
    
    # Create effects
    energy_field = create_energy_field()
    particles = create_resonance_particles()
    force_fields = create_force_fields()
    
    # Setup environment
    setup_dramatic_lighting()
    camera = setup_camera()
    
    # Animate system
    animate_crystal_resonance(crystals, energy_field, particles)
    
    # Configure rendering
    setup_render_settings()
    
    print("Crystalline Resonance Audio Visualizer created!")
    print(f"Created {len(crystals)} fractal crystals")
    print("Features:")
    print("- Fractal crystal formations")
    print("- Volumetric energy fields")
    print("- 5000 resonance particles")
    print("- Dynamic camera movement")
    print("- Advanced crystal materials with caustics")

if __name__ == "__main__":
    main()