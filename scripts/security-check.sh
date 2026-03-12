#!/bin/bash
#
# OpenClaw 安全检查脚本
# 基于工信部NVDB "六要六不要"安全建议
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
CRITICAL=0
WARNING=0
PASSED=0

# 错误处理 - 不退出，只记录
set +e

# 输出函数
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
    PASSED=$((PASSED + 1))
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    WARNING=$((WARNING + 1))
}

print_fail() {
    echo -e "${RED}[✗]${NC} $1"
    CRITICAL=$((CRITICAL + 1))
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查1: OpenClaw版本
check_version() {
    print_header "1. 版本管理检查（六要：使用官方最新版本）"
    
    if command_exists openclaw; then
        VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
        print_info "当前OpenClaw版本: $VERSION"
        
        # 检查是否通过npm/pnpm/bun官方渠道安装
        if npm list -g openclaw >/dev/null 2>&1 || \
           pnpm list -g openclaw >/dev/null 2>&1 || \
           bun pm ls -g openclaw >/dev/null 2>&1; then
            print_pass "通过官方包管理器安装"
        else
            print_warn "无法确认安装来源，建议通过npm/pnpm/bun官方渠道安装"
        fi
    else
        print_fail "未找到openclaw命令"
    fi
}

# 检查2: 配置文件
check_config() {
    print_header "2. 配置文件检查"
    
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
    
    if [ -f "$CONFIG_FILE" ]; then
        print_info "配置文件位置: $CONFIG_FILE"
        
        # 检查文件权限
        PERMS=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null || stat -f "%Lp" "$CONFIG_FILE" 2>/dev/null)
        if [ "$PERMS" -le 644 ]; then
            print_pass "配置文件权限正确 ($PERMS)"
        else
            print_warn "配置文件权限过于宽松 ($PERMS)，建议设置为644或更严格"
        fi
        
        # 检查Gateway绑定配置
        if grep -q "\"bind\".*\"0.0.0.0\"" "$CONFIG_FILE" 2>/dev/null; then
            print_fail "Gateway绑定到0.0.0.0，存在安全风险！建议绑定127.0.0.1"
        else
            print_pass "Gateway未绑定到0.0.0.0"
        fi
        
        # 检查DM策略
        if grep -q "\"dmPolicy\".*\"open\"" "$CONFIG_FILE" 2>/dev/null; then
            print_fail "DM策略设置为open，任何人可直接发送消息！"
        elif grep -q "\"dmPolicy\".*\"pairing\"" "$CONFIG_FILE" 2>/dev/null; then
            print_pass "DM策略设置为pairing，需要配对认证"
        fi
        
        # 检查是否允许所有来源
        if grep -q "\"allowFrom\".*\"\\*\"" "$CONFIG_FILE" 2>/dev/null; then
            print_warn "allowFrom设置为*，允许所有来源，建议限制特定用户"
        fi
        
        # 检查日志级别
        if grep -q "\"logLevel\".*\"debug\"" "$CONFIG_FILE" 2>/dev/null; then
            print_pass "日志级别设置为debug"
        else
            print_warn "建议将日志级别设置为debug以便审计"
        fi
        
        # 检查沙箱配置
        if grep -q "\"sandbox\"" "$CONFIG_FILE" 2>/dev/null; then
            print_pass "已配置沙箱"
        else
            print_info "未配置沙箱，生产环境建议使用Docker沙箱隔离"
        fi
        
    else
        print_warn "未找到配置文件: $CONFIG_FILE"
    fi
}

# 检查3: 网络暴露
check_network() {
    print_header "3. 网络暴露检查（六不要：不要将OpenClaw暴露到互联网）"
    
    # 检查端口18789
    if command_exists lsof; then
        if lsof -i :18789 >/dev/null 2>&1; then
            print_info "端口18789正在监听"
            
            # 检查绑定地址
            BIND_ADDR=$(lsof -i :18789 2>/dev/null | grep LISTEN | awk '{print $9}' | head -1)
            if echo "$BIND_ADDR" | grep -q "0.0.0.0" >/dev/null 2>&1; then
                print_fail "Gateway绑定到0.0.0.0:18789，可从任何地址访问！"
            elif echo "$BIND_ADDR" | grep -q "127.0.0.1" >/dev/null 2>&1; then
                print_pass "Gateway仅绑定到127.0.0.1:18789（本地）"
            else
                print_info "Gateway绑定地址: $BIND_ADDR"
            fi
        else
            print_info "端口18789未监听（Gateway可能未运行）"
        fi
    elif command_exists netstat; then
        if netstat -tlnp 2>/dev/null | grep -q ":18789"; then
            print_info "端口18789正在监听"
        else
            print_info "端口18789未监听"
        fi
    else
        print_info "无法检查端口状态（缺少lsof/netstat）"
    fi
    
    # 检查防火墙
    if command_exists ufw; then
        UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1 || echo "unknown")
        if echo "$UFW_STATUS" | grep -q "active"; then
            print_pass "UFW防火墙已启用"
        else
            print_warn "UFW防火墙未启用"
        fi
    elif command_exists iptables; then
        if sudo iptables -L 2>/dev/null | grep -q "DROP\|REJECT"; then
            print_pass "iptables已配置规则"
        else
            print_warn "iptables未配置规则"
        fi
    fi
}

# 检查4: 权限检查
check_permissions() {
    print_header "4. 权限配置检查（六要：坚持最小权限原则）"
    
    # 检查OpenClaw运行用户
    if pgrep -f "openclaw" >/dev/null 2>&1; then
        PROCESS_USER=$(ps aux | grep -v grep | grep "openclaw" | head -1 | awk '{print $1}')
        print_info "OpenClaw运行用户: $PROCESS_USER"
        
        if [ "$PROCESS_USER" = "root" ]; then
            print_fail "OpenClaw以root用户运行，存在严重安全风险！"
        else
            print_pass "OpenClaw以非root用户运行"
        fi
    else
        print_info "OpenClaw当前未运行"
    fi
    
    # 检查workspace目录权限
    WORKSPACE="$HOME/.openclaw/workspace"
    if [ -d "$WORKSPACE" ]; then
        WS_PERMS=$(stat -c "%a" "$WORKSPACE" 2>/dev/null || stat -f "%Lp" "$WORKSPACE" 2>/dev/null)
        if [ "$WS_PERMS" -le 755 ]; then
            print_pass "workspace目录权限正确"
        else
            print_warn "workspace目录权限过于宽松"
        fi
    fi
}

# 检查5: 技能安全
check_skills() {
    print_header "5. 技能安全检查（六要：谨慎使用技能市场 / 六不要：不要使用可疑技能）"
    
    SKILLS_DIR="$HOME/.openclaw/skills"
    WORKSPACE_SKILLS="$HOME/.openclaw/workspace/skills"
    
    # 统计技能数量
    SKILL_COUNT=0
    if [ -d "$SKILLS_DIR" ]; then
        SKILL_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$WORKSPACE_SKILLS" ]; then
        WS_SKILL_COUNT=$(find "$WORKSPACE_SKILLS" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        SKILL_COUNT=$((SKILL_COUNT + WS_SKILL_COUNT))
    fi
    
    print_info "已安装技能数量: $SKILL_COUNT"
    
    # 检查可疑技能（包含危险命令）
    SUSPICIOUS=0
    if [ -d "$SKILLS_DIR" ]; then
        while IFS= read -r skill_file; do
            if grep -q "curl.*\|bash\|sh .*" "$skill_file" 2>/dev/null; then
                print_warn "发现可能包含外部命令的技能: $skill_file"
                SUSPICIOUS=$((SUSPICIOUS + 1))
            fi
        done < <(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null)
    fi
    
    if [ $SUSPICIOUS -eq 0 ]; then
        print_pass "未发现明显可疑技能"
    else
        print_warn "发现$SUSPICIOUS个包含外部命令的技能，请手动审查"
    fi
}

# 检查6: 日志和审计
check_logging() {
    print_header "6. 日志和审计检查（六要：建立长效防护机制 / 六不要：不要禁用详细日志）"
    
    # 检查日志目录
    LOG_DIR="$HOME/.openclaw/logs"
    if [ -d "$LOG_DIR" ]; then
        print_pass "日志目录存在"
    else
        print_info "未找到专用日志目录"
    fi
    
    # 检查API密钥存储
    CREDS_FILE="$HOME/.openclaw/credentials"
    if [ -f "$CREDS_FILE" ]; then
        CREDS_PERMS=$(stat -c "%a" "$CREDS_FILE" 2>/dev/null || stat -f "%Lp" "$CREDS_FILE" 2>/dev/null)
        if [ "$CREDS_PERMS" -le 600 ]; then
            print_pass "凭证文件权限正确 ($CREDS_PERMS)"
        else
            print_fail "凭证文件权限过于宽松 ($CREDS_PERMS)，必须设置为600！"
        fi
    fi
    
    # 检查openclaw.json中是否有明文密钥
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "\"apiKey\"\|\"api_key\"\|\"token\"" "$CONFIG_FILE" 2>/dev/null; then
            print_warn "配置文件可能包含明文API密钥，建议使用环境变量或凭证文件"
        fi
    fi
}

# 检查7: 运行openclaw doctor
check_doctor() {
    print_header "7. OpenClaw Doctor检查"
    
    if command_exists openclaw; then
        print_info "运行 openclaw doctor..."
        openclaw doctor 2>/dev/null || print_warn "openclaw doctor执行失败或发现问题"
    fi
}

# 生成报告摘要
print_summary() {
    print_header "检查完成"
    
    echo -e "\n${BLUE}安全评分:${NC}"
    echo -e "  ${GREEN}通过: $PASSED${NC}"
    echo -e "  ${YELLOW}警告: $WARNING${NC}"
    echo -e "  ${RED}高危: $CRITICAL${NC}"
    
    if [ $CRITICAL -gt 0 ]; then
        echo -e "\n${RED}总体评级: 危险${NC}"
        echo -e "${RED}请立即修复上述高危问题！${NC}"
    elif [ $WARNING -gt 0 ]; then
        echo -e "\n${YELLOW}总体评级: 警告${NC}"
        echo -e "${YELLOW}建议修复上述警告项以提升安全性${NC}"
    else
        echo -e "\n${GREEN}总体评级: 安全${NC}"
        echo -e "${GREEN}您的OpenClaw配置符合"六要六不要"安全建议${NC}"
    fi
    
    echo -e "\n${BLUE}建议操作:${NC}"
    echo "1. 定期运行此检查（建议每月一次）"
    echo "2. 关注OpenClaw官方安全公告"
    echo "3. 及时更新到最新版本"
    echo "4. 审查安装的第三方技能"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         OpenClaw 安全自检（六要六不要）                    ║"
    echo "║    基于工信部NVDB安全建议                                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_version
    check_config
    check_network
    check_permissions
    check_skills
    check_logging
    check_doctor
    
    print_summary
}

main "$@"
