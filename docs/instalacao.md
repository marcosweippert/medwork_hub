# Instalação (desenvolvimento)

## Requisitos

- Ruby **3.2.4**
- PostgreSQL (banco `medwork_hub_development` / `medwork_hub_test`)
- Bundler
- Node não é obrigatório para o dia a dia: CSS via `tailwindcss-rails`, JS via importmap

## Setup

```bash
git clone https://github.com/marcosweippert/medwork_hub.git
cd medwork_hub
cp .env.example .env
bundle install
bin/rails db:setup
```

`db:setup` cria o banco, carrega o schema e roda `db/seeds.rb`.

**Não rode seed em produção** — o seed aborta nesse ambiente.

O seed **não envia e-mail**. SMTP já salvo em Settings é preservado.

## Subir o app

```bash
bin/dev
```

Sobe Puma + Tailwind (Foreman / `Procfile.dev`). Padrão: [http://localhost:3000](http://localhost:3000).

Só o servidor Rails:

```bash
bin/rails server
```

## Logins do seed

| Papel | E-mail | Senha |
| --- | --- | --- |
| Admin | `admin@medworkhub.com` | `MedWorkHub@123` |
| Staff | `staff@medworkhub.com` | `password` |
| Profissionais | `ana@medworkhub.com` … `lucas@medworkhub.com` | `password` |

Há 12 profissionais de demonstração (medicina, odontologia, psicologia, fisioterapia, nutrição, fono), salas, reservas e faturas em um período de demo.

## Variáveis locais (`.env`)

Copie de `.env.example`. Em desenvolvimento, SMTP vazio grava e-mail em `tmp/mail` (não envia de verdade).

Campos principais: `SMTP_*`, `MAILER_FROM`, `MAILER_HOST`, `MAILER_PORT`, `MAILER_PROTOCOL`.

A senha SMTP da clínica, depois de salva em **Configurações → E-mail**, **não** é reescrita no `.env`.

## Testes

```bash
bin/rails test
```

Fixtures YAML estão vazias de propósito; os testes criam os registros. `I18n.locale` da UI é `pt-BR`.

## Banco

`config/database.yml` usa o adapter `postgresql`. Em produção use `DATABASE_URL` ou `MEDWORK_HUB_DATABASE_PASSWORD`.
