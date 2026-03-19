#!/bin/bash

set -e

[[ -v "${USER_ID}" ]]    && usermod -u $USER_ID designer
[[ -v "${USER_GROUP}" ]] && usermod -g $USER_GROUP designer

if [ -z ${ENABLE_GUI}  ]; then

    if [ "$1" != "" ]; then
        $1
    else
        exec /bin/bash -i
    fi

    
else


# from build/images/base/skel/dockerstartup/ui_startup.sh IIC_OSIC_TOOLS
while :
do
    case "$1" in
        -X | --x11 )
            start_x=true
            shift 1
            ;;
        -V | --vnc )
            start_vnc=true
            shift 1
            ;;
        -w | --wait )
            par_wait=true
            shift 1
            ;;
        -- | "")
            break
            ;;
        *)
            echo "[ERROR] Unexpected option \"$1\""
            exit 1
            ;;
    esac
done

# Marks log lines of outputs so they can be identified
# https://unix.stackexchange.com/questions/67392/multiple-background-processes-in-a-script
tag() { stdbuf -oL sed "s%^%$1 %"; }

if [ "$start_x" != true ] && [ "$start_vnc" != true ]; then
    if [ -z ${DISPLAY+x} ]; then
        # DISPLAY is not set, so set it and run the startup script.
        start_vnc=true
        export DISPLAY=:1
        [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Auto-selected VNC."
    else
        start_x=true
        [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Auto-selected local X11."
    fi
fi

if [ "$start_vnc" = true ]; then
    # resolve_vnc_connection
    VNC_IP=$(hostname -i)

    # change the vnc password
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Change VNC password..."
    # first entry is control, second is the view (if only one is valid for both)
    mkdir -p "$HOME/.vnc"
    PASSWD_PATH="$HOME/.vnc/passwd"
    echo "$VNC_PW" | vncpasswd -f > "$PASSWD_PATH"
    chmod 600 "$PASSWD_PATH"

    # start vncserver and noVNC webclient
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Start noVNC..."

    if [ -f ${NO_VNC_HOME}/utils/novnc_proxy ]; then
        # This is for novnc version >= 1.3.0
        NO_VNC_LAUNCHER=${NO_VNC_HOME}/utils/novnc_proxy
    elif [ -f ${NO_VNC_HOME}/utils/launch.sh ]; then
        # This is for old versions of novnc
        NO_VNC_LAUNCHER=${NO_VNC_HOME}/utils/launch.sh
    fi

    if [ ! -z $NO_VNC_LAUNCHER ]; then
    "$NO_VNC_LAUNCHER" --vnc localhost:"$VNC_PORT" --listen "$NO_VNC_PORT" 2>&1 | tag "[NOVNC]" &

else
    echo -e "[INFO] Not suitable launcher found for NoVNC (launch.sh nor novnc_proxy). Please, make sure it is installed."
    fi

    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Starting vncserver and window manager with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION."

    # workaround, lock files are not removed if the container is re-run otherwise which makes vncserver unaccessible
    rm -rf /tmp/.X1-lock
    rm -rf /tmp/.X11-unix/X1

    if [ "$(arch)" == "aarch64" ]; then  
        OLD_LD_PRELOAD=$LD_PRELOAD
        export LD_PRELOAD="/lib/aarch64-linux-gnu/libgcc_s.so.1 ${LD_PRELOAD}"
    fi

    vncserver "$DISPLAY" -depth "$VNC_COL_DEPTH" -geometry "$VNC_RESOLUTION" -localhost no -fg -xstartup startxfce4 2>&1 | tag "[VNC]" &
  
    if [ "$(arch)" == "aarch64" ]; then
        export LD_PRELOAD=$OLD_LD_PRELOAD
    fi

    # log connect options
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] VNC environment started."
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] VNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT."
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] noVNC HTML client started:\n\t=> connect via http://localhost/?password=$VNC_PW\n"
fi

if [ "$start_x" = true ]; then
    xfce4-terminal | tag "[TERM]" &
    # add an empty newline so one can see that this script is done.
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo
fi

if [ "$par_wait" = true ]; then
    trap cleanup SIGINT SIGTERM
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] Waiting until one of the sub-processes stops..."
    wait -n
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo -e "[INFO] One sub process stopped, exiting..."
fi

fi
