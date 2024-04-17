#!/bin/bash
# Helper script to update version, create commit then push and create release.

major_flag=false
minor_flag=false
patch_flag=false
type_flag=false
yes_flag=false

print_usage() {
  echo -e "\nUsage: $(basename "${0}") [-M|m|p|t|v|y|h]"
  echo "Options :"
  echo "  M  : Increment Major version"
  echo "  m  : Increment minor version"
  echo "  p  : Increment patch version"
  echo "  t  : Change or increment type version"
  echo "  v  : Display project current version"
  echo "  y  : Autovalidate all prompts"
  echo "  h  : Print this help"
}

if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

while getopts 'Mmptvyh' flag; do
  case "${flag}" in
    M) major_flag=true ;;
    m) minor_flag=true ;;
    p) patch_flag=true ;;
    t) type_flag=true ;;
    v) version_flag=true ;;
    y) yes_flag=true ;;
    *) print_usage
       exit 1 ;;
  esac
done


VERSION=$( (sed 's/\/\/.*//' | jq -r '.Version') < manifest.json )

if [[ "${version_flag}" = true ]]; then
    echo "${VERSION}"
    exit
fi

version_regex="([0-9]+)\.([0-9]+)\.([0-9]+)-(.*)"

if ! [[ ${VERSION} =~ ${version_regex} ]]; then
    echo "No match found in ${VERSION}" >&2
    exit
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
type="${BASH_REMATCH[4]}"

if [[ "$major_flag" = true ]]; then
    major=$((major + 1))
    minor=0
    patch=0
    echo "new major = ${major}"

elif [[ "$minor_flag" = true ]]; then
    minor=$((minor + 1))
    patch=0
    echo "new minor = ${minor}"
    type_flag=true
    type="alpha"
    echo "new type = ${type}"

elif [[ "$patch_flag" = true ]]; then
    patch=$((patch + 1))
    echo "new patch = ${patch}"
    type_flag=false
    type="stable"
    echo "new type = ${type}"
fi


if [[ "$type_flag" = true ]]; then
    echo -e "\nChange or update release type? (Current: $type)"
    select yn in "stable" "alpha" "beta" "rc"; do
        case "${yn}" in
            stable) new_type_name="stable"; break ;;
            alpha) new_type_name="alpha"; break ;;
            beta) new_type_name="beta"; break ;;
            rc) new_type_name="rc"; break ;;
        esac
    done

    if [[ "$new_type_name" =~ ^(alpha|beta|rc)$ ]]; then
        type_regex="([a-zA-Z]+)([0-9]*)"

        if [[ $type =~ $type_regex ]]; then
            type_name="${BASH_REMATCH[1]}"
            type_ver="${BASH_REMATCH[2]}"
            
            if [[ -z "${type_ver}" ]] || [[ "${type_ver}" -lt 0 ]] || [[ "${new_type_name}" != "${type_name}" ]]; then
                type_ver=0
            fi
            type_ver=$((type_ver + 1))
            type="${new_type_name}${type_ver}"
        fi
        patch=0
    else
        type="${new_type_name}"
    fi
fi


new_version="${major}.${minor}.${patch}-${type}"

function set_new_version () {
    sed -i "/Version/c\    \"Version\": \"${new_version}\"," manifest.json
    echo "New version set to ${new_version}"
}

function push_new_release () {
    git commit -a -m "Change version to ${new_version}"
    git push
    git tag "${new_version}"
    git push --tags
    echo "Released version ${new_version}"
}


if [[ "$yes_flag" = true ]]; then
    set_new_version
    push_new_release
    exit
fi

echo -e "\nChange version to ${new_version} ?"
select yn in "Yes" "No"; do
    case "${yn}" in
        Yes) set_new_version; break ;;
        No) exit ;;
    esac
done

echo -e "\nRelease ${new_version} ?"
select yn in "Yes" "No"; do
    case "${yn}" in
        Yes) push_new_release; break ;;
        No) exit ;;
    esac
done
