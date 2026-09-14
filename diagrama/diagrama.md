# Diagrama de Particionamento RHEL

/dev/sda
│
├── sda1
│   └── /boot/efi
│       1 GB
│       FAT32
│
├── sda2
│   └── /boot
│       1 GB
│       XFS
│
└── sda3
    └── LUKS2
        │
        └── /dev/mapper/cryptlvm
            │
            └── VG vg_sistema
                │
                ├── lv_root
                │   15 GB → /
                │
                ├── lv_var
                │   8 GB → /var
                │
                ├── lv_varlog
                │   5 GB → /var/log
                │
                ├── lv_vartmp
                │   3 GB → /var/tmp
                │
                ├── lv_home
                │   10 GB → /home
                │
                ├── lv_tmp
                │   3 GB → /tmp
                │
                ├── lv_swap
                │   4 GB → swap
                │
                └── ~9 GB livres