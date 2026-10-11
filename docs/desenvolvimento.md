# Desenvolvimento

## Layout de pastas (o que importa)

```
app/controllers/     # HTML
app/models/          # Booking, Invoice, Ticket, Setting…
app/services/        # CreateUserAccount, NotifyTicket, RoomCalendar, Reminders…
app/views/           # ERB; layouts/application + session
app/javascript/controllers/  # Stimulus (calendário, clipboard, notificações…)
app/assets/tailwind/ # tokens, shell, tailadmin, pages
config/locales/      # en.yml, pt-BR.yml, views.*.yml
db/migrate/
test/                # Minitest
docs/                # esta documentação
```

## Convenções

- Locale forçado: `I18n.locale = :pt-BR` em `ApplicationController`
- Textos de tela em `config/locales/views.pt-BR.yml` (espelho `views.en.yml`)
- YAML: chaves `yes` / `no` entre aspas (`"yes"`), senão viram boolean
- Models de negócio incluem `Auditable` quando a mudança deve ir ao log
- Profissional: `scope_to_current_professional` e `accessible_rooms`

## Jobs “no request”

`run_operational_jobs`: no máximo a cada 5 minutos (cache), `Invoice.expire_overdue!` e `Ticket.auto_close_stale!`.

Lembretes de e-mail: rake `medwork:reminders` → `ReminderDispatchJob`.

## CSS / JS

- Tailwind 4 via `tailwindcss-rails`; entrada `app/assets/tailwind/application.css`
- Estilos da shell em `adminator/*.css`
- Stimulus: `clipboard`, `slot-picker`, `booking-form`, `notifications`, `email-preview`, `bulk-select`

## Testes

Rodar o arquivo ou a suíte:

```bash
bin/rails test
bin/rails test test/controllers/bookings_controller_test.rb
```

Não use fixtures populadas; monte os records no teste.

## Branches recentes

| Branch | Conteúdo |
| --- | --- |
| `feat/invoice-filter-bulk-select` | Ações em lote de faturas no conjunto filtrado |
| `feat/tickets-ui-finance` | Tickets, UI e billing |
| `feat/hub-clinic-platform` | Plataforma da clínica (salas, faturas, chamados) |
