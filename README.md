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
    ├── bootstrap/           # bucket S3 de state — state local próprio, gitignored
    ├── cicd/
    │   ├── frontend/        # OIDC Provider + IAM Role do CI/CD do frontend — referência, fora de state
    │   └── backend/         # idem, backend
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

### `cicd/frontend/` — OIDC Provider + IAM Role (fora do state, gerenciados manualmente)

`terraform/cicd/frontend/` contém o código de referência (`oidc.tf`,
`iam-role.tf`, `iam-policy.tf`) para o OIDC Provider do GitHub Actions e
a IAM Role assumida pelos workflows de deploy do frontend
(`.github/workflows/frontend-deploy-{hom,prod}.yml`, no monorepo) — mas
**os recursos reais foram criados manualmente no console AWS, não pelo
Terraform**, e não estão no state desta config.

**Motivo**: tanto `terraform apply` (criação) quanto `terraform import`
(trazer o que já existe) falham com `AccessDenied` — o perfil usado
(`agent-toolkit`, role `AWSReservedSSO_Perfil-Admin-Desenvolvedor`) não
tem permissão para nenhuma ação de leitura/escrita sobre
`aws_iam_openid_connect_provider`/Role relacionadas
(`iam:CreateOpenIDConnectProvider`, `iam:GetOpenIDConnectProvider`,
`iam:ListOpenIDConnectProviders`, `iam:GetRole`, `iam:GetRolePolicy`,
`iam:ListRolePolicies` — todas negadas), mesmo sendo um perfil
"Admin-Desenvolvedor". Aparenta ser um guardrail intencional (permission
set ou SCP da AWS Organization) contra ações de federação de
identidade/IAM, independente da permissão de admin no restante da
conta.

**Recursos existentes na conta** (criados manualmente, 2026-08-08):
- OIDC Provider: `arn:aws:iam::648443184523:oidc-provider/token.actions.githubusercontent.com`
- IAM Role: `arn:aws:iam::648443184523:role/gastosapp-frontend-cicd`
  - Trust policy e policy inline (`gastosapp-frontend-cicd-deploy`)
    criadas **byte a byte iguais** ao que `iam-role.tf`/`iam-policy.tf`
    gerariam — conferido visualmente no console (não via `terraform
    plan`, que também não funciona sem essas permissões).

**Se a permissão for liberada no futuro** (permission set/SCP ajustado
para permitir as ações acima), trazer para o state com:
```bash
cd terraform/cicd/frontend
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::648443184523:oidc-provider/token.actions.githubusercontent.com
terraform import aws_iam_role.frontend_cicd gastosapp-frontend-cicd
terraform import aws_iam_role_policy.frontend_cicd \
  gastosapp-frontend-cicd:gastosapp-frontend-cicd-deploy
terraform plan   # deve dar "No changes" se o console bateu com o .tf
```

**Uso pelos workflows**: o ARN da Role
(`arn:aws:iam::648443184523:role/gastosapp-frontend-cicd`) é cadastrado
como variável `CICD_ROLE_ARN` nos GitHub Environments `hom`/`prod` (no
monorepo) — não depende do state do Terraform para funcionar, só do
recurso existir de fato na conta (que existe, só não está sob
Terraform).

### `bootstrap/` — bucket S3 de state (FEAT-40)

`terraform/bootstrap/` cria o bucket S3 que guarda o state remoto de
**todas** as configurações Terraform do projeto — as deste repositório
(`environments/{hom,prod}/`, `dns/`) e as de workload que continuam no
monorepo (`backend/infra/terraform/environments/{hom,prod}/`,
`frontend/infra/terraform/environments/{hom,prod}/`). Mantém o
**próprio state local** — não há como o bucket gerenciar o state que o
cria (problema do "ovo e a galinha"). Aplicado uma única vez por conta
AWS (ou raramente, se precisar recriar o bucket); não faz parte do
fluxo de `plan`/`apply` do dia a dia.

Movido do monorepo como arquivos (conteúdo intacto) — inclusive o
próprio `terraform.tfstate` local, copiado fisicamente e gitignored
aqui também (`.gitignore` da pasta). Nenhum state remoto foi tocado
por essa movimentação: o bucket que ele descreve continua o mesmo
(`gastosapp-terraform-state-648443184523`), só o código-fonte e o
arquivo de state local mudaram de repositório.

### `cicd/backend/` — OIDC Provider (reaproveitado) + IAM Role do backend (FEAT-40)

`terraform/cicd/backend/` contém a IAM Role (`gastosapp-backend-cicd`)
assumida via OIDC pelos workflows de deploy do backend
(`.github/workflows/backend-deploy-{hom,prod}.yml`, no monorepo), com
permissão mínima escopada às Lambdas do projeto (API + os 2 triggers do
Cognito, hom e prod) e, desde a FEAT-29, também às ações necessárias
pelos testes integrados sob demanda (Cognito, DynamoDB, Parameter
Store). **Não cria um novo OIDC Provider** — `oidc.tf` referencia por
ARN previsível o Provider já existente na conta (criado manualmente
para o frontend), sem `data`/`resource` (leitura via
`iam:ListOpenIDConnectProviders`/`GetOpenIDConnectProvider` é negada
pelo perfil usado para aplicar Terraform — mesmo guardrail do
`cicd/frontend/`, ver `CLAUDE.md`).

Mesma situação do `cicd/frontend/`: **os recursos reais foram criados
manualmente no console AWS**, não pelo Terraform, e não estão em
nenhum state — tanto `apply` quanto `import` falham com `AccessDenied`
no perfil `agent-toolkit`.

**Recursos existentes na conta** (criados manualmente, 2026-08-08):
- IAM Role: `arn:aws:iam::648443184523:role/gastosapp-backend-cicd`
  - Trust policy e policy inline (`gastosapp-backend-cicd-deploy`)
    criadas a partir do JSON gerado de `iam-role.tf`/`iam-policy.tf` no
    momento da FEAT-14 (2026-08-08).

**DÉBITO conhecido, não corrigido nesta migração** (percebido no
`/specify` da FEAT-40, 2026-09-12, registrado em
`backend/docs/backlog.md` no monorepo): o JSON de referência da policy
inline, documentado no README do monorepo antes desta migração, já
estava desatualizado — trazia só 2 funções e 1 statement, enquanto
`iam-policy.tf` (movido para esta pasta) já declara 6 funções (API +
2 triggers, hom e prod) e 4 statements
(`UpdateBackendLambdaCode`, `ManageIntegrationTestCognitoUser`,
`ManageIntegrationTestDynamoDbItems`, `ReadIntegrationTestParameterStore`).
Como a role vive fora do state, esse JSON seria a única referência
independente do `.tf` do que está de fato aplicado no console —
decisão do usuário foi mover o `cicd/` **como está** (sem regenerar o
JSON) e deixar a correção para depois, aqui neste repositório.

**Se a permissão de leitura de IAM for liberada no futuro**, importar
para trazer ao state:
```bash
cd terraform/cicd/backend
terraform import aws_iam_role.backend_cicd gastosapp-backend-cicd
terraform import aws_iam_role_policy.backend_cicd \
  gastosapp-backend-cicd:gastosapp-backend-cicd-deploy
terraform plan   # deve dar "No changes" se o console bateu com o .tf
```

**Uso pelos workflows**: o ARN da Role é cadastrado como variável
`CICD_ROLE_ARN` nos GitHub Environments `backend-hom`/`backend-prod`
(no monorepo) — não depende do state do Terraform para funcionar, só do
recurso existir de fato na conta.

### States órfãos no bucket (limpeza concluída na FEAT-40, etapa 8)

Cada etapa de migração deixa o objeto de state de origem, no monorepo,
vazio (só `data.*`, quando existe algum, ou zerado por completo) — o
objeto em si não é apagado do bucket, só esvaziado de recursos:

| Objeto no bucket (monorepo) | Etapa que esvaziou | Status |
|---|---|---|
| `gastosapp-frontend/dns/terraform.tfstate` | FEAT-34, etapa 2 | **Removido** em 2026-09-13 (confirmado: só `data.terraform_remote_state.{hom,prod}`, aprovado pelo usuário) |
| `gastosapp-frontend/cicd/terraform.tfstate` | já vazio antes da FEAT-34 (nunca teve recurso gerenciado) | **Removido** em 2026-09-13 (confirmado: só `data.aws_iam_policy_document`, aprovado pelo usuário) |

Decisão do usuário (2026-09-12, `plan.md` §7.3 da FEAT-34): deixar os
objetos órfãos no bucket até o final da FEAT-40 (backend), para uma
limpeza única dos dois lados de uma vez — feito no fechamento da
FEAT-40 (etapa 8, 2026-09-13), um `aws s3 rm` por objeto, cada um
aprovado individualmente depois de conferir o conteúdo.

**`gastosapp-backend/cicd/terraform.tfstate` não entrou nessa
limpeza** — não é órfão: contém `aws_iam_role.backend_cicd` e
`aws_iam_role_policy.backend_cicd` gerenciados (achado da etapa 8, ver
"Bucket de state e mapa de keys" acima).

**Não confundir com os states de workload, que continuam em uso** (não
são órfãos): `gastosapp/{hom,prod}/terraform.tfstate` (backend,
workload — migração da plataforma concluída nas etapas 6 e 7 da
FEAT-40) e `gastosapp-frontend/{hom,prod}/terraform.tfstate`
(frontend, workload) seguem sendo os states do monorepo que as
Lambdas/o bucket S3 de hom e prod realmente usam.
