#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${BUILD_DIR:-$repo_root/build}"
godot_bin="${GODOT_BIN:-godot}"
test_addon_bin="$repo_root/test_project/addons/godot-box3d/bin"
godot_metadata_dir="$repo_root/test_project/.godot"
jobs="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || printf '4')}"

export CMAKE_BUILD_PARALLEL_LEVEL="$jobs"
if [[ -z "${MAKEFLAGS:-}" ]]; then
	export MAKEFLAGS="-j$jobs"
fi

case "$(uname -s)" in
	Darwin)
		extension_filename="libgodot-box3d.dylib"
		;;
	*)
		extension_filename="libgodot-box3d.so"
		;;
esac
extension_library="$repo_root/bin/$extension_filename"

if [[ -f "$repo_root/.gitmodules" ]]; then
	git -C "$repo_root" submodule update --init --recursive
fi

cmake -S "$repo_root" -B "$build_dir"
cmake --build "$build_dir" --target godot-box3d --parallel "$jobs"

if [[ ! -f "$extension_library" ]]; then
	printf 'ERROR: Expected extension library was not built: %s\n' "$extension_library" >&2
	exit 1
fi

mkdir -p "$test_addon_bin" "$godot_metadata_dir"
ln -sf "$extension_library" "$test_addon_bin/$extension_filename"

# Running a script directly does not scan the project for GDExtensions. Register every
# installed one so tests cannot silently use GodotPhysics3D and other physics addons
# (Rapier, Jolt) stay selectable in the demo project.
: > "$godot_metadata_dir/extension_list.cfg"
for extension in "$repo_root"/test_project/addons/*/*.gdextension; do
	[[ -e "$extension" ]] || continue
	printf 'res://addons/%s\n' "${extension#"$repo_root/test_project/addons/"}" \
		>> "$godot_metadata_dir/extension_list.cfg"
done

backend_test="backend_activation_test.gd"

run_test() {
	local test_script="$1"
	local test_output
	local test_status=0

	printf '\n== %s ==\n' "$test_script"
	test_output="$("$godot_bin" --headless --path "$repo_root/test_project" --script "res://tests/$test_script" 2>&1)" || test_status=$?
	printf '%s\n' "$test_output"

	if (( test_status != 0 )); then
		return "$test_status"
	fi
	if [[ "$test_output" == *"RIDs in Godot Box3D were found to not have been freed"* ]]; then
		printf 'ERROR: %s leaked one or more Box3D RIDs.\n' "$test_script" >&2
		return 1
	fi
}

run_test "$backend_test"

for test_path in "$repo_root"/test_project/tests/*_test.gd; do
	test_script="${test_path##*/}"
	if [[ "$test_script" == "$backend_test" ]]; then
		continue
	fi
	run_test "$test_script"
done
