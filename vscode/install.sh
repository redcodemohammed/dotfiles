#!/usr/bin/env bash
# vscode/install.sh: install the Hypr colour theme into every VS Code profile (owner, 2026-10-17).
# Run once per machine. VS Code profiles each keep their own extension list, so a folder dropped
# into ~/.vscode/extensions only reaches the Default profile; `code --install-extension --profile`
# reaches the others. A VSIX is a zip: extension/ (the files), extension.vsixmanifest and
# [Content_Types].xml. Afterwards palette/generate.py rewrites the installed theme file at every
# wallpaper change (COPIES in generate.py), so this never needs running again.
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)/hypr-theme
python3 -I "$(dirname "$src")/../palette/generate.py" >/dev/null # the theme file must exist
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/pkg/extension"
cp -r "$src/package.json" "$src/themes" "$tmp/pkg/extension/"
version=$(jq -r .version "$src/package.json")
cat >"$tmp/pkg/extension.vsixmanifest" <<XML
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="hypr-theme" Version="$version" Publisher="local"/>
    <DisplayName>Hypr</DisplayName>
    <Description xml:space="preserve">The desktop palette, regenerated at every wallpaper change</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0"/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
XML
cat >"$tmp/pkg/[Content_Types].xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
XML
(cd "$tmp/pkg" && python3 -I -m zipfile -c "$tmp/hypr-theme.vsix" "[Content_Types].xml" extension.vsixmanifest extension)
# Every profile by name, from VS Code's own list, and the Default profile.
profiles=$(jq -r '.userDataProfiles[]?.name' "$HOME/.config/Code/User/globalStorage/storage.json" 2>/dev/null || true)
code --install-extension "$tmp/hypr-theme.vsix" --force
while IFS= read -r profile; do
    [ -n "$profile" ] || continue
    code --install-extension "$tmp/hypr-theme.vsix" --force --profile "$profile"
done <<<"$profiles"
echo "Installed. In VS Code: Ctrl+K Ctrl+T, pick Hypr."
