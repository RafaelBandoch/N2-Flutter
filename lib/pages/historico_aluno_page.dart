import 'package:flutter/material.dart';
import '../data/database_helper.dart';


class HistoricoAlunoWidget extends StatefulWidget {
  final int alunoId;
  const HistoricoAlunoWidget({super.key, required this.alunoId});

  @override
  State<HistoricoAlunoWidget> createState() => _HistoricoAlunoWidgetState();
}

class _HistoricoAlunoWidgetState extends State<HistoricoAlunoWidget> {
  final _dbHelper = DatabaseHelper(); // Instância
  List<Map<String, dynamic>> _historicoCompleto = [];
  List<String> _disciplinas = ['Todas'];
  String _disciplinaFiltro = 'Todas';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    carregarHistorico();
  }

  Future<void> carregarHistorico() async {
    final presencas = await _dbHelper.getHistoricoAluno(widget.alunoId);

    final disciplinasUnicas =
        presencas.map((p) => p['disciplina'] as String).toSet();

    setState(() {
      _historicoCompleto = presencas;
      _disciplinas = ['Todas', ...disciplinasUnicas];
      _carregando = false;
    });
  }

  List<Map<String, dynamic>> get _historicoFiltrado {
    if (_disciplinaFiltro == 'Todas') return _historicoCompleto;
    return _historicoCompleto
        .where((h) => h['disciplina'] == _disciplinaFiltro)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            decoration:
                const InputDecoration(labelText: 'Filtrar por disciplina'),
            items: _disciplinas 
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            value: _disciplinaFiltro,
            onChanged: (value) {
              if (value != null) {
                setState(() => _disciplinaFiltro = value);
              }
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _historicoFiltrado.isEmpty
                ? const Center(child: Text('Nenhum registro encontrado'))
                : ListView.builder(
                    itemCount: _historicoFiltrado.length,
                    itemBuilder: (context, index) {
                      final item = _historicoFiltrado[index];
                      return Card(
                        color: Colors.green[100],
                        child: ListTile(
                          title: Text(item['disciplina']),
                          subtitle: Text(
                              'Rodada ${item['numero_rodada']} - ${item['data']}'),
                          trailing: const Icon(
                            Icons.check,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total de presenças: ${_historicoFiltrado.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
