#!/bin/bash
echo "---Checking for optional scripts---"
if [ -f /opt/scripts/user.sh ]; then
    echo "---Found optional script, executing---"
    chmod +x /opt/scripts/user.sh
    /opt/scripts/user.sh
else
    echo "---No optional script found, continuing---"
fi

export DATA_DIR=$HOME

uninstall_amd_driver() {
    if [ -f /usr/bin/amdgpu-uninstall ]; then
        echo "Uninstalling driver"
        echo 'APT::Get::Assume-Yes "true";' >>/etc/apt/apt.conf.d/90assumeyes
        /usr/bin/amdgpu-uninstall
        rm /etc/apt/apt.conf.d/90assumeyes
        echo "Done!"
    else
        echo "---AMD driver not present---"
    fi
}

install_amd_driver() {
    AMD_DRIVER=$1
    AMD_DRIVER_URL=$2
    FLAGS=$3
    echo "---Installing AMD drivers, please wait!---"
    echo "---Downloading driver from "$AMD_DRIVER_URL/$AMD_DRIVER"---"
    echo 'APT::Get::Assume-Yes "true";' >>/etc/apt/apt.conf.d/90assumeyes
    mkdir -p /tmp/opencl-driver-amd
    cd /tmp/opencl-driver-amd
    #echo AMD_DRIVER is $AMD_DRIVER
    curl --referer $AMD_DRIVER_URL -O $AMD_DRIVER_URL/$AMD_DRIVER
    tar -Jxf $AMD_DRIVER &>/dev/null
    rm $AMD_DRIVER
    cd amdgpu-pro-*
    echo "---Installing driver, this can take a very long time with no output. Please wait!---"
    apt-get install -y initramfs-tools &>/dev/null
    ./amdgpu-pro-install $FLAGS &>/dev/null
    apt-get --fix-broken install -y &>/dev/null
    cd /home/docker/
    rm -rf /tmp/opencl-driver-amd
    echo "---AMD Driver installation finished---"
    INSTALLED_DRIVERV=$(cd /home/docker/phoenixminer && ./PhoenixMiner -list | grep -m 1 "OpenCL driver version" | sed 's/OpenCL driver version: //g' | cut -c1-5)
    rm /etc/apt/apt.conf.d/90assumeyes
}

INSTALLED_DRIVERV=$(cd /home/docker/phoenixminer && ./PhoenixMiner -list | grep -m 1 "OpenCL driver version" | sed 's/OpenCL driver version: //g' | cut -c1-5)

if [[ "${INSTALLED_DRIVERV}" != "${DRIVERV:-20.20}" ]]; then
        uninstall_amd_driver
        install_amd_driver "amdgpu-pro-18.20-673703-ubuntu-18.04.tar.xz" "https://drivers.amd.com/drivers/linux" "--opencl=legacy,pal --headless"
fi

term_handler() {
    kill -SIGTERM "$killpid"
    wait "$killpid" -f 2>/dev/null

    exit 143
}

trap 'kill ${!}; term_handler' SIGTERM
if [ "${CUSTOM}" == "true" ]; then
    /home/docker/custom-mine.sh &
else
    /home/docker/mine.sh &
fi
killpid="$!"

while true; do
    wait $killpid
    exit 0
done
