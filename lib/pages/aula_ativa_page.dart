import 'package:flutter/material.dart';
import '../data/database_helper.dart'; 
import 'dart:async';

class AulaAtivaPage extends StatefulWidget {
  const AulaAtivaPage({super.key});

  @override
  State<AulaAtivaPage> createState() => _AulaAtivaPageState();
}

class _AulaAtivaPageState extends State<AulaAtivaPage> {
  final _dbHelper = DatabaseHelper();
  late int _aulaId;
  List<Map<String, dynamic>> _rodadas = [];
  bool _isLoading = true;
  Timer? _timer;
  // ignore: unused_field
  int _rodadaAtual = 0; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _aulaId = ModalRoute.of(context)!.settings.arguments as int;
    _carregarRodadasEIniciarSimulacao();
  }

  @override
  void dispose() {
    _timer?.cancel();
    print("--- SIMULAÇÃO PARADA (TELA FECHADA) ---");
    super.dispose();
  }

  Future<void> _carregarRodadasEIniciarSimulacao() async {
    final rodadas = await _dbHelper.getRodadas(_aulaId);
    setState(() {
      _rodadas = rodadas;
      _isLoading = false;
    });

   
    if (_rodadas.every((r) => r['status'] == 'pendente')) {
      await _iniciarSimulacaoRodadasComTimestamps();
    } else {
      
      await _verificarEstadoAtualRodadas();
    }
  }


  Future<void> _atualizarListaRodadas() async {
    final rodadas = await _dbHelper.getRodadas(_aulaId);
    if (mounted) {
      setState(() {
        _rodadas = rodadas;
      });
    }
  }


  Future<void> _iniciarSimulacaoRodadasComTimestamps() async {
    const duracaoRodadaAtiva = Duration(seconds: 30);
    const duracaoIntervalo = Duration(seconds: 20);
    // ignore: unused_local_variable
    final cicloCompleto = duracaoRodadaAtiva + duracaoIntervalo; 

    print("--- SIMULAÇÃO DE AULA INICIADA COM TIMESTAMPS (Ciclo de 50s) ---");
    print("--- AS RODADAS CONTINUARÃO FUNCIONANDO EM BACKGROUND ---");

    final agora = DateTime.now();
    
   
    for (int i = 0; i < 4; i++) {
      final inicioRodada = agora.add(Duration(seconds: i * 50));
      final fimRodada = inicioRodada.add(duracaoRodadaAtiva);
      
    
      await _dbHelper.atualizarTimestampsRodada(_rodadas[i]['id'], inicioRodada, fimRodada);
    }

    
    await _dbHelper.atualizarStatusRodada(_rodadas[0]['id'], 'ativa');
    await _atualizarListaRodadas();

  
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _verificarEstadoAtualRodadas();
    });
  }

  Future<void> _verificarEstadoAtualRodadas() async {
    final agora = DateTime.now();
    
    for (int i = 0; i < _rodadas.length; i++) {
      final rodada = _rodadas[i];
      final inicio = rodada['inicio'] != null ? DateTime.parse(rodada['inicio']) : null;
      final fim = rodada['fim'] != null ? DateTime.parse(rodada['fim']) : null;
      
      if (inicio != null && fim != null) {
        String novoStatus = rodada['status'];
        
        if (agora.isBefore(inicio)) {
          novoStatus = 'pendente';
        } else if (agora.isAfter(inicio) && agora.isBefore(fim)) {
          novoStatus = 'ativa';
        } else if (agora.isAfter(fim)) {
          novoStatus = 'encerrada';
        }
        
        
        if (novoStatus != rodada['status']) {
          await _dbHelper.atualizarStatusRodada(rodada['id'], novoStatus);
        }
      }
    }
    
    
    await _atualizarListaRodadas();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendente':
        return Colors.grey.shade600;
      case 'ativa':
        return Colors.green.shade700;
      case 'encerrada':
        return Colors.red.shade700;
      default:
        return Colors.black;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pendente':
        return Icons.hourglass_empty;
      case 'ativa':
        return Icons.check_circle; 
      case 'encerrada':
        return Icons.stop_circle_outlined; 
      default:
        return Icons.question_mark;
    }
  }

  void _verPresencas(int rodadaId, int numRodada) async {
    final presencas = await _dbHelper.getPresencasRodada(rodadaId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Presentes na Rodada $numRodada'),
        content: SizedBox(
          width: double.maxFinite,
          child: presencas.isEmpty
              ? const Text('Nenhum aluno registrou presença.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: presencas.length,
                  itemBuilder: (context, index) {
                    final p = presencas[index];
                    
                    final timestamp = DateTime.parse(p['timestamp']);
                    final hora =
                        timestamp.toLocal().toString().split(' ')[1].substring(
                            0, 5);
                    return ListTile(
                      title: Text(p['nome']),
                      subtitle: Text('Registrado às: $hora'),
                    );
                  },
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aula em Andamento')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rodadas.length,
              itemBuilder: (context, index) {
                final rodada = _rodadas[index];
                final status = rodada['status'];
                final numRodada = rodada['numero_rodada'];
                return Card(
                  elevation: 2.0,
                  margin:
                      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 16.0),
                    leading: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 40,
                    ),
                    title: Text('Rodada $numRodada',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('Status: ${status.toUpperCase()}',
                        style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w500)),
                   
                    trailing: status != 'pendente'
                        ? IconButton(
                            tooltip: 'Ver lista de presença',
                            icon: const Icon(Icons.people_alt_outlined),
                            onPressed: () =>
                                _verPresencas(rodada['id'], numRodada),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}

