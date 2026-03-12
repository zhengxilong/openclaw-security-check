---
name: openclaw-security-check
description: 根据新华社/工信部NVDB发布的OpenClaw"六要六不要"安全建议，执行全面的安全检查。当用户询问"检查OpenClaw安全"、"安全审计"、"六要六不要检查"、"openclaw安全检查"、"我的openclaw安全吗"、"查看安全配置"、"安全检查"时自动触发。检测版本更新、互联网暴露、权限配置、技能包安全、日志审计等安全配置问题，并生成详细的安全报告和改进建议。使用bash工具执行检查命令，使用read工具读取配置文件。
---

# OpenClaw 安全自检 Skill（六要六不要）

基于工业和信息化部网络安全威胁和漏洞信息共享平台（NVDB）发布的OpenClaw安全使用"六要六不要"建议执行全面安全检查。

**触发条件**: 用户询问OpenClaw安全相关问题时自动执行此skill。

## 检查范围

### 一、使用官方最新版本检查（要）
- [ ] 检查当前OpenClaw版本是否为最新
- [ ] 检查是否使用官方渠道安装
- [ ] 检查自动更新配置

### 二、严格控制互联网暴露面检查（要/不要）
- [ ] 检查Gateway是否绑定到127.0.0.1（本地）而非0.0.0.0
- [ ] 检查SSH/远程访问配置
- [ ] 检查防火墙规则（iptables/ufw）
- [ ] 检查端口暴露情况（18789等）
- [ ] 检查是否使用了VPN/加密通道

### 三、最小权限原则检查（要/不要）
- [ ] 检查OpenClaw运行用户权限
- [ ] 检查是否使用root/administrator运行
- [ ] 检查文件系统权限配置
- [ ] 检查Docker沙箱配置（如有）
- [ ] 检查高危命令黑名单配置

### 四、技能市场使用安全检查（要/不要）
- [ ] 列出已安装的第三方技能
- [ ] 检查技能包来源可信度
- [ ] 检查技能包代码（避免恶意curl/bash）

### 五、社会工程学攻击防范检查（要/不要）
- [ ] 检查浏览器安全配置
- [ ] 检查DM策略配置（dmPolicy）
- [ ] 检查频道访问控制（allowFrom）

### 六、长效防护机制检查（要/不要）
- [ ] 检查日志级别配置（应为debug）
- [ ] 检查日志文件位置
- [ ] 检查API密钥存储方式（是否加密）
- [ ] 检查配置文件权限

## 执行步骤（使用工具）

### 1. 收集系统信息
- 执行 `bash` 运行 `openclaw doctor` 检查整体健康状况
- 执行 `bash` 运行 `openclaw --version` 获取当前版本
- 执行 `bash` 运行 `npm view openclaw version` 获取最新版本（如npm可用）
- 使用 `read` 读取 `~/.openclaw/openclaw.json` 配置文件
- 使用 `read` 读取 `~/.openclaw/credentials` 凭证文件（检查权限）

### 2. 网络暴露检查
- 执行 `bash` 运行 `lsof -i :18789` 或 `netstat -tlnp | grep 18789` 检查端口监听
- 执行 `bash` 运行 `ps aux | grep -i openclaw | grep -v grep` 查看进程信息
- 执行 `bash` 运行 `sudo ufw status` 检查UFW防火墙（如可用）
- 执行 `bash` 运行 `sudo iptables -L | grep 18789` 检查iptables规则
- 检查配置文件中 `gateway.bind` 是否为 `127.0.0.1`

### 3. 权限检查
- 执行 `bash` 运行 `ps aux | grep -i openclaw` 检查运行用户
- 执行 `bash` 运行 `ls -la ~/.openclaw/` 检查目录权限
- 执行 `bash` 运行 `stat -c "%a %n" ~/.openclaw/openclaw.json ~/.openclaw/credentials 2>/dev/null || stat -f "%Lp %N" ~/.openclaw/openclaw.json ~/.openclaw/credentials` 检查文件权限
- 检查配置中 `agents.defaults.sandbox.mode` 是否启用

### 4. 技能安全检查
- 执行 `bash` 运行 `openclaw skills list` 列出已安装技能
- 执行 `bash` 运行 `find ~/.openclaw/skills ~/.openclaw/workspace/skills -name "SKILL.md" 2>/dev/null` 查找所有技能
- 执行 `bash` 运行 `grep -l "curl.*bash\|wget.*sh\|eval\|exec" ~/.openclaw/skills/*/SKILL.md ~/.openclaw/workspace/skills/*/SKILL.md 2>/dev/null` 检查可疑命令

### 5. 频道安全与日志检查
- 检查配置中 `channels.*.dmPolicy` 是否为 `pairing`
- 检查配置中 `channels.*.allowFrom` 是否限制了特定用户
- 检查配置中 `gateway.logLevel` 是否为 `debug`
- 检查 `skills.load.extraDirs` 是否包含未审查的目录

### 6. 执行辅助脚本（可选）
- 如存在 `~/.openclaw/workspace/skills/openclaw-security-check/scripts/security-check.sh`，执行该脚本获取更详细的检查结果

## 输出格式

生成结构化安全报告，包含：

```
# OpenClaw 安全自检报告

## 总体评级：【安全/警告/危险】

## 详细检查结果

### 1. 版本管理 ✅/⚠️/❌
- 当前版本：x.x.x
- 最新版本：x.x.x
- 状态：已更新/需要更新

### 2. 网络暴露 ✅/⚠️/❌
- Gateway绑定：127.0.0.1 ✅ 或 0.0.0.0 ❌
- 端口暴露：18789端口互联网可访问 ⚠️
- 防火墙配置：已配置/未配置

### 3. 权限配置 ✅/⚠️/❌
- 运行用户：普通用户 ✅ 或 root ❌
- 配置文件权限：正确 ✅ 或过于宽松 ⚠️

### 4. 技能安全 ✅/⚠️/❌
- 第三方技能数量：X个
- 可疑技能：列出

### 5. 防护机制 ✅/⚠️/❌
- 日志级别：debug ✅ 或 其他 ⚠️
- 访问控制：已配置 ✅ 或 未配置 ❌

## 优先修复建议

1. 【高危】立即修复项...
2. 【中危】建议修复项...
3. 【低危】可选优化项...

## 安全配置参考

详见原文档附录部分...
```

## 高危风险判定标准

以下情况判定为**高危风险**：
1. Gateway绑定到0.0.0.0且暴露在公网
2. 使用root/administrator运行OpenClaw
3. API密钥明文存储
4. dmPolicy设置为"open"且无allowFrom限制
5. 安装来源不明的技能包

## 修复命令参考

### 高危问题修复

**1. Gateway绑定到0.0.0.0**
```bash
# 编辑配置文件
# ~/.openclaw/openclaw.json
{
  "gateway": {
    "bind": "127.0.0.1",
    "port": 18789
  }
}
# 重启Gateway
openclaw gateway --restart
```

**2. 使用root运行**
```bash
# 创建专用用户
sudo adduser --shell /bin/bash --disabled-password clawuser
sudo chown -R clawuser:clawuser ~/.openclaw
# 切换到普通用户运行
sudo -u clawuser openclaw gateway
```

**3. DM策略设置为open**
```bash
# 编辑配置文件
# ~/.openclaw/openclaw.json
{
  "channels": {
    "telegram": { "dmPolicy": "pairing" },
    "discord": { "dmPolicy": "pairing" },
    "slack": { "dmPolicy": "pairing" }
  }
}
```

### 一般修复操作
- 更新OpenClaw: `openclaw update` 或 `npm update -g openclaw`
- 查看技能详情: `openclaw skills info <skill-name>`
- 删除可疑技能: `rm -rf ~/.openclaw/skills/<suspicious-skill>/`
- 修改配置文件权限: `chmod 600 ~/.openclaw/openclaw.json ~/.openclaw/credentials`
- 运行辅助脚本: `bash ~/.openclaw/workspace/skills/openclaw-security-check/scripts/security-check.sh`

## 免责声明

本skill仅提供安全检查建议，最终安全责任由用户承担。建议定期进行安全检查（建议每月一次）。
