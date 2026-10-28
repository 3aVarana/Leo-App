#!/bin/sh
#
# Xcode Cloud runs this right after it clones the repo.
# Xcode Cloud numbers every build itself (CI_BUILD_NUMBER) and uses that number when it exports
# the archive, so the project's CURRENT_PROJECT_VERSION is ignored. Writing CI_BUILD_NUMBER into
# the project keeps the build setting, the logs and TestFlight on the same number.
# The change only lives in Xcode Cloud's clone; nothing is committed back.

set -eu

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "ci_post_clone: CI_BUILD_NUMBER is not set" >&2
    exit 1
fi

project="$CI_PRIMARY_REPOSITORY_PATH/Leo.xcodeproj/project.pbxproj"

sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/" "$project"

echo "ci_post_clone: set CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER"
