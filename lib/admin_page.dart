import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';


import 'api.dart';

const _blue = Color(0xff003d6c);

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.api,
    required this.name,
    required this.onExit,
  });
  final PortalApi api;
  final String name;
  final VoidCallback onExit;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const resources = ['epis', 'treinamentos', 'nrs', 'funcionarios'];
  static const titles = ['EPIs', 'Treinamentos', 'NRs', 'Funcionários'];
  int selected = 0;
  bool signingOut = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('MAR | ${titles[selected]}'),
      backgroundColor: _blue,
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
                    /* A sessão local é encerrada mesmo sem rede. */
                  }
                  if (mounted) widget.onExit();
                },
        ),
      ],
    ),
    body: SafeArea(
      child: AdminList(
        key: ValueKey(selected),
        api: widget.api,
        resource: resources[selected],
        onExit: widget.onExit,
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.health_and_safety_outlined),
          label: 'EPIs',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          label: 'Treinamentos',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          label: 'NRs',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Funcionários',
        ),
      ],
    ),
  );
}

class AdminList extends StatefulWidget {
  const AdminList({
    super.key,
    required this.api,
    required this.resource,
    required this.onExit,
  });
  final PortalApi api;
  final String resource;
  final VoidCallback onExit;

  @override
  State<AdminList> createState() => _AdminListState();
}

class _AdminListState extends State<AdminList> {
  late Future<List<Map<String, dynamic>>> future;
  String search = '';
  bool busy = false;

  String get endpoint =>
      widget.resource == 'treinamentos' ? 'turmas' : widget.resource;
  String get title => switch (widget.resource) {
    'epis' => 'Gerenciar EPIs',
    'nrs' => 'Editar NRs',
    'funcionarios' => 'Gerenciar funcionários',
    _ => 'Gerenciar treinamentos',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = widget.api.adminList(endpoint);
  }

  void refresh() => setState(load);

  Future<void> edit([Map<String, dynamic>? item]) async {
    try {
      List<Map<String, dynamic>> nrs = [];
      List<Map<String, dynamic>> people = [];
      if (widget.resource == 'treinamentos' ||
          widget.resource == 'funcionarios') {
        setState(() => busy = true);
        nrs = await widget.api.adminList('nrs');
        if (widget.resource == 'treinamentos')
          people = await widget.api.adminList('funcionarios');
      }
      if (!mounted) return;
      setState(() => busy = false);
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AdminForm(
          api: widget.api,
          resource: endpoint,
          item: item,
          nrs: nrs,
          people: people,
        ),
      );
      if (result == true && mounted) refresh();
    } on PortalError catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      if (error.status == 401) {
        widget.onExit();
        return;
      }
      showMessage('Não foi possível carregar os dados necessários.');
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMessage('Não foi possível conectar ao serviço.');
      }
    }
  }

  void showMessage(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> deleteNr(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir NR?'),
        content: Text('Deseja excluir ${item['nome']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.adminDeleteNr((item['id'] as num).toInt());
      if (mounted) {
        showMessage('NR excluída.');
        refresh();
      }
    } on PortalError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        widget.onExit();
        return;
      }
      showMessage('Não foi possível excluir a NR; ela pode estar vinculada.');
    } catch (_) {
      if (mounted) showMessage('Não foi possível excluir a NR.');
    }
  }

  Future<void> presence(Map<String, dynamic> item, bool value) async {
    try {
      await widget.api.adminPresence(
        (item['id'] as num).toInt(),
        (item['funcionarioId'] as num).toInt(),
        value,
      );
      if (mounted) refresh();
    } on PortalError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        widget.onExit();
        return;
      }
      showMessage('Não foi possível salvar a presença.');
    } catch (_) {
      if (mounted) showMessage('Não foi possível salvar a presença.');
    }
  }

  Future<void> delivery() async {
    setState(() => busy = true);
    try {
      final people = await widget.api.adminList('funcionarios');
      final epis = await widget.api.availableEpis();
      if (!mounted) return;
      setState(() => busy = false);
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AdminForm(
          api: widget.api,
          resource: 'entregas',
          nrs: const [],
          people: people,
          available: epis,
        ),
      );
      if (saved == true && mounted) {
        showMessage('Entrega registrada.');
        refresh();
      }
    } on PortalError catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      if (error.status == 401) {
        widget.onExit();
        return;
      }
      showMessage('Não foi possível carregar os dados da entrega.');
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMessage('Não foi possível carregar os dados da entrega.');
      }
    }
  }

  Future<void> epiOperation(Map<String, dynamic> item, String operation) async {
    List<Map<String, dynamic>> available = [];
    try {
      if (operation == 'substituicao')
        available = await widget.api.availableEpis();
    } on PortalError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        widget.onExit();
        return;
      }
      showMessage('Não foi possível carregar os EPIs disponíveis.');
      return;
    } catch (_) {
      if (mounted)
        showMessage('Não foi possível carregar os EPIs disponíveis.');
      return;
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EpiOperationDialog(
        api: widget.api,
        item: item,
        operation: operation,
        available: available,
      ),
    );
    if (saved == true && mounted) {
      showMessage(
        operation == 'descarte'
            ? 'Descarte registrado.'
            : 'Substituição registrada.',
      );
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError &&
              snapshot.error is PortalError &&
              (snapshot.error as PortalError).status == 401) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onExit();
            });
          }
          final items = snapshot.data ?? [];
          final filtered = items
              .where(
                (item) => item.values.any(
                  (value) => value.toString().toLowerCase().contains(
                    search.toLowerCase(),
                  ),
                ),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              refresh();
              try {
                await future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: _blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.resource == 'treinamentos'
                      ? 'Consulte as turmas, marque presenças e cadastre novas turmas.'
                      : 'Consulte e atualize os registros cadastrados.',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => edit(),
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.resource == 'treinamentos'
                          ? 'Nova turma'
                          : 'Adicionar',
                    ),
                  ),
                ),
                if (widget.resource == 'epis')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy ? null : delivery,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('Registrar entrega'),
                    ),
                  ),
                const SizedBox(height: 12),
                if (snapshot.connectionState != ConnectionState.done || busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  Column(
                    children: [
                      const Text('Não foi possível carregar os dados.'),
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nenhum registro encontrado.'),
                  )
                else
                  for (final item in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: card(item),
                    ),
              ],
            ),
          );
        },
      );

  Widget card(Map<String, dynamic> item) {
    final isTraining = widget.resource == 'treinamentos';
    final name = isTraining
        ? (item['nrNome'] ?? 'Treinamento')
        : (item['nome'] ?? 'Registro');
    final detail = switch (widget.resource) {
      'epis' =>
        'CA ${item['ca']} • Lote ${item['lote']} • Validade ${item['vencimento']}',
      'nrs' =>
        'NR ${item['id']} • Validade: ${item['validadeMeses'] ?? 'não informada'} meses',
      'funcionarios' =>
        '${item['cargo'] ?? ''} • ${item['setor'] ?? ''} • ${item['status'] ?? ''}',
      _ =>
        'Turma #${item['id']} • ${item['data']} • ${item['funcionario'] ?? ''}',
    };
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.toString(),
              style: const TextStyle(color: _blue, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(detail),
            if (isTraining)
              TextButton.icon(
                onPressed: () => edit(item),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar turma'),
              ),
            if (isTraining && item['funcionarioId'] != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Presente'),
                value: item['presente'] == true,
                onChanged: (value) {
                  if (value != null) presence(item, value);
                },
              )
            else if (!isTraining)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => edit(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  if (widget.resource == 'funcionarios')
                    TextButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            PasswordDialog(api: widget.api, employee: item),
                      ),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Definir senha'),
                    ),
                  if (widget.resource == 'nrs')
                    TextButton.icon(
                      onPressed: () => deleteNr(item),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir'),
                    ),
                  if (widget.resource == 'epis' && item['dataDescarte'] == null)
                    TextButton(
                      onPressed: () => epiOperation(item, 'descarte'),
                      child: const Text('Descartar'),
                    ),
                  if (widget.resource == 'epis' &&
                      item['dataDescarte'] == null &&
                      item['substituido'] != true &&
                      (item['funcionarios'] as List? ?? []).isNotEmpty)
                    TextButton(
                      onPressed: () => epiOperation(item, 'substituicao'),
                      child: const Text('Substituir'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.api, required this.employee});
  final PortalApi api;
  final Map<String, dynamic> employee;
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (password.text.length < 8 ||
        password.text.length > 72 ||
        password.text != confirm.text) {
      setState(() => error = 'Use de 8 a 72 caracteres e confirme a senha.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.definePassword(
        (widget.employee['id'] as num).toInt(),
        password.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'Não foi possível definir a senha.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Definir senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A senha de ${widget.employee['nome']} será alterada e as sessões anteriores serão encerradas.',
            ),
            TextField(
              controller: password,
              obscureText: true,
              enabled: !busy,
              maxLength: 72,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              enabled: !busy,
              maxLength: 72,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Salvando...' : 'Definir senha'),
        ),
      ],
    ),
  );
}

class AdminForm extends StatefulWidget {
  const AdminForm({
    super.key,
    required this.api,
    required this.resource,
    this.item,
    required this.nrs,
    required this.people,
    this.available = const [],
  });
  final PortalApi api;
  final String resource;
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> nrs;
  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> available;
  @override
  State<AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<AdminForm> {
  final key = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final nrNames = <String>{};
  final peopleIds = <int>{};
  final epiIds = <int>{};
  Uint8List? ficha;
  String? fichaNome;
  int? nrId;
  String status = 'At';
  String role = 'field';
  bool busy = false;
  String? error;
  bool get editing => widget.item != null;

  Future<void> selecionarFicha() async {
    try {
      final file = await const MethodChannel('br.com.mar/documentos')
          .invokeMapMethod<String, dynamic>('pickPdf');
      if (!mounted || file == null) return;
      final bytes = file['bytes'];
      if (bytes is! Uint8List ||
          bytes.length > 5 * 1024 * 1024 ||
          bytes.length < 5)
        throw const FormatException();
      setState(() {
        ficha = bytes;
        fichaNome = (file['name'] as String?) ?? 'ficha.pdf';
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Não foi possível selecionar o PDF de até 5 MB.',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    final i = widget.item ?? {};
    for (final name in [
      'id',
      'nome',
      'ca',
      'lote',
      'vencimento',
      'validadeMeses',
      'cpf',
      'cargo',
      'setor',
      'email',
      'data',
      'horario',
    ]) {
      fields[name] = TextEditingController(text: i[name]?.toString() ?? '');
    }
    status = (i['status'] ?? 'At').toString();
    role = (i['permissoes'] ?? 'field').toString();
    nrNames.addAll((i['nRs'] as List? ?? []).map((e) => e.toString()));
    nrId = (i['nrId'] as num?)?.toInt();
    if (!editing) {
      fields['data']!.text = DateTime.now().toIso8601String().substring(0, 10);
      fields['horario']!.text = '08:00';
    } else if (widget.resource == 'turmas' &&
        fields['horario']!.text.length >= 5) {
      fields['horario']!.text = fields['horario']!.text.substring(0, 5);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget textField(
    String name,
    String label, {
    bool required = true,
    bool number = false,
    bool date = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: fields[name],
      enabled: enabled && !busy,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: date ? 'AAAA-MM-DD' : null,
      ),
      validator: (value) {
        final v = (value ?? '').trim();
        if (required && v.isEmpty) return 'Informe $label.';
        if (v.isNotEmpty &&
            number &&
            num.tryParse(v.replaceAll(',', '.')) == null)
          return 'Informe um número válido.';
        if (v.isNotEmpty &&
            date &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ||
                DateTime.tryParse(v) == null))
          return 'Use AAAA-MM-DD.';
        return null;
      },
    ),
  );

  Future<void> save() async {
    if (busy || !key.currentState!.validate()) return;
    final f = (String name) => fields[name]!.text.trim();
    final Map<String, dynamic> data;
    if (widget.resource == 'epis') {
      final linked = (widget.item?['funcionarios'] as List? ?? [])
          .map((e) => (e as Map)['id'])
          .toList();
      data = {
        'nome': f('nome'),
        'ca': int.tryParse(f('ca')),
        'lote': f('lote'),
        'vencimento': f('vencimento'),
        'substituido': widget.item?['substituido'] == true,
        'funcionarioIds': linked,
      };
      if (data['ca'] == null || (data['ca'] as int) <= 0) {
        setState(() => error = 'Informe um CA inteiro positivo.');
        return;
      }
    } else if (widget.resource == 'nrs') {
      final n = int.tryParse(f('id'));
      final validity = f('validadeMeses').isEmpty
          ? null
          : double.tryParse(f('validadeMeses').replaceAll(',', '.'));
      if (n == null || n < 0 || (validity != null && validity <= 0)) {
        setState(() => error = 'Confira o número e a validade da NR.');
        return;
      }
      data = {'id': n, 'nome': f('nome'), 'validadeMeses': validity};
    } else if (widget.resource == 'funcionarios') {
      final cpf = f('cpf').replaceAll(RegExp(r'\D'), '');
      if (cpf.length != 11) {
        setState(() => error = 'Informe um CPF com 11 dígitos.');
        return;
      }
      data = {
        'nome': f('nome'),
        'cpf': cpf,
        'cargo': f('cargo'),
        'setor': f('setor'),
        'email': f('email').isEmpty ? null : f('email'),
        'status': status,
        'permissoes': role,
        'nRs': nrNames.toList(),
      };
    } else if (widget.resource == 'turmas') {
      if (nrId == null ||
          (!editing && peopleIds.isEmpty) ||
          !RegExp(r'^\d{2}:\d{2}$').hasMatch(f('horario'))) {
        setState(
          () => error = 'Selecione a NR, funcionários e horário válido.',
        );
        return;
      }
      data = {
        'nrId': nrId,
        'data': f('data'),
        'horario': f('horario'),
        if (!editing) 'funcionarioIds': peopleIds.toList(),
      };
    } else {
      if (peopleIds.length != 1 || epiIds.isEmpty) {
        setState(() => error = 'Selecione um funcionário e ao menos um EPI.');
        return;
      }
      data = {
        'funcionarioId': peopleIds.single,
        'dataEntrega': f('data'),
        'epiIds': epiIds.toList(),
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.adminSave(
        widget.resource,
        data,
        id: editing ? (widget.item!['id'] as num).toInt() : null,
        pdf: widget.resource == 'entregas' ? ficha : null,
        pdfName: fichaNome,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error =
              'Não foi possível salvar. Confira os dados e tente novamente.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        editing
            ? 'Editar registro'
            : widget.resource == 'turmas'
            ? 'Nova turma'
            : 'Novo registro',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.resource == 'epis') ...[
                  textField('nome', 'Nome do EPI'),
                  textField('ca', 'CA', number: true),
                  textField('lote', 'Lote'),
                  textField('vencimento', 'Validade', date: true),
                ],
                if (widget.resource == 'nrs') ...[
                  textField(
                    'id',
                    'Número da NR',
                    number: true,
                    enabled: !editing,
                  ),
                  textField('nome', 'Nome da NR'),
                  textField(
                    'validadeMeses',
                    'Validade em meses',
                    number: true,
                    required: false,
                  ),
                ],
                if (widget.resource == 'funcionarios') ...[
                  textField('nome', 'Nome'),
                  textField('cpf', 'CPF'),
                  textField('cargo', 'Cargo', required: false),
                  textField('setor', 'Setor', required: false),
                  textField('email', 'E-mail', required: false),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Situação'),
                    items: const [
                      DropdownMenuItem(value: 'At', child: Text('Ativo')),
                      DropdownMenuItem(value: 'Af', child: Text('Afastado')),
                      DropdownMenuItem(value: 'In', child: Text('Inativo')),
                    ],
                    onChanged: busy ? null : (v) => setState(() => status = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items: const [
                      DropdownMenuItem(
                        value: 'field',
                        child: Text('Funcionário'),
                      ),
                      DropdownMenuItem(value: 'tst', child: Text('TST')),
                      DropdownMenuItem(value: 'rh', child: Text('RH')),
                      DropdownMenuItem(
                        value: 'gerencia',
                        child: Text('Gerência'),
                      ),
                      DropdownMenuItem(
                        value: 'ADM',
                        child: Text('Administrador'),
                      ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => role = v!),
                  ),
                  const SizedBox(height: 12),
                  const Text('NRs vinculadas'),
                  for (final n in widget.nrs)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(n['nome'].toString()),
                      value: nrNames.contains(n['nome']),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                nrNames.add(n['nome'].toString());
                              } else {
                                nrNames.remove(n['nome'].toString());
                              }
                            }),
                    ),
                ],
                if (widget.resource == 'turmas') ...[
                  DropdownButtonFormField<int>(
                    initialValue: nrId,
                    decoration: const InputDecoration(labelText: 'NR'),
                    isExpanded: true,
                    items: [
                      for (final n in widget.nrs)
                        if ((n['id'] as num).toInt() > 0)
                          DropdownMenuItem(
                            value: (n['id'] as num).toInt(),
                            child: Text(
                              n['nome'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => nrId = v),
                  ),
                  const SizedBox(height: 12),
                  textField('data', 'Data', date: true),
                  textField('horario', 'Horário (HH:MM)'),
                  if (!editing) const Text('Participantes'),
                  if (editing)
                    const Text(
                      'Os participantes e as presenças são preservados.',
                    ),
                  if (!editing)
                    for (final f in widget.people.where(
                      (f) => f['status'] == 'At' || f['status'] == 'Af',
                    ))
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(f['nome'].toString()),
                        value: peopleIds.contains((f['id'] as num).toInt()),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                final id = (f['id'] as num).toInt();
                                if (v == true) {
                                  peopleIds.add(id);
                                } else {
                                  peopleIds.remove(id);
                                }
                              }),
                      ),
                ],
                if (widget.resource == 'entregas') ...[
                  textField('data', 'Data da entrega', date: true),
                  TextButton.icon(
                    onPressed: busy ? null : selecionarFicha,
                    icon: const Icon(Icons.attach_file),
                    label: const Text(
                      'Selecionar ficha PDF (opcional, até 5 MB)',
                    ),
                  ),
                  if (fichaNome != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fichaNome!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover ficha',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  ficha = null;
                                  fichaNome = null;
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  const Text('Funcionário'),
                  for (final f in widget.people.where(
                    (f) => f['status'] == 'At' || f['status'] == 'Af',
                  ))
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(f['nome'].toString()),
                      value: peopleIds.contains((f['id'] as num).toInt()),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              peopleIds.clear();
                              if (v == true)
                                peopleIds.add((f['id'] as num).toInt());
                            }),
                    ),
                  const SizedBox(height: 12),
                  const Text('EPIs disponíveis'),
                  if (widget.available.isEmpty)
                    const Text('Nenhum EPI disponível para entrega.'),
                  for (final e in widget.available)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${e['nome']} • CA ${e['ca']} • #${e['id']}'),
                      value: epiIds.contains((e['id'] as num).toInt()),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              final id = (e['id'] as num).toInt();
                              if (v == true) {
                                epiIds.add(id);
                              } else {
                                epiIds.remove(id);
                              }
                            }),
                    ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Salvando...' : 'Salvar'),
        ),
      ],
    ),
  );
}

class EpiOperationDialog extends StatefulWidget {
  const EpiOperationDialog({
    super.key,
    required this.api,
    required this.item,
    required this.operation,
    required this.available,
  });
  final PortalApi api;
  final Map<String, dynamic> item;
  final String operation;
  final List<Map<String, dynamic>> available;
  @override
  State<EpiOperationDialog> createState() => _EpiOperationDialogState();
}

class _EpiOperationDialogState extends State<EpiOperationDialog> {
  final form = GlobalKey<FormState>();
  final motivo = TextEditingController();
  final data = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  int? novoId;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    motivo.dispose();
    data.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (widget.operation == 'substituicao' && novoId == null) {
      setState(() => error = 'Selecione o novo EPI.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.epiOperation(
        (widget.item['id'] as num).toInt(),
        widget.operation,
        {
          'motivo': motivo.text.trim(),
          'data': data.text.trim(),
          if (novoId != null) 'novoEpiId': novoId,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'Não foi possível registrar a operação. Confira os dados.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.operation == 'descarte' ? 'Descartar EPI' : 'Substituir EPI',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.item['nome'].toString()),
              if (widget.operation == 'substituicao')
                DropdownButtonFormField<int>(
                  initialValue: novoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Novo EPI'),
                  items: [
                    for (final e in widget.available)
                      DropdownMenuItem(
                        value: (e['id'] as num).toInt(),
                        child: Text(
                          '${e['nome']} • #${e['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => novoId = v),
                ),
              TextFormField(
                controller: motivo,
                enabled: !busy,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Motivo'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o motivo.' : null,
              ),
              TextFormField(
                controller: data,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Data (AAAA-MM-DD)',
                ),
                validator: (v) =>
                    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v ?? '') &&
                        DateTime.tryParse(v!) != null
                    ? null
                    : 'Informe uma data válida.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Salvando...' : 'Confirmar'),
        ),
      ],
    ),
  );
}
