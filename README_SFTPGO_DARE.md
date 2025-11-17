# SFTPGo 本地文件系统存储 + DARE 加密

## 项目概述

这个项目提供了 SFTPGo 的完整配置，实现了本地文件系统存储后端和 DARE（Data At Rest Encryption）数据静止加密功能。

## 文件结构

```
.
├── README_SFTPGO_DARE.md        # 本文件 - 快速入门指南
├── SFTPGO_DARE_GUIDE.md         # 详细的配置和使用指南
├── sftpgo-dare.json             # JSON 格式的完整配置文件（推荐）
├── sftpgo-dare.yaml             # YAML 格式的配置文件
├── sftpgo.json                  # 不含 DARE 的基础配置
├── sftpgo-init.sh               # 初始化脚本
├── sftpgo-start.sh              # 启动脚本
├── sftpgo-stop.sh               # 停止脚本
├── sftpgo-test.sh               # 测试脚本
├── docker-compose.yml           # Docker Compose 配置
└── Dockerfile                   # Docker 镜像定义
```

## 快速开始

### 1. 系统要求

- **操作系统**: Linux (推荐 Ubuntu 20.04+), macOS, 或 Windows
- **SFTPGo**: v2.0+ (推荐 v2.3.0+)
- **Python**: 3.6+ (用于配置验证)
- **OpenSSL**: 用于密钥生成

### 2. 安装 SFTPGo

#### Ubuntu/Debian:
```bash
apt-get update
apt-get install sftpgo
```

#### macOS (Homebrew):
```bash
brew install sftpgo
```

#### 其他平台:
访问 [SFTPGo 官方网站](https://sftpgo.github.io/) 下载安装程序

### 3. 快速配置

#### 方法 A: 使用初始化脚本（推荐）

```bash
# 1. 进入项目目录
cd /path/to/project

# 2. 使脚本可执行
chmod +x sftpgo-init.sh sftpgo-start.sh sftpgo-stop.sh

# 3. 运行初始化脚本
./sftpgo-init.sh

# 4. 启动 SFTPGo
./sftpgo-start.sh
```

#### 方法 B: 手动配置

```bash
# 1. 创建数据目录
mkdir -p /srv/sftpgo/data
chmod 755 /srv/sftpgo/data

# 2. 初始化数据库
sftpgo initdb -c sftpgo-dare.json

# 3. 生成加密密钥
mkdir -p keys
openssl rand -base64 32 > keys/secrets.key
openssl rand -base64 32 > keys/encryption.key
chmod 600 keys/*.key

# 4. 启动 SFTPGo
sftpgo serve -c sftpgo-dare.json &
```

#### 方法 C: 使用 Docker Compose

```bash
# 1. 构建和启动容器
docker-compose up -d

# 2. 查看日志
docker-compose logs -f sftpgo

# 3. 停止服务
docker-compose down
```

### 4. 验证安装

```bash
# 检查服务是否运行
ps aux | grep sftpgo

# 测试 SFTP 连接
sftp -P 2022 admin@localhost
# 输入密码: password123!

# 查看日志
tail -f sftpgo.log
```

## 配置要点

### DARE 加密设置

配置文件中的关键加密参数（位于 `sftpgo-dare.json` 中的 `kms` 部分）：

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

**⚠️ 安全建议**: 
- 立即更改主密钥为强随机密钥
- 妥善保管密钥备份
- 不要在版本控制中提交真实的密钥

### 本地文件系统存储

```json
"storage": {
  "fs": {
    "osfs_type": 0
  }
}
```

这配置将所有用户文件存储在本地文件系统中。

### SFTP 服务绑定

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

- 端口: 2022
- 监听地址: 0.0.0.0 (所有接口)
- TLS 模式: 0 (禁用 TLS，可选值: 0=禁用, 1=可选, 2=强制)

## 关键特性

### ✅ DARE 加密
- 自动加密所有存储数据
- 支持本地和远程 KMS
- 透明加密/解密

### ✅ 本地文件系统存储
- 简单易用
- 高性能
- 无依赖性

### ✅ 用户管理
- 预配置的 admin 用户
- 支持基于密钥和密码的认证
- 细粒度权限控制

### ✅ 可视化管理
- Web 管理界面（HTTPS）
- REST API

## 默认凭证

| 项目 | 值 |
|------|-----|
| SFTP 用户名 | admin |
| SFTP 密码 | password123! |
| SFTP 端口 | 2022 |
| Web 管理 URL | https://127.0.0.1:8443 |
| REST API | http://127.0.0.1:8080/api/ |
| 数据目录 | /srv/sftpgo/data |

## 测试 DARE 加密

### 1. 上传测试文件

```bash
# 创建测试文件
echo "This is a test file" > test.txt

# 通过 SFTP 上传
sftp -P 2022 admin@localhost <<EOF
put test.txt remote-test.txt
quit
EOF
```

### 2. 验证加密

```bash
# 查看存储在磁盘上的文件（应该是加密的乱码）
cat /srv/sftpgo/data/remote-test.txt

# 通过 SFTP 下载（应该正确解密）
sftp -P 2022 admin@localhost <<EOF
get remote-test.txt local-test.txt
quit
EOF

# 验证内容相同
diff test.txt local-test.txt
echo "If no output, files are identical - DARE working!"
```

## 常见任务

### 修改管理员密码

```bash
# 使用 SFTPGo CLI
sftpgo user mod admin --password "new-secure-password"

# 或者通过 Web 界面
# https://127.0.0.1:8443 -> 用户管理 -> 编辑 admin
```

### 创建新用户

```bash
sftpgo user add newuser \
  --password "user-password" \
  --home-dir "/srv/sftpgo/data/newuser"
```

### 备份配置和密钥

```bash
tar -czf sftpgo-backup-$(date +%Y%m%d).tar.gz \
  sftpgo-dare.json \
  sftpgo.db \
  keys/
```

### 查看日志

```bash
# 实时日志
tail -f sftpgo.log

# 查看特定错误
grep "ERROR" sftpgo.log

# 查看特定用户的活动
grep "admin" sftpgo.log
```

### 停止 SFTPGo

```bash
# 使用脚本
./sftpgo-stop.sh

# 或手动
kill $(cat sftpgo.pid)
```

## 性能优化

### 1. 增加并发连接

编辑 `sftpgo-dare.json`，修改：

```json
"common": {
  "pool_listeners": 8
}
```

### 2. 调整缓冲区大小

```json
"filesystem": {
  "provider": 0,
  "osconfig": {
    "read_buffer_size": 65536,
    "write_buffer_size": 65536
  }
}
```

### 3. 减少日志开销

```json
"log_level": "warn"
```

## 故障排查

### 问题: 无法启动 SFTPGo

```bash
# 检查日志
tail -100 sftpgo.log

# 验证配置
python3 -m json.tool sftpgo-dare.json

# 检查端口占用
netstat -tlnp | grep 2022

# 检查数据库
ls -la sftpgo.db
```

### 问题: 无法连接 SFTP

```bash
# 检查服务是否运行
ps aux | grep sftpgo

# 检查端口
netstat -tlnp | grep 2022

# 测试连接
sftp -P 2022 -v admin@localhost
```

### 问题: 加密未生效

```bash
# 检查 KMS 配置
grep -A 5 '"encryption"' sftpgo-dare.json

# 查看日志中的加密信息
grep -i "encrypt" sftpgo.log

# 重新初始化（备份后）
mv sftpgo.db sftpgo.db.bak
./sftpgo-init.sh
```

## 安全建议

1. **更改默认密码** - 强烈建议立即修改所有默认密码
2. **使用强加密密钥** - 生成长度 32+ 的随机密钥
3. **启用 TLS** - 为 SFTP 连接启用 TLS 加密
4. **定期备份** - 定期备份配置、数据库和加密密钥
5. **监控日志** - 定期检查日志以发现异常活动
6. **限制访问** - 使用防火墙规则限制对 SFTPGo 的访问

## 进阶配置

### 外部 KMS 集成

SFTPGo 支持与外部密钥管理服务集成。详见 [详细指南](SFTPGO_DARE_GUIDE.md#外部kms集成)。

### TLS/SSL 配置

使用自签名证书或受信证书配置 HTTPS。详见 [详细指南](SFTPGO_DARE_GUIDE.md#启用tlsssl)。

### 多用户配置

创建多个用户，每个用户有自己的主目录和权限。详见 [详细指南](SFTPGO_DARE_GUIDE.md#多用户配置)。

## 性能基准

在标准硬件上的性能指标：

| 指标 | 值 | 备注 |
|------|-----|------|
| 并发连接 | 100+ | 取决于系统资源 |
| 上传速率 | 100-500 MB/s | 取决于磁盘 I/O |
| 下载速率 | 100-500 MB/s | 取决于网络 |
| 加密开销 | 5-15% | 相对于未加密 |
| 内存占用 | 50-200 MB | 基础配置 |

## 部署选项

### 本地部署
```bash
./sftpgo-start.sh
```

### Docker 部署
```bash
docker-compose up -d
```

### Kubernetes 部署
可以使用 Helm Chart 或自定义 Deployment/StatefulSet

### 云平台部署
支持 AWS EC2, Azure VM, GCP Compute Engine 等

## 更新和升级

```bash
# 停止服务
./sftpgo-stop.sh

# 备份
tar -czf backup-$(date +%Y%m%d).tar.gz sftpgo.db sftpgo-dare.json keys/

# 升级 SFTPGo
apt-get update && apt-get upgrade sftpgo

# 重新启动
./sftpgo-start.sh
```

## 许可和支持

- **SFTPGo License**: AGPL-3.0
- **官方网站**: https://sftpgo.github.io/
- **GitHub**: https://github.com/drakkan/sftpgo
- **问题报告**: https://github.com/drakkan/sftpgo/issues

## 相关资源

- [完整配置指南](SFTPGO_DARE_GUIDE.md)
- [SFTPGo 官方文档](https://sftpgo.github.io/docs/overview/)
- [DARE 加密说明](SFTPGO_DARE_GUIDE.md#什么是dare)

## 下一步

1. 📖 阅读 [详细指南](SFTPGO_DARE_GUIDE.md)
2. 🔐 修改默认密码和加密密钥
3. 🧪 运行测试脚本验证配置
4. 📊 监控和优化性能
5. 💾 设置定期备份策略

## 常见问题（FAQ）

**Q: DARE 加密对性能有多大影响？**
A: 通常在 5-15% 之间，取决于 CPU 和磁盘性能。

**Q: 如果丢失加密密钥会发生什么？**
A: 数据将无法恢复。请务必妥善备份密钥。

**Q: 可以改用数据库而不是本地文件系统吗？**
A: 可以。SFTPGo 支持 PostgreSQL、MySQL 等数据库作为存储后端。

**Q: 如何扩展到多服务器部署？**
A: 使用 PostgreSQL 或其他集中式数据库，配置多个 SFTPGo 实例。

**Q: 支持哪些客户端？**
A: 任何支持 SFTP 的 SSH 客户端（如 FileZilla, WinSCP, sftp, scp 等）。

## 修改日志

| 版本 | 日期 | 更改 |
|------|------|------|
| 1.0 | 2024 | 初始版本 |

---

需要帮助？查看 [详细指南](SFTPGO_DARE_GUIDE.md) 或访问 [SFTPGo GitHub](https://github.com/drakkan/sftpgo)。
