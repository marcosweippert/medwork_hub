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

After `bin/rails db:seed` (or `db:setup`). The seed does **not** send email.

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@medworkhub.com` | `MedWorkHub@123` |
| Staff | `staff@medworkhub.com` | `password` |
| Professional | `ana@medworkhub.com` … `lucas@medworkhub.com` | `password` |

Demo data: 8 rooms, 12 professionals, 36 patients, sample hourly bookings from **02/01/2024** to **30/10/2026** (dense around today, plus the 15th of each month). Invoices mix paid / open / overdue / cancelled / refunded, with most paid.

## Secrets

Do not commit `.env` or `config/master.key`. Encrypted credentials (`config/credentials.yml.enc`) are in the repo; each environment needs its own master key or `SECRET_KEY_BASE`.
