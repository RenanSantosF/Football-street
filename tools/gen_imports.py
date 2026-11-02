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

def ue5_names():
    """UE5 Manny (5 vértebras, nomes em minúsculas)."""
    m = ue_names()
    m.update({"Spine":"spine_01","Chest":"spine_03","UpperChest":"spine_05","Neck":"neck_01","Head":"head"})
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

## Animações do Mixamo enviadas pelo autor do projeto (nomes exatos dos arquivos).
USER_PACK = [
    # pedidos ao autor (ainda não enviados; a importação já fica pronta)
    'Standing Up', 'Stand Up', 'Stand Up (1)', 'Goalkeeper Diving Save',
    'Standing Arguing', 'Breathing Idle', 'Walking', 'Start Walking', 'Right Turn',
    'Left Turn', 'Run To Stop', 'Running Turn 180',
    'Jog Forward Diagonal (2)', 'Jog Forward Diagonal (3)',
    'Standing Cover Turn', 'Stop Walking', 'Jog Strafe Left (1)', 'Jog Strafe Right (1)',
    'Walking Turn 180', 'Walking Left Turn', 'Running Right Turn', 'Running Turn 180 (1)',
    'Running To Turn',
    'Change Direction',
    'Defeated',
    'Dribble',
    'Fallen Idle caído depois da falta',
    'Goalkeeper Catch',
    'Goalkeeper Catch (1)',
    'Goalkeeper Pass',
    'Goalkeeper Placing Ball',
    'Goalkeeper Placing Ball (1)',
    'Header',
    'Header Soccerball',
    'Idle To Sprint',
    'Jog Forward',
    'Jog Forward Diagonal',
    'Jog Forward Diagonal (1)',
    'Jog Strafe Left',
    'Jog Strafe Right',
    'Kick Soccerball',
    'Kick Up Soccerball',
    'Kneeing Soccerball',
    'Left Strafe',
    'Left Strafe Walking',
    'Offensive Idle',
    'Offensive Idle aquecimento',
    'Receive',
    'Receive Soccerball',
    'Right Strafe',
    'Run Backward',
    'Run Forward triste depois de errar correndo triste',
    'Running Jump pulando fugindo do carrinho',
    'Samba Dancing',
    'Scissor Kick',
    'Slow Jog',
    'Soccer Header',
    'Soccer Idle',
    'Soccer Pass toque ',
    'Soccer Penalty Kick',
    'Soccer Spin',
    'Soccer Tackle',
    'Soccer Tackle (1)',
    'Soccer Tackle (2)',
    'Soccer Trip',
    'Sprint',
    'Sprint Turn',
    'Stall Soccerball',
    'Stall Soccerball (1)',
    'Standard Run',
    'Strafe',
    'Strike Foward Jog',
    'Transition',
    'Victory',
    'Victory Idle',
    'Walk Strafe Left',
]


def bone_map(names):
    parts = ['"retarget/bone_map": Object(BoneMap,"resource_local_to_scene":false,"resource_name":"",'
             '"profile":Object(SkeletonProfileHumanoid,"resource_local_to_scene":false,"resource_name":"",'
             '"root_bone":&"Root","scale_base_bone":&"Hips","group_size":4,"bone_size":56,"script":null)\n,"bonemap":null']
    for b in ORDER:
        parts.append(f'"bone_map/{b}":&"{names.get(b, "")}"')
    return ",".join(parts) + ',"script":null)'

def write(path, skeleton_path, names, animations, extra_node="", fix_silhouette=False, skip_nodes=()):
    src = path
    # nós que não precisam vir (ex.: malha do boneco do autor num pack de animação)
    skip_nodes_txt = "".join(f',\n"PATH:{n}": {{\n"import/skip_import": true\n}}' for n in skip_nodes)
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
"retarget/remove_tracks/unmapped_bones": true,
"retarget/rest_fixer/fix_silhouette/enable": {"true" if fix_silhouette else "false"}{extra_node}
}}{skip_nodes_txt}
}}
}}
{"gltf/naming_version=1" + chr(10) + "gltf/embedded_image_handling=1" if path.endswith(".gltf") else "fbx/importer=0" + chr(10) + "fbx/allow_geometry_helper_nodes=false" + chr(10) + "fbx/embedded_image_handling=1"}
'''
    with open(path + ".import", "w") as f:
        f.write(txt)
    print("ok", path)

if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    write("assets/animations/ual/AnimationLibrary_Godot_Standard.gltf", "Rig/Skeleton3D", rigify_names(), True)
    os.makedirs("assets/animations/mixamo/pack", exist_ok=True)
    for clip in USER_PACK:
        write(f"assets/animations/mixamo/pack/{clip}.fbx", "Skeleton3D", mixamo_names(), True, fix_silhouette=True)
    # Personagem adolescente (malha + textura), rigado no Mixamo. A malha está
    # em pose A e os clipes "sem skin" em pose T: Fix Silhouette normaliza as
    # duas para a mesma silhueta antes do retarget (senão os braços vão para trás).
    write("assets/characters/teen_01/teen_01.fbx", "Skeleton3D", mixamo_names(), True, fix_silhouette=True)
    # Pack de mocap de futebol (Anderson Rohr), esqueleto UE5 Manny.
    rohr = "assets/animations/rohr"
    if os.path.isdir(rohr):
        for fn in sorted(os.listdir(rohr)):
            if fn.endswith(".fbx"):
                write(f"{rohr}/{fn}", "Skeleton3D", ue5_names(), True, fix_silhouette=True,
                      skip_nodes=("Skeleton3D/Body", "Skeleton3D/HeadFace", "Skeleton3D/HeadFaceless"))
