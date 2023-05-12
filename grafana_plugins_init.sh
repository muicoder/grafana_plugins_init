#!/bin/sh

set -e

pluginsVolume="/opt/plugins/plugins_init"
mkdir -p "$pluginsVolume"
POD_NS=$(
  if [ -s /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
    cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
  else
    echo default
  fi
)

_extract() {
  zip=${1?-no such file}
  if unzip -qo "$zip" -d "$pluginsVolume"; then
    echo "successfully...${zip##*/}"
  else
    $(which rm) -f "$zip"
  fi
}

install() {
  name=${plugin%:*}
  version=${plugin#*:}
  if [ "$version" = "$plugin" ]; then
    version="latest"
  fi
  url="https://grafana.com/api/plugins/$name/versions/$version/download"
  if [ ! -s "$pluginsVolume/$name-$version.zip" ]; then
    wget -O "/tmp/$name-$version.zip" "$url"
    _extract "/tmp/$name-$version.zip"
    $(which mv) -f "/tmp/$name-$version.zip" "$pluginsVolume/$name-$version.zip"
  else
    echo "[installed]$name:$version"
  fi
}

for plugin in $(echo "$GRAFANA_PLUGINS" | sed 's~,~ ~g'); do
  export plugin="$plugin"
  install
done

find "$pluginsVolume" -type f -name "*.$POD_NS.url" -print0 | xargs sort | uniq | while IFS= read -r url; do
  if grep "${url##*/}" "$pluginsVolume/.plugins.$POD_NS.installed" >/dev/null 2>&1; then
    echo "[installed]${url##*/}"
  else
    wget -O "/tmp/${url##*/}" "$url"
    _extract "/tmp/${url##*/}"
    echo "${url##*/}" >>"$pluginsVolume/.plugins.$POD_NS.installed"
  fi
done

# uid=472(grafana)
chown 472:0 -R "$pluginsVolume"
