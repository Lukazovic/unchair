#!/bin/bash
# Creates the EdDSA key pair that signs Unchair updates.
#
# - The private key goes into your login Keychain (Sparkle's default) and is
#   also exported to ~/.unchair/sparkle_private_key so you can add it to the
#   GitHub secret SPARKLE_PRIVATE_KEY. Never commit it.
# - The public key is written into Config/Unchair-Info.plist (SUPublicEDKey).
#
# Run once. Running again keeps the existing Keychain key.
set -euo pipefail
cd "$(dirname "$0")/.."

generate_keys=$(scripts/sparkle-tool.sh generate_keys)
"$generate_keys"
public_key=$("$generate_keys" -p)

mkdir -p ~/.unchair
chmod 700 ~/.unchair
"$generate_keys" -x ~/.unchair/sparkle_private_key
chmod 600 ~/.unchair/sparkle_private_key

/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $public_key" Config/Unchair-Info.plist

echo
echo "Public key saved in Config/Unchair-Info.plist: $public_key"
echo "Private key exported to ~/.unchair/sparkle_private_key."
echo "Add it to GitHub: gh secret set SPARKLE_PRIVATE_KEY < ~/.unchair/sparkle_private_key"
