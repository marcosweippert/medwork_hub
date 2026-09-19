class WelcomeEmailTemplate
  DEFAULT_SUBJECT = "Welcome to {{clinic}} — your temporary password".freeze

  DEFAULT_HTML = <<~HTML.freeze
    <p style="margin:0 0 16px;font-size:16px;line-height:1.5;">Olá <strong>{{name}}</strong>,</p>
    <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#334155;">
      Sua conta no <strong>{{clinic}}</strong> foi criada. Use os dados abaixo no primeiro acesso.
    </p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#EFF6FF;border:1px solid #BFDBFE;border-radius:10px;margin:0 0 22px;">
      <tr>
        <td style="padding:16px 18px;">
          <p style="margin:0 0 8px;font-size:11px;letter-spacing:0.08em;text-transform:uppercase;color:#2563EB;">Acesso provisório</p>
          <p style="margin:0 0 6px;font-size:14px;color:#1E293B;"><strong>E-mail:</strong> {{email}}</p>
          <p style="margin:0 0 6px;font-size:14px;color:#1E293B;"><strong>Senha provisória:</strong> <span style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#FFFFFF;border:1px solid #BFDBFE;border-radius:6px;padding:2px 8px;">{{password}}</span></p>
          <p style="margin:0;font-size:14px;color:#1E293B;"><strong>Perfil:</strong> {{role}}</p>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 12px;font-size:14px;font-weight:700;color:#1E293B;">Passo a passo do primeiro acesso</p>
    <ol style="margin:0 0 22px;padding-left:20px;color:#334155;font-size:14px;line-height:1.7;">
      <li>Abra o MedWork Hub.</li>
      <li>Entre com o e-mail e a senha provisória desta mensagem.</li>
      <li>No primeiro login o sistema pede uma senha nova. Escolha uma senha pessoal e confirme.</li>
      <li>Depois disso você já pode usar o sistema normalmente.</li>
    </ol>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 22px;">
      <tr>
        <td style="background:#2563EB;border-radius:8px;">
          <a href="{{login_url}}" style="display:inline-block;padding:12px 20px;color:#FFFFFF;text-decoration:none;font-size:14px;font-weight:700;">Entrar no MedWork Hub</a>
        </td>
      </tr>
    </table>
    <p style="margin:0;font-size:13px;line-height:1.6;color:#64748B;">
      Por segurança, troque a senha provisória assim que entrar. Não compartilhe este e-mail.
    </p>
  HTML

  TOKENS = %w[name email password role clinic login_url].freeze

  def self.subject_for(setting: Setting.current, **vars)
    interpolate(setting.welcome_email_subject.presence || DEFAULT_SUBJECT, vars.merge(clinic: vars[:clinic] || setting.clinic_name))
  end

  def self.html_for(setting: Setting.current, **vars)
    interpolate(setting.welcome_email_html.presence || DEFAULT_HTML, vars.merge(clinic: vars[:clinic] || setting.clinic_name))
  end

  def self.preview_vars(setting = Setting.current)
    {
      name: "Maria Silva",
      email: "maria@example.com",
      password: "senha-provisoria",
      role: "Professional",
      clinic: setting.clinic_name.presence || "MedWork Hub",
      login_url: "https://example.com/users/sign_in"
    }
  end

  def self.interpolate(template, vars)
    values = vars.stringify_keys
    template.to_s.gsub(/\{\{\s*(\w+)\s*\}\}/) { values[$1].to_s }
  end
end
