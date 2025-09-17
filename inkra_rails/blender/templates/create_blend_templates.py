#!/usr/bin/env python3
"""
Create Blender Template Files for Each Visualizer
Generates .blend files that can be opened directly in Blender
"""

import bpy
import mathutils
import random
import math
import os

def clear_scene():
    """Clear default Blender scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def setup_cycles_render():
    """Configure Cycles render engine with optimized settings"""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.frame_start = 1
    scene.frame_end = 360  # 15 seconds at 24fps

def create_crystalline_template():
    """Create Crystalline Resonance template"""
    print("🔷 Creating Crystalline Resonance template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create crystal formations
    crystals = []
    for i in range(12):
        # Golden ratio spiral positioning
        t = i / 12.0 * math.pi * 2
        radius = 1.5 + (i * 0.3)
        x = radius * math.cos(t) * math.cos(t * 1.618)
        y = radius * math.sin(t) * math.sin(t * 1.618)  
        z = (i - 6) * 0.4
        
        # Create icosphere (better topology than UV sphere)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, 
            radius=0.3,
            location=(x, y, z)
        )
        crystal = bpy.context.object
        crystal.name = f"Crystal_{i}"
        
        # Elongate crystal shape
        crystal.scale = (0.6, 0.6, 2.0)
        
        # Random rotation for natural look
        crystal.rotation_euler = (
            random.uniform(0, math.pi),
            random.uniform(0, math.pi),
            random.uniform(0, math.pi)
        )
        
        # Advanced material
        mat = bpy.data.materials.new(name=f"CrystalMat_{i}")
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        
        # Crystal properties (Blender 4.5.2 compatible)
        principled.inputs['Transmission Weight'].default_value = 0.95
        principled.inputs['IOR'].default_value = 2.4  # Diamond-like
        principled.inputs['Base Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Strength'].default_value = 1.0
        principled.inputs['Roughness'].default_value = 0.1
        
        crystal.data.materials.append(mat)
        crystals.append(crystal)
    
    # Professional lighting setup
    setup_crystalline_lighting()
    
    # Camera setup
    bpy.ops.object.camera_add(location=(0, -8, 3))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(65), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save template
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/crystalline_template.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Saved: {template_path}")

def setup_crystalline_lighting():
    """Professional lighting for crystalline visualizer"""
    
    # Key light
    bpy.ops.object.light_add(type='AREA', location=(3, -4, 6))
    key_light = bpy.context.object
    key_light.data.energy = 50.0
    key_light.data.size = 2.0
    key_light.data.color = (1.0, 0.9, 0.8)
    
    # Rim light
    bpy.ops.object.light_add(type='AREA', location=(-4, 3, 4))
    rim_light = bpy.context.object
    rim_light.data.energy = 30.0
    rim_light.data.size = 1.5
    rim_light.data.color = (0.6, 0.8, 1.0)
    
    # Fill light
    bpy.ops.object.light_add(type='AREA', location=(0, 0, -2))
    fill_light = bpy.context.object  
    fill_light.data.energy = 15.0
    fill_light.data.size = 4.0
    fill_light.data.color = (0.9, 0.9, 1.0)
    
    # Background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.05, 0.05, 0.15, 1.0)
        bg_node.inputs['Strength'].default_value = 0.2

def create_fluid_template():
    """Create Fluid Simulation template"""
    print("🌊 Creating Fluid Simulation template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create wave planes (fluid simulation alternative)
    wave_layers = []
    for i in range(5):
        z_pos = i * 0.5 - 1.0
        bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, z_pos))
        wave_plane = bpy.context.object
        wave_plane.name = f"FluidWave_{i}"
        
        # Add subdivision for wave detail
        wave_plane.modifiers.new(name="Subdivision", type='SUBSURF')
        wave_plane.modifiers["Subdivision"].levels = 4
        
        # Add wave modifier
        wave_plane.modifiers.new(name="Wave", type='WAVE')
        wave_mod = wave_plane.modifiers["Wave"]
        wave_mod.height = 0.2 * (i + 1)  # Different wave heights
        wave_mod.width = 0.8 + (i * 0.1)
        wave_mod.speed = 1.0 + (i * 0.2)
        wave_mod.start_position_object = wave_plane
        
        wave_layers.append(wave_plane)
    
    # Liquid metal material
    create_liquid_metal_material()
    
    # Professional lighting
    setup_fluid_lighting()
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -7, 4))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(55), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save template
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/fluid_template.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Saved: {template_path}")

def create_liquid_metal_material():
    """Create iridescent liquid metal material"""
    mat = bpy.data.materials.new(name="LiquidMetal")
    mat.use_nodes = True
    
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs['Metallic'].default_value = 0.9
    principled.inputs['Roughness'].default_value = 0.1
    principled.inputs['Transmission Weight'].default_value = 0.1
    principled.inputs['Base Color'].default_value = (0.8, 0.9, 1.0, 1.0)

def setup_fluid_lighting():
    """Professional lighting for fluid visualizer"""
    
    # HDRI world
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Strength'].default_value = 1.5

def create_quantum_template():
    """Create Quantum Interference template"""
    print("⚛️ Creating Quantum Interference template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create wave planes with geometry nodes
    wave_planes = []
    for i in range(5):
        angle = i * math.pi / 5
        location = (
            math.cos(angle) * 2,
            math.sin(angle) * 2,
            (i - 2) * 0.5
        )
        
        bpy.ops.mesh.primitive_plane_add(size=4, location=location)
        plane = bpy.context.object
        plane.name = f"WavePlane_{i}"
        plane.rotation_euler = (angle, 0, angle * 0.5)
        
        # Add subdivision surface
        plane.modifiers.new(name="Subdivision", type='SUBSURF')
        plane.modifiers["Subdivision"].levels = 3
        
        # Wave interference material
        create_wave_material(plane, i)
        wave_planes.append(plane)
    
    # Volumetric lighting
    setup_quantum_lighting()
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -6, 2))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(75), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save template  
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/quantum_template.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Saved: {template_path}")

def create_wave_material(obj, index):
    """Create wave interference material"""
    mat = bpy.data.materials.new(name=f"WaveMat_{index}")
    mat.use_nodes = True
    mat.blend_method = 'ALPHA'
    
    principled = mat.node_tree.nodes.get("Principled BSDF")
    hue = index / 5.0
    color = mathutils.Color()
    color.hsv = (hue, 0.8, 1.0)
    
    principled.inputs['Base Color'].default_value = (*color, 1.0)
    principled.inputs['Transmission Weight'].default_value = 0.9
    principled.inputs['Alpha'].default_value = 0.7
    principled.inputs['Emission Color'].default_value = (*color, 1.0)
    principled.inputs['Emission Strength'].default_value = 0.5
    
    obj.data.materials.append(mat)

def setup_quantum_lighting():
    """Volumetric lighting for quantum effects"""
    
    # Enable volumetrics
    scene = bpy.context.scene
    scene.cycles.volume_step_rate = 0.1
    scene.cycles.volume_max_steps = 512
    
    # Multiple colored lights
    colors = [(1.0, 0.5, 0.8), (0.5, 0.8, 1.0), (0.8, 1.0, 0.5)]
    for i, color in enumerate(colors):
        angle = i * 2 * math.pi / 3
        location = (
            math.cos(angle) * 4,
            math.sin(angle) * 4,
            3
        )
        
        bpy.ops.object.light_add(type='POINT', location=location)
        light = bpy.context.object
        light.data.energy = 100.0
        light.data.color = color

def create_organic_template():
    """Create Organic Growth template"""
    print("🌱 Creating Organic Growth template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create base trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=3, location=(0, 0, 0))
    trunk = bpy.context.object
    trunk.name = "OrganicTrunk"
    
    # Add subdivision and displacement
    trunk.modifiers.new(name="Subdivision", type='SUBSURF')
    trunk.modifiers["Subdivision"].levels = 2
    
    # Organic material
    create_organic_material()
    
    # Natural lighting
    setup_organic_lighting()
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -5, 2))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(70), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save template
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/organic_template.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Saved: {template_path}")

def create_organic_material():
    """Create living tissue material"""
    mat = bpy.data.materials.new(name="OrganicTissue")
    mat.use_nodes = True
    
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs['Base Color'].default_value = (0.2, 0.6, 0.3, 1.0)
    principled.inputs['Subsurface Weight'].default_value = 0.3
    principled.inputs['Subsurface Color'].default_value = (0.8, 0.9, 0.4, 1.0)
    principled.inputs['Roughness'].default_value = 0.8

def setup_organic_lighting():
    """Natural lighting for organic growth"""
    
    # Sun light
    bpy.ops.object.light_add(type='SUN', location=(0, 0, 10))
    sun = bpy.context.object
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(30), 0, math.radians(45))
    
    # Sky background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.5, 0.7, 1.0, 1.0)
        bg_node.inputs['Strength'].default_value = 0.3

def create_space_template():
    """Create Procedural Space template"""
    print("🌌 Creating Procedural Space template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create nebula volume
    bpy.ops.mesh.primitive_cube_add(size=10, location=(0, 0, 0))
    nebula = bpy.context.object
    nebula.name = "NebulaVolume"
    
    # Volume material
    create_nebula_material()
    
    # Star particle system
    create_star_field()
    
    # Cosmic lighting
    setup_space_lighting()
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -8, 0))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save template
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/space_template.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Saved: {template_path}")

def create_nebula_material():
    """Create volumetric nebula material"""
    mat = bpy.data.materials.new(name="NebulaMaterial")
    mat.use_nodes = True
    mat.node_tree.nodes.clear()
    
    # Volume scatter node
    volume_scatter = mat.node_tree.nodes.new(type='ShaderNodeVolumeScatter')
    volume_scatter.inputs['Color'].default_value = (0.8, 0.5, 1.0, 1.0)
    volume_scatter.inputs['Density'].default_value = 0.1
    
    # Output
    output = mat.node_tree.nodes.new(type='ShaderNodeOutputMaterial')
    mat.node_tree.links.new(volume_scatter.outputs['Volume'], output.inputs['Volume'])

def create_star_field():
    """Create particle system for stars"""
    
    # Create emitter
    bpy.ops.mesh.primitive_plane_add(size=20)
    emitter = bpy.context.object
    emitter.name = "StarEmitter"
    
    # Particle system
    emitter.modifiers.new(name="ParticleSystem", type='PARTICLE_SYSTEM')
    ps = emitter.particle_systems[0]
    ps.settings.count = 5000
    ps.settings.lifetime = 1000
    ps.settings.render_type = 'HALO'
    ps.settings.material_slot = 'Default'

def setup_space_lighting():
    """Cosmic lighting setup"""
    
    # Starfield background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.01, 0.01, 0.05, 1.0)
        bg_node.inputs['Strength'].default_value = 0.1

def main():
    """Create all template files"""
    print("🔷 CREATING BLENDER TEMPLATE FILES")
    print("=" * 50)
    
    # Ensure templates directory exists
    os.makedirs("/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates", exist_ok=True)
    
    # Create all templates
    create_crystalline_template()
    create_fluid_template() 
    create_quantum_template()
    create_organic_template()
    create_space_template()
    
    print("\n✅ ALL TEMPLATE FILES CREATED")
    print("\nTemplate files saved to:")
    print("• crystalline_template.blend - Fractal crystal formations")
    print("• fluid_template.blend - Liquid metal simulation")  
    print("• quantum_template.blend - Wave interference patterns")
    print("• organic_template.blend - Living growth structures")
    print("• space_template.blend - Procedural cosmic environments")
    
    print("\n📖 Usage:")
    print("1. Open any .blend file in Blender")
    print("2. Replace audio file path in Video Sequence Editor")
    print("3. Adjust animation parameters as needed")
    print("4. Render animation (F12 for single frame, Ctrl+F12 for animation)")

if __name__ == "__main__":
    main()