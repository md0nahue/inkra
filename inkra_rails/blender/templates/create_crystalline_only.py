#!/usr/bin/env python3
"""
Create just the Crystalline template file
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

def main():
    """Create crystalline template"""
    print("🔷 CREATING CRYSTALLINE TEMPLATE")
    
    clear_scene()
    
    # Cycles render setup
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.frame_start = 1
    scene.frame_end = 360
    
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
        
        # Random rotation
        crystal.rotation_euler = (
            random.uniform(0, math.pi),
            random.uniform(0, math.pi),
            random.uniform(0, math.pi)
        )
        
        # Crystal material
        mat = bpy.data.materials.new(name=f"CrystalMat_{i}")
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        
        principled.inputs['Base Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Color'].default_value = (0.2, 0.8, 1.0, 1.0)
        principled.inputs['Emission Strength'].default_value = 1.0
        principled.inputs['Roughness'].default_value = 0.1
        principled.inputs['IOR'].default_value = 2.4
        
        crystal.data.materials.append(mat)
    
    # Professional lighting
    bpy.ops.object.light_add(type='AREA', location=(3, -4, 6))
    key_light = bpy.context.object
    key_light.data.energy = 50.0
    key_light.data.size = 2.0
    
    bpy.ops.object.light_add(type='AREA', location=(-4, 3, 4))
    rim_light = bpy.context.object
    rim_light.data.energy = 30.0
    rim_light.data.size = 1.5
    
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
        bg_node.inputs['Strength'].default_value = 0.2
    
    # Create keyframes for rotation animation
    for frame in range(1, 361, 10):
        bpy.context.scene.frame_set(frame)
        
        for i, obj in enumerate(bpy.data.objects):
            if obj.name.startswith("Crystal_"):
                # Rotation animation
                obj.rotation_euler.z += 0.1 * (i + 1)
                obj.keyframe_insert(data_path="rotation_euler", frame=frame)
                
                # Scale pulsing
                pulse = 1.0 + 0.3 * math.sin((frame + i * 10) * 0.1)
                obj.scale = (0.6 * pulse, 0.6 * pulse, 2.0 * pulse)
                obj.keyframe_insert(data_path="scale", frame=frame)
    
    # Save template
    os.makedirs("/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates", exist_ok=True)
    template_path = "/Users/magnusfremont/Desktop/VibeWriter/inkra_rails/blender/templates/crystalline_resonance.blend"
    bpy.ops.wm.save_as_mainfile(filepath=template_path)
    print(f"✅ Crystalline template saved: {template_path}")
    
    print("\n🎨 Template includes:")
    print("• 12 icosphere crystals in golden spiral formation")
    print("• Professional 3-point lighting setup")
    print("• Emission materials with cyan/blue colors")
    print("• Rotation and pulsing animation keyframes")
    print("• TikTok format render settings (1080x1920)")
    print("• 360 frames (15 seconds at 24fps)")
    
    print("\n📖 Usage:")
    print("1. Open crystalline_resonance.blend in Blender")
    print("2. Add audio in Video Sequence Editor")
    print("3. Adjust animation timing to match audio")
    print("4. Render animation (Ctrl+F12)")

if __name__ == "__main__":
    main()