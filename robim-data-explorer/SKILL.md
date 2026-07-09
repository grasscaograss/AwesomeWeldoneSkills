---
name: robim-data-explorer
description: >
  Explore Robim.Data source code definitions from the local clone at d:/robim_data.
  Use when the user is working in the weldone project (or any project referencing Robim.Data nuget)
  and needs to understand types from the Robim.Data namespace or its sub-namespaces
  (Robim.Data.Geometry, Robim.Data.Math, Robim.Data.Process, Robim.Data.ArcWeldingCraft,
  Robim.Data.Weld, Robim.Data.Coarse, Robim.Data.Scanning, etc.).
  Trigger scenarios: (1) user mentions a type name that belongs to Robim.Data,
  (2) user asks about data structures defined in Robim.Data nuget packages,
  (3) user needs to understand proto definitions in Robim.Data.Proto,
  (4) user references fields/properties whose types are in Robim.Data and the
  definition is not available through standard project references.
license: Apache-2.0
compatibility: Requires Robim.Data source clone at d:/robim_data.
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Robim.Data Explorer

When this skill is triggered, the user needs to understand a type or data structure
that lives in the Robim.Data nuget package. The source code is available locally at
`d:/robim_data`.

## Workflow

1. **Identify the type name** the user is asking about.
2. **Look up in the index**: Open `references/type-index.md` and search for the type name.
3. **If found**: Read the corresponding file from `d:/robim_data/<file-path>`.
4. **If not found**: Use `Grep` to search `d:/robim_data/src` for the type name.
5. **Return the relevant code** to the user with context.

## Directory Structure of d:/robim_data

```
d:/robim_data/
  src/
    Robim.Data/               -- Hand-written C# core data models
      Geometry/               -- Point, Box, Plane, Mesh, PolyLineCurve, etc.
      Math/                   -- Vector, Matrix3D, Quaternion, Euler, Transform3D, etc.
      Process/                -- Pose, JointState, ArmPlanData, Process, etc.
      ProfileCutting/         -- Profile, Part, Nest, Macro, etc.
      Common/                 -- Extension methods, diff builder
      Display/                -- Display extensions
      Protobuf/               -- .proto definition files (ArcWeldingCraft, WeldSeam, Cmd, etc.)
    Robim.Data.Proto/         -- Nuget packaging for proto files
    Robim.Service.Core/       -- Service implementations (CommonServer, DeviceServiceImpl, etc.)
    Robim.Data.Wpf/           -- WPF controls and viewmodels
    Robim.Data.Test/          -- Test projects
    robim_data_cpp/           -- C++ bindings
    java/                     -- Java bindings
```

## Key Namespaces and Where to Find Them

| Namespace | Likely Source |
|-----------|---------------|
| `Robim.Data` | `src/Robim.Data/*.cs` or `Common/`, `Uitilitys/` |
| `Robim.Data.Geometry` | `src/Robim.Data/Geometry/*.cs` |
| `Robim.Data.Math` | `src/Robim.Data/Math/*.cs` |
| `Robim.Data.Process` | `src/Robim.Data/Process/*.cs` |
| `Robim.Data.Process.Cutting` | `src/Robim.Data/Process/*.cs` |
| `Robim.Data.ProfileCutting` | `src/Robim.Data/ProfileCutting/*.cs` |
| `Robim.Data.ArcWeldingCraft` | `src/Robim.Data/Protobuf/ArcWeldingCraft.proto` |
| `Robim.Data.Weld` | `src/Robim.Data/Protobuf/WeldSeam.proto` or `WeldSeamV3.proto` |
| `Robim.Data.Scanning` | `src/Robim.Data/Protobuf/Vision*.proto` |
| `Robim.Data.Coarse` | `src/Robim.Data/Protobuf/Vision*.proto` |
| `Robim.Data.Service` | `src/Robim.Data/Protobuf/*.proto` (CloudPlatform, etc.) |

## Proto File → C# Namespace Mapping

Proto files under `src/Robim.Data/Protobuf/` generate C# types in namespaces
matching the `package` declaration in each `.proto` file. For example:
- `ArcWeldingCraft.proto` → `package Robim.Data.ArcWeldingCraft`
- `WeldSeam.proto` → `package Robim.Data.Weld`
- `VisionBasicModel.proto` → contains `Robim.Data.Coarse`, `Robim.Data.Scanning`

When searching for proto-generated types, grep both the `.proto` file (for schema)
and the `obj/` generated `.cs` files if you need the exact generated C# code.

## Index Maintenance

The file `references/type-index.md` is a pre-generated index of all public types.
If the user reports that types are missing or outdated, run the index script with pwsh 7 (UTF-8 default):
`pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/update-index.ps1`
