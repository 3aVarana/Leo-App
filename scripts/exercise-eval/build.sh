#!/bin/bash
# Compiles the app's exercise generator with main.swift into a command-line harness, without
# touching the Xcode project. Needs a Mac with Apple Intelligence turned on. See README.md.
#
#     scripts/exercise-eval/build.sh            # writes build/exercise-eval/harness
#     scripts/exercise-eval/build.sh <out-dir>

set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${1:-$root/build/exercise-eval}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Everything ExerciseGenerator needs, and nothing that imports SwiftUI.
files=(
    Leo/Domain/AgeGroup.swift
    Leo/Domain/ComprehensionSkill.swift
    Leo/Domain/Exercise.swift
    Leo/Domain/RoundTopic.swift
    Leo/Domain/Topic.swift
    Leo/Data/FoundationModels/ContentLanguage.swift
    Leo/Data/FoundationModels/ExerciseGenerator.swift
    Leo/Data/FoundationModels/GeneratedExercise.swift
    Leo/Data/FoundationModels/PromptVocabulary.swift
    Leo/Data/Repositories/ExerciseRepository.swift
)
# Files that exist only from a given version of the app on.
optional_files=(
    Leo/Data/FoundationModels/ExerciseRepair.swift
)

for file in "${files[@]}"; do
    cp "$root/$file" "$work/"
done
for file in "${optional_files[@]}"; do
    if [[ -f "$root/$file" ]]; then cp "$root/$file" "$work/"; fi
done
cp "$root/scripts/exercise-eval/main.swift" "$work/"

mkdir -p "$out"
swiftc -parse-as-library -O "$work"/*.swift -o "$out/harness"
echo "Built $out/harness"
