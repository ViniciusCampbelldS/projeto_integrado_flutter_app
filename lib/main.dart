import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'recovery_dialog.dart';

const blue = Color(0xff003d6c);
const orange = Color(0xffe27425);
const background = Color(0xfff3f7fa);
const line = Color(0xffdce5ec);
const documents = MethodChannel('br.com.mar/documentos');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment(
    'MAR_API_URL',
    defaultValue: 'http://10.0.2.2:8080/api/',
  );
  runApp(MarApp(api: PortalApi(Uri.parse(url.endsWith('/') ? url : '$url/'))));
}

class MarApp extends StatefulWidget {
  const MarApp({super.key, required this.api});
  final PortalApi api;

  @override
  State<MarApp> createState() => _MarAppState();
}

class _MarAppState extends State<MarApp> {
  String? name;

  void endSession() => setState(() {
    widget.api.token = null;
    name = null;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MAR',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: blue)
          .copyWith(primary: blue, secondary: orange),
      scaffoldBackgroundColor: background,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: name == null
        ? LoginPage(
            api: widget.api,
            onLogin: (value) => setState(() => name = value),
          )
        : EmployeePage(api: widget.api, name: name!, onExit: endSession),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});
  final PortalApi api;
  final ValueChanged<String> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final cpf = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    cpf.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final name = await widget.api.login(cpf.text.trim(), password.text);
      if (mounted) widget.onLogin(name);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = switch (e) {
          PortalError(status: 403) =>
            'O aplicativo é exclusivo para funcionários.',
          PortalError(status: 400 || 401) => 'Confira seu CPF e sua senha.',
          PortalError(status: 429) =>
            'Muitas tentativas. Aguarde e tente novamente.',
          _ => 'Não foi possível entrar. Tente novamente.',
        },
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MAR'),
      backgroundColor: blue,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Panel(
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/logo-mar.png',
                        height: 56,
                        fit: BoxFit.contain,
                        semanticLabel: 'MAR Metalúrgica',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Portal do funcionário',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: cpf,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.username],
                        maxLength: 14,
                        decoration: const InputDecoration(
                          labelText: 'CPF',
                          hintText: '000.000.000-00',
                          counterText: '',
                        ),
                        validator: (value) =>
                            RegExp(
                              r'^(?:[0-9]{11}|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2})$',
                            ).hasMatch((value ?? '').trim())
                            ? null
                            : 'Informe um CPF com 11 dígitos.',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        maxLength: 72,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => signIn(),
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          counterText: '',
                        ),
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Informe sua senha.' : null,
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : signIn,
                        child: Text(busy ? 'Entrando…' : 'Entrar'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => RecoveryDialog(api: widget.api),
                              ),
                        child: const Text('Esqueci minha senha'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EmployeePage extends StatefulWidget {
  const EmployeePage({
    super.key,
    required this.api,
    required this.name,
    required this.onExit,
  });
  final PortalApi api;
  final String name;
  final VoidCallback onExit;

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  int selected = 0;
  bool signingOut = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MAR  |  Portal do funcionário'),
      backgroundColor: blue,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout),
          onPressed: signingOut
              ? null
              : () async {
                  setState(() => signingOut = true);
                  try {
                    await widget.api.logout();
                  } catch (_) {
                    // A sessão local também termina se a conexão estiver indisponível.
                  }
                  if (mounted) widget.onExit();
                },
        ),
      ],
    ),
    body: SafeArea(
      child: PortalPage(
        key: ValueKey(selected),
        api: widget.api,
        name: widget.name,
        training: selected == 1,
        onExit: widget.onExit,
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.health_and_safety_outlined),
          label: 'Meus EPIs',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          label: 'Meus treinamentos',
        ),
      ],
    ),
  );
}

class PortalPage extends StatefulWidget {
  const PortalPage({
    super.key,
    required this.api,
    required this.name,
    required this.training,
    required this.onExit,
  });
  final PortalApi api;
  final String name;
  final bool training;
  final VoidCallback onExit;

  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> {
  late Future<List<Map<String, dynamic>>> records;
  Future<List<Map<String, dynamic>>>? sheets;
  bool savingPdf = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    records = fetch(widget.training ? 'treinamentos' : 'epis');
    if (!widget.training) sheets = fetch('fichas-epi');
  }

  Future<List<Map<String, dynamic>>> fetch(String path) async {
    try {
      return await widget.api.list(path);
    } on PortalError catch (error) {
      if (error.status == 401 && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onExit();
        });
      }
      rethrow;
    }
  }

  Future<void> download(int id) async {
    if (savingPdf) return;
    setState(() => savingPdf = true);
    try {
      final bytes = await widget.api.ficha(id);
      if (!mounted) return;
      final saved = await documents.invokeMethod<bool>('savePdf', {
        'id': id,
        'bytes': bytes,
      });
      if (mounted && saved == true) message('Ficha salva.');
    } on PortalError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        widget.onExit();
      } else {
        message('Não foi possível baixar a ficha.');
      }
    } catch (_) {
      if (mounted) message('Não foi possível salvar a ficha.');
    } finally {
      if (mounted) setState(() => savingPdf = false);
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(load);
      await Future.wait([records, if (sheets != null) sheets!])
          .then<void>((_) {}, onError: (Object _) {});
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        Text(
          'Olá, ${widget.name}',
          style: const TextStyle(color: Color(0xff667485)),
        ),
        Text(
          widget.training ? 'Meus treinamentos' : 'Meus EPIs',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: blue, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.training ? 'Consulte suas NRs e acompanhe os vencimentos.' : 'Consulte seus equipamentos, baixe fichas e relate desgaste ou dano.',
        ),
        const SizedBox(height: 20),
        section(
          widget.training
              ? 'Treinamentos obrigatórios'
              : 'Equipamentos vinculados',
          records,
          widget.training
              ? 'Nenhum treinamento registrado.'
              : 'Nenhum EPI vinculado.',
          widget.training ? trainingCard : equipmentCard,
        ),
        if (sheets != null) ...[
          const SizedBox(height: 22),
          section(
            'Fichas de entrega',
            sheets!,
            'Nenhuma ficha disponível.',
            (item) => Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined, color: blue),
                title: Text(label(item['nome'], 'Ficha de entrega')),
                subtitle: Text('Entrega em ${dateLabel(item['dataEntrega'])}'),
                trailing: IconButton(
                  tooltip: 'Salvar PDF',
                  icon: const Icon(Icons.download),
                  onPressed: savingPdf
                      ? null
                      : () => download(item['id'] as int),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget section(
    String title,
    Future<List<Map<String, dynamic>>> future,
    String empty,
    Widget Function(Map<String, dynamic>) card,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: blue),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Panel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Panel(
              child: Column(
                children: [
                  const Text('Não foi possível carregar os dados.'),
                  TextButton(
                    onPressed: () => setState(load),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          final items = snapshot.requireData;
          if (items.isEmpty) return Panel(child: Text(empty));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: card(item),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget equipmentCard(Map<String, dynamic> item) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined, color: blue),
          title: Text(label(item['nome'], 'Equipamento')),
          subtitle: Text(
            'CA ${label(item['ca'], '—')} • Vencimento ${dateLabel(item['vencimento'])}',
          ),
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(
              item['substituido'] == true ? 'Substituído' : 'Em uso',
              Colors.green.shade800,
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Relatar estado'),
              onPressed: () async {
                final sent = await showDialog<bool>(
                  context: context,
                  builder: (_) => ReportDialog(
                    api: widget.api,
                    id: item['id'] as int,
                    title: label(item['nome'], 'EPI'),
                  ),
                );
                if (mounted && sent == true) message('Relato enviado.');
              },
            ),
          ],
        ),
      ],
    ),
  );

  Widget trainingCard(Map<String, dynamic> item) {
    final (status, color) = trainingStatus(item);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined, color: orange),
            title: Text(label(item['nr'], 'Treinamento')),
            subtitle: item['nome'] == null
                ? null
                : Text(item['nome'].toString()),
          ),
          Text('Treinamento: ${dateLabel(item['data'])}'),
          Text('Vencimento: ${dateLabel(item['vencimento'])}'),
          const SizedBox(height: 8),
          StatusBadge(status, color),
        ],
      ),
    );
  }
}

String label(Object? value, String fallback) => value?.toString() ?? fallback;

String dateLabel(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

(String, Color) trainingStatus(Map<String, dynamic> item) {
  if (item['presente'] != true) return ('Não realizado', Colors.blueGrey);
  final due = DateTime.tryParse(item['vencimento']?.toString() ?? '');
  if (due == null) return ('Sem vencimento informado', Colors.blueGrey);
  final today = DateTime.now();
  final days = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days < 0) return ('Vencido', Colors.red.shade800);
  if (days <= (item['diasAviso'] as num? ?? 30))
    return ('Próximo do vencimento', Colors.brown);
  return ('Ativo', Colors.green.shade800);
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.api,
    required this.id,
    required this.title,
  });
  final PortalApi api;
  final int id;
  final String title;
  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const options = [
    'Distante do vencimento',
    'Desgaste leve',
    'Precisa substituição',
    'Danificado',
  ];
  final comment = TextEditingController();
  String status = options.first;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.relato(widget.id, status, comment.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'Não foi possível confirmar o envio do relato.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text('Relatar estado • ${widget.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Situação'),
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => status = value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              maxLength: 4000,
              maxLines: 3,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Comentário (opcional)',
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : send,
          child: Text(busy ? 'Enviando…' : 'Enviar'),
        ),
      ],
    ),
  );
}
