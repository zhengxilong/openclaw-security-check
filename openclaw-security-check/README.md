# OpenClaw 安全自检 Skill

基于新华社/工业和信息化部网络安全威胁和漏洞信息共享平台（NVDB）发布的OpenClaw"六要六不要"安全建议开发的安全检查工具。

## 功能特性

根据"六要六不要"安全建议，执行以下6大维度的安全检查：

### 1. 使用官方最新版本检查 ✅
- 检查当前OpenClaw版本
- 验证官方安装渠道
- 提示版本更新

### 2. 严格控制互联网暴露面检查 🌐
- 检查Gateway绑定地址（应绑定127.0.0.1，不要绑定0.0.0.0）
- 检查端口18789暴露情况
- 验证防火墙配置（iptables/ufw）
- 检查VPN/加密通道使用

### 3. 最小权限原则检查 🔒
- 检查运行用户权限（不要使用root/administrator）
- 检查配置文件权限
- 验证Docker沙箱配置
- 检查高危命令黑名单

### 4. 技能市场使用安全检查 📦
- 列出已安装技能
- 识别可疑技能（包含curl/bash等危险命令）
- 提醒审查技能来源

### 5. 社会工程学攻击防范检查 🛡️
- 检查DM策略配置（dmPolicy）
- 验证频道访问控制（allowFrom）
- 提醒浏览器安全配置

### 6. 长效防护机制检查 📋
- 检查日志级别配置（应开启debug级别）
- 验证日志审计功能
- 检查API密钥存储方式
- 提醒定期安全更新

## 安装方法

### 方法1：复制到Workspace Skills目录

```bash
# 创建skills目录
mkdir -p ~/.openclaw/workspace/skills

# 复制skill
cp -r openclaw-security-check ~/.openclaw/workspace/skills/

# 重启OpenClaw或刷新技能
openclaw gateway --restart
```

### 方法2：复制到Managed Skills目录

```bash
# 创建skills目录
mkdir -p ~/.openclaw/skills

# 复制skill
cp -r openclaw-security-check ~/.openclaw/skills/

# 重启OpenClaw或刷新技能
openclaw gateway --restart
```

## 使用方法

安装后，向OpenClaw发送以下任意指令即可触发安全检查：

```
检查OpenClaw安全
执行安全审计
六要六不要检查
openclaw安全检查
我的openclaw安全吗
查看安全配置
安全检查
```

## 独立运行脚本

也可以直接运行辅助脚本进行检查：

```bash
cd openclaw-security-check
./scripts/security-check.sh
```

## 输出说明

检查完成后会生成详细报告，包含：

- **总体评级**：安全 / 警告 / 危险
- **详细检查结果**：每个检查项的状态
- **优先修复建议**：按风险等级排序的修复建议
- **安全配置参考**：符合安全基线的配置示例

### 风险等级定义

- **高危（红色）**：需要立即修复的安全漏洞
- **警告（黄色）**：建议修复的潜在风险
- **通过（绿色）**：符合安全建议

## 常见安全问题修复

### 问题1：Gateway绑定到0.0.0.0

**风险**：允许从任何IP访问Gateway

**修复**：
```json
// ~/.openclaw/openclaw.json
{
  "gateway": {
    "bind": "127.0.0.1"
  }
}
```

### 问题2：使用root运行

**风险**：权限过大，被攻击后可能导致系统完全沦陷

**修复**：
```bash
# 创建专用用户
sudo adduser --shell /bin/rbash --disabled-password clawuser

# 切换用户运行
sudo -u clawuser openclaw gateway
```

### 问题3：DM策略设置为open

**风险**：任何人可直接发送消息，存在提示词注入风险

**修复**：
```json
// ~/.openclaw/openclaw.json
{
  "channels": {
    "telegram": {
      "dmPolicy": "pairing"
    },
    "discord": {
      "dmPolicy": "pairing"
    }
  }
}
```

### 问题4：日志级别过低

**风险**：无法追溯操作记录，合规风险

**修复**：
```bash
openclaw gateway --log-level debug >> /var/log/openclaw.log 2>&1
```

## 安全基线配置参考

### 最小权限部署

```bash
# 创建受限用户
sudo adduser --shell /bin/rbash --disabled-password clawuser
sudo mkdir -p /home/clawuser/bin
sudo ln -s /bin/ls /home/clawuser/bin/ls
sudo ln -s /bin/echo /home/clawuser/bin/echo

# 限制PATH
echo 'if [ "$USER" = "clawuser" ]; then export PATH=/home/clawuser/bin; readonly PATH; fi' | sudo tee /etc/profile.d/restricted_clawuser.sh
```

### 防火墙配置

```bash
# 使用UFW限制访问
sudo ufw default deny incoming
sudo ufw allow from 192.168.1.0/24 to any port 18789
sudo ufw enable

# 或使用iptables
sudo iptables -A INPUT -p tcp --dport 18789 -s 127.0.0.1 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 18789 -j DROP
```

### Docker沙箱配置

```yaml
# docker-compose.yml
services:
  openclaw:
    image: openclaw/openclaw:latest
    volumes:
      - /home/clawuser/workspace:/workspace:rw
      - /etc/openclaw:/config:ro  # 只读挂载系统配置
    user: "1000:1000"  # 非root用户
    cap_drop:
      - ALL  # 丢弃所有特权
```

## 定期检查建议

建议定期进行安全检查：

- **每日**：查看异常日志
- **每周**：检查新安装的技能
- **每月**：运行完整安全检查
- **每季**：审查访问控制列表

## 参考文档

- [OpenClaw官方安全指南](https://docs.openclaw.ai/security)
- [工信部NVDB安全公告](https://www.miit.gov.cn/)
- [OpenClaw Skills开发文档](https://docs.openclaw.ai/tools/creating-skills)

## 免责声明

本skill仅提供安全检查建议，不构成安全保证。最终安全责任由用户承担。建议结合其他安全工具和最佳实践使用。

## License

MIT
