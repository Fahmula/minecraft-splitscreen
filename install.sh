#!/bin/bash
targetDir=$HOME/.local/share/PolyMC

curlProgress() {
    if [ ! -f "$3" ]; then
        echo "📦 Downloading $2"

        curl -L --progress-bar "$4" -o "$3"

        if md5sum "$3" | grep -q $1; then
            echo -e "\033[1A\r\033[K\033[1A\r\033[K✅ $2 download complete and verified"
        else
            echo -e "\033[1A\r\033[K\033[1A\r\033[K❌ $2 download failed"
            rm -f "$3"
            fail "A download failed. Try to run the script again. If it persists, report the problem on GitHub."
        fi
    else
        echo "✅ $2 already present."
    fi
}

fail() {
    echo -e "\n\n❌ $1\n"
    zenity --error --text="$1"
    exit 1
}

if [ ! -d "$targetDir" ]; then
    [ $(df /home | awk '$6 == "/home" { print $4 }') -lt 2000000 ] && fail 'Please make sure you have at least 2GB available on the internal storage.'
    zenity --question --text='This script will download the PolyMC launcher, install a few mods for making Splitscreen work and add Minecraft to Steam.\n\nInstall it?' || exit 1
fi

mkdir -p $targetDir
pushd $targetDir >/dev/null

    curlProgress 50ff824528d9de6d123db8c5d14b74ad \
                 PolyMC \
                 PolyMC-Linux-8.1-x86_64.AppImage \
                 https://github.com/PolyMC/PolyMC/releases/download/8.1/PolyMC-Linux-amd64-8.1.AppImage
    chmod +x "PolyMC-Linux-8.1-x86_64.AppImage"

    if [ ! -f "jdk-25.0.4.1+1-jre/bin/java" ]; then
        curlProgress dc22566f89ad35891b4a8884271cb06f \
                     Java \
                     OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz \
                     https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz
        echo -n "📦 Extracting Java"
        if ! (tar xzf OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz && rm OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz); then
            echo -e "\r\033[K❌ Extracting Java failed"
            rm -rf OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz jdk-25.0.4.1+1-jre
            fail 'Extracting Java failed.'
        else
            echo -e "\r\033[K✅ Java extracted"
        fi
    else
        echo "✅ Java already present."
    fi

    if [ ! -f polymc.cfg ]; then
        # create polymc.cfg
        sed 's/^            //' <<________EOF > polymc.cfg
            [General]
            ApplicationTheme=system
            ConfigVersion=1.2
            FlameKeyShouldBeFetchedOnStartup=false
            IconTheme=pe_colored
            JavaPath=jdk-25.0.4.1+1-jre/bin/java
            Language=en_US
            LastHostname=$HOSTNAME
            MaxMemAlloc=4096
            MinMemAlloc=512
________EOF
    fi

    # create the 4 game instances
    for i in {1..4}; do
        mkdir -p "instances/26.3-$i/.minecraft/mods" "instances/26.3-$i/.minecraft/config"
        pushd "instances/26.3-$i" >/dev/null

            if [ ! -f ".minecraft/mods/fabric-api-0.161.0+26.3.jar" ]; then
                # download fabric api
                if [ -f "../26.3-1/.minecraft/mods/fabric-api-0.161.0+26.3.jar" ]; then
                    cp "../26.3-1/.minecraft/mods/fabric-api-0.161.0+26.3.jar" ".minecraft/mods/fabric-api-0.161.0+26.3.jar"
                else
                    curlProgress 0bce1e70b0593d995206eeb3f980d781 \
                                 'Fabric API' \
                                 .minecraft/mods/fabric-api-0.161.0+26.3.jar \
                                 https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar
                fi
            fi

            if [ ! -f ".minecraft/mods/framework-fabric-0.13.27+26.3.jar" ]; then
                # download framework
                if [ -f "../26.3-1/.minecraft/mods/framework-fabric-0.13.27+26.3.jar" ]; then
                    cp "../26.3-1/.minecraft/mods/framework-fabric-0.13.27+26.3.jar" ".minecraft/mods/framework-fabric-0.13.27+26.3.jar"
                else
                    curlProgress 19fe7aed54c17aa37c0b1236116f43b3 \
                                 'Framework Mod' \
                                 .minecraft/mods/framework-fabric-0.13.27+26.3.jar \
                                 https://github.com/MrCrayfish/Framework/releases/download/v0.13.27%2B26.3/framework-fabric-0.13.27%2B26.3-signed.jar
                fi
            fi

            if [ ! -f ".minecraft/mods/controllable-fabric-0.26.2+26.3.jar" ]; then
                # download controllable
                if [ -f "../26.3-1/.minecraft/mods/controllable-fabric-0.26.2+26.3.jar" ]; then
                    cp "../26.3-1/.minecraft/mods/controllable-fabric-0.26.2+26.3.jar" ".minecraft/mods/controllable-fabric-0.26.2+26.3.jar"
                else
                    curlProgress 414eda92f33034407259b4b3694d2547 \
                                 'Controllable Mod' \
                                 .minecraft/mods/controllable-fabric-0.26.2+26.3.jar \
                                 https://raw.githubusercontent.com/Fahmula/minecraft-splitscreen/refs/tags/26.3/controllable-fabric-0.26.2%2B26.3.jar
                fi
            fi

            if [ ! -f ".minecraft/mods/mcwifipnp-2.1.4-26.3-fabric.jar" ]; then
                # download mcwifipnp
                if [ -f "../26.3-1/.minecraft/mods/mcwifipnp-2.1.4-26.3-fabric.jar" ]; then
                    cp "../26.3-1/.minecraft/mods/mcwifipnp-2.1.4-26.3-fabric.jar" ".minecraft/mods/mcwifipnp-2.1.4-26.3-fabric.jar"
                else
                    curlProgress fe536cfcdc54d7c8fde28a89e6687e1b \
                                 'LAN World Plug-n-Play Mod' \
                                 .minecraft/mods/mcwifipnp-2.1.4-26.3-fabric.jar \
                                 https://cdn.modrinth.com/data/RTWpcTBp/versions/Bj7WrQZY/mcwifipnp-2.1.4-26.3-fabric.jar
                fi
            fi

            if [ ! -f ".minecraft/options.txt" ]; then
                echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none" > .minecraft/options.txt
                if [ "$i" -gt 1 ]; then
                    echo "soundCategory_music:0" >> .minecraft/options.txt
                fi
            fi

            if [ ! -f ".minecraft/servers.dat" ]; then
                echo -ne '\n\0\0\x09\0\x07servers\n\0\0\0\x01\x08\0\x02ip\0\x0f127.0.0.1:47283\x08\0\x04name\0\x0bSplitscreen\0\0' > .minecraft/servers.dat
            fi

            if [ ! -f ".minecraft/config/controllable-client.toml" ]; then
                # create controllable-client.toml
                sed 's/^                    //' <<________________EOF > ".minecraft/config/controllable-client.toml"
                    [options]
                    autoSelectIndex = $((i-1)).0
________________EOF
            fi

            if [ ! -f "instance.cfg" ]; then
                sed 's/^                    //' <<________________EOF > "instance.cfg"
                    [General]
                    ConfigVersion=1.2
                    InstanceType=OneSix
                    JavaPath=jdk-25.0.4.1+1-jre/bin/java
                    OverrideJavaLocation=true
                    iconKey=default
                    name=26.3-$i
                    JvmArgs=-Dorg.lwjgl.openal.libname=/usr/lib/libopenal.so
                    OverrideJavaArgs=true
________________EOF
            fi

            if [ ! -f "mmc-pack.json" ]; then
                sed 's/^                    //' <<________________EOF > "mmc-pack.json"
                    {
                        "components": [
                            {
                                "cachedName": "LWJGL 3",
                                "cachedVersion": "3.4.3",
                                "cachedVolatile": true,
                                "dependencyOnly": true,
                                "uid": "org.lwjgl3",
                                "version": "3.4.3"
                            },
                            {
                                "cachedName": "Minecraft",
                                "cachedRequires": [
                                    {
                                        "suggests": "3.4.3",
                                        "uid": "org.lwjgl3"
                                    }
                                ],
                                "cachedVersion": "26.3",
                                "important": true,
                                "uid": "net.minecraft",
                                "version": "26.3"
                            },
                            {
                                "cachedName": "Intermediary Mappings",
                                "cachedRequires": [
                                    {
                                        "equals": "26.3",
                                        "uid": "net.minecraft"
                                    }
                                ],
                                "cachedVersion": "26.3",
                                "cachedVolatile": true,
                                "dependencyOnly": true,
                                "uid": "net.fabricmc.intermediary",
                                "version": "26.3"
                            },
                            {
                                "cachedName": "Fabric Loader",
                                "cachedRequires": [
                                    {
                                        "uid": "net.fabricmc.intermediary"
                                    }
                                ],
                                "cachedVersion": "0.19.5",
                                "uid": "net.fabricmc.fabric-loader",
                                "version": "0.19.5"
                            }
                        ],
                        "formatVersion": 1
                    }
________________EOF
            fi

        popd >/dev/null
    done

    if [ ! -f "accounts.json" ]; then
        # create accounts.json
        sed 's/^            //' <<________EOF > accounts.json
            {
                "accounts": [
                    {
                        "active": true,
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "99f7b67dff4a3921ab1855d7abaafc82",
                            "name": "P1",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "bf6cb3d6c80d4448a932522de4a51d51",
                                "userName": "P1"
                            },
                            "iat": 1745307597,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "45c6ab0a786e3272b6806c93ba62c2b4",
                            "name": "P2",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "878b7cd9a9e34505b64efde6ce1f9470",
                                "userName": "P2"
                            },
                            "iat": 1745307602,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "ac4e5ee749823b818186f0480155d43d",
                            "name": "P3",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "de836a1d55a448e091cf21ed2800bf1a",
                                "userName": "P3"
                            },
                            "iat": 1745307605,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "35b0aa2bc5633d5b9f98490635965826",
                            "name": "P4",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "5d36c1ee9be04fe8a0d256cbbd3af3d2",
                                "userName": "P4"
                            },
                            "iat": 1745307609,
                            "token": "0"
                        }
                    }
                ],
                "formatVersion": 3
            }
________EOF
    fi

    # download the launch wrapper
    rm -f minecraft.sh
    curlProgress 5cd816ccc9f67de0b4df1c082f5c611d \
                 'Launch script' \
                 minecraft.sh \
                 https://raw.githubusercontent.com/Fahmula/minecraft-splitscreen/refs/tags/26.3/minecraft.sh
    chmod +x minecraft.sh

    # add the launch wrapper to Steam
    if ! grep -q local/share/PolyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf; then
        rm -f add-to-steam.py
        curlProgress 6383cc991f751b6dc5fdd2a3f5d83b7c \
                     'Shortcut creation script' \
                     add-to-steam.py \
                     https://raw.githubusercontent.com/Fahmula/minecraft-splitscreen/refs/tags/26.3/add-to-steam.py
        echo -n '⏳ Shutting down Steam in order to add the Minecraft shortcut'
        steam -shutdown
        while pgrep -F ~/.steam/steam.pid >/dev/null; do
            echo -n .
            sleep 1
        done
        [ -f shortcuts-backup.vdf ] || cp ~/.steam/steam/userdata/*/config/shortcuts.vdf shortcuts-backup.vdf
        if python add-to-steam.py >/dev/null; then
            echo -e "\r\033[K✅ Shortcut added to Steam (if your shortcuts broke, there's a backup at $(pwd)/shortcuts-backup.vdf)"
        else
            echo -e "\r\033[K❌ Adding shortcut failed (if your shortcuts broke, there's a backup at $(pwd)/shortcuts-backup.vdf)"
            nohup steam >/dev/null 2>&1 &
            fail 'Adding shortcut to Steam failed.'
        fi
    fi
popd >/dev/null

if zenity --question --icon-name=dialog-ok --text='No errors. Go back to Game Mode and start Minecraft.\n\nGo to Game Mode now?'; then
    qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
elif ! pgrep -F ~/.steam/steam.pid >/dev/null; then
    nohup steam >/dev/null 2>&1 &
fi

# END OF FILE
