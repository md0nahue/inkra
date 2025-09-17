#!/usr/bin/env python3
"""
Procedural Space Audio Visualizer
Creates a cosmic environment with stars, nebulae, and audio-reactive elements
"""

import bpy
import bmesh
import mathutils
import random
import math
from mathutils import Vector, Color

def clear_scene():
    """Clear existing objects from scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def create_procedural_stars(count=1000):
    """Create a field of procedural stars using geometry nodes"""
    
    # Create base plane
    bpy.ops.mesh.primitive_plane_add(size=50, location=(0, 0, 0))
    star_field = bpy.context.object
    star_field.name = "StarField"
    
    # Add Geometry Nodes modifier
    geo_modifier = star_field.modifiers.new(name="StarNodes", type='NODES')
    
    # Create node tree
    node_tree = bpy.data.node_groups.new(name="StarGeometry", type='GeometryNodeTree')
    geo_modifier.node_group = node_tree
    
    # Input and Output nodes
    input_node = node_tree.nodes.new('NodeGroupInput')
    output_node = node_tree.nodes.new('NodeGroupOutput')
    input_node.location = (-800, 0)
    output_node.location = (600, 0)
    
    # Distribute points
    distribute = node_tree.nodes.new('GeometryNodeDistributePointsOnFaces')
    distribute.location = (-600, 0)
    distribute.inputs['Density'].default_value = count / 100.0
    
    # Instance on points
    instance = node_tree.nodes.new('GeometryNodeInstanceOnPoints')
    instance.location = (-200, 0)
    
    # Create star geometry (icosphere)
    star_geo = node_tree.nodes.new('GeometryNodeMeshIcoSphere')
    star_geo.location = (-400, -200)
    star_geo.inputs['Radius'].default_value = 0.02
    
    # Random scale for star variation
    random_scale = node_tree.nodes.new('GeometryNodeInputRandom')
    random_scale.location = (-400, -400)
    random_scale.data_type = 'FLOAT_VECTOR'
    
    # Scale instances
    scale_instances = node_tree.nodes.new('GeometryNodeScaleInstances')
    scale_instances.location = (0, 0)
    
    # Links
    node_tree.links.new(input_node.outputs['Geometry'], distribute.inputs['Mesh'])
    node_tree.links.new(distribute.outputs['Points'], instance.inputs['Points'])
    node_tree.links.new(star_geo.outputs['Mesh'], instance.inputs['Instance'])
    node_tree.links.new(instance.outputs['Instances'], scale_instances.inputs['Instances'])
    node_tree.links.new(random_scale.outputs['Value'], scale_instances.inputs['Scale'])
    node_tree.links.new(scale_instances.outputs['Instances'], output_node.inputs['Geometry'])
    
    # Create star material
    star_mat = create_star_material()
    star_field.data.materials.append(star_mat)
    
    return star_field

def create_star_material():
    """Create emissive material for stars"""
    mat = bpy.data.materials.new(name="StarMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    # Emission shader
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (200, 0)
    emission.inputs['Strength'].default_value = 3.0
    
    # Color ramp for star colors
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (0, 0)
    
    # Random input for color variation
    object_info = nodes.new('ShaderNodeObjectInfo')
    object_info.location = (-200, 0)
    
    # Configure color ramp for star colors (blue to white to red)
    color_ramp.color_ramp.elements[0].color = (0.5, 0.7, 1.0, 1.0)  # Blue
    color_ramp.color_ramp.elements[1].color = (1.0, 0.9, 0.7, 1.0)  # Warm white
    
    # Links
    mat.node_tree.links.new(object_info.outputs['Random'], color_ramp.inputs['Fac'])
    mat.node_tree.links.new(color_ramp.outputs['Color'], emission.inputs['Color'])
    mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])
    
    return mat

def create_audio_reactive_nebula():
    """Create volumetric nebula that reacts to audio"""
    
    # Create volume cube
    bpy.ops.mesh.primitive_cube_add(size=20, location=(0, 0, 0))
    nebula = bpy.context.object
    nebula.name = "Nebula"
    
    # Create volumetric material
    nebula_mat = bpy.data.materials.new(name="NebulaMaterial")
    nebula_mat.use_nodes = True
    nodes = nebula_mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (800, 0)
    
    # Volume Scatter
    volume_scatter = nodes.new('ShaderNodeVolumeScatter')
    volume_scatter.location = (600, 0)
    volume_scatter.inputs['Density'].default_value = 0.1
    
    # Principled Volume (for more control)
    principled_vol = nodes.new('ShaderNodeVolumePrincipled')
    principled_vol.location = (400, 0)
    principled_vol.inputs['Density'].default_value = 0.05
    principled_vol.inputs['Emission Strength'].default_value = 0.5
    
    # Noise texture for nebula structure
    noise_tex = nodes.new('ShaderNodeTexNoise')
    noise_tex.location = (0, 0)
    noise_tex.inputs['Scale'].default_value = 2.0
    noise_tex.inputs['Detail'].default_value = 10.0
    noise_tex.inputs['Distortion'].default_value = 1.0
    
    # Texture coordinate
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Color ramp for nebula colors
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (200, 100)
    
    # Set nebula colors (purple to blue to pink)
    color_ramp.color_ramp.elements[0].color = (0.2, 0.1, 0.5, 1.0)  # Deep purple
    color_ramp.color_ramp.elements[1].color = (0.8, 0.2, 0.6, 1.0)  # Pink
    
    # Links
    nebula_mat.node_tree.links.new(tex_coord.outputs['Generated'], noise_tex.inputs['Vector'])
    nebula_mat.node_tree.links.new(noise_tex.outputs['Fac'], color_ramp.inputs['Fac'])
    nebula_mat.node_tree.links.new(color_ramp.outputs['Color'], principled_vol.inputs['Color'])
    nebula_mat.node_tree.links.new(noise_tex.outputs['Fac'], principled_vol.inputs['Density'])
    nebula_mat.node_tree.links.new(principled_vol.outputs['Volume'], output.inputs['Volume'])
    
    nebula.data.materials.append(nebula_mat)
    
    return nebula

def create_audio_reactive_planets():
    """Create planets that scale and glow with audio"""
    
    planets = []
    
    # Create several planets at different distances
    planet_data = [
        {"pos": (5, 0, 0), "scale": 0.5, "color": (1.0, 0.3, 0.1)},    # Mars-like
        {"pos": (-7, 3, 2), "scale": 0.8, "color": (0.2, 0.5, 1.0)},   # Earth-like  
        {"pos": (0, -8, -1), "scale": 1.2, "color": (0.9, 0.8, 0.3)},  # Jupiter-like
        {"pos": (12, -5, 3), "scale": 0.3, "color": (0.8, 0.8, 0.8)},  # Moon-like
    ]
    
    for i, data in enumerate(planet_data):
        # Create planet
        bpy.ops.mesh.primitive_uv_sphere_add(radius=data["scale"], location=data["pos"])
        planet = bpy.context.object
        planet.name = f"Planet_{i}"
        
        # Create planet material
        planet_mat = bpy.data.materials.new(name=f"PlanetMat_{i}")
        planet_mat.use_nodes = True
        nodes = planet_mat.node_tree.nodes
        
        # Get principled BSDF
        bsdf = nodes.get("Principled BSDF")
        bsdf.inputs['Base Color'].default_value = data["color"] + (1.0,)
        bsdf.inputs['Metallic'].default_value = 0.0
        bsdf.inputs['Roughness'].default_value = 0.8
        
        # Add emission for glow
        bsdf.inputs['Emission Color'].default_value = data["color"] + (1.0,)
        bsdf.inputs['Emission Strength'].default_value = 0.2
        
        planet.data.materials.append(planet_mat)
        planets.append(planet)
    
    return planets

def create_wormhole_effect():
    """Create a central wormhole/portal effect"""
    
    # Create torus for wormhole ring
    bpy.ops.mesh.primitive_torus_add(major_radius=2, minor_radius=0.3, location=(0, 0, 0))
    wormhole = bpy.context.object
    wormhole.name = "Wormhole"
    
    # Create wormhole material with animated shader
    wormhole_mat = bpy.data.materials.new(name="WormholeMaterial")
    wormhole_mat.use_nodes = True
    nodes = wormhole_mat.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)
    
    # Emission shader
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (400, 0)
    emission.inputs['Strength'].default_value = 5.0
    
    # Wave texture for animation
    wave_tex = nodes.new('ShaderNodeTexWave')
    wave_tex.location = (0, 0)
    wave_tex.inputs['Scale'].default_value = 10.0
    wave_tex.inputs['Distortion'].default_value = 2.0
    
    # Texture coordinate
    tex_coord = nodes.new('ShaderNodeTexCoord')
    tex_coord.location = (-200, 0)
    
    # Color ramp for energy colors
    color_ramp = nodes.new('ShaderNodeValToRGB')
    color_ramp.location = (200, 0)
    color_ramp.color_ramp.elements[0].color = (0.0, 1.0, 1.0, 1.0)  # Cyan
    color_ramp.color_ramp.elements[1].color = (1.0, 0.0, 1.0, 1.0)  # Magenta
    
    # Links
    wormhole_mat.node_tree.links.new(tex_coord.outputs['Generated'], wave_tex.inputs['Vector'])
    wormhole_mat.node_tree.links.new(wave_tex.outputs['Color'], color_ramp.inputs['Fac'])
    wormhole_mat.node_tree.links.new(color_ramp.outputs['Color'], emission.inputs['Color'])
    wormhole_mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])
    
    wormhole.data.materials.append(wormhole_mat)
    
    return wormhole

def animate_space_objects(star_field, nebula, planets, wormhole, frame_count=300):
    """Animate all space objects for audio reactivity"""
    
    for frame in range(1, frame_count + 1, 10):
        bpy.context.scene.frame_set(frame)
        
        # Animate wormhole rotation
        wormhole.rotation_euler.z = frame * 0.05
        wormhole.keyframe_insert(data_path="rotation_euler", frame=frame)
        
        # Animate nebula density (simulate audio reactivity)
        if nebula.data.materials:
            nebula_mat = nebula.data.materials[0]
            if nebula_mat.use_nodes:
                principled_vol = nebula_mat.node_tree.nodes.get("Principled Volume")
                if principled_vol:
                    density = 0.05 + 0.03 * math.sin(frame * 0.1)
                    principled_vol.inputs['Density'].default_value = density
                    principled_vol.inputs['Density'].keyframe_insert("default_value", frame=frame)
        
        # Animate planets
        for i, planet in enumerate(planets):
            # Orbit animation
            angle = frame * 0.02 * (i + 1)
            radius = 5 + i * 2
            x = radius * math.cos(angle)
            y = radius * math.sin(angle)
            
            planet.location.x = x
            planet.location.y = y
            planet.keyframe_insert(data_path="location", frame=frame)
            
            # Scale pulsing (audio reactivity simulation)
            scale_factor = 1.0 + 0.2 * math.sin(frame * 0.08 + i)
            planet.scale = (scale_factor, scale_factor, scale_factor)
            planet.keyframe_insert(data_path="scale", frame=frame)

def setup_space_camera():
    """Setup camera for cinematic space view"""
    
    bpy.ops.object.camera_add(location=(15, -15, 8))
    camera = bpy.context.object
    
    # Point camera towards center
    direction = Vector((0, 0, 0)) - camera.location
    camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    
    # Camera settings
    camera.data.lens = 35  # Wide angle for space
    camera.data.clip_end = 1000  # Far clipping for space
    
    return camera

def setup_space_world():
    """Setup world shader for space background"""
    
    world = bpy.context.scene.world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    nodes.clear()
    
    # Output
    output = nodes.new('ShaderNodeOutputWorld')
    output.location = (400, 0)
    
    # Background shader
    background = nodes.new('ShaderNodeBackground')
    background.location = (200, 0)
    background.inputs['Strength'].default_value = 0.1
    
    # Sky texture for subtle gradient
    sky_tex = nodes.new('ShaderNodeTexSky')
    sky_tex.location = (0, 0)
    sky_tex.sky_type = 'HOSEK_WILKIE'
    
    # Links
    world.node_tree.links.new(sky_tex.outputs['Color'], background.inputs['Color'])
    world.node_tree.links.new(background.outputs['Background'], output.inputs['Surface'])

def setup_render_settings():
    """Configure render settings for space scene"""
    scene = bpy.context.scene
    
    # Use Cycles for volumetrics
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 1024  # High samples for volumetrics
    scene.cycles.use_denoising = True
    
    # Enable motion blur
    scene.render.motion_blur_shutter = 0.5
    
    # Resolution
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    
    # Frame range
    scene.frame_start = 1
    scene.frame_end = 300

def main():
    """Create procedural space audio visualizer"""
    
    print("Creating Procedural Space Audio Visualizer...")
    
    # Clear scene
    clear_scene()
    
    # Create space objects
    star_field = create_procedural_stars()
    nebula = create_audio_reactive_nebula()
    planets = create_audio_reactive_planets()
    wormhole = create_wormhole_effect()
    
    # Setup environment
    camera = setup_space_camera()
    setup_space_world()
    
    # Animate objects
    animate_space_objects(star_field, nebula, planets, wormhole)
    
    # Configure rendering
    setup_render_settings()
    
    print("Procedural Space Audio Visualizer created!")
    print("Objects created:")
    print("- Star field with 1000+ stars")
    print("- Volumetric nebula")
    print("- 4 animated planets")
    print("- Central wormhole effect")

if __name__ == "__main__":
    main()