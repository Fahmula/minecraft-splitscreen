#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
MC_VERSION="26.2"
FABRIC_LOADER_VERSION="0.16.9"
JAVA_VERSION="21"
POLYMC_VERSION="7.1"

# ------------------------------------------------------------------------------
# MOD DOWNLOAD SOURCES (Bookmark / Click to find updates):
# - Fabric API:    https://www.curseforge.com/minecraft/mc-mods/fabric-api/files/all
# - Framework:     https://www.curseforge.com/minecraft/mc-mods/framework/files/all
# - Controllable:  https://www.curseforge.com/minecraft/mc-mods/controllable/files/all
# - mcwifipnp:     https://www.curseforge.com/minecraft/mc-mods/mcwifipnp/files/all
# - Sodium:        https://www.curseforge.com/minecraft/mc-mods/sodium/files/all
# ------------------------------------------------------------------------------
MOD_FILES=(
    "fabric-api.jar"
    "framework-fabric.jar"
    "controllable-fabric.jar"
    "mcwifipnp-fabric.jar"
    "sodium-fabric.jar"
)

REPO_RAW_URL="https://raw.githubusercontent.com/Fahmula/minecraft-splitscreen/refs/heads/main"
targetDir="$HOME/.local/share/PolyMC"
# ==============================================================================

fail() {
    echo -e "\n\n❌ $1\n"
    zenity --error --text="$1" 2>/dev/null || true
    exit 1
}

if [ ! -d "$targetDir" ]; then
    [ $(df /home | awk '$6 == "/home" { print $4 }') -lt 2000000 ] && fail 'Please make sure you have at least 2GB available on internal storage.'
    zenity --question --text='This script will install PolyMC, configure 4 Fabric Splitscreen instances, and add Minecraft to Steam.\n\nContinue?' 2>/dev/null || true
fi

mkdir -p "$targetDir"
pushd "$targetDir" >/dev/null

    # 1. Download PolyMC AppImage
    polyImage="PolyMC-Linux-${POLYMC_VERSION}-x86_64.AppImage"
    polyUrl="https://github.com/PolyMC/PolyMC/releases/download/${POLYMC_VERSION}/${polyImage}"

    if [ ! -f "PolyMC-Linux-x86_64.AppImage" ]; then
        echo "📦 Downloading PolyMC $POLYMC_VERSION..."
        if ! curl -L --progress-bar "$polyUrl" -o "PolyMC-Linux-x86_64.AppImage"; then
            rm -f "PolyMC-Linux-x86_64.AppImage"
            fail "Downloading PolyMC $POLYMC_VERSION failed."
        fi
        chmod +x "PolyMC-Linux-x86_64.AppImage"
        echo "✅ PolyMC ready."
    else
        echo "✅ PolyMC-Linux-x86_64.AppImage already present."
    fi

    # 2. Download Java (Always unpacks cleanly into ./java/)
    if [ ! -f "java/bin/java" ]; then
        echo "📦 Downloading Java $JAVA_VERSION..."
        curl -L --progress-bar "https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/x64/jdk/hotspot/normal/eclipse" -o "java.tar.gz"
        echo -n "📦 Extracting Java..."
        mkdir -p java
        if tar -xzf java.tar.gz -C java --strip-components=1 && rm -f java.tar.gz; then
            echo -e "\r\033[K✅ Java $JAVA_VERSION ready"
        else
            echo -e "\r\033[K❌ Extracting Java failed"
            rm -rf java java.tar.gz
            fail 'Extracting Java failed.'
        fi
    else
        echo "✅ Java runtime already present."
    fi

    # 3. PolyMC global configuration
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

    # 4. Fetch mod files from repository
    mkdir -p repo_mods
    pushd repo_mods >/dev/null
        for mod in "${MOD_FILES[@]}"; do
            echo "📦 Fetching $mod..."
            curl -sSL "$REPO_RAW_URL/mods/$mod" -o "$mod"
        done
    popd >/dev/null

    # 5. Create the 4 static instances
    for i in {1..4}; do
        instanceDir="instances/splitscreen-$i"
        mkdir -p "$instanceDir/.minecraft/mods" "$instanceDir/.minecraft/config"
        pushd "$instanceDir" >/dev/null

            # Wipe old mods on update, copy fresh ones
            rm -f .minecraft/mods/*.jar
            cp ../../repo_mods/*.jar .minecraft/mods/

            # Standard options
            if [ ! -f ".minecraft/options.txt" ]; then
                echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none" > .minecraft/options.txt
                if [ "$i" -gt 1 ]; then
                    echo "soundCategory_music:0" >> .minecraft/options.txt
                fi
            fi

            # Auto LAN server entry
            if [ ! -f ".minecraft/servers.dat" ]; then
                echo -ne '\n\0\0\x09\0\x07servers\n\0\0\0\x01\x08\0\x02ip\0\x0f127.0.0.1:47283\x08\0\x04name\0\x0bSplitscreen\0\0' > .minecraft/servers.dat
            fi

            # Assign static controller index (P1 = 0.0, P2 = 1.0, etc.)
            cat <<EOF > ".minecraft/config/controllable-client.toml"
[client]
[client.options]
autoSelectIndex = $((i-1)).0
EOF

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
            "cachedVersion": "3.3.3",
            "cachedVolatile": true,
            "dependencyOnly": true,
            "uid": "org.lwjgl3",
            "version": "3.3.3"
        },
        {
            "cachedName": "Minecraft",
            "cachedRequires": [
                {
                    "suggests": "3.3.3",
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

    # 6. Create accounts.json (P1 - P4)
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

    # 7. Download launch wrapper
    rm -f minecraft.sh
    curl -sSL "$REPO_RAW_URL/minecraft.sh" -o minecraft.sh
    chmod +x minecraft.sh

    # 8. Add to Steam
    if [ -d "$HOME/.steam/steam/userdata" ] && ! grep -q local/share/PolyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf 2>/dev/null; then
        rm -f add-to-steam.py
        curl -sSL "$REPO_RAW_URL/add-to-steam.py" -o add-to-steam.py
        echo -n '⏳ Shutting down Steam in order to add shortcut...'
        steam -shutdown 2>/dev/null || true
        while pgrep -F ~/.steam/steam.pid >/dev/null 2>&1; do
            echo -n .
            sleep 1
        done
        [ -f shortcuts-backup.vdf ] || cp ~/.steam/steam/userdata/*/config/shortcuts.vdf shortcuts-backup.vdf 2>/dev/null
        if python3 add-to-steam.py >/dev/null 2>&1; then
            echo -e "\r\033[K✅ Shortcut added to Steam"
        fi
    fi
popd >/dev/null

echo "✅ Installation completed successfully."

# END OF FILE