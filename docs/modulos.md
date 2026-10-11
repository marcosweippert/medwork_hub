# Módulos

## Painel

Rota: `/` (`dashboards#index`). Staff/admin. KPIs de receita do mês, a receber, atraso e chamados abertos, transações recentes e salas em destaque.

## Salas

CRUD em `/rooms`. Campos: nome, capacidade, valores (hora/dia/mês), abertura/fechamento, tipos (`room_types`).

- **Disponibilidade** `/rooms/availability`
- **Calendário da sala** `/rooms/:id/calendar` — grade de slots (`Setting#slot_minutes`)
- **Reservar** POST em `/rooms/:id/reservations`
- **Bloqueios** da sala (manutenção, uso interno)

Profissional só lista salas compatíveis.

## Reservas (agendamentos)

`/bookings` e `/bookings/calendar`. Ações: cancelar, remarcar, concluir. Notas de atendimento (`appointment_notes`).

Série recorrente usa `recurrence_group_id`.

Conflito: não sobrepõe outra reserva “holding” nem `RoomBlock`.

## Lista de espera

`/waitlist_entries`. Entrada por sala. Ações em lote e **converter** em reserva quando houver vaga. Relatório em `/reports/waitlist`.

## Profissionais e pacientes

Profissional liga-se a um `User` (`role: professional`) e a `practice_areas`. Pacientes podem ser associados à reserva.

## Faturas

`/invoices`. Status: aberta, paga, atrasada, cancelada, estornada.

- Marcar paga (`mark_paid!`) confirma horários (ou cancela se outro holding entrou no mesmo slot)
- Estornar, cancelar, cancelar horários selecionados
- Ações em lote (incluindo o conjunto filtrado)
- PIX: QR e código se a clínica tiver chave em Settings
- WhatsApp: link com o número configurado

**Billing** `/billing` e **Transações** `/transactions` — visão financeira para staff.

## Chamados

`/tickets`. Status: `open`, `in_progress`, `waiting`, `resolved`, `closed`. Prioridades: baixa a urgente. Categorias: financeiro, salas, agendamentos, técnico, outro.

- SLA por prioridade (Settings). Aviso antes do vencimento; “atrasado” depois
- Assignee padrão opcional
- Comentários; chamado resolvido/encerrado **não** aceita mensagem
- Assumir (`take`), resolver, reabrir
- Export CSV; ações em lote
- Encerramento automático de resolvidos após `ticket_auto_close_days` (job operacional)

Abertura notifica staff (e solicitante, conforme settings).

## Notificações

Sino no header. `/notifications` lista; marcar todas como lidas. Tipos atuais: chamado aberto e mensagem no chamado.

## Configurações (admin)

`/settings` em cartões:

- Clínica (nome, logo, semana, slots, sábado)
- Política de cancelamento (horas grátis, percentual atrasado / já iniciado)
- E-mail (SMTP, remetente, host dos links)
- PIX / WhatsApp
- Chamados (SLA, prioridade padrão, assignee, auto-close, quem notificar)

## Usuários

`/users`. Convite (`invite`) reenvia boas-vindas. Criação via `CreateUserAccount` (profissional aninhado se o papel for professional).

## E-mails outbound

`/outbound_emails`. Log do que o Hub enviou, reenvio, encaminhar, preview, modelo de boas-vindas. Sem SMTP, o corpo cai em `tmp/mail` no desenvolvimento.

Lembretes de reserva e fatura atrasada **não** rodam em cada request. Cron:

```bash
bin/rails medwork:reminders
```

(a cada 15 minutos é o intervalo sugerido.) O mesmo comando expira faturas em atraso e fecha chamados resolvidos antigos.

## Relatórios (staff)

`/reports` e rotas `/reports/*`: ocupação, receita, profissionais, recebíveis, reservas, cancelamentos, aging, salas, previsão, pico de horário, bloqueios, lista de espera, pacientes, e-mails, atividade.

## Auditoria (admin)

`/audit_events`. Criações, alterações e exclusões (`Auditable`). Filtros, exclusão, export **Excel** (`/audit_events/export`).

## Perfil

`/profile` — nome e dados da conta logada.
