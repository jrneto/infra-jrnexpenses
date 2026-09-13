#!/bin/bash
# Recria a tabela DynamoDB de homologação (GastosApp-Hom) do zero, via
# Terraform — mais barato e instantâneo que zerar item a item (scan +
# delete-item, ver backend/infra/scripts/reset-dynamodb.sh no monorepo,
# que só existe para o LocalStack local). Tabela é PAY_PER_REQUEST, sem
# PITR/backup contínuo/deletion_protection (backend-dynamodb.tf), então
# destruir e recriar não tem custo nem exige mais nenhum passo de
# limpeza.
#
# Usa `terraform apply -replace` (não `destroy -target` + `apply`):
# -target em destroy arrastaria em cascata qualquer recurso que
# referencie a tabela neste MESMO state. Desde a FEAT-40 (migração da
# plataforma para este repositório), as 3 Lambdas que consomem o nome/
# ARN da tabela (via variável de ambiente DynamoDb__TableName e as
# policies IAM) vivem em outro state — o do monorepo
# (backend/infra/terraform/environments/hom/), que só lê esses valores
# via terraform_remote_state. Como o nome/ARN da tabela não muda (sem
# sufixo aleatório), o `plan` seguinte do monorepo continua "No
# changes" — não é preciso reaplicar nada do lado de lá.
#
# Uso: ./recreate-table.sh (a partir de
# infra-jrnexpenses/terraform/environments/hom, com terraform já
# inicializado — ver README.md deste repositório — e credenciais AWS
# com permissão sobre a tabela GastosApp-Hom)
#
# ATENÇÃO: apaga TODOS OS DADOS da tabela de homologação. Ação
# irreversível — pede confirmação antes de aplicar.
set -e

TARGET="aws_dynamodb_table.gastos_app"

echo "Isso vai APAGAR TODOS OS DADOS da tabela GastosApp-Hom e recriá-la vazia."
echo "Alvo: $TARGET (ambiente: hom)"
read -r -p "Confirma? Digite 'sim' para continuar: " CONFIRM
if [ "$CONFIRM" != "sim" ]; then
  echo "Cancelado."
  exit 1
fi

terraform apply -replace="$TARGET"
