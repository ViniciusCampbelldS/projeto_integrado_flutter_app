import 'package:material_ui/material_ui.dart';

import 'api.dart';

class RecoveryDialog extends StatefulWidget {
  const RecoveryDialog({super.key, required this.api});

  final PortalApi api;

  @override
  State<RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<RecoveryDialog> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  bool busy = false;
  String? message;
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.recoverPassword(email.text.trim());
      if (mounted) setState(() => message = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = switch (e) {
            PortalError(status: 400) => 'Confira o e-mail informado.',
            PortalError(status: 429) =>
              'Muitas tentativas. Aguarde e tente novamente.',
            _ => 'Não foi possível solicitar a recuperação. Tente novamente.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Recuperar senha'),
      content: message != null
          ? Semantics(liveRegion: true, child: Text(message!))
          : Form(
              key: form,
              child: TextFormField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                maxLength: 254,
                decoration: InputDecoration(
                  labelText: 'E-mail cadastrado',
                  counterText: '',
                  errorText: error,
                  errorMaxLines: 3,
                ),
                validator: (value) => (value ?? '').trim().contains('@')
                    ? null
                    : 'Informe seu e-mail cadastrado.',
                onFieldSubmitted: (_) => send(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(message == null ? 'Cancelar' : 'Fechar'),
        ),
        if (message == null)
          FilledButton(
            onPressed: busy ? null : send,
            child: Text(busy ? 'Enviando…' : 'Enviar instruções'),
          ),
      ],
    ),
  );
}
