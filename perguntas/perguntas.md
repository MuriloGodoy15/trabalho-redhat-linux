# Perguntas e Respostas

## 1) Múltipla escolha

Beleza, o Rocky e o AlmaLinux são praticamente clones do RHEL e são de graça. Então por que uma empresa ia pagar pela assinatura da Red Hat?

a) Porque o kernel do RHEL é mais rápido que o das distros clonadas
b) Porque a assinatura dá suporte oficial, garante patch de segurança por até 10 anos e libera o Insights pra monitorar os servidores
c) Porque só o RHEL tem SELinux, as clones não suportam isso
d) Porque sem assinatura o root para de funcionar depois de um tempo

**Resposta: B.** O kernel é literalmente o mesmo binário nas três (é rebuild, não é "outro Linux"), SELinux tá em todas, e não existe esse bloqueio de root em nenhuma delas. O que você paga é suporte técnico, garantia de patch e as ferramentas de gestão — não é o sistema funcionando diferente por baixo.

## 2) Múltipla escolha

No esquema de disco que a gente montou, o `/boot` ficou fora do container do LUKS de propósito. Alguém sabe dizer por quê?

a) Porque o xfs não roda dentro de partição criptografada
b) Porque o GRUB tem que ler o kernel antes de qualquer chave de criptografia existir — não dá pra pedir senha pra abrir algo que ainda nem carregou
c) Porque tirar o `/boot` da criptografia economiza um espaço bom no disco
d) Porque o UEFI simplesmente não deixa criar partição criptografada

**Resposta: B.** É o próprio "buraco" de segurança que a gente teve que explicar na apresentação: o bootloader precisa rodar antes de qualquer coisa criptografada existir, então essa parte fica de fora por necessidade — não é limitação de sistema de arquivo nem regra do UEFI.

## 3) Múltipla escolha

Liberamos a porta nova do SSH no firewalld e mesmo assim a conexão continuava sendo recusada. Com SELinux enforcing ligado, o que mais precisa ser feito?

a) Nada, só o firewall já resolveria
b) Dar um `setenforce 0` pra desligar o SELinux até funcionar
c) Usar `semanage port` pra marcar a porta nova com o contexto `ssh_port_t`, porque sem isso o SELinux barra o sshd mesmo com o firewall aberto
d) Reiniciar o servidor inteiro, já que trocar porta de SSH pede reboot

**Resposta: C.** Todo mundo pensa em desligar o SELinux quando dá esse tipo de erro (opção B), mas é exatamente o que o trabalho não quer ver — a ideia é rotular a porta direito, não desligar a proteção.

## 4) Dissertativa

A gente colocou `noexec` em `/var` e isso acabou quebrando a execução dos containers rodando ali. Na visão de vocês, compensa manter o `noexec` e resolver esse problema de outro jeito, ou é melhor tirar essa restrição só em `/var`? Respondam justificando, em no máximo 3 linhas.

*(Não tem gabarito fechado aqui — o que vale é o aluno reconhecer que existe um trade-off real entre segurança e funcionalidade, e defender a escolha com um motivo que faça sentido.)*

## 5) Dissertativa

O nosso script `ssh-audit-harden.sh` tem um modo `--rollback`. Por que isso é importante num script que mexe em configuração de sistema, e o que aconteceria se esse modo não existisse e uma mudança quebrasse o SSH remotamente?

*(A ideia aqui é puxar pra regra de ouro que a gente seguiu: nunca fechar a sessão atual do SSH sem confirmar numa segunda sessão que a config nova funciona. Sem rollback, um erro pode significar ficar trancado pra fora da própria máquina.)*
