import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import 'dart:async';

class DashboardAlunoPage extends StatefulWidget {
  const DashboardAlunoPage({super.key});

  @override
  State<DashboardAlunoPage> createState() => _DashboardAlunoPageState();
}

class _DashboardAlunoPageState extends State<DashboardAlunoPage> {
  final _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _usuario;
  List<Map<String, dynamic>> _rodadasAtivas = [];
  List<Map<String, dynamic>> _historico = [];
  bool _isLoading = true;
  String _mensagemPresenca = '';
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _usuario = args;
      print('Usuário carregado: ${_usuario?['nome']} (ID: ${_usuario?['id']})');
      _carregarDados();
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _carregarRodadasAtivas();
      });
    } else {
      print('ERRO: Argumentos inválidos recebidos');
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      await _carregarRodadasAtivas();
      await _carregarHistorico();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERRO ao carregar dados: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _mensagemPresenca = 'Erro ao carregar dados. Verifique sua conexão.';
        });
      }
    }
  }

  Future<void> _carregarRodadasAtivas() async {
    try {
      final rodadas = await _dbHelper.getRodadasAtivas();
      if (mounted) {
        setState(() {
          _rodadasAtivas = rodadas;
        });
      }
    } catch (e) {
      print('ERRO ao carregar rodadas ativas: $e');
    }
  }

  Future<void> _carregarHistorico() async {
    if (_usuario != null) {
      try {
        final historico = await _dbHelper.getHistoricoAluno(_usuario!['id']);
        if (mounted) {
          setState(() {
            _historico = historico;
          });
        }
      } catch (e) {
        print('ERRO ao carregar histórico: $e');
      }
    }
  }

  Future<void> _registrarPresenca(int rodadaId) async {
    if (_usuario == null) {
      print('ERRO: Usuário é null ao tentar registrar presença');
      return;
    }

    try {
      final sucesso =
          await _dbHelper.registrarPresenca(_usuario!['id'], rodadaId);

      if (mounted) {
        setState(() {
          _mensagemPresenca = sucesso
              ? 'Presença registrada com sucesso!'
              : 'Você já registrou presença nesta rodada.';
        });

        await _carregarRodadasAtivas();
        await _carregarHistorico();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _mensagemPresenca = '';
            });
          }
        });
      }
    } catch (e) {
      print('ERRO ao registrar presença: $e');
      if (mounted) {
        setState(() {
          _mensagemPresenca = 'Erro ao registrar presença. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeAluno = _usuario?['nome'] ?? 'Aluno';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Dashboard - $nomeAluno'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.check), text: 'Dar Presença'),
              Tab(icon: Icon(Icons.history), text: 'Meu Histórico'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAbaPresenca(),
                  _buildAbaHistorico(),
                ],
              ),
      ),
    );
  }

  Widget _buildAbaPresenca() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_mensagemPresenca.isNotEmpty)
            Text(
              _mensagemPresenca,
              style: TextStyle(
                  color: _mensagemPresenca.contains('sucesso')
                      ? Colors.green
                      : Colors.orange),
            ),
          const SizedBox(height: 16),
          _rodadasAtivas.isEmpty
              ? const Expanded(
                  child: Center(
                    child: Text(
                      'Nenhuma rodada de chamada está ativa no momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: _rodadasAtivas.length,
                    itemBuilder: (context, index) {
                      final rodada = _rodadasAtivas[index];
                      return Card(
                        color: Colors.green.shade100,
                        child: ListTile(
                          title: Text(
                              'Rodada ${rodada['numero_rodada']} está ATIVA!'),
                          subtitle: const Text(
                              'Clique no botão para registrar sua presença.'),
                          trailing: ElevatedButton(
                            onPressed: () => _registrarPresenca(rodada['id']),
                            child: const Text('Presente!'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAbaHistorico() {
    return _historico.isEmpty
        ? const Center(
            child: Text('Você ainda não possui registros de presença.'))
        : ListView.builder(
            itemCount: _historico.length,
            itemBuilder: (context, index) {
              final registro = _historico[index];
              return ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
                title: Text(
                    '${registro['disciplina']} - Rodada ${registro['numero_rodada']}'),
                subtitle: Text(
                    '${registro['data']} às ${registro['timestamp'].split('T')[1].substring(0, 5)}'),
              );
            },
          );
  }
}
