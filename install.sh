#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
MC_VERSION="26.2"
LWJGL_VERSION="3.4.1"
POLYMC_URL="https://github.com/PolyMC/PolyMC/releases/download/7.1/PolyMC-Linux-amd64-7.1.AppImage"

# Target installation directory on Steam Deck
targetDir="$HOME/.local/share/PolyMC"

# All 6 core mods fetched directly from Modrinth API
MODRINTH_MODS=(
    "fabric-api"
    "yacl"
    "controlify"
    "mcwifipnp"
    "sodium"
    "modmenu"
)
# ==============================================================================

fail() {
    echo -e "\n\n❌ $1\n"
    zenity --error --text="$1" 2>/dev/null || true
    exit 1
}

# 1. Determine Java version requirement automatically
if [[ "$MC_VERSION" =~ ^2[6-9]\. ]]; then
    JAVA_VERSION="25"
elif [[ "$MC_VERSION" =~ ^1\.(2[1-9]|20\.[5-9]) ]]; then
    JAVA_VERSION="21"
else
    JAVA_VERSION="17"
fi

if [ ! -d "$targetDir" ]; then
    [ $(df /home | awk '$6 == "/home" { print $4 }') -lt 2000000 ] && fail 'Please make sure you have at least 2GB available on internal storage.'
    zenity --question --text="Install Minecraft $MC_VERSION Splitscreen (Fabric + PolyMC)?" 2>/dev/null || true
fi

mkdir -p "$targetDir"
pushd "$targetDir" >/dev/null

    # 2. Download PolyMC AppImage
    if [ ! -f "PolyMC-Linux-x86_64.AppImage" ]; then
        echo "📦 Downloading PolyMC..."
        if ! curl -fL --progress-bar "$POLYMC_URL" -o "PolyMC-Linux-x86_64.AppImage"; then
            rm -f "PolyMC-Linux-x86_64.AppImage"
            fail "Downloading PolyMC failed."
        fi
        chmod +x "PolyMC-Linux-x86_64.AppImage"
        echo "✅ PolyMC ready."
    else
        echo "✅ PolyMC-Linux-x86_64.AppImage already present."
    fi

    # 3. Download Java Runtime (Java 25 / 21 / 17 into ./java/)
    if [ ! -f "java/bin/java" ]; then
        echo "📦 Downloading Java $JAVA_VERSION..."
        if ! curl -fL --progress-bar "https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/x64/jdk/hotspot/normal/eclipse" -o "java.tar.gz"; then
            rm -f "java.tar.gz"
            fail "Downloading Java $JAVA_VERSION failed."
        fi
        echo -n "📦 Extracting Java..."
        mkdir -p java
        if tar -xzf java.tar.gz -C java --strip-components=1 && rm -f java.tar.gz; then
            echo -e "\r\033[K✅ Java $JAVA_VERSION extracted"
        else
            echo -e "\r\033[K❌ Extracting Java failed"
            rm -rf java java.tar.gz
            fail 'Extracting Java failed.'
        fi
    else
        echo "✅ Java runtime already present."
    fi

    # 4. Resolve Recommended Fabric Loader Version via API
    echo "🔍 Querying Fabric Meta for recommended loader..."
    FABRIC_LOADER_VERSION=$(curl -s "https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}" | jq -r '.[0].loader.version // empty')
    if [[ -z "$FABRIC_LOADER_VERSION" ]]; then
        FABRIC_LOADER_VERSION="0.19.3" # Fallback baseline
    fi
    echo "✅ Using Fabric Loader: $FABRIC_LOADER_VERSION"

    # 5. Fetch all mods from Modrinth API
    mkdir -p repo_mods
    rm -f repo_mods/*.jar
    pushd repo_mods >/dev/null
        for mod in "${MODRINTH_MODS[@]}"; do
            echo "📦 Fetching latest $mod for Minecraft $MC_VERSION from Modrinth..."
            download_url=$(curl -sG "https://api.modrinth.com/v2/project/$mod/version" \
                --data-urlencode "game_versions=[\"$MC_VERSION\"]" \
                --data-urlencode 'loaders=["fabric"]' \
                | jq -r '.[0].files[] | select(.primary == true or .primary == null) | .url' | head -n 1)

            if [[ -z "$download_url" || "$download_url" == "null" ]]; then
                echo "⚠️ Could not find a compatible $mod build for $MC_VERSION"
            else
                filename=$(basename "$download_url")
                if curl -fSL "$download_url" -o "$filename"; then
                    echo "✅ Downloaded $filename"
                fi
            fi
        done
    popd >/dev/null

    # 6. PolyMC global configuration
    if [ ! -f polymc.cfg ]; then
        cat <<EOF > polymc.cfg
[General]
ApplicationTheme=system
ConfigVersion=1.2
FlameKeyShouldBeFetchedOnStartup=false
IconTheme=pe_colored
JavaPath=java/bin/java
Language=en_US
LastHostname=$HOSTNAME
MaxMemAlloc=4096
MinMemAlloc=512
UseNativeOpenAL=true
EOF
    fi

    # 7. Create/Update the 4 static instances
    for i in {1..4}; do
        instanceDir="instances/splitscreen-$i"
        mkdir -p "$instanceDir/.minecraft/mods" "$instanceDir/.minecraft/config"
        pushd "$instanceDir" >/dev/null

            # Safely replace only mod JARs (saves & configs are untouched)
            rm -f .minecraft/mods/*.jar
            cp ../../repo_mods/*.jar .minecraft/mods/

            # Standard options
            if [ ! -f ".minecraft/options.txt" ]; then
                echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none\npauseOnLostFocus:false" > .minecraft/options.txt
                if [ "$i" -gt 1 ]; then
                    echo "soundCategory_music:0" >> .minecraft/options.txt
                fi
            fi

            # Auto LAN server entry
            if [ ! -f ".minecraft/servers.dat" ]; then
                echo -ne '\n\0\0\x09\0\x07servers\n\0\0\0\x01\x08\0\x02ip\0\x0f127.0.0.1:47283\x08\0\x04name\0\x0bSplitscreen\0\0' > .minecraft/servers.dat
            fi

            # Write instance.cfg
            cat <<EOF > "instance.cfg"
[General]
ConfigVersion=1.2
InstanceType=OneSix
JavaPath=java/bin/java
OverrideJavaLocation=true
iconKey=default
name=splitscreen-$i
JvmArgs=-Dorg.lwjgl.openal.libname=/usr/lib/libopenal.so
OverrideJavaArgs=true
EOF

            # Write Fabric mmc-pack.json
            cat <<EOF > "mmc-pack.json"
{
    "components": [
        {
            "cachedName": "LWJGL 3",
            "cachedVersion": "$LWJGL_VERSION",
            "cachedVolatile": true,
            "dependencyOnly": true,
            "uid": "org.lwjgl3",
            "version": "$LWJGL_VERSION"
        },
        {
            "cachedName": "Minecraft",
            "cachedRequires": [
                {
                    "suggests": "$LWJGL_VERSION",
                    "uid": "org.lwjgl3"
                }
            ],
            "cachedVersion": "$MC_VERSION",
            "important": true,
            "uid": "net.minecraft",
            "version": "$MC_VERSION"
        },
        {
            "cachedName": "Intermediary Mappings",
            "cachedRequires": [
                {
                    "equals": "$MC_VERSION",
                    "uid": "net.minecraft"
                }
            ],
            "cachedVersion": "$MC_VERSION",
            "important": true,
            "uid": "net.fabricmc.intermediary",
            "version": "$MC_VERSION"
        },
        {
            "cachedName": "Fabric Loader",
            "cachedRequires": [
                {
                    "uid": "net.fabricmc.intermediary"
                }
            ],
            "cachedVersion": "$FABRIC_LOADER_VERSION",
            "important": true,
            "uid": "net.fabricmc.fabric-loader",
            "version": "$FABRIC_LOADER_VERSION"
        }
    ],
    "formatVersion": 1
}
EOF
        popd >/dev/null
    done

    # 8. Create offline account profiles (P1 - P4)
    if [ ! -f "accounts.json" ]; then
        cat <<EOF > accounts.json
{
    "accounts": [
        {
            "active": true,
            "entitlement": { "canPlayMinecraft": true, "ownsMinecraft": true },
            "profile": { "capes": [], "id": "99f7b67dff4a3921ab1855d7abaafc82", "name": "P1", "skin": { "id": "", "url": "", "variant": "" } },
            "type": "Offline",
            "ygg": { "extra": { "clientToken": "bf6cb3d6c80d4448a932522de4a51d51", "userName": "P1" }, "iat": 1745307597, "token": "0" }
        },
        {
            "entitlement": { "canPlayMinecraft": true, "ownsMinecraft": true },
            "profile": { "capes": [], "id": "45c6ab0a786e3272b6806c93ba62c2b4", "name": "P2", "skin": { "id": "", "url": "", "variant": "" } },
            "type": "Offline",
            "ygg": { "extra": { "clientToken": "878b7cd9a9e34505b64efde6ce1f9470", "userName": "P2" }, "iat": 1745307602, "token": "0" }
        },
        {
            "entitlement": { "canPlayMinecraft": true, "ownsMinecraft": true },
            "profile": { "capes": [], "id": "ac4e5ee749823b818186f0480155d43d", "name": "P3", "skin": { "id": "", "url": "", "variant": "" } },
            "type": "Offline",
            "ygg": { "extra": { "clientToken": "de836a1d55a448e091cf21ed2800bf1a", "userName": "P3" }, "iat": 1745307605, "token": "0" }
        },
        {
            "entitlement": { "canPlayMinecraft": true, "ownsMinecraft": true },
            "profile": { "capes": [], "id": "35b0aa2bc5633d5b9f98490635965826", "name": "P4", "skin": { "id": "", "url": "", "variant": "" } },
            "type": "Offline",
            "ygg": { "extra": { "clientToken": "5d36c1ee9be04fe8a0d256cbbd3af3d2", "userName": "P4" }, "iat": 1745307609, "token": "0" }
        }
    ],
    "formatVersion": 3
}
EOF
    fi

popd >/dev/null

echo "✅ Installation completed successfully!"