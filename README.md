# Environment Provisioning Toolkit

**Automação de ambientes Windows com PowerShell, SQL Server e IIS.**

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Windows](https://img.shields.io/badge/Windows-Desktop-0078D4?logo=windows&logoColor=white) ![SQL Server](https://img.shields.io/badge/SQL%20Server-Restore-CC2927) ![CI](https://img.shields.io/badge/CI-Pester-2671E5)

> **Projeto demonstrativo para portfólio.** Implementação genérica e independente, com nomes fictícios, criada para apresentar habilidades em automação, sustentação e provisionamento de laboratórios. Não contém código, instaladores, credenciais ou configurações particulares de clientes/empregadores. Não foi homologada para produção.

## Visão geral

Ferramenta PowerShell que organiza tarefas comuns de preparação de ambientes de teste em um plano único:

| Área | Demonstração técnica |
| --- | --- |
| SQL Server | Localização do backup mais recente, `RESTORE FILELISTONLY`, criação das cláusulas `MOVE` e restauração parametrizada |
| Windows | Instalação controlada de pacotes MSI e EXE, com verificação de código de saída |
| IIS | Criação de site, aplicações e application pools sem apagar configurações preexistentes |
| Interface | GUI Windows Forms que apresenta o plano de execução sem realizar alterações |
| Qualidade | Configuração JSON, módulo reutilizável, Pester e GitHub Actions |

## Pré-requisitos

- Windows 10/11 ou Windows Server com **Windows PowerShell 5.1+** (PowerShell 7 no Windows também é adequado para CLI, dependendo dos módulos instalados).
- Para visualização GUI: `System.Windows.Forms`, disponível no Windows.
- Para testes: [Pester 5](https://pester.dev/).
- **Apenas para execução SQL:** módulo [`SqlServer`](https://www.powershellgallery.com/packages/SqlServer), acesso ao SQL Server e permissões de restauração.
- **Apenas para execução IIS:** role/feature IIS + módulo `WebAdministration`, normalmente com execução elevada.
- Pacotes MSI/EXE autorizados, apenas se for testar a etapa de instalação.

## Começar sem instalar nem alterar nada

Abra o PowerShell na pasta do repositório e execute:

```powershell
# Exibe o planejamento de todas as etapas. Não modifica a máquina.
.\Invoke-Provisioning.ps1

# Exibe somente a parte de SQL Server.
.\Invoke-Provisioning.ps1 -Action Restore

# Abre a demonstração gráfica (Windows).
.\gui\Start-Gui.ps1
```

A configuração de demonstração está em [`examples/config.sample.json`](examples/config.sample.json). Os caminhos e recursos são **fictícios**.

## Configuração de laboratório

Crie sua configuração local sem versionar informações internas:

```powershell
Copy-Item .\examples\config.sample.json .\config.local.json
```

Edite `config.local.json` com servidores e caminhos do **seu laboratório**, mantendo `environment` como `LAB`. O arquivo `config.local.json` está no `.gitignore`.

### Executar operações reais — somente laboratório autorizado

> **Atenção:** `-Apply` pode instalar software, alterar o IIS ou restaurar bancos. Faça um backup/snapshot antes. [Leia os controles de segurança](docs/SAFETY.md).

```powershell
# Exemplo: cria SOMENTE recursos IIS novos; falha se o site/pool já existir.
.\Invoke-Provisioning.ps1 -ConfigPath .\config.local.json `
  -Action IIS -Apply -ConfirmEnvironment LAB

# Exemplo SQL com autenticação SQL, solicitada interativamente.
$cred = Get-Credential
.\Invoke-Provisioning.ps1 -ConfigPath .\config.local.json `
  -Action Restore -Apply -ConfirmEnvironment LAB -SqlCredential $cred

# Bancos existentes só podem ser substituídos após permissão adicional:
# ... -AllowReplace
```

A configuração padrão usa autenticação integrada do Windows; nesse caso, `-SqlCredential` não é necessário. Para autenticação SQL, ajuste `sql.authentication` para `Sql`.

## Executar os testes

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester .\tests
```

O workflow em `.github/workflows/powershell-ci.yml` analisa a sintaxe dos scripts e executa os testes automaticamente em Windows. Testes de SQL e IIS em servidores reais não fazem parte da CI pública.

## Arquitetura e segurança

A CLI e a GUI usam o mesmo módulo `src/ProvisioningToolkit.psm1`. A GUI é propositalmente **somente leitura**, permitindo demonstrar o plano sem tocar na máquina. Para executar operações reais, é necessário informar `-Apply -ConfirmEnvironment LAB` na CLI.

- [Diagrama da arquitetura e decisões técnicas](docs/ARCHITECTURE.md)
- [Segurança, riscos e condições de uso](docs/SAFETY.md)

## Contexto e aprendizado

Este exemplo documenta conceitos úteis em **sustentação de aplicações, automação de infraestrutura e práticas de DevOps**: parametrização, idempotência parcial, validações, isolamento de configuração, implementação de guardrails, testes automatizados e controle de versão.

**Limitações intencionais:** não há credenciais predefinidas, desligamento de serviços globais, manipulação de registro do Windows, criação automática de usuários SQL privilegiados ou apagamento automático de sites do IIS. A restauração em si **não é idempotente** e requer cuidados manuais de backup e reversão. A GUI não executa mudanças e o projeto não contém binários de demonstração.

## Próximos passos

- [ ] Adicionar captura de tela real da GUI em `docs/` (capturada no Windows).
- [ ] Criar testes de integração em ambiente descartável.
- [ ] Adicionar logs estruturados e métricas de duração por etapa.
- [ ] Implementar rollback onde for aplicável.

---

**Autor:** projeto para portfólio pessoal — personalize o perfil e a descrição do repositório antes de publicar.
