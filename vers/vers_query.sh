#!/bin/bash 
 
 set -euo pipefail
 
 base_folder=${base_folder:-$HOME/src/itc-deployment-tools}
 # bash /home/baum/src/python/vers/vers_query.sh --env ci1 --os windows --version 5.0.0.822

 
 usage() {
   echo "usage: $0 [--base <itc-deployment-tools>] --env <env> --os <windows|mac> --version <ver> [--arch <arch>] [--kind <kind>]" >&2
 }
 
 die() {
   echo "error: $*" >&2
   exit 1
 }
 
 require_cmd() {
   command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
 }
 
 entry_for() {
   local versions_json="$1"
   local os="$2"
   local arch="$3"
   local kind="$4"
   local ver="$5"
 
   jq -c --arg os "$os" --arg arch "$arch" --arg kind "$kind" --arg ver "$ver" '
     .installers[]
     | select(.kind == $os and .architecture == $arch)
     | .components[]
     | select(.kind == $kind)
     | .versions[]
     | select(.version == $ver)
   ' "$versions_json" | head -n 1
 }
 
 tenant_list_for() {
   local landlord_json="$1"
   local os="$2"
   local kind="$3"
   local arch="$4"
   local ver="$5"
 
   jq -c --arg os "$os" --arg kind "$kind" --arg arch "$arch" --arg ver "$ver" '
     .data
     | map(
         select(
           .os == $os
           and .version == $ver
           and ((.architecture? == $arch) or (has("architecture") | not))
           and (
             .kind == $kind
             or ($kind == "autoupdater" and .kind == "autupdater")
           )
         )
       )
     | (.[0].tenants // [])
   ' "$landlord_json"
 }
 
 ui_max_for() {
   local ui_json="$1"
   local os="$2"
   local kind="$3"
   local arch="$4"
   local ver="$5"
   local tags_json="$6"
 
   jq -r --arg os "$os" --arg kind "$kind" --arg arch "$arch" --arg ver "$ver" --argjson tags "$tags_json" '
     (
       .groups
       | map(.entries[])
       | map(select(."components.kind" == $kind))
       | map(.entries[])
       | map(select(.type == "custom" and .version == $ver and .kind == $os and .architecture == $arch and (."components.versions.tags" // []) == $tags))
       | .[0]
     ) as $custom
     | if $custom then
         "custom"
       else
         (
           .groups
           | map(.entries[])
           | map(select(."components.kind" == $kind))
           | map(.entries[])
           | map(select(.type == "filter"))
           | map(select((.filters.kind // "") == $os and (.filters.architecture // "") == $arch and ((.filters."components.versions.tags" // []) == $tags)))
           | .[0].max
         )
       end
   ' "$ui_json" 2>/dev/null || echo ""
 }
 
 main() {
   require_cmd jq
 
   local base="$base_folder"
   local env=""
   local os=""
   local arch="x64"
   local kind="bundle"
   local ver=""
 
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --base)
         base="${2:-}"; shift 2 ;;
       --env)
         env="${2:-}"; shift 2 ;;
       --os)
         os="${2:-}"; shift 2 ;;
       --arch)
         arch="${2:-}"; shift 2 ;;
       --kind)
         kind="${2:-}"; shift 2 ;;
       --version)
         ver="${2:-}"; shift 2 ;;
       -h|--help)
         usage
         exit 0
         ;;
       *)
         usage
         die "unknown arg: $1"
         ;;
     esac
   done
 
   [[ -n "$env" ]] || die "--env is required"
   [[ -n "$os" ]] || die "--os is required"
   [[ -n "$ver" ]] || die "--version is required"
 
   local versions_json="$base/resources/versions_by_tenants/$env/downloads/versions.json"
   local ui_json="$base/resources/versions_by_tenants/$env/downloads/ui.json"
   local landlord_json="$base/resources/versions_by_tenants/$env/landlord/download_versions_by_tenants.json"
 
   [[ -f "$versions_json" ]] || die "missing file: $versions_json"
   [[ -f "$ui_json" ]] || die "missing file: $ui_json"
   [[ -f "$landlord_json" ]] || die "missing file: $landlord_json"
 
   local parent
   parent="$(entry_for "$versions_json" "$os" "$arch" "$kind" "$ver")"
   [[ -n "$parent" ]] || die "version not found in downloads: os=$os arch=$arch kind=$kind version=$ver"
 
   local parent_tags
   parent_tags="$(jq -c '.tags // []' <<<"$parent")"
   local parent_limited
   parent_limited="$(jq -r '.limitedDistribution // false' <<<"$parent")"
 
   local parent_ui
   parent_ui="$(ui_max_for "$ui_json" "$os" "$kind" "$arch" "$ver" "$parent_tags")"
 
   local parent_tenants
   parent_tenants="$(tenant_list_for "$landlord_json" "$os" "$kind" "$arch" "$ver")"
   local parent_tenant_str
   if [[ "$(jq 'length' <<<"$parent_tenants")" -eq 0 ]]; then
     parent_tenant_str="none"
   else
     parent_tenant_str="$(jq -r 'map(tostring) | join(",")' <<<"$parent_tenants")"
   fi
 
   local updaters_json
   updaters_json="$(jq -c '.related.updater // [] | map(.version) | map(select(. != null))' <<<"$parent")"
 
   local updater_summaries=""
   local updater_ver
   while IFS= read -r updater_ver; do
     [[ -n "$updater_ver" ]] || continue
 
     local upd
     upd="$(entry_for "$versions_json" "$os" "$arch" "autoupdater" "$updater_ver")"
 
     local upd_tags="[]"
     local upd_limited="false"
     if [[ -n "$upd" ]]; then
       upd_tags="$(jq -c '.tags // []' <<<"$upd")"
       upd_limited="$(jq -r '.limitedDistribution // false' <<<"$upd")"
     fi
 
     local upd_ui
     upd_ui="$(ui_max_for "$ui_json" "$os" "autoupdater" "$arch" "$updater_ver" "$upd_tags")"
 
     local upd_tenants
     upd_tenants="$(tenant_list_for "$landlord_json" "$os" "autoupdater" "$arch" "$updater_ver")"
     local upd_tenant_str
     if [[ "$(jq 'length' <<<"$upd_tenants")" -eq 0 ]]; then
       upd_tenant_str="none"
     else
       upd_tenant_str="$(jq -r 'map(tostring) | join(",")' <<<"$upd_tenants")"
     fi
 
     local upd_tags_str
     upd_tags_str="$(jq -r 'map(tostring) | join("|")' <<<"$upd_tags")"
     [[ -n "$upd_tags_str" ]] || upd_tags_str=""
 
     local upd_piece
     upd_piece="$updater_ver(tags=[$upd_tags_str] limited=$upd_limited tenantLimit=$upd_tenant_str uiMax=$upd_ui)"
 
     if [[ -z "$updater_summaries" ]]; then
       updater_summaries="$upd_piece"
     else
       updater_summaries+=";$upd_piece"
     fi
   done < <(jq -r '.[]' <<<"$updaters_json")
 
   local parent_tags_str
   parent_tags_str="$(jq -r 'map(tostring) | join("|")' <<<"$parent_tags")"
   [[ -n "$parent_tags_str" ]] || parent_tags_str=""
 
   echo "env=$env os=$os arch=$arch kind=$kind ver=$ver tags=[$parent_tags_str] limited=$parent_limited tenantLimit=$parent_tenant_str uiMax=$parent_ui updaters=[$updater_summaries]"
 }
 
 main "$@"
