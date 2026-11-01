#!/usr/bin/env python3
"""Gera os arquivos .import dos modelos humanoides com o BoneMap embutido
(retarget para SkeletonProfileHumanoid). Só é necessário rodar quando um
modelo novo com outro padrão de nomes de ossos for adicionado; os .import
gerados já estão no repositório."""
import os, sys

PROFILE = ["Root","Hips","Spine","Chest","UpperChest","Neck","Head","LeftEye","RightEye","Jaw"]
FINGERS = ["Thumb","Index","Middle","Ring","Little"]
SEGS = {"Thumb": ["Metacarpal","Proximal","Distal"], "_": ["Proximal","Intermediate","Distal"]}

def arm_side(side):
    out = [f"{side}Shoulder", f"{side}UpperArm", f"{side}LowerArm", f"{side}Hand"]
    for f in FINGERS:
        for s in SEGS.get(f, SEGS["_"]):
            out.append(f"{side}{f}{s}")
    return out

ORDER = PROFILE + arm_side("Left") + arm_side("Right") + \
    [f"{s}{b}" for s in ("Left","Right") for b in ("UpperLeg","LowerLeg","Foot","Toes")]

def ue_names():
    m = {"Root":"root","Hips":"pelvis","Spine":"spine_01","Chest":"spine_02","UpperChest":"spine_03",
         "Neck":"neck_01","Head":"Head"}
    fn = {"Thumb":"thumb","Index":"index","Middle":"middle","Ring":"ring","Little":"pinky"}
    for side, s in (("Left","l"),("Right","r")):
        m[f"{side}Shoulder"]=f"clavicle_{s}"; m[f"{side}UpperArm"]=f"upperarm_{s}"
        m[f"{side}LowerArm"]=f"lowerarm_{s}"; m[f"{side}Hand"]=f"hand_{s}"
        for f in FINGERS:
            for i, seg in enumerate(SEGS.get(f, SEGS["_"])):
                m[f"{side}{f}{seg}"]=f"{fn[f]}_0{i+1}_{s}"
        m[f"{side}UpperLeg"]=f"thigh_{s}"; m[f"{side}LowerLeg"]=f"calf_{s}"
        m[f"{side}Foot"]=f"foot_{s}"; m[f"{side}Toes"]=f"ball_{s}"
    return m

def rigify_names():
    m = {"Root":"root","Hips":"DEF-hips","Spine":"DEF-spine.001","Chest":"DEF-spine.002",
         "UpperChest":"DEF-spine.003","Neck":"DEF-neck","Head":"DEF-head"}
    fn = {"Thumb":"thumb","Index":"f_index","Middle":"f_middle","Ring":"f_ring","Little":"f_pinky"}
    for side, s in (("Left","L"),("Right","R")):
        m[f"{side}Shoulder"]=f"DEF-shoulder.{s}"; m[f"{side}UpperArm"]=f"DEF-upper_arm.{s}"
        m[f"{side}LowerArm"]=f"DEF-forearm.{s}"; m[f"{side}Hand"]=f"DEF-hand.{s}"
        for f in FINGERS:
            for i, seg in enumerate(SEGS.get(f, SEGS["_"])):
                m[f"{side}{f}{seg}"]=f"DEF-{fn[f]}.0{i+1}.{s}"
        m[f"{side}UpperLeg"]=f"DEF-thigh.{s}"; m[f"{side}LowerLeg"]=f"DEF-shin.{s}"
        m[f"{side}Foot"]=f"DEF-foot.{s}"; m[f"{side}Toes"]=f"DEF-toe.{s}"
    return m

def mixamo_names(prefix="mixamorig_"):
    m = {"Hips":"Hips","Spine":"Spine","Chest":"Spine1","UpperChest":"Spine2","Neck":"Neck","Head":"Head"}
    fn = {"Thumb":"Thumb","Index":"Index","Middle":"Middle","Ring":"Ring","Little":"Pinky"}
    for side in ("Left","Right"):
        m[f"{side}Shoulder"]=f"{side}Shoulder"; m[f"{side}UpperArm"]=f"{side}Arm"
        m[f"{side}LowerArm"]=f"{side}ForeArm"; m[f"{side}Hand"]=f"{side}Hand"
        for f in FINGERS:
            for i, seg in enumerate(SEGS.get(f, SEGS["_"])):
                m[f"{side}{f}{seg}"]=f"{side}Hand{fn[f]}{i+1}"
        m[f"{side}UpperLeg"]=f"{side}UpLeg"; m[f"{side}LowerLeg"]=f"{side}Leg"
        m[f"{side}Foot"]=f"{side}Foot"; m[f"{side}Toes"]=f"{side}ToeBase"
    return {k: prefix + v for k, v in m.items()}

## Arquivos do "Soccer Game Pack" do Mixamo (nomes exatos do download).
SOCCER_PACK = [
    "fallen idle", "goalkeeper body block (2)", "goalkeeper body block (3)", "goalkeeper body block",
    "goalkeeper catch (2)", "goalkeeper catch (3)", "goalkeeper catch (4)", "goalkeeper catch",
    "goalkeeper directing (2)", "goalkeeper directing", "goalkeeper diving save (2)",
    "goalkeeper diving save", "goalkeeper drop kick", "goalkeeper idle (2)", "goalkeeper idle",
    "goalkeeper miss", "goalkeeper overhand throw", "goalkeeper pass", "goalkeeper placing ball (2)",
    "goalkeeper placing ball", "goalkeeper scoop", "goalkeeper sidestep (2)", "goalkeeper sidestep",
    "header soccerball (2)", "header soccerball", "jog backward diagonal (2)", "jog backward diagonal",
    "jog backward", "jog forward diagonal (2)", "jog forward diagonal", "jog forward",
    "jog strafe left", "jog strafe right", "kick soccerball (2)", "kick soccerball",
    "kick up soccerball", "kneeing soccerball (2)", "kneeing soccerball", "offensive idle",
    "receive soccerball", "scissor kick", "soccer penalty kick", "soccer tackle (2)",
    "soccer tackle (3)", "soccer tackle", "soccer trip", "stall soccerball (2)",
    "stall soccerball (3)", "stall soccerball (4)", "stall soccerball", "standing up",
    "strike foward jog", "throw in", "transition",
]


def bone_map(names):
    parts = ['"retarget/bone_map": Object(BoneMap,"resource_local_to_scene":false,"resource_name":"",'
             '"profile":Object(SkeletonProfileHumanoid,"resource_local_to_scene":false,"resource_name":"",'
             '"root_bone":&"Root","scale_base_bone":&"Hips","group_size":4,"bone_size":56,"script":null)\n,"bonemap":null']
    for b in ORDER:
        parts.append(f'"bone_map/{b}":&"{names.get(b, "")}"')
    return ",".join(parts) + ',"script":null)'

def write(path, skeleton_path, names, animations, extra_node=""):
    src = path
    txt = f'''[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://{src}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=0
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import={"true" if animations else "false"}
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
_subresources={{
"nodes": {{
"PATH:{skeleton_path}": {{
{bone_map(names)},
"retarget/remove_tracks/unmapped_bones": true{extra_node}
}}
}}
}}
{"gltf/naming_version=1" + chr(10) + "gltf/embedded_image_handling=1" if path.endswith(".gltf") else "fbx/importer=0" + chr(10) + "fbx/allow_geometry_helper_nodes=false" + chr(10) + "fbx/embedded_image_handling=1"}
'''
    with open(path + ".import", "w") as f:
        f.write(txt)
    print("ok", path)

if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    ue = ue_names()
    write("assets/characters/base/Superhero_Male_FullBody.gltf", "Armature/Skeleton3D", ue, False)
    for h in ("Hair_SimpleParted", "Hair_Buzzed", "Hair_Long"):
        write(f"assets/characters/hair/{h}.gltf", "Armature/Skeleton3D", ue, False)
    write("assets/animations/ual/AnimationLibrary_Godot_Standard.gltf", "Rig/Skeleton3D", rigify_names(), True)
    os.makedirs("assets/animations/mixamo/soccer_pack", exist_ok=True)
    for clip in SOCCER_PACK:
        write(f"assets/animations/mixamo/soccer_pack/{clip}.fbx", "Skeleton3D", mixamo_names(), True)
