#!/usr/bin/env bash
# Disposable staging checkout only. Requires editor + exact retail templates,
# a complete export preset, xvfb, and room for one build at a time.
set -euo pipefail
if [[ "$#" != 3 || "${NERIS_DISPOSABLE_STAGE:-}" != 1 ]]; then
  echo "Usage: NERIS_DISPOSABLE_STAGE=1 $0 staging-checkout godot-editor roomy-output" >&2
  exit 2
fi
root="$(realpath "$1")"
editor="$(realpath "$2")"
out="$(realpath -m "$3")"
if [[ -e "$out" && -n "$(ls -A "$out")" ]]; then
  echo "Output must be a fresh empty directory." >&2; exit 2
fi
mkdir -p "$out"/{bin,away,new,old,off,invalid-old,first-clear,load,transfer}
cd "$root"
test -r export_presets.cfg && test -r game/overworld/neris_normal_entry.gd
if [[ -e override.cfg ]]; then
  echo "Use a clean stage without override.cfg." >&2; exit 2
fi
test -r tests/native_neris_release_smoke.gd && test -r tests/native_neris_bake_qa.gd
cp project.godot "$out/project.before"
restore() { cp "$out/project.before" "$root/project.godot"; }
trap restore EXIT
python3 - <<'PYCI'
from pathlib import Path
p=Path('project.godot')
raw=p.read_text()
assert raw.count('[autoload]\n')==raw.count('neris_3d_overworld=true')==1
raw=raw.replace('[autoload]\n','[autoload]\nNativeNerisReleaseSmoke="*res://tests/native_neris_release_smoke.gd"\nNativeNerisBakeQA="*res://tests/native_neris_bake_qa.gd"\n')
p.write_text(raw)
PYCI
"$editor" --headless --path "$root" --import > "$out/import.log" 2>&1
"$editor" --headless --path "$root" --export-release "Linux x86_64" "$out/bin/torn-asunder.x86_64" > "$out/export.log" 2>&1
[[ -x "$out/bin/torn-asunder.x86_64" && ! -e "$out/bin/torn-asunder.pck" ]]
seed_old() {
  local target="$out/$1/godot/app_userdata/Torn Asunder/profile.cfg"
  mkdir -p "$(dirname "$target")"
  printf '[campaigns]\nmara=1\nsova=2\nneris=3\n\n[campaign_waypoints]\nmara="year_one_mine"\nsova="year_one_mine"\nneris="year_one_mine"\n\n[mission_progress]\nneris=PackedStringArray("neris_failing_grove", "%s")\n\n[settings]\nfullscreen=false\n' "$2" > "$target"
}
run_case() (
  cd "$out/away"
  export XDG_DATA_HOME="$out/$1" XDG_CONFIG_HOME="$out/$1"
  export LIBGL_ALWAYS_SOFTWARE=1 MESA_SHADER_CACHE_DISABLE=true LP_NUM_THREADS=2 NERIS_QA_EXPECT_RETAIL=1
  case "$1" in
    new) NERIS_PRIVATE_QA=travel timeout 210s "$out/bin/torn-asunder.x86_64" --headless 2>&1 | tee "$out/new.log"; grep -E '^True shared ae6 title Neris travel: [0-9]+ passed, 0 failed\.' "$out/new.log" ;;
    old) NERIS_PRIVATE_QA=old xvfb-run -a timeout 120s "$out/bin/torn-asunder.x86_64" --audio-driver Dummy --windowed --resolution 1280x720 2>&1 | tee "$out/cold.log"; grep -E '^True shared ae6 title Neris old: [0-9]+ passed, 0 failed\.' "$out/cold.log" ;;
    load|transfer) NERIS_BAKE_QA="$1" xvfb-run -a timeout 185s "$out/bin/torn-asunder.x86_64" --audio-driver Dummy --windowed --resolution 1280x720 2>&1 | tee "$out/$1.log"; grep -E "^Shared ae6 baked $1: [0-9]+ passed, 0 failed\." "$out/$1.log" ;;
    *) NERIS_PRIVATE_QA="$1" timeout 240s "$out/bin/torn-asunder.x86_64" --headless 2>&1 | tee "$out/$1.log"; grep -E "True shared ae6 title Neris $1: [0-9]+ passed, 0 failed\." "$out/$1.log" ;;
  esac
)
seed_old old neris_cairnspine_survey
seed_old invalid-old mara_mine_escort
run_case new
run_case first-clear
run_case old
run_case invalid-old
run_case load
run_case transfer
run_case off
