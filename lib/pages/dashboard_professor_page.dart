import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import 'dart:async';

class DashboardProfessorPage extends StatefulWidget {
  const DashboardProfessorPage({super.key});

  @override
  State<DashboardProfessorPage> createState() => _DashboardProfessorPageState();
}

class _DashboardProfessorPageState extends State<DashboardProfessorPage> {
  final _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _usuario;
  List<Map<String, dynamic>> _aulasAtivas = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _usuario = args;
      _carregarDados();
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _carregarAulasAtivas();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    await _carregarAulasAtivas();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarAulasAtivas() async {
    if (_usuario != null) {
      try {
        final aulas = await _dbHelper.getAulasAtivas(_usuario!['id']);
        if (mounted) {
          setState(() {
            _aulasAtivas = aulas;
          });
        }
      } catch (e) {
        print('ERRO ao carregar aulas ativas: $e');
      }
    }
  }

  void _irParaAulaAtiva(int aulaId) {
    Navigator.pushNamed(context, '/aulaAtiva', arguments: aulaId);
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
          _carregarAulasAtivas();
        }
      }
    }
  }

  void _verHistoricoAulas() {
    Navigator.pushNamed(context, '/historicoProfessor', arguments: _usuario);
  }

  void _verHistoricoAlunos() {
    Navigator.pushNamed(context, '/historicoAlunos');
  }

  @override
  Widget build(BuildContext context) {
    final nomeProfessor = _usuario?['nome'] ?? 'Professor';

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $nomeProfessor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_aulasAtivas.isNotEmpty) ...[
                    const Text(
                      'Aulas Ativas Hoje',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._aulasAtivas.map((aula) => _buildCardAulaAtiva(aula)),
                    const SizedBox(height: 24),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar Nova Aula'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/iniciarAula',
                          arguments: _usuario);
                    },
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('Ver Histórico de Aulas'),
                    onPressed: _verHistoricoAulas,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.people),
                    label: const Text('Histórico por Aluno'),
                    onPressed: _verHistoricoAlunos,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCardAulaAtiva(Map<String, dynamic> aula) {
    final disciplina = aula['disciplina'];
    final rodadasAtivas = aula['rodadas_ativas'] ?? 0;
    final rodadasEncerradas = aula['encerradas'] ?? 0;
    final rodadasPendentes = aula['rodadas_pendentes'] ?? 0;
    final totalRodadas = aula['total_rodadas'] ?? 0;

    Color statusColor = Colors.grey;
    String statusText = 'Sem atividade';
    IconData statusIcon = Icons.hourglass_empty;

    if (rodadasAtivas > 0) {
      statusColor = Colors.green;
      statusText = '$rodadasAtivas rodada(s) ativa(s)';
      statusIcon = Icons.play_circle_filled;
    } else if (rodadasPendentes > 0) {
      statusColor = Colors.orange;
      statusText = '$rodadasPendentes rodada(s) pendente(s)';
      statusIcon = Icons.schedule;
    } else if (rodadasEncerradas > 0) {
      statusColor = Colors.red;
      statusText = 'Aula finalizada';
      statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _irParaAulaAtiva(aula['id']),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      disciplina,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _apagarAula(aula['id'], disciplina),
                    tooltip: 'Apagar aula',
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Progresso: ${rodadasEncerradas}/$totalRodadas rodadas concluídas',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
