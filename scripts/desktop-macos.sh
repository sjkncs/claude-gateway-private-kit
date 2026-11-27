#!/bin/bash
set +x
set -eu
if ! open -Ra Claude; then open 'https://claude.com/download'; echo 'Install Claude Desktop and reopen this launcher.'; exit 1; fi
IFS= read -r -p 'HTTPS gateway base URL: ' endpoint
[[ $endpoint =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/[^[:space:]?#]*)?$ && $endpoint != *\\* ]] || exit 2
IFS= read -r -p 'Gateway model ID: ' model
[[ $model =~ [^[:space:]] ]] || exit 2
IFS= read -rs -p 'Gateway token (saved in a personal macOS profile): ' token
printf '\n'
[[ -n $token ]] || exit 2
umask 077
stage=$(mktemp -d)
profile="$stage/Claude Gateway.mobileconfig"
trap 'rm -f "$profile"; rmdir "$stage"' EXIT
KIT_ENDPOINT="$endpoint" KIT_MODEL="$model" KIT_TOKEN="$token" /usr/bin/osascript -l JavaScript > "$profile" <<'JXA'
ObjC.import('Foundation')
const env=$.NSProcessInfo.processInfo.environment
const get=k=>ObjC.unwrap(env.objectForKey(k))
const id=()=>ObjC.unwrap($.NSUUID.UUID.UUIDString)
const common={PayloadVersion:1,PayloadDisplayName:'Claude Desktop Gateway'}
const domain='com.anthropic.claudefordesktop'
const child=Object.assign({},common,{PayloadType:domain,PayloadIdentifier:'org.claudegatewaykit.user.desktop',PayloadUUID:id(),inferenceProvider:'gateway',inferenceGatewayBaseUrl:get('KIT_ENDPOINT').replace(/\/$/,''),inferenceGatewayAuthScheme:'bearer',inferenceGatewayApiKey:get('KIT_TOKEN'),inferenceModels:[{name:get('KIT_MODEL')}]})
const root=Object.assign({},common,{PayloadType:'Configuration',PayloadScope:'User',PayloadIdentifier:'org.claudegatewaykit.user',PayloadUUID:id(),PayloadContent:[child]})
const data=$.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError($(root),100,0,null)
ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data,$.NSUTF8StringEncoding))
JXA
unset token
/usr/bin/plutil -lint "$profile" >/dev/null
open "$profile"
IFS= read -r -p 'Approve the profile in System Settings. After installation press Return here: ' done_install
echo 'If Claude Desktop was already running, fully quit and reopen it to load the profile.'
open -a Claude
