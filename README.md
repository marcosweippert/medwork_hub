# MedWork Hub

Clinic app for room reservations, professionals, patients, invoices (PIX), waitlist, reports, and email.

## Requirements

- Ruby 3.2.4
- PostgreSQL
- Node.js and Yarn (Bootstrap / FullCalendar)
- Bundler

## Setup

```bash
git clone https://github.com/marcosweippert/medwork_hub.git
cd medwork_hub
cp .env.example .env
bundle install
yarn install
bin/rails db:setup
```

`db:setup` creates the database, loads the schema, and runs `db/seeds.rb`. SMTP credentials live in Settings (admin UI) or in `.env`; the seed keeps existing SMTP values when it resets data.

Start the app:

```bash
bin/dev
```

Open [http://localhost:3000](http://localhost:3000).

## Seed logins

After `bin/rails db:seed` (or `db:setup`):

| Role | Email | Password |
| --- | --- | --- |
| Staff | `staff@medworkhub.com` | `password` |
| Professional | `ana@medworkhub.com` … `thiago@medworkhub.com` | `password` |
| Admin | `marcos.weippert@gmail.com` | temporary password in the welcome email |

The seed covers **02/01/2024 – 31/08/2026**: 300 professionals, 500 patients, rooms, bookings, paid / cancelled / refunded invoices, waitlist, notes, and audit events.

## Secrets

Do not commit `.env` or `config/master.key`. Encrypted credentials (`config/credentials.yml.enc`) are in the repo; each environment needs its own master key or `SECRET_KEY_BASE`.
