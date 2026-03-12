# OpenClaw 安全配置基线参考

本文档基于工信部NVDB发布的"六要六不要"安全建议，提供详细的安全配置参考。

## 一、智能体部署基线

### 1.1 创建专用用户

**不要**使用root或sudo组用户运行OpenClaw。

```bash
# 创建受限用户
sudo adduser --shell /bin/rbash --disabled-password clawuser

# 可选：创建受限shell环境
sudo mkdir -p /home/clawuser/bin
sudo ln -s /bin/ls /home/clawuser/bin/ls
sudo ln -s /bin/echo /home/clawuser/bin/echo
sudo ln -s /bin/cat /home/clawuser/bin/cat
sudo ln -s /bin/grep /home/clawuser/bin/grep
sudo ln -s /usr/bin/openclaw /home/clawuser/bin/openclaw

# 限制PATH并设置为只读
echo 'if [ "$USER" = "clawuser" ]; then export PATH=/home/clawuser/bin; readonly PATH; fi' | sudo tee /etc/profile.d/restricted_clawuser.sh
sudo chmod 644 /etc/profile.d/restricted_clawuser.sh
```

### 1.2 禁用root登录

```bash
# 禁用SSH root登录
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

## 二、网络访问控制基线

### 2.1 Gateway绑定配置

**要**绑定到127.0.0.1，**不要**绑定到0.0.0.0。

```json
// ~/.openclaw/openclaw.json
{
  "gateway": {
    "bind": "127.0.0.1",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "your-strong-token-here"
    }
  }
}
```

### 2.2 iptables防火墙配置

```bash
# 创建自定义链
sudo iptables -N OPENCLAW_ALLOWED

# 添加允许的IP（替换为实际IP）
sudo iptables -A OPENCLAW_ALLOWED -s 192.168.1.100 -j ACCEPT
sudo iptables -A OPENCLAW_ALLOWED -s 10.0.0.5 -j ACCEPT
sudo iptables -A OPENCLAW_ALLOWED -j RETURN

# 应用到OpenClaw端口
sudo iptables -A INPUT -p tcp --dport 18789 -j OPENCLAW_ALLOWED
sudo iptables -A INPUT -p tcp --dport 18789 -j DROP

# 关闭危险端口（根据需要）
# Telnet
sudo iptables -A INPUT -p tcp --dport 23 -j DROP
# Windows文件共享
sudo iptables -A INPUT -p tcp --dport 135:139 -j DROP
sudo iptables -A INPUT -p tcp --dport 445 -j DROP
# Windows远程桌面
sudo iptables -A INPUT -p tcp --dport 3389 -j DROP
# VNC
sudo iptables -A INPUT -p tcp --dport 5900:5910 -j DROP
# 数据库端口（如需外网访问请限制IP）
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP   # MySQL
sudo iptables -A INPUT -p tcp --dport 5432 -j DROP   # PostgreSQL
sudo iptables -A INPUT -p tcp --dport 6379 -j DROP   # Redis
sudo iptables -A INPUT -p tcp --dport 27017 -j DROP  # MongoDB
```

### 2.3 UFW配置（Ubuntu/Debian）

```bash
# 启用UFW
sudo ufw enable

# 默认拒绝入站
sudo ufw default deny incoming

# 允许特定IP访问OpenClaw端口
sudo ufw allow from 192.168.1.0/24 to any port 18789

# 拒绝18789端口的其他访问
sudo ufw deny 18789

# 允许SSH（限制IP更安全）
sudo ufw allow from 192.168.1.100 to any port 22

# 查看状态
sudo ufw status verbose
```

### 2.4 VPN接入配置

当使用VPN时：

```bash
# 将OpenClaw Gateway绑定127.0.0.1（不要绑定0.0.0.0）
# 在openclaw.json中设置：
{
  "gateway": {
    "bind": "127.0.0.1",
    "auth": {
      "mode": "token",
      "token": "your-strong-random-token-min-32-chars"
    }
  }
}

# 关闭18789端口的公网访问
sudo ufw deny 18789

# 强制通过VPN访问
```

## 三、日志审计基线

### 3.1 开启详细日志

```bash
# 方法1：命令行参数
openclaw gateway --log-level debug >> /var/log/openclaw.log 2>&1

# 方法2：配置文件
{
  "gateway": {
    "logLevel": "debug"
  }
}

# 方法3：systemd服务
# /etc/systemd/system/openclaw.service
[Service]
ExecStart=/usr/bin/openclaw gateway --log-level debug
StandardOutput=append:/var/log/openclaw.log
StandardError=append:/var/log/openclaw.log
```

### 3.2 日志轮转配置

```bash
# /etc/logrotate.d/openclaw
/var/log/openclaw.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 clawuser clawuser
}
```

## 四、文件系统访问控制

### 4.1 Docker部署配置

```yaml
# docker-compose.yml
version: '3.8'

services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    user: "1000:1000"  # 非root用户
    
    # 只读挂载系统目录，读写挂载工作目录
    volumes:
      - /home/clawuser/workspace:/workspace:rw
      - /home/clawuser/.openclaw:/config:rw
      - /etc/openclaw:/etc/openclaw:ro
      - /usr/share/zoneinfo:/usr/share/zoneinfo:ro
    
    # 安全选项
    security_opt:
      - no-new-privileges:true
    
    # 限制权限
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    
    # 网络隔离（使用单独网络）
    networks:
      - openclaw-network
    
    # 资源限制
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M

networks:
  openclaw-network:
    driver: bridge
    internal: false  # 如需完全隔离改为true
```

### 4.2 宿主机目录权限

```bash
# 创建工作目录
sudo mkdir -p /home/clawuser/workspace
sudo chown clawuser:clawuser /home/clawuser/workspace
sudo chmod 700 /home/clawuser/workspace

# 设置配置目录权限
sudo mkdir -p /home/clawuser/.openclaw
sudo chown -R clawuser:clawuser /home/clawuser/.openclaw
sudo chmod 700 /home/clawuser/.openclaw

# 敏感配置文件权限
chmod 600 ~/.openclaw/credentials
chmod 600 ~/.openclaw/openclaw.json
```

## 五、技能包安全基线

### 5.1 技能审查流程

```bash
# 1. 列出已安装技能
openclaw skills list

# 2. 查看技能详情
openclaw skills info <skill-name>

# 3. 审查SKILL.md内容
cat ~/.openclaw/skills/<skill-name>/SKILL.md

# 4. 检查是否包含危险命令
# 警告信号：
# - curl | bash 模式
# - 下载并执行脚本
# - 要求输入密码
# - 访问系统敏感目录
# - 修改系统配置
```

### 5.2 危险技能识别

以下特征的技能**不要使用**：

1. 要求"下载ZIP并解压执行"
2. 要求"运行shell脚本"
3. 要求"输入系统密码"
4. 包含 `curl | bash` 或 `wget | sh` 模式
5. 访问 `/etc/shadow`, `/root/` 等敏感目录
6. 修改系统配置或安装软件

### 5.3 推荐技能来源

- OpenClaw内置55个官方技能
- awesome-openclaw-skills社区精选列表
- 自己审查过的私有技能

## 六、频道安全基线

### 6.1 DM策略配置

```json
// 安全配置示例
{
  "channels": {
    "telegram": {
      "dmPolicy": "pairing",  // 必须配对，不要设为"open"
      "allowFrom": ["your_telegram_id"]  // 限制特定用户
    },
    "discord": {
      "dmPolicy": "pairing",
      "allowFrom": ["discord_user_id"]
    },
    "slack": {
      "dmPolicy": "pairing",
      "allowFrom": ["U123456"]
    }
  }
}
```

### 6.2 群组访问控制

```json
{
  "channels": {
    "telegram": {
      "groups": {
        "-1001234567890": {
          "requireMention": true,  // 需要@bot才能响应
          "allowFrom": ["admin_user_id"]
        }
      }
    }
  }
}
```

## 七、模型与API安全基线

### 7.1 API密钥存储

**不要**在配置文件中存储明文API密钥：

```json
// ❌ 不安全的配置
{
  "agent": {
    "apiKey": "sk-xxxxxxxxxxxx"  // 不要这样做！
  }
}

// ✅ 安全的配置
{
  "agent": {
    // 使用环境变量或凭证文件
  }
}
```

**要**使用环境变量或凭证文件：

```bash
# 设置环境变量
export OPENAI_API_KEY="sk-xxxxxx"

# 或使用OpenClaw凭证文件
openclaw credentials set openai_api_key
```

### 7.2 模型配置安全

```json
{
  "agent": {
    "model": "anthropic/claude-sonnet-4",  // 使用可信模型
    "thinking": "high",  // 高思考级别降低提示词注入风险
    "maxTokens": 4096
  }
}
```

## 八、安全更新流程

### 8.1 定期检查更新

```bash
# 检查当前版本
openclaw --version

# 检查最新版本
npm view openclaw version

# 更新OpenClaw
openclaw update

# 或使用包管理器
npm update -g openclaw
pnpm update -g openclaw
bun update -g openclaw
```

### 8.2 更新前备份

```bash
# 备份配置
cp -r ~/.openclaw ~/.openclaw.backup.$(date +%Y%m%d)

# 备份工作区
cp -r ~/.openclaw/workspace ~/openclaw-workspace-backup.$(date +%Y%m%d)
```

### 8.3 更新验证

```bash
# 1. 检查版本
openclaw --version

# 2. 运行诊断
openclaw doctor

# 3. 运行安全自检
openclaw agent --message "检查OpenClaw安全"

# 4. 测试基本功能
openclaw agent --message "你好"
```

## 九、应急响应

### 9.1 发现安全事件时

1. **立即断开网络连接**
   ```bash
   sudo systemctl stop openclaw
   sudo ufw enable
   sudo ufw default deny incoming
   ```

2. **保存日志证据**
   ```bash
   cp /var/log/openclaw.log ~/security-incident-$(date +%Y%m%d).log
   ```

3. **检查异常进程**
   ```bash
   ps aux | grep -i openclaw
   netstat -tlnp
   ```

4. **修改所有凭证**
   ```bash
   # 轮换API密钥
   # 修改系统密码
   # 更新tokens
   ```

### 9.2 完全卸载

```bash
# 1. 停止服务
openclaw gateway --stop

# 2. 执行卸载
openclaw uninstall

# 3. 删除残留文件
rm -rf ~/.openclaw
rm -rf ~/.config/openclaw

# 4. 如果使用npm/pnpm/bun
npm rm -g openclaw
# 或
pnpm remove -g openclaw
# 或
bun remove -g openclaw
```

## 十、安全检查清单

### 部署前检查

- [ ] 使用官方渠道下载最新版本
- [ ] 创建专用非root用户
- [ ] 配置最小权限
- [ ] 配置防火墙规则
- [ ] 设置Gateway绑定127.0.0.1
- [ ] 配置DM策略为pairing
- [ ] 限制allowFrom访问列表
- [ ] 开启debug日志级别
- [ ] 审查所有要安装的技能
- [ ] 使用环境变量存储API密钥

### 日常维护检查

- [ ] 查看日志异常
- [ ] 检查新安装的技能
- [ ] 验证配置文件未被修改
- [ ] 确认运行用户权限
- [ ] 检查端口暴露情况

### 月度深度检查

- [ ] 运行完整安全审计
- [ ] 检查并应用安全更新
- [ ] 审查访问日志
- [ ] 轮换API密钥
- [ ] 验证备份有效性
- [ ] 测试应急响应流程

---

**注意**：本文档基于工信部NVDB发布的OpenClaw安全建议，建议定期关注官方安全公告并更新配置。
