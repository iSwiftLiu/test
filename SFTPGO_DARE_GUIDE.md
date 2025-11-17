# SFTPGo 本地文件系统存储 + DARE 加密配置指南

## 概述

本指南提供了使用本地文件系统作为存储后端配置 SFTPGo，并启用 DARE（Data At Rest Encryption）加密功能的完整说明。

## 什么是 DARE？

DARE（Data At Rest Encryption）是一种数据静止加密机制，用于保护存储在磁盘上的数据。它确保即使物理硬盘被盗，未经授权的用户也无法访问数据。

### DARE 的主要特点：
- **透明加密**: 自动加密所有存储的数据
- **主密钥管理**: 支持本地或外部 KMS（Key Management Service）
- **安全存储**: 确保敏感数据在磁盘上是加密的

## 系统要求

### 硬件要求
- CPU: 1+ 核心
- 内存: 512MB+ (建议 1GB+)
- 磁盘空间: 根据存储需求自定

### 软件要求
- SFTPGo v2.0+（建议 v2.3.0+）
- Linux/macOS/Windows
- Python 3.6+ (用于配置验证)
- OpenSSL (用于密钥生成)

### 网络要求
- SFTP 端口: 2022 (可配置)
- Web 管理界面: 8443 (HTTPS)
- REST API: 8080

## 文件说明

### 配置文件

#### 1. `sftpgo-dare.json` (推荐)
主配置文件，使用 JSON 格式。包含：
- SFTP 服务器配置
- 本地文件系统存储配置
- DARE 加密配置
- 用户管理设置
- Web 管理界面配置

#### 2. `sftpgo-dare.yaml`
YAML 格式的配置文件，功能与 JSON 相同。
选择您熟悉的格式即可。

#### 3. `sftpgo.json`
基础配置文件，不包含 DARE 加密功能。
用于需要纯本地文件系统存储而不需要加密的场景。

### 脚本文件

#### 1. `sftpgo-init.sh`
初始化脚本，用于：
- 检查系统环境和依赖
- 创建必要的目录结构
- 初始化数据库
- 生成加密密钥
- 验证配置

**使用方法:**
```bash
chmod +x sftpgo-init.sh
./sftpgo-init.sh
```

#### 2. `sftpgo-start.sh`
启动脚本，用于：
- 启动 SFTPGo 服务
- 验证服务状态
- 显示服务信息

**使用方法:**
```bash
chmod +x sftpgo-start.sh
./sftpgo-start.sh
```

#### 3. `sftpgo-stop.sh`
停止脚本，用于：
- 优雅地停止 SFTPGo 服务
- 清理进程

**使用方法:**
```bash
chmod +x sftpgo-stop.sh
./sftpgo-stop.sh
```

## 安装步骤

### 1. 安装 SFTPGo

**Ubuntu/Debian:**
```bash
apt-get update
apt-get install sftpgo
```

**macOS (使用 Homebrew):**
```bash
brew install sftpgo
```

**Docker:**
```bash
docker run -d \
  -p 2022:2022 \
  -p 8080:8080 \
  -p 8443:8443 \
  -v $(pwd)/sftpgo-dare.json:/etc/sftpgo/sftpgo.json \
  -v /srv/sftpgo/data:/var/lib/sftpgo/data \
  drakkan/sftpgo:latest
```

### 2. 准备配置

```bash
# 复制配置文件到适当位置
mkdir -p /etc/sftpgo
cp sftpgo-dare.json /etc/sftpgo/sftpgo.json

# 或使用 YAML 格式（需要 SFTPGo 支持）
cp sftpgo-dare.yaml /etc/sftpgo/sftpgo.yaml
```

### 3. 运行初始化脚本

```bash
# 使脚本可执行
chmod +x sftpgo-init.sh

# 设置环境变量（可选）
export SFTPGO_HOME=/etc/sftpgo
export SFTPGO_DATA_DIR=/srv/sftpgo/data

# 运行初始化脚本
./sftpgo-init.sh
```

初始化脚本将：
- 检查 SFTPGo 是否安装
- 创建数据目录: `/srv/sftpgo/data`
- 初始化 SQLite 数据库: `sftpgo.db`
- 生成加密密钥并存储在 `keys/` 目录
- 验证 DARE 配置

### 4. 启动 SFTPGo

```bash
chmod +x sftpgo-start.sh
./sftpgo-start.sh
```

## 配置详解

### DARE 加密配置

在 `sftpgo-dare.json` 中的 KMS（Key Management Service）部分：

```json
"kms": {
  "secrets": {
    "url": "local",
    "master_key": "sftpgo-secret-key-please-change-this-value"
  },
  "encryption": {
    "url": "local",
    "master_key": "sftpgo-encryption-key-please-change-this"
  }
}
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `kms.secrets.url` | 密钥管理服务，"local" 表示本地管理 | local |
| `kms.secrets.master_key` | 用于加密敏感配置数据的主密钥 | - |
| `kms.encryption.url` | 数据加密服务 | local |
| `kms.encryption.master_key` | 用于加密静止数据的主密钥 | - |

### 本地文件系统存储配置

```json
"storage": {
  "fs": {
    "osfs_type": 0
  }
}
```

- `osfs_type: 0` - 标准操作系统文件系统
- `osfs_type: 1` - 仅限 Windows 的本地网络驱动器

### SFTP 服务配置

```json
"sftpd": {
  "bindings": [
    {
      "port": 2022,
      "address": "0.0.0.0",
      "apply_proxy_config": true,
      "tls_mode": 0
    }
  ]
}
```

| 参数 | 说明 |
|------|------|
| `port` | SFTP 服务端口 |
| `address` | 监听地址（0.0.0.0 表示所有接口） |
| `tls_mode` | TLS 模式（0=禁用, 1=可选, 2=强制） |

## 使用和测试

### 1. 验证 SFTPGo 运行

```bash
# 查看进程
ps aux | grep sftpgo

# 查看日志
tail -f sftpgo.log

# 检查端口监听
netstat -tlnp | grep sftpgo
```

### 2. 测试 SFTP 连接

```bash
# 使用 sftp 客户端连接
sftp -P 2022 admin@localhost

# 输入密码：password123!

# 或使用 ssh 连接进行验证
ssh -p 2022 admin@localhost

# 使用密钥认证（如已配置）
sftp -P 2022 -i ~/.ssh/id_rsa admin@localhost
```

### 3. 验证 DARE 加密

#### 检查加密的文件

```bash
# 上传文件
echo "Test data" | sftp -b - -P 2022 admin@localhost <<EOF
put - test.txt
quit
EOF

# 查看存储文件（应该是加密的）
ls -la /srv/sftpgo/data/

# 尝试直接读取（应该是乱码）
cat /srv/sftpgo/data/test.txt

# 通过 SFTP 下载（应该正确解密）
sftp -P 2022 admin@localhost <<EOF
get test.txt test-downloaded.txt
quit
EOF

# 验证下载的文件内容
cat test-downloaded.txt
```

#### 检查加密密钥

```bash
# 查看生成的密钥
ls -la ./keys/
cat ./keys/secrets.key
cat ./keys/encryption.key

# 注意：这些是敏感信息，应该妥善保管
```

### 4. 使用 REST API 测试

```bash
# 列出用户
curl -k -X GET "https://localhost:8443/api/v2/users" \
  -H "X-SFTPGO-API-KEY: your-api-key"

# 或通过 Web 界面
# 访问 https://localhost:8443/
# 用户名: admin
# 密码: password123!
```

### 5. 检查 Web 管理界面

```bash
# 启动浏览器（使用你的 IP 地址替换 localhost）
firefox https://localhost:8443/

# 或使用 curl 检查
curl -k -v https://localhost:8443/
```

## 性能优化

### 1. 调整缓冲区大小

```json
"filesystem": {
  "provider": 0,
  "osconfig": {
    "read_buffer_size": 65536,
    "write_buffer_size": 65536
  }
}
```

### 2. 增加并发连接

```json
"common": {
  "pool_listeners": 8
}
```

### 3. 调整日志级别

生产环境推荐设置为 `warn` 或 `error`:

```json
"log_level": "warn"
```

### 4. 启用日志压缩

```json
"log_compress": true,
"log_max_age": 28,
"log_max_backups": 3
```

## 安全建议

### 1. 更改默认密码

**强烈建议**立即更改默认用户密码：

```bash
# 使用 SFTPGo CLI
sftpgo user mod admin --password "your-secure-password"

# 或通过 Web 界面
# https://localhost:8443/ -> Users -> Edit admin
```

### 2. 安全保管加密密钥

```bash
# 备份加密密钥
tar -czf sftpgo-keys-backup.tar.gz ./keys/

# 转移到安全位置
scp sftpgo-keys-backup.tar.gz user@secure-server:/backups/

# 删除本地副本后需要时恢复
# 注意：丢失密钥将导致数据无法恢复
```

### 3. 启用 TLS/SSL

```json
"sftpd": {
  "bindings": [
    {
      "tls_mode": 2,
      "certificate_file": "/etc/sftpgo/cert.pem",
      "certificate_key_file": "/etc/sftpgo/key.pem"
    }
  ]
}
```

### 4. 配置防火墙

```bash
# 仅允许特定 IP 访问
sudo ufw allow from 192.168.1.0/24 to any port 2022
sudo ufw allow from 192.168.1.0/24 to any port 8443
```

### 5. 定期备份

```bash
# 备份数据库和配置
tar -czf sftpgo-backup-$(date +%Y%m%d).tar.gz \
  sftpgo.db \
  sftpgo-dare.json \
  ./keys/

# 备份用户数据
rsync -avz /srv/sftpgo/data/ /backups/sftpgo-data/
```

### 6. 监控和日志

```bash
# 实时监控日志
tail -f sftpgo.log | grep -E "ERROR|WARN"

# 查看特定用户的活动
grep "username=admin" sftpgo.log

# 检查失败的登录尝试
grep "login failed" sftpgo.log
```

## 故障排查

### 问题 1：SFTPGo 无法启动

**症状:** 运行 `sftpgo-start.sh` 后服务立即退出

**解决方案:**
```bash
# 检查日志
tail -100 sftpgo.log

# 验证配置文件语法
python3 -m json.tool sftpgo-dare.json

# 检查数据库
ls -la sftpgo.db
```

### 问题 2：无法连接到 SFTP 服务

**症状:** `sftp: Connection refused`

**解决方案:**
```bash
# 检查 SFTPGo 是否运行
ps aux | grep sftpgo

# 检查端口是否打开
netstat -tlnp | grep 2022

# 检查防火墙
sudo ufw status
```

### 问题 3：DARE 加密未生效

**症状:** 文件在磁盘上以纯文本形式存储

**解决方案:**
```bash
# 验证 KMS 配置
python3 -c "import json; print(json.load(open('sftpgo-dare.json'))['kms'])"

# 检查日志中是否有加密相关的错误信息
grep -i "encrypt\|kms" sftpgo.log

# 重新初始化数据库
rm sftpgo.db
./sftpgo-init.sh
```

### 问题 4：Web 管理界面无法访问

**症状:** `Connection refused` 或 `SSL certificate error`

**解决方案:**
```bash
# 检查 8443 端口
netstat -tlnp | grep 8443

# 使用忽略证书警告的方式测试
curl -k https://localhost:8443/

# 检查证书
openssl s_client -connect localhost:8443
```

### 问题 5：内存或磁盘占用过高

**症状:** SFTPGo 进程消耗大量内存或磁盘空间

**解决方案:**
```bash
# 减少日志级别
# 在配置文件中设置 "log_level": "error"

# 减少日志保留时间
# 在配置文件中设置 "log_max_age": 7

# 清理旧日志
find . -name "sftpgo*.log.*" -mtime +30 -delete

# 监控磁盘使用
du -sh /srv/sftpgo/data/
```

## 环境变量

可以通过环境变量自定义行为：

```bash
# 设置 SFTPGo 主目录
export SFTPGO_HOME=/opt/sftpgo

# 设置配置文件路径
export SFTPGO_CONFIG_FILE=/opt/sftpgo/sftpgo-dare.json

# 设置数据目录
export SFTPGO_DATA_DIR=/var/lib/sftpgo/data

# 启动脚本
./sftpgo-start.sh
```

## 容器化部署

### Docker Compose 示例

```yaml
version: '3.8'

services:
  sftpgo:
    image: drakkan/sftpgo:latest
    container_name: sftpgo-dare
    ports:
      - "2022:2022"
      - "8080:8080"
      - "8443:8443"
    volumes:
      - ./sftpgo-dare.json:/etc/sftpgo/sftpgo.json:ro
      - /srv/sftpgo/data:/var/lib/sftpgo/data
      - ./keys:/var/lib/sftpgo/keys
      - ./sftpgo.db:/var/lib/sftpgo/sftpgo.db
    environment:
      - SFTPGO_LOG_LEVEL=info
    restart: unless-stopped
    networks:
      - sftpgo-net

networks:
  sftpgo-net:
    driver: bridge
```

**使用方法:**
```bash
docker-compose up -d

# 查看日志
docker-compose logs -f sftpgo

# 停止服务
docker-compose down
```

## 性能基准

### 单服务器配置基准

| 指标 | 值 | 备注 |
|------|-----|------|
| 最大并发连接 | 100+ | 取决于系统资源 |
| 文件上传速率 | 100-500 MB/s | 取决于磁盘速率 |
| 文件下载速率 | 100-500 MB/s | 取决于磁盘和网络 |
| DARE 加密开销 | 5-15% | 取决于 CPU |
| 内存占用 | 50-200 MB | 基础配置 |

## 常见用例

### 1. 个人文件共享

最小化配置，单用户，本地网络：
- 小型数据集（<100GB）
- 基础认证
- 本地文件系统存储

### 2. 企业备份服务

中等规模部署：
- 多用户支持
- DARE 加密强制启用
- 定期备份策略
- 审计日志记录

### 3. 开发环境

开发和测试：
- 禁用 TLS（仅用于内部网络）
- 调试日志级别
- 快速原型设计

## 更新和维护

### 升级 SFTPGo

```bash
# 备份当前配置和数据
./sftpgo-stop.sh
tar -czf sftpgo-backup-$(date +%Y%m%d).tar.gz \
  sftpgo.db sftpgo-dare.json ./keys/

# 升级 SFTPGo
apt-get update && apt-get upgrade sftpgo

# 测试新版本
./sftpgo-start.sh

# 检查日志中是否有错误
tail sftpgo.log
```

### 数据库维护

```bash
# 检查数据库完整性
sqlite3 sftpgo.db "PRAGMA integrity_check;"

# 优化数据库
sqlite3 sftpgo.db "VACUUM;"

# 备份数据库
cp sftpgo.db sftpgo.db.backup
```

## 许可证和支持

- **SFTPGo**: 开源项目，遵循 AGPL-3.0 许可证
- **官方文档**: https://sftpgo.github.io/
- **GitHub 仓库**: https://github.com/drakkan/sftpgo
- **问题报告**: https://github.com/drakkan/sftpgo/issues

## 联系和反馈

如有问题或建议，请：

1. 查看官方文档和常见问题解答
2. 查阅本指南的故障排查部分
3. 提出问题时包括以下信息：
   - SFTPGo 版本
   - 操作系统版本
   - 错误日志
   - 配置文件（删除敏感信息）

## 附录

### A. 完整配置示例

见 `sftpgo-dare.json` 和 `sftpgo-dare.yaml`

### B. 脚本参考

- `sftpgo-init.sh` - 初始化脚本
- `sftpgo-start.sh` - 启动脚本
- `sftpgo-stop.sh` - 停止脚本

### C. 相关文件

```
.
├── sftpgo-dare.json          # DARE 配置文件 (JSON)
├── sftpgo-dare.yaml          # DARE 配置文件 (YAML)
├── sftpgo.json               # 基础配置文件
├── sftpgo-init.sh            # 初始化脚本
├── sftpgo-start.sh           # 启动脚本
├── sftpgo-stop.sh            # 停止脚本
├── SFTPGO_DARE_GUIDE.md      # 本文档
├── sftpgo.log                # 日志文件（运行时生成）
├── sftpgo.db                 # SQLite 数据库（运行时生成）
├── sftpgo.pid                # 进程 ID 文件（运行时生成）
└── keys/                     # 加密密钥目录（初始化时生成）
    ├── secrets.key
    └── encryption.key
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2024 | 初始版本 |

---

**最后更新**: 2024年

**文档维护者**: SFTPGo Team
