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


### Repository layout

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                        # local only, git-ignored
│   ├── mysql_password
│   ├── mysql_root_password
│   ├── wp_admin_password
│   └── wp_user_password
└── srcs/
    ├── .env                        # local only, git-ignored
    ├── .env.example                # committed template
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/setup.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/setup.sh
```

---
