# Visão geral

O **MedWork Hub** é o sistema da clínica para **reservar salas**, **cobrar profissionais (PIX)**, **atender pacientes na grade**, **abrir chamados** e **enviar avisos por e-mail**.

Não é prontuário clínico completo: o foco é ocupação de salas, financeiro da clínica e operação do dia a dia.

## O que o Hub cobre

- Grade de salas (tipos, horários, bloqueios, lista de espera)
- Reservas com fatura (aberta = reservado, paga = ocupado)
- PIX na fatura e atalho de WhatsApp
- Pacientes e profissionais (especialidades / áreas de atuação)
- Chamados com SLA, fila e notificações no header
- Relatórios de ocupação, receita, inadimplência, e-mails, etc.
- Auditoria (histórico + Excel)

## Stack

| Camada | Tecnologia |
| --- | --- |
| App | Ruby 3.2.4, Rails 7.1 |
| Banco | PostgreSQL |
| Auth | Devise (sessão; sem cadastro público) |
| Front | Turbo, Stimulus, Importmap, Tailwind CSS 4 |
| UI | Shell TailAdmin / Adminator (CSS em `app/assets/tailwind/`) |
| PIX QR | gem `rqrcode` |
| Testes | Minitest, Capybara |

## Conceitos

**Clínica** — um registro `Setting` (nome, logo, política de cancelamento, SMTP, PIX, SLA de chamados). `Setting.current` vale para o request.

**Sala** — espaço com tipos (`room_types`) alinhados às áreas do profissional. Só reserva quem `can_reserve?` aquele tipo.

**Reserva (`Booking`)** — intervalo na sala. Status interno: `pending`, `scheduled`, `confirmed`, `cancelled`, `completed`. No calendário o que importa é a fatura: **open → reservado**, **paid → ocupado**.

**Fatura (`Invoice`)** — cobra o profissional pela reserva (hora / dia / mês). Status: `open`, `paid`, `overdue`, `cancelled`, `refunded`. Atrasadas viram `overdue` automaticamente (job operacional a cada ~5 min).

**Chamado (`Ticket`)** — suporte interno. Profissional vê só os seus; staff/admin vê a fila.

## Fluxo típico

1. Staff/admin cadastra profissional e sala.
2. Profissional (ou recepção) escolhe horários no calendário da sala.
3. O Hub cria reserva + fatura em aberto (PIX se configurado).
4. Pagamento marca a fatura paga e confirma os horários (ou cancela se houver conflito).
5. Eventos disparam e-mail quando o SMTP está configurado.

## Repositório

Código: [github.com/marcosweippert/medwork_hub](https://github.com/marcosweippert/medwork_hub). Branch de trabalho recente da plataforma: `feat/hub-clinic-platform`.
