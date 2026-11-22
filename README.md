# MAR • Portal do funcionário

App Flutter para Android. Entre com o CPF e a senha da sua conta de funcionário do portal MAR para consultar EPIs e treinamentos, salvar fichas de entrega em PDF e relatar o estado de um EPI.

## Desenvolvimento

1. Inicie a API de `tst_app_backend` na porta 8080.
2. No emulador Android, execute `flutter run`. O endereço padrão é `http://10.0.2.2:8080/api/`.
3. Para uma API publicada, execute `flutter run --dart-define=MAR_API_URL=https://seu-backend/api/`. A versão de distribuição exige HTTPS.

Use o e-mail cadastrado em **Esqueci minha senha**. A entrega das instruções depende da configuração de e-mail da API principal. A sessão fica em memória. Cada conta só pode consultar os próprios registros. O relato aceita situação e comentário, conforme o contrato da API.
