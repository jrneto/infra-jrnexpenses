# infra-jrnexpenses — Contexto para IA

Repositório dedicado à infraestrutura de **plataforma** do GastosApp
(frontend + backend), apartado do monorepo `meus-gastos-pessoais`.
Nasceu das specs `frontend/specs/FEAT-34-extracao-infra-repo-apartado/`
e `backend/specs/FEAT-40-extracao-infra-repo-apartado/` — consulte-as
para o racional completo da extração (o que saiu de cada contexto, por
quê, e o mecanismo de migração de state usado).

## Governança

- **Apply sempre manual e local** — nenhum workflow de CI executa
  Terraform neste repositório (mesmo princípio do monorepo). Repositório
  privado, sem pipeline.
- **Toda execução que altera state remoto ou recurso real
  (`terraform state push`, `terraform apply`) exige aprovação explícita
  do usuário no momento daquela execução** — nunca em lote, nunca
  antecipada. `plan`, `state pull` e `state list` são leitura e podem
  rodar livremente.
- **Custo zero**: nenhum recurso é criado, alterado ou destruído fora do
  que já existia no monorepo antes da extração. Qualquer recurso AWS
  novo (custo ou segurança) segue a mesma regra do monorepo: aprovação
  explícita do usuário antes de qualquer `apply`.
- Terraform é a única IaC aceita — não gerar/alterar `.tf` para um
  recurso além do já existente sem pedido explícito.

## Bucket de state e mapa de keys

Mesmo bucket de sempre (criado pelo `bootstrap/` do backend, no
monorepo): `gastosapp-terraform-state-648443184523`, `us-east-1`,
`use_lockfile = true`. Init sempre parcial, via `-backend-config`.

| Config | Key | Conteúdo |
|---|---|---|
| `terraform/dns/` | `infra-jrnexpenses/dns/terraform.tfstate` | hosted zone `jrnexpenses.com.` + records (persistente, `prevent_destroy`) |
| `terraform/environments/hom/` | `infra-jrnexpenses/hom/terraform.tfstate` | plataforma completa de hom (frontend: OAC/CloudFront/ACM/WAF; backend: entra na FEAT-40) |
| `terraform/environments/prod/` | `infra-jrnexpenses/prod/terraform.tfstate` | idem, prod |
| `terraform/cicd/{frontend,backend}/` | — (fora de state) | referência de OIDC Provider + IAM Role, guardrail IAM (ver abaixo) |
| `terraform/bootstrap/` (FEAT-40) | state local | bucket de state em si — nunca gerenciado pelo próprio bucket que descreve |

**Um state por ambiente, não por contexto**: `environments/{hom,prod}/`
é a plataforma inteira daquele ambiente (frontend + backend juntos) —
decisão de 2026-09-12 (racional em `plan.md` da FEAT-34, §5). `dns/`,
`cicd/{frontend,backend}/` e `bootstrap/` continuam separados.

## Ordem de dependência entre states

```
monorepo (frontend/backend) → terraform/environments/{hom,prod}/ → terraform/dns/
```

- `terraform/environments/{hom,prod}/` expõe outputs (ex.:
  `cloudfront_distribution_arn`, `cloudfront_domain_name`,
  `acm_domain_validation_options`) via `terraform_remote_state`.
- `terraform/dns/` lê esses outputs dos states de ambiente (não muda com
  a extração — já era assim quando `environments/` vivia no monorepo).
- O monorepo (bucket policy do S3 do frontend, e o que a FEAT-40 fizer
  equivalente no backend) lê o ARN/outputs de `environments/{hom,prod}/`
  também via `terraform_remote_state`, mesmo bucket de state.

## Princípio: infra nunca lê state do monorepo

A direção de dependência é sempre **monorepo → infra, nunca o
inverso**. Nenhuma config deste repositório declara
`terraform_remote_state` apontando para uma key do monorepo
(`gastosapp-frontend/*` ou equivalente do backend). Quando uma config
daqui precisa de um valor que só existe do lado do monorepo (ex.: nome/
domínio regional do bucket S3 do frontend), a leitura é feita por
**data source direto na AWS** (ex.: `data "aws_s3_bucket"` por nome),
nunca por `terraform_remote_state` cruzado.

## Guardrail IAM do perfil `agent-toolkit`

O perfil `agent-toolkit` (usado por todas as execuções de Terraform,
inclusive por agentes de IA) **não tem permissão para gerenciar IAM**
(`Create`/`Get`/`List` de `OpenIDConnectProvider`/`Role`/`RolePolicy`) —
guardrail intencional contra federação de identidade sendo criada/
alterada de forma autônoma. Por isso:

- `terraform/cicd/{frontend,backend}/` existe só como **referência**
  (arquivos `.tf` documentando o que foi criado manualmente no console),
  **fora de qualquer state** — `apply`/`import` falhariam com
  `AccessDenied`.
- Trazer `cicd/` para dentro de state (via `import`) continua bloqueado
  até o guardrail ser revisto — não tentar sem alinhar com o usuário
  antes.

## Assinatura ao plano Free do CloudFront

Hom e prod estão assinados ao plano flat-rate **Free** do CloudFront
(cobre distribuição + WAF + DDoS a US$0/mês, dentro de 1M req/100GB por
mês) — assinatura feita **manualmente no console**, recurso Terraform
ainda não lançado em nenhuma versão do provider AWS
([PR #49235](https://github.com/hashicorp/terraform-provider-aws/pull/49235)
em aberto). Trazer via `import` quando o recurso existir no provider,
para os dois ambientes.

## Fluxo de branches

Repositório nasceu com `develop` (default de trabalho) e `main`
(reflete o que está de fato aplicado/validado):

- Commits **direto em `develop`**, um por etapa de migração (não há
  ciclo `/specify` → `/plan` → `/tasks` neste repositório — as specs que
  orientam o trabalho vivem no monorepo, FEAT-34/FEAT-40).
- Ao fechar cada FEAT de extração (34, depois 40), abre-se **PR
  `develop → main` manual** — nenhum workflow abre esse PR sozinho,
  mesmo princípio do monorepo (`main` só avança quando o que está nela
  bate com o que foi de fato aplicado).
- Merge sempre manual, revisado pelo usuário.

## Scripts de migração

`scripts/migration/` guarda os scripts de `terraform state mv` usados em
cada etapa de extração (ex.: `wave-2-dns.sh`). São **registro auditável
do que foi movido**, não utilitários reutilizáveis — não são
idempotentes por desenho, rodam uma única vez, cada um documentando os
endereços de state migrados naquela etapa.
