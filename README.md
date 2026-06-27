# Hive-Inception

### Configuration

- VM: Alpine Linux x86_64
- RAM: 4GB
- CPUs: 2
- Disk: 30GB

### VM Setup (Alpine Linux 3.24)

- Network: `eth0` - first wired network interface (Ethernet)
- `DHCP` (Dynamic Host Configuration Protocol): on - automatically assigning IP addresses and other communication parameters to devices connected to the network using a client–server architecture
- NTP (Network Time Protocol) client: `chrony` - lighter, faster and more accurate than the traditional ntpd
- APK mirror: default or a geographically close one
- SSH server: `openssh` - standard SSH server
- Disk: `sda` (the main virtual hard disk) and possibly `sdb` if there are extra disks added
- Disk setup: `sys` - full installation of Alpine

### Dependencies
(source file - */etc/apk/repositories*)
- docker
- docker-cli-compose
