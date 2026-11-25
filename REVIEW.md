# Auditoría Técnica de IaC (Terraform) y CM (Ansible)

Este documento resume la revisión del repositorio en la rama `main` frente a los requisitos del [`README.md`](./README.md) y el diagrama de arquitectura [`movie_analyst_aws.png`](./movie_analyst_aws.png), así como las correcciones e implementaciones realizadas en la rama `agent-review`.

---

## Veredicto sobre la rama `main`

**No cumplía con la tarea del README.**

1. **Infrastructure as Code (Terraform) — Parcial / Con bloqueadores críticos:**
   Aunque existía una estructura modular (`vpc`, `frontend`, `backend`, `ansible_management`), el código presentaba **errores bloqueantes que hacían fallar `terraform apply` en AWS**, errores de conectividad que impedían la comunicación entre capas y brechas de seguridad.
2. **Configuration Management (Ansible) — No implementado (0%):**
   El archivo `ansible/playbook.yml` estaba completamente vacío (`0 bytes`) y no existía inventario, configuración (`ansible.cfg`), variables ni roles para desplegar la aplicación.

---

## Matriz de Cumplimiento (README + Diagrama AWS)

| Componente / Requisito | Estado en `main` | Estado en `agent-review` |
| :--- | :--- | :--- |
| VPC (`us-east-1a/b`, subnets públicas/privadas, IGW, NAT GW) | Parcial (faltaba DNS hostnames/support, `map_public_ip_on_launch` y pin de versión) | Corregido |
| ALB público + Frontend ASG (`us-east-1a/b`, público) | Fallaba (política ASG duplicada, EC2 sin IP pública, SG permitía bypass `0.0.0.0/0`) | Corregido |
| NLB interno + Backend ASG (`us-east-1a/b`, privado) | Fallaba (`internal = false` en subnets privadas, health check TCP inválido con `path`, política ASG duplicada) | Corregido |
| RDS MySQL en subnets privadas (`us-east-1a/b`) | Fallaba en runtime (SG abría puerto `80` en lugar de `3306`, sin `db_name`, `multi_az = false`) | Corregido |
| Control Node Ansible en subnet pública `us-east-1b` | Fallaba (sin `key_name` para SSH, sin IAM role para inventario dinámico, sin Ansible instalado) | Corregido |
| Outputs de Terraform y plantilla `tfvars` | Vacíos (`outputs.tf` en 0 bytes, sin `terraform.tfvars.example`) | Implementado |
| Ansible CM (Playbook, inventario dinámico, roles) | Vacío (`ansible/playbook.yml` en 0 bytes) | Implementado |

---

## Hallazgos Detallados en `main`

### 1. Bloqueadores que hacían fallar `terraform apply`

1. **NLB configurado como internet-facing en subnets privadas** (`terraform/backend/main.tf:105-110`):
   - Tenía `internal = false` asignado a `var.vpc_private_subnets`. AWS rechaza la creación de un Load Balancer público en subnets sin ruta hacia un Internet Gateway, y además contradecía el diagrama donde el NLB es interno entre Frontend y Backend.
   - **Corrección:** cambiado a `internal = true`.

2. **Health Check inválido en Target Group TCP del NLB** (`terraform/backend/main.tf:118-129`):
   - Definía `protocol = "TCP"` pero incluía `path = "/"` y `timeout = 5` dentro de `health_check` (parámetros no válidos para health checks TCP en NLB).
   - **Corrección:** configurado `protocol = "TCP"` limpio sin `path` y parametrizado el puerto con `var.backend_app_port` (por defecto `3000`).

3. **Nombres duplicados en políticas de Auto Scaling** (`terraform/frontend/main.tf:133-159` y `terraform/backend/main.tf:212-238`):
   - Tanto `cpu_policy_up` como `cpu_policy_down` usaban exactamente el mismo nombre (`name = "cpu-policy-up"`), provocando colisión en AWS. Además, `TargetTrackingScaling` escala tanto hacia arriba como hacia abajo con una sola política; tener dos políticas `TargetTrackingScaling` sobre la misma métrica (`ASGAverageCPUUtilization` a 80% y 30%) genera conflictos de escalado.
   - **Corrección:** reemplazadas por una única política `TargetTrackingScaling` por capa con nombre único (`target_value = 70.0`).

### 2. Errores críticos de conectividad y operación

4. **Security Group de RDS MySQL abría puerto `80` en lugar de `3306`** (`terraform/backend/main.tf:19-33`):
   - El backend nunca podía conectarse a MySQL.
   - **Corrección:** puerto `3306` restringido estrictamente al Security Group de las instancias backend (`referenced_security_group_id = aws_security_group.sg_ec2.id`).

5. **Control Node sin par de llaves SSH (`key_name`)** (`terraform/ansible_management/main.tf:25-39`):
   - La instancia `aws_instance.control_node` no tenía `key_name`, impidiendo conectarse por SSH para operar Ansible. Además, su variable de subnet se llamaba `private_subnet` aunque recibía `module.vpc.public_subnets[1]`.
   - **Corrección:** adjuntado `key_name`, renombrada la variable a `public_subnet_id`, añadido perfil IAM con `AmazonEC2ReadOnlyAccess` para inventario dinámico y `user_data` para instalar Ansible y `boto3`.

6. **Instancias Frontend en subnets públicas sin IP pública** (`terraform/vpc/main.tf`, `terraform/frontend/main.tf:98-107`):
   - `terraform-aws-modules/vpc/aws` desactiva `map_public_ip_on_launch` por defecto y el Launch Template no tenía `associate_public_ip_address = true`. Sin IP pública en una subnet pública (cuya ruta por defecto es el IGW, no el NAT GW), las instancias no tienen salida a internet para instalar paquetes con Ansible.
   - **Corrección:** habilitado `map_public_ip_on_launch = true` en VPC y `associate_public_ip_address = true` en el Launch Template de frontend, más `enable_dns_hostnames = true` y `enable_dns_support = true`.

7. **Launch Templates sin `version = "$Latest"` y sin tags `Role`** (`terraform/frontend/main.tf`, `terraform/backend/main.tf`):
   - Sin `version = "$Latest"`, los ASG no aplican nuevas versiones del Launch Template. Sin el tag `Role = "frontend" | "backend"` propagado al arranque, Ansible no puede descubrir dinámicamente los nodos por rol.
   - **Corrección:** añadidos `version = "$Latest"` y tags `Name` y `Role` con `propagate_at_launch = true`.

### 3. Seguridad y buenas prácticas

8. **Credenciales AWS estáticas en `provider "aws"`** (`terraform/main.tf:11-15`):
   - Exigía `aws_access_key` y `aws_secret_key` como variables de Terraform.
   - **Corrección:** removidas del bloque `provider "aws"` para usar la cadena estándar de credenciales de AWS (variables de entorno, perfil AWS CLI o rol IAM/OIDC).

9. **Security Groups excesivamente permisivos**:
   - Frontend EC2 permitía HTTP (80) desde `0.0.0.0/0` (permitiendo saltarse el ALB). **Corrección:** restringido a `sg_alb`.
   - Backend EC2 permitía puerto 80 desde `0.0.0.0/0`. **Corrección:** restringido a los CIDRs de subnets de la VPC en `var.backend_app_port`.
   - SSH (22) en Frontend y Backend permitía toda la subnet pública `public_subnets[1]`. **Corrección:** restringido al Security Group `sg_control` del Control Node.
   - SSH (22) en Control Node parametrizado mediante `var.allowed_ssh_cidr` para restringirlo a la IP del operador.

10. **Higiene del código Terraform**:
    - Movido el bloque `backend "s3"` desde `terraform/main.tf` a `terraform/backend.tf` (antes vacío).
    - Eliminadas variables declaradas pero nunca usadas (`frontend_cidr_ip4_backend_target`, `backend_cidr_ip4_backend_target`).
    - Corregidos tipos `list` -> `list(string)` y descripciones copiadas erróneamente.
    - Poblados `terraform/outputs.tf`, `terraform/frontend/outputs.tf` y `terraform/backend/outputs.tf`.
    - Creado `terraform/terraform.tfvars.example`.

### 4. Configuration Management (Ansible)

11. **Implementación completa de Ansible** (`ansible/`):
    - `ansible/ansible.cfg`: configuración para inventario dinámico AWS y pipelining SSH.
    - `ansible/requirements.yml`: colecciones `amazon.aws` y `community.mysql`.
    - `ansible/inventory/aws_ec2.yml`: descubrimiento automático de instancias EC2 en ejecución agrupadas por tag `Role` (`role_frontend`, `role_backend`) conectando por IP privada desde el Control Node.
    - `ansible/group_vars/all.yml.example`: plantilla de variables enlazada con los outputs de Terraform (`rds_address`, `nlb_dns_name`, puertos y repositorios de la app).
    - `ansible/playbook.yml` y roles modulares:
      - `roles/common`: dependencias base y Node.js LTS.
      - `roles/backend`: despliegue de `movie-analyst-api`, `mysql-client`, carga inicial opcional del esquema SQL en RDS (con `run_once: true`), servicio `systemd` en puerto `3000`.
      - `roles/frontend`: despliegue de `movie-analyst-ui` apuntando a `BACK_HOST` (NLB interno), servicio `systemd` en puerto `3030` y reverse proxy Nginx en puerto `80`.
