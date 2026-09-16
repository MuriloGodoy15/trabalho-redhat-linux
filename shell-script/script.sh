#!/usr/bin/env bash
 
set -euo pipefail
 
ARQUIVO_SSH="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak-redhat"
LOG="/var/log/ssh-audit-harden.log"
 
PORTA_SSH="2222"
GRUPO_SSH="sshusers"
 
TMP_FILE=""
 
# Códigos:
# 0 = sucesso
# 1 = encontrou problema
# 2 = erro de uso
# 3 = dependência faltando
 
log() {
    local nivel="$1"
    local mensagem="$2"
 
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$nivel] $mensagem" | tee -a "$LOG"
}
 
limpeza() {
    if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
        rm -f "$TMP_FILE"
    fi
}
 
mostrar_ajuda() {
    cat <<EOF
Uso: $0 [OPÇÃO]
 
Opções:
  --audit       Verifica a configuração atual do SSH
  --apply       Aplica as configurações de segurança
  --rollback    Volta a configuração anterior
  -h, --help    Mostra esta ajuda
 
Exemplo:
  sudo $0 --audit
  sudo $0 --apply
  sudo $0 --rollback
EOF
}
 
verificar_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "ERRO: execute este script como root ou usando sudo."
        exit 2
    fi
}
 
verificar_dependencias() {
    local comandos=(
        sshd
        ssh-keygen
        semanage
        firewall-cmd
        systemctl
        update-crypto-policies
        shellcheck
    )
 
    for comando in "${comandos[@]}"; do
        if ! command -v "$comando" >/dev/null 2>&1; then
            log "ERROR" "Dependência não encontrada: $comando"
            exit 3
        fi
    done
}
 
criar_backup() {
    if [[ ! -f "$BACKUP" ]]; then
        cp "$ARQUIVO_SSH" "$BACKUP"
        log "INFO" "Backup criado em $BACKUP"
    else
        log "INFO" "Backup já existe, não foi sobrescrito."
    fi
}
 
mostrar_config() {
    local chave="$1"
 
    sshd -T 2>/dev/null | grep -E "^${chave} " || true
}
 
auditar() {
    local erros=0
    local valor=""
 
    log "INFO" "Iniciando auditoria da configuração SSH."
 
    if ! systemctl is-active --quiet sshd; then
        log "ERROR" "O serviço sshd não está ativo."
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="port" {print $2; exit}')
    if [[ "$valor" == "$PORTA_SSH" ]]; then
        log "INFO" "Porta SSH: OK ($valor)"
    else
        log "WARN" "Porta SSH: encontrada $valor, esperado $PORTA_SSH"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="permitrootlogin" {print $2; exit}')
    if [[ "$valor" == "no" ]]; then
        log "INFO" "PermitRootLogin: OK"
    else
        log "WARN" "PermitRootLogin está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="passwordauthentication" {print $2; exit}')
    if [[ "$valor" == "no" ]]; then
        log "INFO" "PasswordAuthentication: OK"
    else
        log "WARN" "PasswordAuthentication está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="pubkeyauthentication" {print $2; exit}')
    if [[ "$valor" == "yes" ]]; then
        log "INFO" "PubkeyAuthentication: OK"
    else
        log "WARN" "PubkeyAuthentication está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="maxauthtries" {print $2; exit}')
    if [[ "$valor" == "3" ]]; then
        log "INFO" "MaxAuthTries: OK"
    else
        log "WARN" "MaxAuthTries está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="logingracetime" {print $2; exit}')
    if [[ "$valor" == "30" ]]; then
        log "INFO" "LoginGraceTime: OK"
    else
        log "WARN" "LoginGraceTime está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="clientaliveinterval" {print $2; exit}')
    if [[ "$valor" == "300" ]]; then
        log "INFO" "ClientAliveInterval: OK"
    else
        log "WARN" "ClientAliveInterval está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="allowgroups" {print $2; exit}')
    if [[ "$valor" == "$GRUPO_SSH" ]]; then
        log "INFO" "AllowGroups: OK ($GRUPO_SSH)"
    else
        log "WARN" "AllowGroups está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="x11forwarding" {print $2; exit}')
    if [[ "$valor" == "no" ]]; then
        log "INFO" "X11Forwarding: OK"
    else
        log "WARN" "X11Forwarding está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="permitemotegateway" {print $2; exit}')
    if [[ "$valor" == "no" ]]; then
        log "INFO" "PermitRemoteOpen: verificação manual necessária."
    fi
 
    valor=$(sshd -T | awk '$1=="usepam" {print $2; exit}')
    if [[ "$valor" == "yes" ]]; then
        log "INFO" "UsePAM: OK"
    else
        log "WARN" "UsePAM está como: $valor"
        erros=1
    fi
 
    valor=$(sshd -T | awk '$1=="pubkeyacceptedalgorithms" {print $2; exit}')
    if [[ -n "$valor" ]]; then
        log "INFO" "PubkeyAcceptedAlgorithms: configurado."
    else
        log "WARN" "Não foi possível verificar PubkeyAcceptedAlgorithms."
        erros=1
    fi
 
    echo
    echo "===== CONFIGURAÇÃO EFETIVA DO SSH ====="
    sshd -T | grep -E \
        '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|logingracetime|clientaliveinterval|allowgroups|x11forwarding|usepam|ciphers|macs) '
    echo "========================================"
    echo
 
    if [[ "$erros" -eq 0 ]]; then
        log "INFO" "Auditoria finalizada sem problemas principais."
        return 0
    fi
 
    log "WARN" "A auditoria encontrou configurações que precisam ser corrigidas."
    return 1
}
 
adicionar_config() {
    local configuracao="$1"
    local chave="$2"
 
    if grep -Eq "^[[:space:]]*${chave}[[:space:]]+" "$ARQUIVO_SSH"; then
        sed -i -E "s|^[[:space:]]*${chave}[[:space:]].*|${configuracao}|" "$ARQUIVO_SSH"
    else
        echo "$configuracao" >> "$ARQUIVO_SSH"
    fi
}
 
configurar_ssh() {
    log "INFO" "Aplicando configurações de segurança no SSH."
 
    adicionar_config "Port $PORTA_SSH" "Port"
    adicionar_config "PermitRootLogin no" "PermitRootLogin"
    adicionar_config "PasswordAuthentication no" "PasswordAuthentication"
    adicionar_config "PubkeyAuthentication yes" "PubkeyAuthentication"
    adicionar_config "MaxAuthTries 3" "MaxAuthTries"
    adicionar_config "LoginGraceTime 30" "LoginGraceTime"
    adicionar_config "ClientAliveInterval 300" "ClientAliveInterval"
    adicionar_config "AllowGroups $GRUPO_SSH" "AllowGroups"
    adicionar_config "X11Forwarding no" "X11Forwarding"
 
    # Algoritmos considerados adequados para o laboratório.
    adicionar_config "Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-gcm@openssh.com" "Ciphers"
    adicionar_config "MACs hmac-sha2-512,hmac-sha2-256" "MACs"
 
    if ! getent group "$GRUPO_SSH" >/dev/null 2>&1; then
        groupadd "$GRUPO_SSH"
        log "INFO" "Grupo $GRUPO_SSH criado."
    fi
 
    log "INFO" "Configuração do sshd atualizada."
}
 
configurar_selinux() {
    log "INFO" "Configurando porta $PORTA_SSH no SELinux."
 
    if semanage port -l | grep -Eq "^ssh_port_t.*\b$PORTA_SSH\b"; then
        log "INFO" "Porta $PORTA_SSH já está liberada no SELinux."
    else
        semanage port -a -t ssh_port_t -p tcp "$PORTA_SSH" 2>/dev/null || \
        semanage port -m -t ssh_port_t -p tcp "$PORTA_SSH"
 
        log "INFO" "Porta $PORTA_SSH adicionada ao SELinux."
    fi
}
 
configurar_firewall() {
    log "INFO" "Configurando firewalld."
 
    firewall-cmd --permanent --add-port="${PORTA_SSH}/tcp" >/dev/null
 
    # Remove a porta padrão, se estiver liberada diretamente.
    firewall-cmd --permanent --remove-service=ssh >/dev/null 2>&1 || true
 
    firewall-cmd --reload >/dev/null
 
    log "INFO" "Firewalld configurado para a porta $PORTA_SSH."
}
 
aplicar() {
    local usuario_atual=""
 
    criar_backup
 
    configurar_ssh
    configurar_selinux
    configurar_firewall
 
    # Política criptográfica do RHEL.
    update-crypto-policies --set DEFAULT
 
    # Verifica se a configuração não ficou inválida.
    if ! sshd -t; then
        log "ERROR" "A configuração do SSH ficou inválida."
 
        cp "$BACKUP" "$ARQUIVO_SSH"
 
        log "WARN" "Backup restaurado automaticamente."
 
        systemctl restart sshd || true
 
        exit 1
    fi
 
    systemctl enable sshd >/dev/null
    systemctl restart sshd
 
    log "INFO" "Configuração do SSH aplicada com sucesso."
 
    usuario_atual="${SUDO_USER:-}"
 
    if [[ -n "$usuario_atual" && "$usuario_atual" != "root" ]]; then
        usermod -aG "$GRUPO_SSH" "$usuario_atual"
        log "INFO" "Usuário $usuario_atual adicionado ao grupo $GRUPO_SSH."
    else
        log "WARN" "Usuário não identificado automaticamente para o grupo $GRUPO_SSH."
        log "WARN" "Adicione manualmente o usuário permitido antes de testar SSH."
    fi
 
    echo
    echo "SSH configurado."
    echo "Nova porta: $PORTA_SSH"
    echo "Grupo permitido: $GRUPO_SSH"
    echo
    echo "IMPORTANTE: não feche sua sessão atual antes de testar"
    echo "uma segunda conexão SSH usando a nova porta."
}
 
rollback() {
    if [[ ! -f "$BACKUP" ]]; then
        log "ERROR" "Backup não encontrado: $BACKUP"
        exit 1
    fi
 
    log "INFO" "Restaurando configuração anterior do SSH."
 
    cp "$BACKUP" "$ARQUIVO_SSH"
 
    semanage port -d -t ssh_port_t -p tcp "$PORTA_SSH" \
        >/dev/null 2>&1 || true
 
    firewall-cmd --permanent --remove-port="${PORTA_SSH}/tcp" \
        >/dev/null 2>&1 || true
 
    firewall-cmd --reload >/dev/null 2>&1 || true
 
    if ! sshd -t; then
        log "ERROR" "O backup restaurado possui configuração inválida."
        exit 1
    fi
 
    systemctl restart sshd
 
    log "INFO" "Rollback realizado com sucesso."
}
 
main() {
    local opcao="${1:-}"
 
    verificar_root
    verificar_dependencias
 
    case "$opcao" in
        --audit)
            auditar
            ;;
 
        --apply)
            aplicar
            ;;
 
        --rollback)
            rollback
            ;;
 
        -h|--help)
            mostrar_ajuda
            ;;
 
        "")
            echo "ERRO: nenhuma opção foi informada."
            echo
            mostrar_ajuda
            exit 2
            ;;
 
        *)
            echo "ERRO: opção inválida: $opcao"
            echo
            mostrar_ajuda
            exit 2
            ;;
    esac
}
 
trap limpeza EXIT
 
TMP_FILE=$(mktemp)
 
main "$@"
