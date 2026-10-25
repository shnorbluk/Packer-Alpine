```shell
podman run -it --rm -e RDP_SERVER=yes -p 45670:3389 -v /mnt:/mnt -v /mnt/share/tmp/wine_c:/home/wineuser/.wine/drive_c scottyhardy/docker-wine bash
export DISPLAY=:0.0
export XDG_RUNTIME_DIR=/tmp/xdg-runtime
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
export WINEPREDIX=/mnt/extend/wine
wineboot --init
```


```shell
doas truncate -s 20G /mnt/share/tmp/podman-storage.img
doas mkfs.ext4 /mnt/share/tmp/podman-storage.img
doas mkdir /mnt/extend
doas mount -o loop,noatime,async /mnt/share/tmp/podman-storage.img /mnt/extend/
doas chown -R $(id -u):$(id -g) /mnt/extend
mkdir /mnt/extend/{tmp,local}
export TMPDIR="/mnt/extend/tmp"
doas rm -rf ~/.local
ln -s /mnt/extend/local ~/.local
```


```shell
podman push 192.168.56.1:5000/docker-wine
```

```shell
alpine-vm:~$ zcat /mnt/share/home/Documents/docker-wine.tgz | time docker load
real    7m 8.43s
user    0m 0.84s
sys     0m 12.71s
alpine-vm:~$ time podman pull docker.io/scottyhardy/docker-wine
real    3m 55.53s
user    0m 41.51s
sys     0m 47.10s
alpine-vm:~$ time podman pull 192.168.56.1:5000/docker-wine
real    2h 28m 42s
user    14m 25.23s
sys     42m 42.02s
```
