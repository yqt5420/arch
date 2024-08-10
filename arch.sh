#!/bin/bash

#从这里开始是换源操作，封装成一个函数，让他可以重复执行
## --------------------------pacman操作---------------------------------- ##
## 更换国内源
echo 'start开始换国内源'
echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.xjtu.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.shanghaitech.edu.cn/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

## -------------------------------------------------------------- ##
### 开启multilib仓库支持
echo '[multilib]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
echo ' ' >> /etc/pacman.conf
## 增加archlinuxcn源
echo '[archlinuxcn]' >> /etc/pacman.conf
echo 'SigLevel = Never' >> /etc/pacman.conf
echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch' >> /etc/pacman.conf
## -------------------------------------------------------------- ##
## 增加arch4edu源
echo '[arch4edu]' >> /etc/pacman.conf
echo 'SigLevel = Never' >> /etc/pacman.conf
echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/arch4edu/$arch' >> /etc/pacman.conf
## 开启pacman颜色支持
sed -i 's/#Color/Color/g' /etc/pacman.conf
echo '换源操作结束stop'
# 检查分区是否存在
check_partition() {
    local partition="$1"

    # 使用ls -l命令检查分区是否存在，$devdir是设备目录，通常是/dev
    local devdir=$(dirname "$partition")
    if [ ! -d "$devdir" ] || [ ! -e "$partition" ]; then
        echo "错误：分区设备 $partition 不存在。"
        exit 1
    fi
}

# 确保脚本以root权限运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi
# 中间还有分区和挂载步骤
#自己用cfdisk分区，
#请输入boot分区、根分区的路径（这里做个交互存在变量里）
# 提示用户输入分区信息
read -p "请输入boot分区的设备路径（例如 /dev/sda1）: " boot_dir
read -p "请输入根分区的设备路径（例如 /dev/sda2）: " root_dir

# 验证分区路径
if [[ -z "$boot_dir" || -z "$root_dir" ]]; then
    echo "错误：分区路径不能为空。"
    exit 1
fi
# 检查用户输入的分区是否存在
check_partition "$boot_dir"
check_partition "$root_dir"

#格式化boot分区
mkfs.fat -F32 "$boot_dir"
#格式化根分区
mkfs.btrfs -f -L aw "$root_dir"
#挂载根分区# 创建 / 目录子卷# 创建 /home 目录子卷
mount -t btrfs -o compress=lzo "$root_dir" /mnt
btrfs subvolume create /mnt/@ 
btrfs subvolume create /mnt/@home 
umount -R /mnt
# 挂载根分区
mount -t btrfs -o subvol=/@,compress=lzo "$root_dir" /mnt
mkdir -p /mnt/{boot,home}
# 挂载 /home 子卷
mount -t btrfs -o subvol=/@home,compress=lzo "$root_dir" /mnt/home
# 挂载 boot 分区
mount "$boot_dir" /mnt/boot
# 更新一下pacman密钥，不然直接复制过去的pacman.conf文件会报错
pacman -Sy



## -------------------------------------------------------------- ##
# 给新系统安装基础软件,使用长期支持的内核
# pacstrap /mnt base base-devel linux linux-firmware btrfs-progs 
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs 
sleep 5
pacstrap /mnt intel-ucode amd-ucode
sleep 3
# pacstrap /mnt archlinux-keyring archlinuxcn-keyring
# sleep 3
# 安装常用软件
pacstrap /mnt networkmanager vim sudo fish git wget nano htop neofetch yay openssh screen wireless-regdb wireless_tools wpa_supplicant cronie wqy-zenhei timeshift grub efibootmgr os-prober 
pacstrap /mnt firefox firefox-i18n-zh-cn ttf-jetbrains-mono-nerd noto-fonts-emoji
pacstrap /mnt ttf-jetbrains-mono-nerd noto-fonts-emoji
pacstrap /mnt fcitx5-im fcitx5-rime
# 引导程序
  
# 安装中文字体
## -------------------------------------------------------------- ##
######################################################################
##############复制生成新系统的配置文件##################################

# 生成 fstab 文件
genfstab -U /mnt > /mnt/etc/fstab

#设置系统语言为中文
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
# 设置时区
ln -sf /mnt/usr/share/zoneinfo/Asia/Shanghai /mnt/etc/localtime
# 设置主机名和hosts
echo "aw" > /mnt/etc/hostname
echo "127.0.0.1   localhost
::1         localhost
127.0.1.1   aw.localdomain aw" >> /mnt/etc/hosts
#设置fcitx5输入法环境
###########################################
echo "GTK_IM_MODULE=fcitx" >> /mnt/etc/environment
echo "QT_IM_MODULE=fcitx" >> /mnt/etc/environment
echo "XMODIFIERS=@im=fcitx" >> /mnt/etc/environment
echo "SDL_IM_MODULE=fcitx" >> /mnt/etc/environment
##############对新系统进行换源操作###############################
mv /mnt/etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.back
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp /etc/pacman.conf /mnt/etc/pacman.conf



############################################################################
############################################################################
#############生成新系统设置脚本##############################################
echo "#!/bin/bash" > /mnt/root/set.sh
#同步时间
echo "hwclock --systohc" >> /mnt/root/set.sh
# 中文生效
echo "locale-gen" >> /mnt/root/set.sh
#安装引导程序到boot分区
echo "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH" >> /mnt/root/set.sh
#修改grub配置文件
echo "sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"/g' /etc/default/grub" >> /mnt/root/set.sh
echo "sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub" >> /mnt/root/set.sh
#下载并设置grub主题
echo "curl -o /usr/share/grub/themes/yuan.tar.gz https://mirror.ghproxy.com/https://raw.githubusercontent.com/voidlhf/StarRailGrubThemes/master/themes/Yunli_cn.tar.gz" >> /mnt/root/set.sh
echo "tar -xzf /usr/share/grub/themes/yuan.tar.gz -C /boot/grub/themes/" >> /mnt/root/set.sh
echo "echo \"GRUB_THEME=\"/boot/grub/themes/Yunli_cn/theme.txt\"\" >> /etc/default/grub" >> /mnt/root/set.sh
#生成grub配置文件
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> /mnt/root/set.sh
# 设置 root 密码
echo "echo \"root:aw\" | chpasswd" >> /mnt/root/set.sh
echo "usermod -s /bin/fish root " >> /mnt/root/set.sh
# 创建用户
echo "useradd -m -G wheel -s /bin/fish aw" >> /mnt/root/set.sh
echo "echo \"aw:aw\" | chpasswd" >> /mnt/root/set.sh
# 给用户添加 sudo 权限
echo "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers" >> /mnt/root/set.sh
echo "echo 'aw ALL= (ALL) NOPASSWD: ALL' >> /etc/sudoers" >> /mnt/root/set.sh
# 创建用户目录
echo "mkdir -p /home/aw" >> /mnt/root/set.sh
echo "chown -R aw:aw /home/aw" >> /mnt/root/set.sh

# 设置开机自启的任务
echo "systemctl enable NetworkManager" >> /mnt/root/set.sh
echo "systemctl enable sshd" >> /mnt/root/set.sh
echo "systemctl enable cronie" >> /mnt/root/set.sh
echo "systemctl enable bluetooth" >> /mnt/root/set.sh
echo "pacman-key --init" >> /mnt/root/set.sh
echo "pacman-key --populate archlinux" >> /mnt/root/set.sh
echo "pacman -S --noconfirm archlinuxcn-keyring archlinux-keyring arch4edu-keyring" >> /mnt/root/set.sh


echo "echo '# Kde
yay -Sy --needed --noconfirm plasma konsole dolphin sddm kate spectacle
sudo systemctl enable sddm
yay -Sy --needed --noconfirm rime-ice-git fcitx5-skin-fluentdark-git
echo "patch:
  # 仅使用「雾凇拼音」的默认配置，配置此行即可
  __include: rime_ice_suggestion:/
  # 以下根据自己所需自行定义，仅做参考。
  # 针对对应处方的定制条目，请使用 <recipe>.custom.yaml 中配置，例如 rime_ice.custom.yaml
  __patch:
    key_binder/bindings/+:
      # 开启逗号句号翻页
      - { when: paging, accept: comma, send: Page_Up }
      - { when: has_menu, accept: period, send: Page_Down }" > /home/aw/.local/share/fcitx5/rime/default.custom.yaml

yay -Sy --needed --noconfirm sof-firmware alsa-firmware alsa-ucm-conf # 声音固件
yay -Sy --needed --noconfirm ntfs-3g # 使系统可以识别 NTFS 格式的硬盘
yay -Sy --needed --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra # 安装谷歌开源字体及表情
yay -Sy --needed --noconfirm ark # 压缩软件。在 dolphin 中可用右键解压压缩包
yay -Sy --needed --noconfirm packagekit-qt6 packagekit appstream-qt appstream # 确保 Discover（软件中心）可用，需重启
yay -Sy --needed --noconfirm gwenview # 图片查看器
flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub' > /mnt/home/aw/install_app.sh" >> /mnt/root/set.sh


chmod a+x /mnt/root/set.sh
chmod a+x /mnt/home/aw/install_app.sh

arch-chroot /mnt /bin/bash /root/set.sh

arch-chroot /mnt /bin/bash /home/aw/install_app.sh
echo '###############Set system Done!####################'
echo '###############app install Done!####################'
umount -R /mnt
reboot


