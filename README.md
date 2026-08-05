# godot-box3d

A [GDExtension](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/what_is_gdextension.html) that integrates [Box3D](https://github.com/erincatto/box3d), Erin Catto's 3D physics engine, into Godot 4 as a drop-in replacement for the built-in `PhysicsServer3D`.

The structure of this extension is based on [godot-jolt](https://github.com/godot-jolt/godot-jolt), which pioneered swapping out Godot's 3D physics backend via GDExtension.

> **Status: early and experimental.** Box3D itself is a young engine, and this extension is a work in progress. Expect missing features and rough edges.

## What works

- Rigid, static, and kinematic bodies
- Shapes: box, sphere, capsule, cylinder, convex polygon, concave polygon (trimesh), heightmap, and world boundary
- Areas, including overlap events, gravity/damping overrides, priority ordering, and point gravity
- Direct space state queries: ray casts, point and shape intersection, shape casts (`cast_motion`), `collide_shape`, and `rest_info`
- `body_test_motion`, so `CharacterBody3D` and `move_and_slide()` work
- Contact monitoring, so `RigidBody3D` reports real contact points, normals, and impulses
- Per-pair collision exceptions
- Joints: pin, hinge, and slider (pin anchors can be moved after creation)
- A test project (`test_project/`) with a demo hub covering shapes, joints, areas, contacts, collision exceptions, and trimesh, plus a spawn benchmark and 18 headless regression tests

## What's left to do

- Separation ray shapes
- ConeTwist joints
- `Generic6DOFJoint3D` (Box3D has no per-axis lock/limit/motor constraint, so there is no faithful mapping; use `PinJoint3D`, `HingeJoint3D`, or `SliderJoint3D` instead)
- `SoftBody3D`
- Per-shape indices in query and contact results (multi-shape bodies always report shape 0)
- More platforms and architectures (currently Linux, Windows, and macOS builds)
- Performance benchmarking and tuning
- Documentation

## Behavior differences

- **`Area3D` does not detect trimesh or heightmap bodies.** In Box3D a concave shape (`ConcavePolygonShape3D`) or `HeightMapShape3D` can never act as a sensor *visitor*, by design, since testing an arbitrary mesh against a sensor is too expensive.
  So an `Area3D` silently ignores a body whose shape is a trimesh or heightmap: no `body_entered` / `body_exited` fires for it.
  This diverges from Godot's built-in physics (and Jolt), which report such a body on the first physics frame.
  If you need a body to be detected by an area, give it a convex shape. (A trimesh may still be used *as* an `Area3D`'s own shape to detect convex bodies passing through it.)

- **`collide_shape()` reports contact points without penetration depth.** Box3D exposes GJK, which finds the closest points between two shapes but cannot measure how far they already overlap.
  For a genuinely overlapping pair both returned points are the same witness point, so the pair's separation reads as zero, where Godot's built-in physics returns two points whose distance is the penetration depth.
  Whether shapes overlap, which bodies they are, `max_results`, and `collision_mask` all behave normally, so use it to answer "is anything here, and roughly where" rather than "how deep".

- **Shape queries need a convex query shape.** `intersect_shape`, `cast_motion`, `collide_shape`, `rest_info`, and `body_test_motion` build a point-cloud proxy of the shape being queried *with*, and trimesh, heightmap, and world-boundary shapes have no finite point cloud.
  Passing one of those as the query shape returns no results. They work normally as targets in the world.

## Requirements

- Godot 4.3 or newer

## Building

The project builds with CMake:

```sh
cmake -B build
cmake --build build
```

The resulting library is placed in `bin/` and loaded via `godot-box3d.gdextension`. Copy `bin/` and the `.gdextension` file into your project, then select the Box3D physics server in your project settings.

## Testing

With a Godot 4.7 executable available as `godot`, run:

```sh
scripts/run_headless_tests.sh
```

Set `GODOT_BIN=/path/to/godot` when the executable is not on `PATH`. The runner builds the extension, verifies that the Box3D backend loaded, and exits nonzero when any smoke test fails.

## Contributing

Help wanted! This is a big surface area for one person, and contributions of any size are very welcome: missing features from the list above, bug reports with reproduction scenes, benchmarks, documentation, or just trying it in your project and reporting what breaks. Open an issue or a pull request.

## License

MIT. See [LICENSE](LICENSE) for details.

Box3D is licensed under the [MIT license](https://github.com/erincatto/box3d/blob/main/LICENSE). This project takes structural inspiration from [godot-jolt](https://github.com/godot-jolt/godot-jolt), also MIT licensed.
