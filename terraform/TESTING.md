# Guia de Testes e Verificação da Infraestrutura

Este documento descreve como testar e verificar a infraestrutura de segurança implementada em Terraform para o Google Cloud Platform, garantindo que todos os componentes estejam funcionando conforme esperado.

## Pré-requisitos para Testes

Antes de iniciar os testes, certifique-se de que você possui:

- Credenciais GCP configuradas com permissões adequadas
- Terraform instalado (versão 1.0.0 ou superior)
- Google Cloud SDK instalado e configurado
- Um domínio registrado (caso deseje testar o módulo DNS)

## Processo de Implantação e Testes

### 1. Inicialização e Planejamento do Terraform

Primeiro, inicialize o Terraform e verifique o plano de execução para garantir que todos os recursos serão criados conforme esperado:

```bash
cd terraform
terraform init
terraform plan -var "project_id=seu-projeto-id" -var "domain_name=seu-dominio.com" -out=tfplan
```

Revise cuidadosamente o plano gerado, verificando se todos os módulos (WAF, IDS, Monitoramento e DNS) estão sendo criados corretamente e se não há erros de configuração.

### 2. Aplicação da Infraestrutura

Após validar o plano, aplique a infraestrutura:

```bash
terraform apply tfplan
```

Este processo pode levar alguns minutos, especialmente para recursos como Cloud IDS que exigem mais tempo para provisionamento. Monitore o progresso e verifique se não há erros durante a aplicação.

### 3. Verificação dos Recursos Criados

Após a conclusão bem-sucedida da aplicação do Terraform, verifique cada componente da infraestrutura:

### Verificação do WAF (Cloud Armor)

Verifique se a política de segurança do Cloud Armor foi criada corretamente:

```bash
gcloud compute security-policies describe $(terraform output -raw waf_security_policy_name)
```

Confirme que todas as regras configuradas estão presentes, incluindo proteções contra XSS, SQL Injection, e outras ameaças especificadas.

Para testar a eficácia do WAF, você pode simular ataques usando ferramentas como OWASP ZAP ou curl com payloads maliciosos, verificando se são bloqueados pela política de segurança.

### Verificação do IDS (Cloud IDS)

Verifique se os endpoints do Cloud IDS foram criados em todas as regiões configuradas:

```bash
for region in $(terraform output -json ids_endpoints | jq -r 'keys[]'); do
  echo "Verificando IDS na região $region"
  gcloud compute networks subnets describe $(terraform output -json ids_endpoints | jq -r ".[\"$region\"].name") --region=$region
done
```

Para testar o IDS, você pode gerar tráfego suspeito entre VMs na rede monitorada e verificar se os alertas são gerados no Cloud Security Command Center com a severidade "INFORMATIONAL".

### Verificação do Monitoramento

Acesse o dashboard de monitoramento criado através da URL fornecida pelo output do Terraform:

```bash
echo "URL do Dashboard: $(terraform output -raw monitoring_dashboard_url)"
```

No Console do Google Cloud, navegue até a seção de Monitoring e verifique:
- Se o dashboard está exibindo métricas para o Load Balancer
- Se os gráficos de contagem de requisições, latência e saúde dos backends estão funcionando
- Se os alertas configurados estão ativos

Gere algum tráfego para o Load Balancer e verifique se as métricas são atualizadas no dashboard.

### Verificação do DNS

Se você configurou um domínio, verifique se a zona DNS e os registros foram criados corretamente:

```bash
gcloud dns managed-zones describe $(terraform output -json dns_name_servers | jq -r '.[0]')
```

Anote os nameservers retornados pelo Terraform:

```bash
terraform output dns_name_servers
```

Configure esses nameservers no seu registrador de domínio. Após a propagação do DNS (que pode levar até 48 horas), teste a resolução dos domínios:

```bash
nslookup seu-dominio.com
nslookup grafana.seu-dominio.com
```

Verifique se os endereços IP retornados correspondem ao IP do Load Balancer e da VM do Grafana, respectivamente.

## Verificação de Integração

Para garantir que todos os componentes estão integrados corretamente:

1. Acesse o Load Balancer através do domínio configurado e verifique se o tráfego está sendo roteado corretamente.
2. Verifique se o WAF está protegendo o Load Balancer tentando acessar URLs com payloads maliciosos.
3. Monitore o dashboard para confirmar que as métricas estão sendo coletadas corretamente.
4. Verifique no Cloud Security Command Center se o IDS está detectando atividades suspeitas na rede.

## Solução de Problemas Comuns

### Problemas com o WAF
- Verifique se a política de segurança está associada ao Load Balancer
- Confirme que as regras têm as prioridades corretas (números menores têm precedência)

### Problemas com o IDS
- O provisionamento do Cloud IDS pode levar até 30 minutos
- Verifique se o packet mirroring está configurado corretamente
- Confirme que as VMs estão na mesma rede que o IDS está monitorando

### Problemas com o Monitoramento
- Pode levar alguns minutos para que as métricas comecem a aparecer nos dashboards
- Verifique se o projeto tem as APIs necessárias habilitadas (Monitoring API)

### Problemas com o DNS
- A propagação do DNS pode levar até 48 horas
- Verifique se os nameservers estão configurados corretamente no registrador
- Confirme que os registros A apontam para os IPs corretos

## Limpeza de Recursos

Quando não precisar mais da infraestrutura, você pode removê-la com:

```bash
terraform destroy -var "project_id=seu-projeto-id" -var "domain_name=seu-dominio.com"
```

Confirme a operação quando solicitado. Isso removerá todos os recursos criados pelo Terraform, exceto possíveis dados persistentes como logs e alertas já gerados.
