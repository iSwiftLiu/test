# SFTPGo DARE 架构设计

## 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      SFTPGo with DARE                           │
│                   (Local Filesystem Storage)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
           ┌────▼────┐  ┌────▼────┐  ┌───▼────┐
           │   SFTP  │  │  REST   │  │  Web   │
           │ Server  │  │   API   │  │ Admin  │
           │ :2022   │  │ :8080   │  │:8443   │
           └────┬────┘  └────┬────┘  └───┬────┘
                │             │           │
                └─────────────┼───────────┘
                              │
                    ┌─────────▼──────────┐
                    │   SFTPGo Core      │
                    │   (Auth, Perms)    │
                    └─────────┬──────────┘
                              │
                ┌─────────────┼──────────────┐
                │             │              │
           ┌────▼────┐  ┌────▼────┐  ┌────▼────┐
           │  DARE   │  │ Storage │  │ Database│
           │Encrypt/ │  │  Layer  │  │(SQLite) │
           │Decrypt  │  │         │  │         │
           └────┬────┘  └────┬────┘  └────┬────┘
                │             │            │
           ┌────▼────┐   ┌────▼─────┐ ┌──▼────┐
           │   KMS   │   │ Local    │ │SQLite │
           │(Secrets)│   │Filesystem│ │ File  │
           │         │   │          │ │       │
           └─────────┘   └──────────┘ └───────┘
                │             │            │
        ┌───────▼─────────┐   │      ┌─────▼──┐
        │  Encryption     │   │      │ Data   │
        │    Keys         │   │      │ Files  │
        │  - secrets.key  │   │      │        │
        │  - encrypt.key  │   │      │        │
        └─────────────────┘   │      └────────┘
                              │
                    ┌─────────▼─────────┐
                    │  /srv/sftpgo/data │
                    │  (Storage Volume) │
                    └───────────────────┘
```

## 数据流

### 文件上传流程 (含 DARE 加密)

```
┌──────────┐
│ SFTP     │
│ Client   │
└────┬─────┘
     │ (SFTP Command)
     ▼
┌─────────────────────────┐
│ SFTP Server (Port 2022) │
└────┬────────────────────┘
     │
     ▼
┌─────────────────────────┐
│ Authentication          │
│ - Username/Password     │
│ - SSH Key              │
└────┬────────────────────┘
     │ (Authenticated)
     ▼
┌─────────────────────────┐
│ Authorization Check     │
│ (Permissions)           │
└────┬────────────────────┘
     │ (Authorized)
     ▼
┌─────────────────────────┐
│ DARE Encryption Engine  │
│ - Load Master Key       │
│ - Generate Data Key     │
│ - Encrypt File Content  │
└────┬────────────────────┘
     │ (Encrypted Data)
     ▼
┌─────────────────────────┐
│ Write to Filesystem     │
│ /srv/sftpgo/data/...    │
└────┬────────────────────┘
     │
     ▼
┌─────────────────────────┐
│ Update Database         │
│ (File Metadata)         │
└─────────────────────────┘
```

### 文件下载流程 (含 DARE 解密)

```
┌──────────┐
│ SFTP     │
│ Client   │
└────┬─────┘
     │ (SFTP GET)
     ▼
┌─────────────────────────┐
│ SFTP Server (Port 2022) │
└────┬────────────────────┘
     │
     ▼
┌─────────────────────────┐
│ Authentication          │
└────┬────────────────────┘
     │
     ▼
┌─────────────────────────┐
│ Authorization Check     │
│ (Read Permission)       │
└────┬────────────────────┘
     │ (Authorized)
     ▼
┌─────────────────────────┐
│ Read from Filesystem    │
│ /srv/sftpgo/data/...    │
│ (Encrypted Data)        │
└────┬────────────────────┘
     │ (Encrypted Content)
     ▼
┌─────────────────────────┐
│ DARE Decryption Engine  │
│ - Load Master Key       │
│ - Decrypt File Content  │
└────┬────────────────────┘
     │ (Plaintext Data)
     ▼
┌─────────────────────────┐
│ Send to SFTP Client     │
└─────────────────────────┘
```

## 组件架构

### 1. SFTP 服务层

```
SFTP Server Module
├── Connection Handler
│   ├── TCP Listener (Port 2022)
│   ├── SSH Protocol Parser
│   └── SFTP Subsystem Handler
├── Authentication
│   ├── Password Auth
│   ├── Public Key Auth
│   └── Identity Verification
└── Session Management
    ├── Active Connections
    ├── Transfer Control
    └── Resource Limits
```

### 2. 加密层 (DARE)

```
DARE Encryption Layer
├── Key Management
│   ├── Master Key (secrets.key)
│   ├── Master Key (encryption.key)
│   └── Data Key Generation
├── Encryption Engine
│   ├── Cipher Selection
│   ├── IV Generation
│   └── Authentication Tag
└── Decryption Engine
    ├── Key Derivation
    ├── Cipher Operations
    └── Tag Verification
```

### 3. 存储层

```
Storage Layer
├── Filesystem Operations
│   ├── File I/O
│   ├── Directory Management
│   └── Permission Handling
├── Buffer Management
│   ├── Read Buffer (configurable)
│   └── Write Buffer (configurable)
└── File Metadata
    ├── Inode
    ├── Permissions
    └── Timestamps
```

### 4. 数据库层

```
Database Layer (SQLite)
├── Schema
│   ├── users table
│   ├── folders table
│   ├── admin table
│   └── shares table
├── Connection Pool
│   ├── Connection Management
│   └── Query Execution
└── Data Persistence
    ├── Transaction Support
    └── Integrity Checks
```

## 部署模式

### 模式 1: 本地部署

```
┌────────────────────────────────────┐
│      Physical/Virtual Server       │
│                                    │
│  ┌────────────────────────────┐   │
│  │  Operating System (Linux)  │   │
│  │  ├─ SFTPGo Binary          │   │
│  │  ├─ SQLite Database        │   │
│  │  ├─ Encryption Keys        │   │
│  │  └─ Data Files             │   │
│  └────────────────────────────┘   │
│         ▲        ▲        ▲        │
│         │        │        │        │
│      2022    8080      8443        │
│      (SFTP) (API)    (Web)         │
└────────────────────────────────────┘
        │        │        │
    ┌───┴────┬───┴────┬───┴────┐
    │        │        │        │
  SFTP    REST      Web     Admin
 Client    API   Browser    Tools
```

### 模式 2: Docker 部署

```
┌─────────────────────────────────────────┐
│            Docker Host Machine          │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │    Docker Container (SFTPGo)      │  │
│  │  ├─ SFTPGo Application            │  │
│  │  ├─ SQLite DB (Volume)            │  │
│  │  ├─ Encryption Keys (Volume)      │  │
│  │  └─ Data Files (Volume)           │  │
│  └───────────────────────────────────┘  │
│         ▲        ▲        ▲              │
│         │        │        │              │
│      2022    8080      8443              │
│      (SFTP) (API)    (Web)               │
└─────────────────────────────────────────┘
        │        │        │
    ┌───┴────┬───┴────┬───┴────┐
    │        │        │        │
  SFTP    REST      Web     Admin
 Client    API   Browser    Tools
```

## 文件加密示意图

### 未加密文件存储

```
User File: "Hello World"
    ▼
直接写入磁盘
    ▼
Disk: "Hello World" (明文 - 不安全!)
```

### 使用 DARE 加密后

```
User File: "Hello World"
    ▼
┌─────────────────────────┐
│ DARE 加密引擎           │
│ ├─ 加载主密钥           │
│ ├─ 生成数据密钥         │
│ └─ 使用 AES-256 加密   │
└─────────────────────────┘
    ▼
Encrypted Data: "xK9@#$L2...7Q$m" (密文)
    ▼
Disk: "xK9@#$L2...7Q$m" (加密 - 安全!)
    ▼
下载时解密
    ▼
┌─────────────────────────┐
│ DARE 解密引擎           │
│ ├─ 加载主密钥           │
│ ├─ 导出数据密钥         │
│ └─ 使用 AES-256 解密   │
└─────────────────────────┘
    ▼
Decrypted: "Hello World"
    ▼
Client receives: "Hello World" ✓
```

## 配置流程

```
┌──────────────────────────┐
│ 1. 安装 SFTPGo           │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ 2. 创建配置文件          │
│ sftpgo-dare.json         │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ 3. 运行初始化脚本        │
│ ./sftpgo-init.sh         │
│ ├─ 创建目录              │
│ ├─ 初始化数据库          │
│ └─ 生成密钥              │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ 4. 启动 SFTPGo 服务      │
│ ./sftpgo-start.sh        │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ 5. 验证配置              │
│ ./sftpgo-test.sh         │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ 6. 使用 SFTPGo           │
│ - Web 管理界面           │
│ - SFTP 客户端            │
│ - REST API               │
└──────────────────────────┘
```

## 安全架构

```
┌────────────────────────────────────┐
│        Security Layers             │
└────────────────────────────────────┘

Layer 1: Network Security
├─ Firewall Rules
├─ Port Filtering
└─ Access Control

Layer 2: Transport Security
├─ TLS/SSL (可选)
├─ SSH Protocol
└─ SFTP (Secure FTP)

Layer 3: Authentication
├─ Password Auth
├─ SSH Key Auth
└─ Multi-factor (可选)

Layer 4: Authorization
├─ User Permissions
├─ Directory ACLs
└─ Resource Limits

Layer 5: Data Security
├─ DARE Encryption
├─ Master Key Management
├─ Data Key Generation
└─ Encrypted Storage

Layer 6: Audit & Monitoring
├─ Access Logs
├─ Event Logging
└─ Performance Monitoring
```

## 扩展架构 (多服务器)

```
┌──────────────────────────────────────────────────────┐
│         Multi-Server SFTPGo Deployment               │
└──────────────────────────────────────────────────────┘

         ┌────────────────────────────┐
         │   Load Balancer            │
         │   (Nginx/HAProxy)          │
         └──────────┬─────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
    ┌───▼──┐   ┌───▼──┐   ┌───▼──┐
    │SFTP  │   │SFTP  │   │SFTP  │
    │ 1    │   │ 2    │   │ N    │
    └───┬──┘   └───┬──┘   └───┬──┘
        │          │          │
        └──────────┼──────────┘
                   │
        ┌──────────▼──────────┐
        │  Shared Storage     │
        │  (NFS/S3/etc)       │
        └─────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  PostgreSQL DB      │
        │  (Centralized)      │
        └─────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  KMS Service        │
        │  (External)         │
        └─────────────────────┘
```

## 技术栈

```
┌─────────────────────────────────────┐
│        SFTPGo DARE Stack            │
├─────────────────────────────────────┤
│ Language:      Go (Golang)          │
│ Protocol:      SFTP (SSH)           │
│ Database:      SQLite / PostgreSQL  │
│ Encryption:    AES-256 (DARE)       │
│ REST Framework: Built-in            │
│ Web UI:        HTML5 + JavaScript   │
│ Storage:       Local Filesystem     │
└─────────────────────────────────────┘
```

## 监控架构

```
┌──────────────────────────────────────┐
│     SFTPGo Monitoring Stack          │
└──────────────────────────────────────┘

SFTPGo
  │
  ├─ Logs (sftpgo.log)
  │   └─ Log Analysis Tools
  │
  ├─ Metrics (REST API)
  │   ├─ Connection Count
  │   ├─ Data Transferred
  │   └─ Error Rates
  │
  └─ Events
      ├─ Login Events
      ├─ File Operations
      └─ Security Events
```

## 故障恢复架构

```
┌──────────────────────┐
│   Backup Strategy    │
├──────────────────────┤
│                      │
│ Daily Backups:       │
│ ├─ Configuration     │
│ ├─ Database          │
│ ├─ Encryption Keys   │
│ └─ User Data         │
│                      │
│ Storage:             │
│ ├─ Local Backup      │
│ ├─ Remote NAS        │
│ └─ Cloud Storage     │
│                      │
│ Recovery:            │
│ ├─ Point-in-time     │
│ ├─ Full Restore      │
│ └─ Incremental       │
└──────────────────────┘
```

---

## 总结

该架构设计提供了：
- ✅ 安全的加密存储（DARE）
- ✅ 高效的本地文件系统存储
- ✅ 灵活的部署选项
- ✅ 可扩展的设计
- ✅ 完整的监控和审计
- ✅ 强大的故障恢复能力
