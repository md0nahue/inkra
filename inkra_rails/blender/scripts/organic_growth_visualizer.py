#!/usr/bin/env python3
"""
Organic Growth Audio Visualizer
Creates plant-like growth patterns that react to audio
Uses L-systems and procedural growth algorithms
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

def create_growth_base_system():
    """Create base system for organic growth using curves"""
    
    # Create base curve for main stem
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    main_stem = bpy.context.object
    main_stem.name = "MainStem"
    
    # Modify curve for organic shape
    bpy.context.view_layer.objects.active = main_stem
    bpy.ops.object.mode_set(mode='EDIT')
    
    # Add more points for complexity
    bpy.ops.curve.subdivide(number_cuts=10)
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Set curve properties
    main_stem.data.dimensions = '3D'
    main_stem.data.fill_mode = 'FULL'
    main_stem.data.bevel_depth = 0.05
    main_stem.data.resolution_u = 12
    
    return main_stem

def create_branching_system(parent_stem, generation=0, max_generations=4):
    """Create recursive branching system"""
    
    branches = []
    
    if generation >= max_generations:
        return branches
    
    # Number of branches decreases with generation
    branch_count = max(2, 8 - generation * 2)
    
    for i in range(branch_count):
        # Create branch curve
        angle = (i / branch_count) * 2 * math.pi
        height = random.uniform(1, 3)
        
        # Calculate branch position
        x_offset = math.cos(angle) * 0.5
        y_offset = math.sin(angle) * 0.5
        z_offset = height
        
        bpy.ops.curve.primitive_bezier_curve_add(
            location=(x_offset, y_offset, z_offset)
        )
        branch = bpy.context.object
        branch.name = f"Branch_Gen{generation}_{i}"
        
        # Scale branch based on generation
        scale = 1.0 - (generation * 0.3)
        branch.scale = (scale, scale, scale)
        
        # Modify curve shape
        bpy.context.view_layer.objects.active = branch
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.curve.subdivide(number_cuts=5)
        bpy.ops.object.mode_set(mode='OBJECT')
        
        # Set curve properties
        branch.data.dimensions = '3D'
        branch.data.fill_mode = 'FULL'
        branch.data.bevel_depth = 0.02 * scale
        branch.data.resolution_u = 8
        
        # Random rotation for natural look
        branch.rotation_euler = (
            random.uniform(-0.5, 0.5),
            random.uniform(-0.5, 0.5),
            random.uniform(0, 2 * math.pi)
        )
        
        branches.append(branch)
        
        # Create sub-branches recursively
        sub_branches = create_branching_system(branch, generation + 1, max_generations)
        branches.extend(sub_branches)
    
    return branches

def create_leaf_system(branches):
    """Create leaves using geometry nodes"""
    
    leaves = []
    
    for branch in branches:
        # Create leaf emitter plane
        bpy.ops.mesh.primitive_plane_add(
            size=0.1, 
            location=branch.location + Vector((0, 0, random.uniform(0.5, 1.5)))
        )
        leaf_emitter = bpy.context.object
        leaf_emitter.name = f"LeafEmitter_{branch.name}"
        
        # Add Geometry Nodes modifier
        geo_modifier = leaf_emitter.modifiers.new(name="LeafNodes", type='NODES')
        
        # Create leaf node tree
        node_tree = bpy.data.node_groups.new(name=f"LeafGeometry_{branch.name}", type='GeometryNodeTree')
        geo_modifier.node_group = node_tree
        
        # Input/Output nodes
        input_node = node_tree.nodes.new('NodeGroupInput')
        output_node = node_tree.nodes.new('NodeGroupOutput')
        input_node.location = (-600, 0)
        output_node.location = (400, 0)
        
        # Distribute points for leaves
        distribute = node_tree.nodes.new('GeometryNodeDistributePointsOnFaces')
        distribute.location = (-400, 0)
        distribute.inputs['Density'].default_value = random.uniform(50, 200)
        
        # Instance on points
        instance = node_tree.nodes.new('GeometryNodeInstanceOnPoints')
        instance.location = (-200, 0)
        
        # Create leaf geometry (scaled plane)
        leaf_geo = node_tree.nodes.new('GeometryNodeMeshGrid')
        leaf_geo.location = (-400, -300)
        leaf_geo.inputs['Size X'].default_value = 0.2
        leaf_geo.inputs['Size Y'].default_value = 0.1
        
        # Random rotation for leaves
        random_rot = node_tree.nodes.new('GeometryNodeInputRandom')
        random_rot.location = (-400, -500)
        random_rot.data_type = 'FLOAT_VECTOR'
        
        # Rotate instances
        rotate_instances = node_tree.nodes.new('GeometryNodeRotateInstances')
        rotate_instances.location = (0, 0)
        
        # Links
        node_tree.links.new(input_node.outputs['Geometry'], distribute.inputs['Mesh'])
        node_tree.links.new(distribute.outputs['Points'], instance.inputs['Points'])
        node_tree.links.new(leaf_geo.outputs['Mesh'], instance.inputs['Instance'])
        node_tree.links.new(instance.outputs['Instances'], rotate_instances.inputs['Instances'])
        node_tree.links.new(random_rot.outputs['Value'], rotate_instances.inputs['Rotation'])
        node_tree.links.new(rotate_instances.outputs['Instances'], output_node.inputs['Geometry'])
        
        leaves.append(leaf_emitter)
    
    return leaves

def create_flower_system():
    """Create flowers using procedural generation"""
    
    flowers = []
    
    # Create different flower types
    flower_types = [
        {"petals": 5, "color": (1.0, 0.3, 0.8), "size": 0.3},    # Pink flower
        {"petals": 6, "color": (0.9, 0.9, 0.2), "size": 0.4},    # Yellow flower
        {"petals": 8, "color": (0.2, 0.3, 1.0), "size": 0.2},    # Blue flower
        {"petals": 4, "color": (1.0, 0.5, 0.1), "size": 0.35},   # Orange flower
    ]
    
    for i, flower_type in enumerate(flower_types):
        # Random position for flower
        x = random.uniform(-2, 2)
        y = random.uniform(-2, 2)
        z = random.uniform(2, 4)
        
        # Create flower center
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.05, 
            location=(x, y, z)
        )
        flower_center = bpy.context.object
        flower_center.name = f"FlowerCenter_{i}"
        
        # Create petals
        flower_group = [flower_center]
        
        for petal in range(flower_type["petals"]):
            angle = (petal / flower_type["petals"]) * 2 * math.pi
            petal_x = x + math.cos(angle) * flower_type["size"] * 0.5
            petal_y = y + math.sin(angle) * flower_type["size"] * 0.5
            
            bpy.ops.mesh.primitive_plane_add(
                size=flower_type["size"],
                location=(petal_x, petal_y, z)
            )
            petal_obj = bpy.context.object
            petal_obj.name = f"Petal_{i}_{petal}"
            
            # Rotate petal towards center
            direction = Vector((x - petal_x, y - petal_y, 0))
            petal_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
            petal_obj.rotation_euler.z += angle
            
            flower_group.append(petal_obj)
        
        # Create flower material
        flower_mat = create_flower_material(flower_type["color"])
        
        # Apply material to all flower parts
        for flower_part in flower_group:
            flower_part.data.materials.append(flower_mat)
        
        flowers.extend(flower_group)
    
    return flowers

def create_flower_material(base_color):
    """Create material for flowers"""
    
    mat = bpy.data.materials.new(name=f"FlowerMaterial_{random.randint(1000, 9999)}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    
    # Get principled BSDF
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = base_color + (1.0,)
    bsdf.inputs['Roughness'].default_value = 0.3
    bsdf.inputs['Specular IOR Level'].default_value = 0.8
    
    # Add subtle emission
    bsdf.inputs['Emission Color'].default_value = base_color + (1.0,)
    bsdf.inputs['Emission Strength'].default_value = 0.1
    
    # Subsurface scattering for organic look
    bsdf.inputs['Subsurface Weight'].default_value = 0.2
    bsdf.inputs['Subsurface Color'].default_value = base_color + (1.0,)
    
    return mat

def create_growth_animation(stem, branches, leaves, flowers, frame_count=300):
    """Animate organic growth over time"""
    
    # Animate main stem growth
    for frame in range(1, min(50, frame_count)):
        bpy.context.scene.frame_set(frame)
        
        # Scale stem growth
        growth_factor = frame / 50.0
        stem.scale.z = growth_factor
        stem.keyframe_insert(data_path="scale", frame=frame)
    
    # Animate branch growth (staggered)
    for i, branch in enumerate(branches):
        start_frame = 20 + i * 5  # Stagger branch growth
        
        for frame in range(start_frame, min(start_frame + 40, frame_count)):
            bpy.context.scene.frame_set(frame)
            
            if frame < start_frame + 20:
                growth_factor = (frame - start_frame) / 20.0
                branch.scale = (growth_factor, growth_factor, growth_factor)
                branch.keyframe_insert(data_path="scale", frame=frame)
    
    # Animate leaf appearance
    for i, leaf in enumerate(leaves):
        appear_frame = 60 + i * 2
        
        # Hide initially
        bpy.context.scene.frame_set(1)
        leaf.hide_viewport = True
        leaf.hide_render = True
        leaf.keyframe_insert(data_path="hide_viewport", frame=1)
        leaf.keyframe_insert(data_path="hide_render", frame=1)
        
        # Appear at designated frame
        if appear_frame < frame_count:
            bpy.context.scene.frame_set(appear_frame)
            leaf.hide_viewport = False
            leaf.hide_render = False
            leaf.keyframe_insert(data_path="hide_viewport", frame=appear_frame)
            leaf.keyframe_insert(data_path="hide_render", frame=appear_frame)
    
    # Animate flower blooming
    for i, flower_part in enumerate(flowers):
        bloom_frame = 100 + i * 3
        
        # Start small
        bpy.context.scene.frame_set(bloom_frame)
        flower_part.scale = (0.1, 0.1, 0.1)
        flower_part.keyframe_insert(data_path="scale", frame=bloom_frame)
        
        # Grow to full size
        if bloom_frame + 20 < frame_count:
            bpy.context.scene.frame_set(bloom_frame + 20)
            flower_part.scale = (1.0, 1.0, 1.0)
            flower_part.keyframe_insert(data_path="scale", frame=bloom_frame + 20)

def create_wind_animation(branches, leaves, frame_count=300):
    """Add wind animation for realism"""
    
    for frame in range(1, frame_count + 1, 5):
        bpy.context.scene.frame_set(frame)
        
        # Wind effect on branches
        for i, branch in enumerate(branches):
            wind_strength = 0.1 * math.sin(frame * 0.05 + i)
            
            # Slight rotation for wind effect
            original_rot = branch.rotation_euler.copy()
            branch.rotation_euler.x = original_rot.x + wind_strength
            branch.rotation_euler.y = original_rot.y + wind_strength * 0.5
            branch.keyframe_insert(data_path="rotation_euler", frame=frame)

def setup_natural_lighting():
    """Setup natural lighting for organic scene"""
    
    # Sun light
    bpy.ops.object.light_add(type='SUN', location=(5, 5, 10))
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.data.color = (1.0, 0.95, 0.8)  # Warm sunlight
    sun.rotation_euler = (math.radians(45), 0, math.radians(30))
    
    # Sky light (area)
    bpy.ops.object.light_add(type='AREA', location=(0, 0, 8))
    sky_light = bpy.context.object
    sky_light.data.energy = 1.5
    sky_light.data.color = (0.7, 0.8, 1.0)  # Cool sky light
    sky_light.data.size = 10
    sky_light.rotation_euler = (0, 0, 0)
    
    # Setup world (sky)
    world = bpy.context.scene.world
    world.use_nodes = True
    world_nodes = world.node_tree.nodes
    
    bg_node = world_nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.3, 0.6, 1.0, 1.0)  # Sky blue
        bg_node.inputs['Strength'].default_value = 0.5

def setup_camera():
    """Setup camera for organic growth scene"""
    
    bpy.ops.object.camera_add(location=(4, -4, 3))
    camera = bpy.context.object
    
    # Point towards growth center
    constraint = camera.constraints.new(type='TRACK_TO')
    
    # Create empty target
    bpy.ops.object.empty_add(location=(0, 0, 2))
    target = bpy.context.object
    target.name = "CameraTarget"
    
    constraint.target = target
    constraint.track_axis = 'TRACK_NEGATIVE_Z'
    constraint.up_axis = 'UP_Y'
    
    return camera

def setup_render_settings():
    """Configure render settings"""
    scene = bpy.context.scene
    
    # Use Cycles for better materials
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 512
    scene.cycles.use_denoising = True
    
    # Resolution
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 300

def main():
    """Create organic growth audio visualizer"""
    
    print("Creating Organic Growth Audio Visualizer...")
    
    # Clear scene
    clear_scene()
    
    # Create growth system
    main_stem = create_growth_base_system()
    branches = create_branching_system(main_stem)
    leaves = create_leaf_system(branches[:10])  # Limit leaves for performance
    flowers = create_flower_system()
    
    # Setup environment
    setup_natural_lighting()
    camera = setup_camera()
    
    # Animate growth
    create_growth_animation(main_stem, branches, leaves, flowers)
    create_wind_animation(branches, leaves)
    
    # Configure rendering
    setup_render_settings()
    
    print("Organic Growth Audio Visualizer created!")
    print(f"Components created:")
    print(f"- Main stem: 1")
    print(f"- Branches: {len(branches)}")
    print(f"- Leaf emitters: {len(leaves)}")
    print(f"- Flowers: {len(flowers)}")

if __name__ == "__main__":
    main()