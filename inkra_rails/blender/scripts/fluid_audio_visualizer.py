#!/usr/bin/env python3
"""
Fluid Simulation Audio Visualizer
Creates ocean-like waves that react to audio
"""

import bpy
import bmesh
import mathutils
import random
import math

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_fluid_domain():
    """Create fluid simulation domain"""
    
    # Create domain cube
    bpy.ops.mesh.primitive_cube_add(scale=(5, 5, 3), location=(0, 0, 1.5))
    domain = bpy.context.object
    domain.name = "FluidDomain"
    
    # Add fluid physics
    bpy.context.view_layer.objects.active = domain
    bpy.ops.physics.fluid_add(type='DOMAIN')
    
    # Configure domain settings
    domain.modifiers["Fluid"].domain_settings.domain_type = 'LIQUID'
    domain.modifiers["Fluid"].domain_settings.resolution_max = 128
    domain.modifiers["Fluid"].domain_settings.use_adaptive_domain = True
    domain.modifiers["Fluid"].domain_settings.additional_res = 2
    
    # Viscosity for smooth flow
    domain.modifiers["Fluid"].domain_settings.viscosity_base = 0.1
    
    return domain

def create_audio_reactive_inflow():
    """Create inflow objects that react to audio"""
    
    inflows = []
    
    # Create multiple inflow sources in a pattern
    for i in range(8):
        angle = (i / 8.0) * 2 * math.pi
        x = 2.5 * math.cos(angle)
        y = 2.5 * math.sin(angle)
        
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.3, location=(x, y, 3))
        inflow = bpy.context.object
        inflow.name = f"AudioInflow_{i}"
        
        # Add fluid physics
        bpy.ops.physics.fluid_add(type='FLOW')
        inflow.modifiers["Fluid"].flow_settings.flow_type = 'LIQUID'
        inflow.modifiers["Fluid"].flow_settings.use_inflow = True
        inflow.modifiers["Fluid"].flow_settings.volume_density = 1.0
        
        # Set different colors for each inflow
        hue = i / 8.0
        color = mathutils.Color((hue, 1.0, 1.0))
        inflow.modifiers["Fluid"].flow_settings.surface_emission = 1.5
        
        inflows.append(inflow)
    
    return inflows

def create_obstacle_field():
    """Create obstacles that interact with fluid"""
    
    obstacles = []
    
    # Create geometric obstacles
    for i in range(5):
        x = random.uniform(-3, 3)
        y = random.uniform(-3, 3)
        z = random.uniform(0, 2)
        
        # Random obstacle type
        obstacle_type = random.choice(['cube', 'sphere', 'cylinder'])
        
        if obstacle_type == 'cube':
            bpy.ops.mesh.primitive_cube_add(scale=(0.5, 0.5, 1), location=(x, y, z))
        elif obstacle_type == 'sphere':
            bpy.ops.mesh.primitive_ico_sphere_add(radius=0.7, location=(x, y, z))
        else:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=1.5, location=(x, y, z))
        
        obstacle = bpy.context.object
        obstacle.name = f"FluidObstacle_{i}"
        
        # Add obstacle physics
        bpy.ops.physics.fluid_add(type='OBSTACLE')
        obstacle.modifiers["Fluid"].obstacle_settings.surface_distance = 0.1
        
        obstacles.append(obstacle)
    
    return obstacles

def create_particle_foam_system():
    """Create particle system for foam and spray effects"""
    
    # Create emitter object
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 4))
    emitter = bpy.context.object
    emitter.name = "FoamEmitter"
    
    # Add particle system
    particle_mod = emitter.modifiers.new(name="FoamParticles", type='PARTICLE_SYSTEM')
    particles = particle_mod.particle_system
    
    # Configure particles for foam effect
    particles.settings.count = 2000
    particles.settings.frame_start = 1
    particles.settings.frame_end = 300
    particles.settings.lifetime = 30
    particles.settings.random_lifetime = 0.5
    
    # Physics
    particles.settings.physics_type = 'NEWTON'
    particles.settings.mass = 0.1
    particles.settings.particle_size = 0.02
    particles.settings.size_random = 0.5
    
    # Gravity and air resistance
    particles.settings.effector_weights.gravity = -0.2
    particles.settings.drag_factor = 0.8
    
    # Emission
    particles.settings.emit_from = 'FACE'
    particles.settings.use_emit_random = True
    particles.settings.normal_factor = 1.0
    particles.settings.factor_random = 2.0
    
    return emitter

def create_fluid_material():
    """Create advanced material for fluid visualization"""
    
    mat = bpy.data.materials.new(name="FluidMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output node
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    # Glass BSDF for water-like appearance
    glass = nodes.new('ShaderNodeBsdfGlass')
    glass.location = (200, 0)
    glass.inputs['Color'].default_value = (0.1, 0.3, 0.8, 1.0)
    glass.inputs['Roughness'].default_value = 0.05
    glass.inputs['IOR'].default_value = 1.33
    
    # Volume Scatter for depth
    volume_scatter = nodes.new('ShaderNodeVolumeScatter')
    volume_scatter.location = (200, -200)
    volume_scatter.inputs['Color'].default_value = (0.2, 0.5, 1.0, 1.0)
    volume_scatter.inputs['Density'].default_value = 0.1
    
    # Links
    mat.node_tree.links.new(glass.outputs['BSDF'], output.inputs['Surface'])
    mat.node_tree.links.new(volume_scatter.outputs['Volume'], output.inputs['Volume'])
    
    return mat

def setup_lighting():
    """Setup dramatic lighting for fluid"""
    
    # Add sun light
    bpy.ops.object.light_add(type='SUN', location=(5, 5, 10))
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.data.color = (1.0, 0.95, 0.8)
    sun.rotation_euler = (math.radians(45), 0, math.radians(45))
    
    # Add area light for fill
    bpy.ops.object.light_add(type='AREA', location=(-3, -3, 6))
    area = bpy.context.object
    area.data.energy = 2.0
    area.data.color = (0.8, 0.9, 1.0)
    area.data.size = 4.0
    
    # Environment lighting
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    
    bg_node = world_nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.05, 0.05, 0.1, 1.0)
        bg_node.inputs['Strength'].default_value = 0.3

def animate_audio_reactivity(inflows, frame_count=300):
    """Animate inflow objects to simulate audio reactivity"""
    
    for frame in range(1, frame_count + 1, 5):
        bpy.context.scene.frame_set(frame)
        
        for i, inflow in enumerate(inflows):
            # Simulate frequency-based animation
            freq_factor = math.sin(frame * 0.1 + i) * 0.5 + 0.5
            
            # Scale based on "frequency"
            scale = 0.2 + freq_factor * 0.8
            inflow.scale = (scale, scale, scale)
            inflow.keyframe_insert(data_path="scale", frame=frame)
            
            # Move vertically
            z_offset = freq_factor * 0.5
            inflow.location.z = 3 + z_offset
            inflow.keyframe_insert(data_path="location", frame=frame)
            
            # Adjust flow rate
            flow_rate = 0.5 + freq_factor * 1.5
            inflow.modifiers["Fluid"].flow_settings.volume_density = flow_rate

def setup_camera():
    """Setup camera for optimal fluid viewing"""
    bpy.ops.object.camera_add(location=(8, -8, 6))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(60), 0, math.radians(45))
    
    # Camera settings for motion blur
    camera.data.dof.use_dof = True
    camera.data.dof.aperture_fstop = 2.8
    
    return camera

def setup_render_settings():
    """Configure render settings for fluid simulation"""
    scene = bpy.context.scene
    
    # Use Cycles for realistic rendering
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 512
    scene.cycles.use_denoising = True
    
    # Resolution
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 300
    
    # Motion blur for fluid motion
    scene.render.motion_blur_shutter = 0.5
    scene.cycles.motion_blur_position = 'CENTER'

def main():
    """Create fluid audio visualizer"""
    
    print("Creating Fluid Audio Visualizer...")
    
    # Clear scene
    clear_scene()
    
    # Create fluid simulation components
    domain = create_fluid_domain()
    inflows = create_audio_reactive_inflow()
    obstacles = create_obstacle_field()
    foam_emitter = create_particle_foam_system()
    
    # Apply fluid material to domain
    fluid_mat = create_fluid_material()
    domain.data.materials.append(fluid_mat)
    
    # Setup lighting and camera
    setup_lighting()
    camera = setup_camera()
    
    # Animate for audio reactivity
    animate_audio_reactivity(inflows)
    
    # Configure rendering
    setup_render_settings()
    
    print("Fluid Audio Visualizer created!")
    print("Note: Bake fluid simulation before rendering")
    print("Go to Physics Properties > Fluid > Bake")

if __name__ == "__main__":
    main()