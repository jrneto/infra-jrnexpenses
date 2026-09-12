# infra-jrnexpenses

Infraestrutura Terraform de **plataforma** do GastosApp (frontend +
backend), apartada do monorepo `meus-gastos-pessoais`. Governança,
mapa de states e princípios de dependência: ver [`CLAUDE.md`](CLAUDE.md).

## Layout

```
infra-jrnexpenses/
├── CLAUDE.md
├── README.md
├── scripts/
│   └── migration/          # scripts de `state mv` por etapa de extração (registro histórico)
└── terraform/
    ├── cicd/
    │   ├── frontend/        # OIDC Provider + IAM Role do CI/CD do frontend — referência, fora de state
    │   └── backend/         # idem, backend (FEAT-40)
    ├── dns/                 # hosted zone + records — camada persistente, um state
    └── environments/
        ├── hom/             # plataforma completa de homologação (frontend + backend), um state
        └── prod/            # idem, produção
```

## Pré-requisitos

- Terraform >= 1.10 instalado localmente
- AWS CLI autenticado na conta do projeto (`648443184523`, perfil
  `agent-toolkit`, região `us-east-1`)

## Comandos por configuração

Cada config em `terraform/` (`dns/`, `environments/hom/`,
`environments/prod/`) é independente, com seu próprio state no mesmo
bucket (`gastosapp-terraform-state-648443184523`) — `key`s em
`CLAUDE.md`. Init é sempre **parcial**, via `-backend-config` (a `key`
vive em `versions.tf` de cada config; bucket/região são passados na
hora):

```bash
cd terraform/<config>
terraform init \
  -backend-config="bucket=gastosapp-terraform-state-648443184523" \
  -backend-config="region=us-east-1"

terraform plan     # leitura, roda livremente
terraform apply    # só com aprovação explícita do usuário no momento
```

`terraform/cicd/{frontend,backend}/` **não roda `init`/`plan`/`apply`**
— é referência fora de state (guardrail IAM, ver `CLAUDE.md`).

## Migração a partir do monorepo

Este repositório nasceu vazio (commit inicial só com `README.md` de uma
linha + `.gitignore` do template Terraform do GitHub, sem reescrever
histórico) e foi populado em etapas, uma por state, sem criar/destruir/
recriar nenhum recurso AWS — `terraform state pull`/`state mv`
(offline)/`state push` movendo cada recurso do state do monorepo para
o state daqui, com `terraform plan` = "No changes" dos dois lados ao
final de cada etapa. Detalhamento completo do mecanismo e das decisões:

- **Frontend** — `dns/` (zona + records), CloudFront, OAC, ACM, WAF e
  `cicd/frontend/` do frontend: [`frontend/specs/FEAT-34-extracao-infra-repo-apartado/`](https://github.com/jrneto/meus-gastos-pessoais/tree/main/frontend/specs/FEAT-34-extracao-infra-repo-apartado)
  no monorepo (`spec.md`, `plan.md`, `tasks.md`).
- **Backend** — DynamoDB, Cognito, Parameter Store, SES, API Gateway,
  domínio `api*`, `cicd/backend/` e `bootstrap/`:
  [`backend/specs/FEAT-40-extracao-infra-repo-apartado/`](https://github.com/jrneto/meus-gastos-pessoais/tree/main/backend/specs/FEAT-40-extracao-infra-repo-apartado)
  no monorepo.

O que **fica** no monorepo, em ambos os contextos: só o Terraform
essencial ao deploy do workload em si (ex., no frontend: bucket S3 +
public access block + encryption + policy) — o monorepo passa a ler
outputs (ex. ARN da distribuição CloudFront) daqui via
`terraform_remote_state`, nunca o inverso.

### `cicd/` — OIDC Provider + IAM Role (fora do state)

Ver seção equivalente em `frontend/infra/terraform/README.md` do
monorepo (motivo do guardrail, ARNs dos recursos existentes, comando de
`import` para quando a permissão for liberada) — movida para cá quando
`terraform/cicd/frontend/` for populado (FEAT-34, etapa 1).
