#!/bin/bash
set +x
set -eu
if ! open -Ra Claude; then open 'https://claude.com/download'; echo 'Install Claude Desktop and reopen this launcher.'; exit 1; fi
settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
field() {
    local value
    if value=$(/usr/bin/plutil -extract "env.$1" raw -o - "$settings" 2>/dev/null); then
        printf '%s' "$value"
    fi
}
endpoint=$(field ANTHROPIC_BASE_URL)
token=''
if [[ -n $endpoint ]]; then token=$(field ANTHROPIC_AUTH_TOKEN); fi
model=$(field ANTHROPIC_MODEL)
[[ -n $endpoint ]] || IFS= read -r -p 'HTTPS gateway base URL: ' endpoint
[[ $endpoint =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/[^[:space:]?#]*)?$ && $endpoint != *\\* ]] || exit 2
[[ -n $model ]] || IFS= read -r -p 'Gateway model ID: ' model
[[ $model =~ [^[:space:]] ]] || exit 2
[[ -n $token ]] || IFS= read -rs -p 'Gateway token (saved in a personal macOS profile): ' token
printf '\n'
[[ -n $token && $token != *[[:cntrl:]]* ]] || exit 2
umask 077
stage=$(mktemp -d)
profile="$stage/Claude Gateway.mobileconfig"
trap 'rm -f "$profile" "$stage/request.json" "$stage/reply.json"; rmdir "$stage"' EXIT
marker="OK$(/usr/bin/uuidgen | cut -c1-8)"
KIT_MODEL="$model" KIT_MARKER="$marker" /usr/bin/osascript -l JavaScript > "$stage/request.json" <<'JXA'
ObjC.import('Foundation')
const env=$.NSProcessInfo.processInfo.environment
const get=k=>ObjC.unwrap(env.objectForKey(k))
JSON.stringify({model:get('KIT_MODEL'),max_tokens:96,messages:[{role:'user',content:'Return exactly '+get('KIT_MARKER')}]})
JXA
printf 'Authorization: Bearer %s\n' "$token" | /usr/bin/curl --disable --silent --show-error --fail --max-time 75 --proto '=https' --header @- --header 'anthropic-version: 2023-06-01' --header 'Content-Type: application/json' --data-binary "@$stage/request.json" --output "$stage/reply.json" "${endpoint%/}/v1/messages"
KIT_REPLY="$stage/reply.json" KIT_MARKER="$marker" /usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Foundation')
const env=$.NSProcessInfo.processInfo.environment
const get=k=>ObjC.unwrap(env.objectForKey(k))
const payload=JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(get('KIT_REPLY'),$.NSUTF8StringEncoding,null)))
if (!Array.isArray(payload.content) || !payload.content.some(b=>b.type==='text' && b.text.trim()===get('KIT_MARKER'))) throw Error('Gateway reply verification failed.')
JXA
echo 'Gateway replied using the selected model.'
managed_matches() {
    KIT_ENDPOINT="$endpoint" KIT_MODEL="$model" KIT_TOKEN="$token" /usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Foundation')
ObjC.import('CoreFoundation')
const env=$.NSProcessInfo.processInfo.environment
const get=k=>ObjC.unwrap(env.objectForKey(k))
const domain='com.anthropic.claudefordesktop'
const read=k=>ObjC.deepUnwrap($.CFPreferencesCopyAppValue($(k),$(domain)))
const provider=read('inferenceProvider')
if (provider == null) 'absent'
else if (provider==='gateway' && read('inferenceGatewayBaseUrl')===get('KIT_ENDPOINT').replace(/\/$/,'') && read('inferenceGatewayApiKey')===get('KIT_TOKEN') && (read('inferenceModels')||[]).some(m=>m.name===get('KIT_MODEL'))) 'match'
else 'different'
JXA
}
state=$(managed_matches)
case "$state" in
different) echo 'Existing Desktop preferences differ. Review the active profile in System Settings.'; exit 1 ;;
absent)
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
/usr/bin/plutil -lint "$profile" >/dev/null
open "$profile"
IFS= read -r -p 'Approve the profile in System Settings. After installation press Return here: ' done_install
[[ $(managed_matches) == match ]] || { echo 'The approved gateway profile could not be verified.'; exit 1; }
echo 'If Claude Desktop was already running, fully quit and reopen it to load the profile.'
;;
match) echo 'Existing Desktop gateway profile verified.' ;;
*) exit 1 ;;
esac
unset token
open -a Claude
/usr/bin/osascript <<'APPLESCRIPT'
with timeout of 45 seconds
    tell application "System Events"
        repeat 12 times
            tell application process "Claude"
                if exists front window then
                    set sawGateway to false
                    set sawComposer to false
                    repeat with itemRef in (entire contents of front window)
                        try
                            set labelText to (name of itemRef as text) & " " & (description of itemRef as text)
                            if labelText contains "Gateway" then set sawGateway to true
                            if role of itemRef is "AXTextArea" then set sawComposer to true
                        end try
                    end repeat
                    if sawGateway and sawComposer then return "Claude Desktop gateway workspace verified."
                end if
            end tell
            delay 2
        end repeat
    end tell
end timeout
error "Desktop opened. Gateway and message input could not be verified. Check the window and macOS Accessibility permission."
APPLESCRIPT
