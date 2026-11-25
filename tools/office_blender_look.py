"""Shared Blender export helpers for the authored office assemblies."""

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def scanned_materials(atlas, tiles, prefix):
    image = bpy.data.images.load(str(atlas), check_existing=True)
    result = {}
    for kind in tiles:
        material = bpy.data.materials.new(prefix + kind)
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Metallic"].default_value = .89 if kind == "brass" else 0
        shader.inputs["Roughness"].default_value = .43 if kind == "brass" else .83
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Closest"
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
        result[kind] = material
    return result


def bake_vertex_ao(obj):
    """Bake near-field occlusion into mesh corners after assembling the prop."""
    mesh = obj.data
    points = [vertex.co for vertex in mesh.vertices]
    tree = BVHTree.FromPolygons(points, [face.vertices[:] for face in mesh.polygons], all_triangles=True)
    layer = mesh.color_attributes.new(name="AmbientOcclusion", type="BYTE_COLOR", domain="CORNER")
    mesh.color_attributes.active_color = layer
    extent = max(obj.dimensions)
    radius = min(.20, max(.017, extent * .18))
    up = Vector((0, 0, 1))
    for face in mesh.polygons:
        normal = face.normal
        reference = up if abs(normal.dot(up)) < .9 else Vector((1, 0, 0))
        side = normal.cross(reference).normalized()
        tangent = normal.cross(side)
        for idx in face.loop_indices:
            point = points[mesh.loops[idx].vertex_index]
            origin = point.lerp(face.center, .08) + normal * .0003
            shade = 0
            for direction in (side, -side, tangent, -tangent):
                _, _, _, distance = tree.ray_cast(origin, (normal + direction * 1.4).normalized(), radius)
                if distance is not None:
                    shade += 1.0 - distance / radius
            value = 1.0 - shade * .083
            layer.data[idx].color = (value, value, value, 1)
