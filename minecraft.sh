#!/bin/bash

export target=/tmp
cd /home/deck/.local/share/PolyMC

splitScreen() {
    local pattern=$1
    splitScreenKwinScript "$pattern" > "$target/splitscreen_kwinscript"
    executeKwinScript "$target/splitscreen_kwinscript"
    rm -f "$target/splitscreen_kwinscript"
}

splitScreenKwinScript() {
    local pattern=$1
    cat <<____EOF
        const area = workspace.clientArea(KWin.FullScreenArea, workspace.activeWindow);
        let allWindows = workspace.stackingOrder.filter(w => w.normalWindow && !w.skipTaskbar);
        let matchingWindows = allWindows.filter(w => w.caption.match(/$pattern/));
        let nonMatchingWindows = allWindows.filter(w => !w.caption.match(/$pattern/));

        for (var i = 0; i < nonMatchingWindows.length; i++) {
            nonMatchingWindows[i].minimized = true;
        }

        var numWindows = matchingWindows.length;
        var numRows = Math.ceil(Math.sqrt(numWindows));
        var numCols = Math.ceil(numWindows / numRows);

        var windowWidth = area.width / numCols;
        var windowHeight = area.height / numRows;

        for (var i = 0; i < matchingWindows.length; i++) {
            var window = matchingWindows[i];
            var row = Math.floor(i / numCols);
            var col = i % numCols;
            var x = col * windowWidth;
            var y = row * windowHeight;
            window.noBorder = true;
            window.frameGeometry = { x: x, y: y, width: windowWidth, height: windowHeight };
        }
____EOF
}

executeKwinScript() {
    ID=$(dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.loadScript "string:$1" "string:splitscreen" | awk '{print $2}')
    qdbus org.kde.KWin /Scripting start
    dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.unloadScript "string:splitscreen" >/dev/null 2>&1
}

nestedPlasma() {
    unset LD_PRELOAD XDG_DESKTOP_PORTAL_DIR XDG_SEAT_PATH XDG_SESSION_PATH
    RES=$(xdpyinfo | awk '/dimensions/{print $2}')

    cat <<____EOF > "$target/kwin_wayland_wrapper"
#!/bin/bash
/usr/bin/kwin_wayland_wrapper --width $(echo "$RES" | cut -d 'x' -f 1) --height $(echo "$RES" | cut -d 'x' -f 2) --no-lockscreen \$@
____EOF
    chmod a+x "$target/kwin_wayland_wrapper"
    export PATH="$target:$PATH"

    dbus-run-session startplasma-wayland
}

writeOfflineModeConfig() {
    while sleep 5; do
        ls -1d instances/*/.minecraft/saves/* 2>/dev/null | while read -r world; do
            if [ ! -f "$world/mcwifipnp.json" ]; then
                cat <<________________EOF > "$world/mcwifipnp.json"
{
    "port": 47283,
    "motd": "Splitscreen",
    "UseUPnP": false,
    "OnlineMode": false,
    "EnableUUIDFixer": false,
    "CopyToClipboard": false
}
________________EOF
            fi
        done
    done
}

launchGame() {
    windowCountBeforeLaunch=$(xwininfo -root -tree | grep 854x480 | wc -l)
    kde-inhibit --power --screenSaver --colorCorrect --notifications ./PolyMC-Linux-x86_64.AppImage -l "$1" -a "$2" &
    echo $! >> minecraft.pid
    while [ $(xwininfo -root -tree | grep 854x480 | wc -l) -le $windowCountBeforeLaunch ]; do
        sleep 1
    done
}

launchGames() {
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'autohide';"
    writeOfflineModeConfig &
    writeOfflineModeConfigPID=$!

    rm -f minecraft.pid
    launchGame splitscreen-1 P1
    launchGame splitscreen-2 P2
    [ "$numberOfControllers" -gt 2 ] && launchGame splitscreen-3 P3
    [ "$numberOfControllers" -gt 3 ] && launchGame splitscreen-4 P4

    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'autohide';"
    splitScreen "^Minecraft"

    wait $(<minecraft.pid)

    kill "$writeOfflineModeConfigPID"
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'none';"
    sleep 2
}

(
    echo "$(date) - Script called with $# arguments: $@"
    export numberOfControllers=$(( $(ls -1 /dev/input/js* 2>/dev/null | wc -l) / 2 ))
    echo "Number of controllers: $numberOfControllers"

    if [ "$1" = "launchFromGameMode" ]; then
        rm -f ~/.config/autostart/minecraft.desktop
        sleep 1
        launchGames
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
    elif xwininfo -root -tree | grep -q plasmashell; then
        launchGames
    else
        if [ "$numberOfControllers" -lt 2 ]; then
            ./PolyMC-Linux-x86_64.AppImage -l splitscreen-1 -a P1
        else
            SCRIPT_PATH="$(readlink -f "$0")"
            mkdir -p ~/.config/autostart
            echo -e "[Desktop Entry]\nExec=\"$SCRIPT_PATH\" launchFromGameMode\nIcon=dialog-scripts\nName=Minecraft\nPath=\nType=Application\nX-KDE-AutostartScript=true" > ~/.config/autostart/minecraft.desktop
            chmod +x ~/.config/autostart/minecraft.desktop
            nestedPlasma
        fi
    fi
) >> minecraft.sh.log 2>&1