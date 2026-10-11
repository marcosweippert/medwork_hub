# Papéis e permissões

Três papéis em `User::ROLES`: `admin`, `staff`, `professional`.

Login obrigatório em todas as páginas (Devise). Não há auto-cadastro (`devise_for :users, skip: [:registrations]`).

No primeiro acesso, se `must_change_password` estiver marcado, o usuário é obrigado a criar senha em `/password_change`.

## Resumo

| Área | Admin | Staff | Profissional |
| --- | --- | --- | --- |
| Painel | sim | sim | redireciona para Salas |
| Salas / calendário | todas | todas | só tipos da sua especialidade; não cria sala |
| Reservas | todas | todas | as suas |
| Lista de espera | todas | todas | a sua |
| Profissionais / pacientes | sim | sim | não |
| Faturas | todas + pagar/estornar | todas + pagar/estornar | só as suas; **não** marca paga |
| Chamados | fila completa | fila completa | só os que abriu; não muda status da fila |
| Relatórios | sim | sim | não |
| Usuários | sim (pode excluir) | sim (não exclui) | não |
| Configurações | sim | não | não |
| E-mails enviados | sim | não | não |
| Auditoria | sim | não | não |
| Billing / transações | sim | sim | não |
| Perfil | sim | sim | sim |

`clinic_staff?` = admin **ou** staff.

## Profissional

- Home: **Salas**.
- Calendário trava o profissional logado (não escolhe outro).
- Não vê salas de outro tipo (`Room.for_professional`).
- Não paga fatura, não cancela horários em lote, não abre billing nem auditoria.

## Staff

Opera a clínica (reservas, faturas, fila de chamados, relatórios, usuários), sem as telas de infraestrutura (SMTP, PIX, log de e-mail, auditoria).

Settings é **somente admin** (`require_admin`).

## Admin

Tudo o que o staff faz, mais configurações da clínica, e-mails outbound e auditoria.
