#!/bin/bash

set -eu

export OVA_ISO_PATH='./tkg-base-ova'

file_path=$(find $OVA_ISO_PATH/ -name "*.ova")

echo "$file_path"

if echo $GOVC_INSECURE == "1"
  then echo "Insecure vCenter Cert"
else
  export GOVC_TLS_CA_CERTS=/tmp/vcenter-ca.pem
  echo "$GOVC_CA_CERT" > "$GOVC_TLS_CA_CERTS"
fi

govc import.spec "$file_path" | python -m json.tool > tkg-base-import.json

cat > filters <<'EOF'
.NetworkMapping[].Network = $network |
.PowerOn = $powerOn
EOF

jq \
  --arg network "$TKG_BASE_PORTGROUP" \
  --argjson powerOn "$TKG_BASE_POWER_ON" \
  --from-file filters \
  tkg-base-import.json > options.json

cat options.json

if [ -z "$VC_VM_FOLDER" ]; then
  govc import.ova -options=options.json "$file_path"
else
  if [ "$(govc folder.info "$VC_VM_FOLDER" 2>&1 | grep "$VC_VM_FOLDER" | awk '{print $2}')" != "$VC_VM_FOLDER" ]; then
    govc folder.create "$VC_VM_FOLDER"
  fi
  govc import.ova -folder="$VC_VM_FOLDER" -options=options.json "$file_path"
fi