# Movie Analyst — IaC & CM Migration (Terraform + Ansible)

### Infrastructure as a code

Create the necessary scripts to automate the provisioning of the environments for the application.

### Configuration Management

Use any CM tool to automate the deployment of the application requirements in the newly created environment.

![Movie Analyst AWS Architecture][logo]

[logo]: movie_analyst_aws.png "First SetUp"

---

> **Revisión técnica:** Consulta [`REVIEW.md`](./REVIEW.md) para ver el análisis completo de hallazgos encontrados en la rama `main` y las correcciones implementadas en `agent-review`.

## Arquitectura Provisionada

- **VPC (`us-east-1a`, `us-east-1b`)**: 2 subnets públicas, 2 subnets privadas, Internet Gateway y NAT Gateway.
- **Capa Frontend (Subnets públicas)**: Application Load Balancer (HTTP :80) + Auto Scaling Group de instancias EC2 con Nginx (:80) -> Movie Analyst UI (:3030).
- **Capa Backend (Subnets privadas)**: Network Load Balancer interno (TCP :3000) + Auto Scaling Group de instancias EC2 ejecutando Movie Analyst API (:3000).
- **Base de Datos (Subnets privadas)**: Amazon RDS MySQL 8.0 (Multi-AZ configurable, cifrada, accesible únicamente desde el Security Group de backend en el puerto `3306`).
- **Ansible Control Node (Subnet pública `us-east-1b`)**: Instancia EC2 con rol IAM `AmazonEC2ReadOnlyAccess`, Ansible preinstalado vía `user_data` y acceso SSH restringido hacia los ASG de frontend y backend.

## Estructura del Repositorio

```text
.
├── README.md
├── REVIEW.md
├── movie_analyst_aws.png
├── terraform/
│   ├── main.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── vpc/
│   ├── frontend/
│   ├── backend/
│   └── ansible_management/
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml
    ├── playbook.yml
    ├── inventory/
    │   └── aws_ec2.yml
    ├── group_vars/
    │   └── all.yml.example
    └── roles/
        ├── common/
        ├── backend/
        └── frontend/
```

## Requisitos Previos

- [Terraform](https://developer.hashicorp.com/terraform) `>= 1.10.0`
- Credenciales de AWS configuradas mediante variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) o perfil de AWS CLI (`AWS_PROFILE`).
- Bucket S3 y tabla DynamoDB configurados para el backend remoto en [`terraform/backend.tf`](./terraform/backend.tf) (o ejecutar `terraform init -backend=false` para pruebas locales).
- Par de llaves SSH generado localmente:
  ```bash
  mkdir -p terraform/ssh-keys
  ssh-keygen -t ed25519 -f terraform/ssh-keys/key-pair -N ""
  ```

## 1. Provisionamiento de Infraestructura (Terraform)

```bash
cd terraform

# Copiar plantilla de variables y ajustar AMIs, CIDR SSH y password de MySQL
cp terraform.tfvars.example terraform.tfvars

# Inicializar, validar y revisar el plan
terraform init
terraform validate
terraform plan

# Aplicar infraestructura
terraform apply

# Obtener endpoints para Ansible
terraform output
```

## 2. Despliegue de la Aplicación (Ansible)

1. Copia el directorio `ansible/` y la llave privada hacia el **Control Node** (o usa `ssh -A` con agent forwarding):
   ```bash
   CONTROL_IP=$(terraform -chdir=terraform output -raw control_node_public_ip)
   scp -i terraform/ssh-keys/key-pair -r ansible ubuntu@${CONTROL_IP}:~/
   scp -i terraform/ssh-keys/key-pair terraform/ssh-keys/key-pair ubuntu@${CONTROL_IP}:~/.ssh/id_ed25519
   ```

2. Conéctate al Control Node, configura las variables con los outputs de Terraform y ejecuta el playbook:
   ```bash
   ssh -i terraform/ssh-keys/key-pair ubuntu@${CONTROL_IP}
   chmod 600 ~/.ssh/id_ed25519

   cd ~/ansible
   ansible-galaxy collection install -r requirements.yml

   cp group_vars/all.yml.example group_vars/all.yml
   # Edita group_vars/all.yml con `rds_address`, `nlb_dns_name` y `db_password`

   # Verificar descubrimiento dinámico de instancias
   ansible-inventory --graph

   # Ejecutar despliegue automatizado (backend -> frontend)
   ansible-playbook playbook.yml
   ```

3. Verifica la aplicación accediendo al DNS público del ALB:
   ```bash
   echo "http://$(terraform -chdir=terraform output -raw alb_dns_name)"
   ```