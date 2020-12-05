#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Kesalahan：${plain} harus menggunakan pengguna root untuk menjalankan skrip ini！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Versi sistem tidak terdeteksi，Harap hubungi penulis naskah！${plain}\n" && exit 1
fi

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "Perangkat lunak ini tidak mendukung 32 Sistem bit (x86), silakan gunakan sistem 64 bit (x86_64), jika pendeteksian salah, silakan hubungi penulis "
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}mohon gunakan CentOS 7 Atau sistem yang lebih tinggi！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}mohon gunakan Ubuntu 16 Atau sistem yang lebih tinggi！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}mohon gunakan Debian 8 Atau sistem yang lebih tinggi！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar unzip -y
    else
        apt install wget curl tar unzip -y
    fi
}

uninstall_old_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray ]]; then
        confirm "Versi lama terdeteksi v2ray，Apakah akan mencopot pemasangan，Akan dihapus /usr/bin/v2ray/ dan /etc/systemd/system/v2ray.service" "Y"
        if [[ $? != 0 ]]; then
            echo "Tidak dapat menginstal tanpa uninstall v2-ui"
            exit 1
        fi
        echo -e "${green}Copot pemasangan versi lama v2ray${plain}"
        systemctl stop v2ray
        rm /usr/bin/v2ray/ -rf
        rm /etc/systemd/system/v2ray.service -f
        systemctl daemon-reload
    fi
    if [[ -f /usr/local/bin/v2ray ]]; then
        confirm "Instalasi lain terdeteksi v2ray，Apakah akan mencopot pemasangan，v2-ui Sudah resmi v2ray Inti，Untuk mencegah konflik dengan portnya, disarankan untuk menghapus " "Y"
        if [[ $? != 0 ]]; then
            echo -e "${red}Anda memilih untuk tidak mencopot pemasangan，Harap pastikan bahwa v2ray dan v2-ui diinstal oleh skrip lain ${green}自带的官方 v2ray 内核${red}不会端口冲突${plain}"
        else
            echo -e "${green}Mulai uninstall v2ray yang diinstal dengan cara lain${plain}"
            systemctl stop v2ray
            bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            systemctl daemon-reload
        fi
    fi
}

install_v2ray() {
    uninstall_old_v2ray
    echo -e "${green}Mulai instal atau tingkatkan v2ray${plain}"
    bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Instalasi atau upgrade v2ray gagal, silakan periksa pesan kesalahan${plain}"
        echo -e "${yellow}Sebagian besar alasan mungkin disebabkan oleh ketidakmampuan untuk mendownload paket instalasi v2ray di area di mana server Anda saat ini berada. Ini lebih umum terjadi pada mesin domestik. Solusinya adalah menginstal v2ray secara manual. Untuk alasan spesifik, silakan lihat pesan kesalahan di atas${plain}"
        exit 1
    fi
    echo "
[Unit]
Description=V2Ray Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Environment=V2RAY_LOCATION_ASSET=/usr/local/share/v2ray/
ExecStart=/usr/local/bin/v2ray -confdir /usr/local/etc/v2ray/
Restart=on-failure

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/v2ray.service
    if [[ ! -f /usr/local/etc/v2ray/00_log.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/00_log.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/01_api.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/01_api.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/02_dns.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/02_dns.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/03_routing.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/03_routing.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/04_policy.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/04_policy.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/05_inbounds.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/05_inbounds.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/06_outbounds.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/06_outbounds.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/07_transport.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/07_transport.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/08_stats.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/08_stats.json
    fi
    if [[ ! -f /usr/local/etc/v2ray/09_reverse.json ]]; then
        echo "{}" > /usr/local/etc/v2ray/09_reverse.json
    fi
    systemctl daemon-reload
    systemctl enable v2ray
    systemctl start v2ray
}

close_firewall() {
    if [[ x"${release}" == x"centos" ]]; then
        systemctl stop firewalld
        systemctl disable firewalld
    elif [[ x"${release}" == x"ubuntu" ]]; then
        ufw disable
#    elif [[ x"${release}" == x"debian" ]]; then
#        iptables -P INPUT ACCEPT
#        iptables -P OUTPUT ACCEPT
#        iptables -P FORWARD ACCEPT
#        iptables -F
    fi
}

install_v2-ui() {
    systemctl stop v2-ui
    cd /usr/local/
    if [[ -e /usr/local/v2-ui/ ]]; then
        rm /usr/local/v2-ui/ -rf
    fi

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/sprov065/v2-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Gagal mendeteksi versi v2-ui，Mungkin di luar batas API Github，Silakan coba lagi nanti，Atau secara manual tentukan versi v2-ui yang akan diinstal${plain}"
            exit 1
        fi
        echo -e "Versi terbaru v2-ui terdeteksi：${last_version}，mulai penginstalan"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux.tar.gz https://github.com/sprov065/v2-ui/releases/download/${last_version}/v2-ui-linux.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download v2-ui gagal，Harap pastikan server Anda dapat mengunduh file Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/sprov065/v2-ui/releases/download/${last_version}/v2-ui-linux.tar.gz"
        echo -e "mulai penginstalan v2-ui v$1"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}unduh v2-ui v$1 kegagalan，Harap pastikan versi ini ada${plain}"
            exit 1
        fi
    fi

    tar zxvf v2-ui-linux.tar.gz
    rm v2-ui-linux.tar.gz -f
    cd v2-ui
    chmod +x v2-ui bin/v2ray-v2-ui bin/v2ctl
    cp -f v2-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable v2-ui
    systemctl start v2-ui
    echo -e "${green}v2-ui v${last_version}${plain} Penginstalan selesai，dan panel telah dimulai，"
    echo -e ""
    echo -e "Jika ini adalah instalasi baru, port web default-nya adalah ${green}65432${plain}，Nama pengguna dan kata sandi keduanya secara default adalah ${green}admin${plain}"
    echo -e "Harap pastikan bahwa port ini tidak digunakan oleh program lain，${yellow}Dan pastikan 65432 Port telah dirilis${plain}"
    echo -e "Jika Anda ingin mengubah 65432 ke port lain, masukkan perintah v2-ui untuk memodifikasi, dan pastikan juga bahwa port yang Anda modifikasi juga diizinkan"
    echo -e ""
    echo -e "Jika itu untuk memperbarui panel, akses panel seperti yang Anda lakukan sebelumnya"
    echo -e ""
    curl -o /usr/bin/v2-ui -Ls https://raw.githubusercontent.com/sprov065/v2-ui/master/v2-ui.sh
    chmod +x /usr/bin/v2-ui
    echo -e "v2-ui Cara Menggunakan Script: "
    echo -e "----------------------------------------------"
    echo -e "v2-ui              - Tampilkan menu manajemen (lebih banyak fungsi)""
    echo -e "v2-ui start        - Luncurkan panel v2-ui"
    echo -e "v2-ui stop         - Hentikan panel v2-ui"
    echo -e "v2-ui restart      - Mulai ulang panel v2-ui"
    echo -e "v2-ui status       - Lihat status v2-ui"
    echo -e "v2-ui enable       - Setel v2-ui untuk memulai secara otomatis"
    echo -e "v2-ui disable      - Batalkan booting v2-ui secara otomatis"
    echo -e "v2-ui log          - Lihat log v2-ui"
    echo -e "v2-ui update       - Perbarui panel v2-ui"
    echo -e "v2-ui install      - Instal panel v2-ui"
    echo -e "v2-ui uninstall    - Copot pemasangan panel v2-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}start installation${plain}"
install_base
uninstall_old_v2ray
close_firewall
install_v2-ui $1
