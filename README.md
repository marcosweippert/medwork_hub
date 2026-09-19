# MedWork Hub

Clínica para reserva de salas, profissionais, pacientes, faturas (PIX), lista de espera, relatórios e e-mail.

## Requisitos

- Ruby 3.2.4
- PostgreSQL
- Bundler

## Setup

```bash
git clone https://github.com/marcosweippert/medwork_hub.git
cd medwork_hub
cp .env.example .env
bundle install
bin/rails db:setup
```

`db:setup` cria o banco, carrega o schema e roda `db/seeds.rb`. SMTP fica em Settings (admin) ou no `.env`; o seed preserva SMTP já salvo. **Não rode seed em produção** — o comando aborta nesse ambiente.

Suba o app:

```bash
bin/dev
```

Abra [http://localhost:3000](http://localhost:3000).

## Logins do seed

O seed **não** envia e-mail.

| Papel | E-mail | Senha |
| --- | --- | --- |
| Admin | `admin@medworkhub.com` | `MedWorkHub@123` |
| Staff | `staff@medworkhub.com` | `password` |
| Profissional | `ana@medworkhub.com` … `lucas@medworkhub.com` | `password` |

## Lembretes por e-mail

Lembretes de reserva e faturas em atraso **não** disparam em cada request. Rode no cron:

```bash
bin/rails medwork:reminders
```

Sugestão: a cada 15 minutos.

## Produção

Defina pelo menos:

- `SECRET_KEY_BASE` ou `RAILS_MASTER_KEY` (para `config/credentials.yml.enc` / `config/master.key`)
- `MEDWORK_HUB_DATABASE_PASSWORD` ou `DATABASE_URL`
- SMTP em Settings (a senha SMTP **não** é gravada de volta no `.env`)

O ambiente de produção assume SSL atrás de proxy (`force_ssl` + `assume_ssl`). Uploads usam disco local; em um host real troque `config/storage.yml` para S3 (ou equivalente).

## Segredos

Não versione `.env` nem `config/master.key`.
