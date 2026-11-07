# Segurança e limites de uso

Este é um **projeto público de portfólio**, reescrito para laboratórios e demonstrações. **Não é uma ferramenta homologada para produção**.

## Restrições intencionais

- **Visualização como padrão:** chamar `Invoke-Provisioning.ps1` sem `-Apply` apenas mostra um plano.
- **Confirmação de laboratório:** execução real exige `-Apply -ConfirmEnvironment LAB`, e o JSON aceita apenas `environment: LAB`.
- **Substituição de bases:** um banco existente não pode ser restaurado por cima sem `-AllowReplace`.
- **IIS:** não remove sites existentes, pools existentes ou a configuração global. Se houver conflito, a operação para.
- **Windows Update:** não remove chaves de registro, não desabilita atualização e não força bloqueio de reinicialização.
- **Rede e SQL:** não habilita `xp_cmdshell`, não mapeia drives pela conta do serviço SQL e não cria logins privilegiados.
- **Credenciais:** não há senhas embutidas; para autenticação SQL, forneça um `PSCredential` em memória (ex.: `Get-Credential`).
- **Instaladores:** apenas os pacotes e argumentos listados no JSON são executados; não há tentativa automática de flags desconhecidas.

## Antes de executar com `-Apply`

1. Use uma máquina virtual isolada ou laboratório que você controla, com snapshot/backup recuperável.
2. Verifique o JSON completo, inclusive caminhos, instância SQL, aplicativos e porta IIS.
3. Confirme que a conta de serviço SQL tem acesso ao caminho do arquivo `.bak` e à pasta de dados no **host SQL**.
4. Rode o PowerShell com os privilégios estritamente necessários. IIS e instalações geralmente exigem elevação.
5. Nunca use dados reais, credenciais corporativas, sistemas de terceiros ou bancos em produção.
6. Antes de publicar modificações, revise o diff e procure por segredos, IPs, URLs privadas e nomes de clientes.

## Sobre restauração

O fluxo lê o `RESTORE FILELISTONLY`, gera os caminhos com `MOVE` e executa `RESTORE DATABASE`. Para substituir um banco existente, ele o coloca temporariamente em `SINGLE_USER` e tenta devolvê-lo a `MULTI_USER` em `finally`. Isso desconecta sessões. **Só use `-AllowReplace` com autorização e backup de reversão.**

O SQL Server acessa o arquivo `.bak` com as permissões do serviço do SQL Server. A pasta de destino deve existir e ser gravável para esse serviço. A aplicação que executa o script não transfere backups automaticamente.

## Propriedade intelectual

Este repositório usa apenas termos fictícios e código genérico de demonstração. Não inclua arquivos, instaladores, nomes de bancos, senhas ou procedimentos internos de empregadores ou clientes sem autorização formal. O fato de você ter desenvolvido uma automação durante seu emprego não implica automaticamente autorização para publicar o código original.

## Escopo de validação

Testes automatizados cobrem leitura do JSON, planejamento seguro, bloqueios e geração de SQL. Testes de integração com SQL Server, instaladores reais e IIS exigem um ambiente Windows de laboratório configurado separadamente.
