# MAR • Portal do funcionário

App Flutter para Android. Com CPF e senha, o funcionário consulta os próprios EPIs e treinamentos, salva fichas de entrega em PDF e relata o estado de um EPI. O perfil administrador consulta e gerencia EPIs, treinamentos, NRs e funcionários. O catálogo de NRs não aparece para funcionários.

## Desenvolvimento

1. Inicie a API de `tst_app_backend` na porta 8080.
2. No emulador Android, execute `flutter run`. O endereço padrão é `http://10.0.2.2:8080/api/`.
3. Para uma API publicada, execute `flutter run --dart-define=MAR_API_URL=https://seu-backend/api/`. A versão de distribuição exige HTTPS.

Use o e-mail cadastrado em **Esqueci minha senha**. A entrega das instruções depende da configuração de e-mail da API principal. A sessão fica em memória. Funcionários só podem consultar os próprios registros; administradores têm acesso às telas administrativas. O relato aceita situação e comentário, conforme o contrato da API.

O administrador pode cadastrar e editar EPIs, registrar entregas com ficha PDF opcional, substituições e descartes, manter NRs e funcionários, definir senhas, criar e editar turmas e marcar presença. A edição de uma turma depende da nova rota da API principal e é bloqueada após o registro de presença. Os funcionários podem baixar fichas vinculadas às suas entregas.
