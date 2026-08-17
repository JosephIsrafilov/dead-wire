import re

with open('scenes/office/m1_office.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all nodes from Floor to BaseboardEast
start_idx = content.find('[node name="Floor"')
end_idx = content.find('[node name="DeskSetup"')

if start_idx != -1 and end_idx != -1:
    new_csg = '''[node name="Floor" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.05, 0)
size = Vector3(5.8, 0.1, 4.6)
material = ExtResource("2_floor")
use_collision = true

[node name="Ceiling" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.9, 0)
size = Vector3(5.8, 0.1, 4.6)
material = ExtResource("4_ceiling")
use_collision = true

[node name="WestWall" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.96, 1.425, 0)
size = Vector3(0.12, 2.85, 4.6)
material = ExtResource("3_wall")
use_collision = true

[node name="EastWall" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.96, 1.425, 0)
size = Vector3(0.12, 2.85, 4.6)
material = ExtResource("3_wall")
use_collision = true

[node name="NorthWall_Left" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.25, 1.425, -2.36)
size = Vector3(3.3, 2.85, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="NorthWall_Right" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.35, 1.425, -2.36)
size = Vector3(1.1, 2.85, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="NorthWall_Bottom" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.1, 0.475, -2.36)
size = Vector3(1.4, 0.95, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="NorthWall_Top" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.1, 2.45, -2.36)
size = Vector3(1.4, 0.8, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="NorthWindow" parent="." instance=ExtResource("7_window")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.1, 1.5, -2.36)

[node name="NorthNightBackdrop" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.1, 1.5, -3.2)
size = Vector3(2.4, 2.0, 0.05)
material = ExtResource("6_glass")

[node name="SouthWall_Left" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.5, 1.425, 2.36)
size = Vector3(0.8, 2.85, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="SouthWall_Right" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.9, 1.425, 2.36)
size = Vector3(4.0, 2.85, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="SouthWall_Top" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.6, 2.475, 2.36)
size = Vector3(1.0, 0.75, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="SouthDoor" parent="." instance=ExtResource("8_door")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.6, 1.05, 2.36)

[node name="TicketCounterWall_Bottom" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.5, 0.5, 1.0)
size = Vector3(4.8, 1.0, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="TicketCounterWall_Top" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.5, 2.4, 1.0)
size = Vector3(4.8, 1.0, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="TicketCounterWall_Right" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.4, 1.425, 1.0)
size = Vector3(1.0, 2.85, 0.12)
material = ExtResource("3_wall")
use_collision = true

[node name="TicketCounterOpening" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.5, 1.45, 1.0)
size = Vector3(1.5, 0.9, 0.05)
material = ExtResource("6_glass")

[node name="BaseboardNorth" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.08, -2.28)
size = Vector3(5.76, 0.16, 0.04)
material = ExtResource("5_trim")

[node name="BaseboardSouth" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.08, 2.28)
size = Vector3(5.76, 0.16, 0.04)
material = ExtResource("5_trim")

[node name="BaseboardWest" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.88, 0.08, 0)
size = Vector3(0.04, 0.16, 4.56)
material = ExtResource("5_trim")

[node name="BaseboardEast" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.88, 0.08, 0)
size = Vector3(0.04, 0.16, 4.56)
material = ExtResource("5_trim")

'''
    
    content = content[:start_idx] + new_csg + content[end_idx:]
    with open('scenes/office/m1_office.tscn', 'w', encoding='utf-8') as f:
        f.write(content)
