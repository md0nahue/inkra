#!/usr/bin/env python3
"""
Create Simple Blender Template Files
Just creates basic setups without complex modifiers
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
    """Configure Cycles render engine"""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.frame_start = 1
    scene.frame_end = 360  # 15 seconds at 24fps

def create_basic_crystalline():
    """Create basic crystalline template"""
    print("🔷 Creating Crystalline template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create 12 crystals in golden spiral
    for i in range(12):
        t = i / 12.0 * math.pi * 2
        radius = 1.5 + (i * 0.3)
        x = radius * math.cos(t)
        y = radius * math.sin(t)  
        z = (i - 6) * 0.4
        
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, 
            radius=0.3,
            location=(x, y, z)
        )
        crystal = bpy.context.object
        crystal.name = f"Crystal_{i}"
        crystal.scale = (0.6, 0.6, 2.0)
        
        # Basic material
        mat = bpy.data.materials.new(name=f"CrystalMat_{i}")
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        
        principled.inputs['Base Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Strength'].default_value = 1.0
        principled.inputs['Roughness'].default_value = 0.1
        
        crystal.data.materials.append(mat)
    
    # Simple lighting
    bpy.ops.object.light_add(type='AREA', location=(3, -4, 6))
    key_light = bpy.context.object
    key_light.data.energy = 50.0
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -8, 3))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(65), 0, 0)
    bpy.context.scene.camera = camera
    
    # Background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.05, 0.05, 0.15, 1.0)
    
    # Save
    bpy.ops.wm.save_as_mainfile(
        filepath="/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/crystalline_basic.blend"
    )
    print("✅ Crystalline template saved")

def create_basic_wave():
    """Create basic wave template"""
    print("🌊 Creating Wave template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create 5 wave planes
    for i in range(5):
        z_pos = i * 0.5 - 1.0
        bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, z_pos))
        wave_plane = bpy.context.object
        wave_plane.name = f"Wave_{i}"
        
        # High subdivision for wave detail
        bpy.ops.object.modifier_add(type='SUBSURF')
        wave_plane.modifiers["Subdivision Surface"].levels = 4
        
        # Iridescent material
        mat = bpy.data.materials.new(name=f"WaveMat_{i}")
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        
        hue = i / 5.0
        color = mathutils.Color()
        color.hsv = (hue, 0.8, 1.0)
        
        principled.inputs['Base Color'].default_value = (*color, 1.0)
        principled.inputs['Metallic'].default_value = 0.8
        principled.inputs['Roughness'].default_value = 0.1
        
        wave_plane.data.materials.append(mat)
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -7, 4))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(55), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save
    bpy.ops.wm.save_as_mainfile(
        filepath="/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/wave_basic.blend"
    )
    print("✅ Wave template saved")

def create_basic_quantum():
    """Create basic quantum template"""
    print("⚛️ Creating Quantum template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create interference planes
    for i in range(5):
        angle = i * math.pi / 5
        location = (
            math.cos(angle) * 2,
            math.sin(angle) * 2,
            (i - 2) * 0.5
        )
        
        bpy.ops.mesh.primitive_plane_add(size=4, location=location)
        plane = bpy.context.object
        plane.name = f"QuantumPlane_{i}"
        plane.rotation_euler = (angle, 0, angle * 0.5)
        
        # High subdivision
        bpy.ops.object.modifier_add(type='SUBSURF')
        plane.modifiers["Subdivision Surface"].levels = 3
        
        # Transparent quantum material
        mat = bpy.data.materials.new(name=f"QuantumMat_{i}")
        mat.use_nodes = True
        mat.blend_method = 'ALPHA'
        
        principled = mat.node_tree.nodes.get("Principled BSDF")
        hue = i / 5.0
        color = mathutils.Color()
        color.hsv = (hue, 0.8, 1.0)
        
        principled.inputs['Base Color'].default_value = (*color, 1.0)
        principled.inputs['Alpha'].default_value = 0.7
        principled.inputs['Emission Color'].default_value = (*color, 1.0)
        principled.inputs['Emission Strength'].default_value = 0.5
        
        plane.data.materials.append(mat)
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -6, 2))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(75), 0, 0)
    bpy.context.scene.camera = camera
    
    # Save
    bpy.ops.wm.save_as_mainfile(
        filepath="/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/quantum_basic.blend"
    )
    print("✅ Quantum template saved")

def create_basic_organic():
    """Create basic organic template"""
    print("🌱 Creating Organic template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create tree trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=3, location=(0, 0, 0))
    trunk = bpy.context.object
    trunk.name = "OrganicTrunk"
    
    # Subdivision
    bpy.ops.object.modifier_add(type='SUBSURF')
    trunk.modifiers["Subdivision Surface"].levels = 2
    
    # Organic material
    mat = bpy.data.materials.new(name="OrganicMaterial")
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    
    principled.inputs['Base Color'].default_value = (0.2, 0.6, 0.3, 1.0)
    principled.inputs['Roughness'].default_value = 0.8
    
    trunk.data.materials.append(mat)
    
    # Sun lighting
    bpy.ops.object.light_add(type='SUN', location=(0, 0, 10))
    sun = bpy.context.object
    sun.data.energy = 5.0
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -5, 2))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(70), 0, 0)
    bpy.context.scene.camera = camera
    
    # Sky background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.5, 0.7, 1.0, 1.0)
    
    # Save
    bpy.ops.wm.save_as_mainfile(
        filepath="/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/organic_basic.blend"
    )
    print("✅ Organic template saved")

def create_basic_space():
    """Create basic space template"""
    print("🌌 Creating Space template...")
    
    clear_scene()
    setup_cycles_render()
    
    # Create nebula volume (simple cube)
    bpy.ops.mesh.primitive_cube_add(size=8, location=(0, 0, 0))
    nebula = bpy.context.object
    nebula.name = "NebulaVolume"
    
    # Basic space material
    mat = bpy.data.materials.new(name="SpaceMaterial")
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    
    principled.inputs['Base Color'].default_value = (0.2, 0.1, 0.5, 1.0)
    principled.inputs['Emission Color'].default_value = (0.5, 0.3, 1.0, 1.0)
    principled.inputs['Emission Strength'].default_value = 0.3
    
    nebula.data.materials.append(mat)
    
    # Add some stars (icospheres)
    for i in range(20):
        x = random.uniform(-10, 10)
        y = random.uniform(-10, 10)
        z = random.uniform(-5, 5)
        
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=random.uniform(0.05, 0.2),
            location=(x, y, z)
        )
        star = bpy.context.object
        star.name = f"Star_{i}"
        
        # Bright star material
        star_mat = bpy.data.materials.new(name=f"StarMat_{i}")
        star_mat.use_nodes = True
        star_principled = star_mat.node_tree.nodes.get("Principled BSDF")
        
        star_principled.inputs['Emission Color'].default_value = (1.0, 1.0, 0.8, 1.0)
        star_principled.inputs['Emission Strength'].default_value = 5.0
        
        star.data.materials.append(star_mat)
    
    # Camera
    bpy.ops.object.camera_add(location=(0, -8, 0))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = camera
    
    # Dark space background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.01, 0.01, 0.05, 1.0)
    
    # Save
    bpy.ops.wm.save_as_mainfile(
        filepath="/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/space_basic.blend"
    )
    print("✅ Space template saved")

def main():
    """Create all basic template files"""
    print("🔷 CREATING BASIC BLENDER TEMPLATES")
    print("=" * 40)
    
    # Ensure templates directory exists
    os.makedirs("/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates", exist_ok=True)
    
    # Create templates one by one
    create_basic_crystalline()
    create_basic_wave()
    create_basic_quantum()
    create_basic_organic()
    create_basic_space()
    
    print("\n✅ ALL BASIC TEMPLATES CREATED")
    print("\nFiles saved:")
    print("• crystalline_basic.blend")
    print("• wave_basic.blend")
    print("• quantum_basic.blend") 
    print("• organic_basic.blend")
    print("• space_basic.blend")

if __name__ == "__main__":
    main()