# Produção e operação

## Variáveis obrigatórias

- `SECRET_KEY_BASE` **ou** `RAILS_MASTER_KEY` (`config/master.key` / credentials)
- `MEDWORK_HUB_DATABASE_PASSWORD` ou `DATABASE_URL`
- SMTP em **Settings** (não dependa só do `.env` depois do primeiro save)

Não versione `.env` nem `config/master.key`.

## SSL

Produção assume HTTPS atrás de proxy (`force_ssl` + `assume_ssl`). Configure o reverse proxy (nginx, Caddy, load balancer) com o certificado.

## Uploads

Active Storage usa disco local. Com `AWS_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e, se precisar, `AWS_REGION`, produção passa a gravar no S3 (`config/storage.yml`, serviço `amazon`).

## Dados do paciente

Na ficha do paciente, **Exportar dados** baixa um JSON (nome, contato, histórico, reservas e notas). **Excluir paciente** apaga o cadastro e as notas; as reservas ficam, sem o vínculo. Profissional só alcança os próprios pacientes.

## E-mail

1. Admin → Configurações → E-mail: servidor, usuário, senha, remetente, host público dos links (`MAILER_HOST` / campos equivalentes).
2. Teste enviando um convite de usuário ou o e-mail de boas-vindas.
3. Cron de lembretes:

```cron
*/15 * * * * cd /app && bin/rails medwork:reminders
```

Sem esse cron, lembretes, faturas em atraso e o encerramento de chamados resolvidos **não** rodam. Convites e e-mails avulsos entram na fila do processo (`deliver_later`).

## Seed

`db:seed` **abort em production**. Use o painel para o primeiro admin, ou um rake/console controlado.

## Backup

PostgreSQL (pg_dump) + volume do Active Storage se ainda for disco. Auditoria e faturas são a fonte financeira — backup diário no mínimo.

## Processos

- Web: Puma (`bin/rails server` / `bin/dev` no local)
- Sem worker Redis obrigatório para o núcleo atual (jobs de lembrete são invocados pelo cron/rake)

## Checklist de go-live

- [ ] Postgres com senha forte e backup
- [ ] `SECRET_KEY_BASE` / master key
- [ ] SMTP testado (convite chega)
- [ ] PIX (chave, nome ≤ 25, cidade ≤ 15)
- [ ] Política de cancelamento alinhada com a recepção
- [ ] SLA de chamados
- [ ] Cron `medwork:reminders`
- [ ] HTTPS
- [ ] Admin real (não o seed) e senha trocada
