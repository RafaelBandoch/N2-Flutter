import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class HistoricoProfessorPage extends StatefulWidget {
  const HistoricoProfessorPage({super.key});

  @override
  State<HistoricoProfessorPage> createState() => _HistoricoProfessorPageState();
}

class _HistoricoProfessorPageState extends State<HistoricoProfessorPage> {
  final _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _usuario;
  List<Map<String, dynamic>> _aulas = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _usuario = args;
      _carregarHistorico();
    }
  }

  Future<void> _carregarHistorico() async {
    if (_usuario != null) {
      try {
        final aulas = await _dbHelper.getAulasProfessor(_usuario!['id']);
        if (mounted) {
          setState(() {
            _aulas = aulas;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('ERRO ao carregar histórico: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _apagarAula(int aulaId, String disciplina) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar a aula de "$disciplina"?\n\nEsta ação não pode ser desfeita e apagará todas as rodadas e presenças registradas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final sucesso = await _dbHelper.apagarAula(aulaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sucesso ? 'Aula apagada com sucesso!' : 'Erro ao apagar aula'),
            backgroundColor: sucesso ? Colors.green : Colors.red,
          ),
        );
        if (sucesso) {
          _carregarHistorico();
        }
      }
    }
  }

  void _verDetalhesAula(int aulaId) async {
    final estatisticas = await _dbHelper.getEstatisticasAula(aulaId);
    if (estatisticas != null && mounted) {
      final aula = estatisticas['aula'];
      final rodadas = estatisticas['rodadas'];
      final presencas = estatisticas['presencas'];
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Detalhes - ${aula['disciplina']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data: ${aula['data']}'),
              const SizedBox(height: 8),
              Text('Total de Rodadas: ${rodadas['total_rodadas']}'),
              Text('Rodadas Ativas: ${rodadas['rodadas_ativas']}'),
              Text('Rodadas Encerradas: ${rodadas['rodadas_encerradas']}'),
              Text('Rodadas Pendentes: ${rodadas['rodadas_pendentes']}'),
              const SizedBox(height: 8),
              Text('Total de Presenças: ${presencas['total_presencas']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeProfessor = _usuario?['nome'] ?? 'Professor';

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico - $nomeProfessor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarHistorico,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _aulas.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhuma aula encontrada',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _aulas.length,
                  itemBuilder: (context, index) {
                    final aula = _aulas[index];
                    return _buildCardAula(aula);
                  },
                ),
    );
  }

  Widget _buildCardAula(Map<String, dynamic> aula) {
    final disciplina = aula['disciplina'];
    final data = aula['data'];
    final aulaId = aula['id'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.school, color: Colors.blue),
        title: Text(
          disciplina,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Data: $data'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _verDetalhesAula(aulaId),
              tooltip: 'Ver detalhes',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _apagarAula(aulaId, disciplina),
              tooltip: 'Apagar aula',
            ),
          ],
        ),
      ),
    );
  }
}
