import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class HistoricoAlunosPage extends StatefulWidget {
  const HistoricoAlunosPage({super.key});

  @override
  State<HistoricoAlunosPage> createState() => _HistoricoAlunosPageState();
}

class _HistoricoAlunosPageState extends State<HistoricoAlunosPage> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _alunos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarAlunos();
  }

  Future<void> _carregarAlunos() async {
    try {
      final alunos = await _dbHelper.getAlunos();
      if (mounted) {
        setState(() {
          _alunos = alunos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERRO ao carregar alunos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _verHistoricoAluno(int alunoId, String nomeAluno) async {
    final historico = await _dbHelper.getHistoricoCompletoAluno(alunoId);
    final estatisticas = await _dbHelper.getEstatisticasAluno(alunoId);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetalhesAlunoPage(
            alunoId: alunoId,
            nomeAluno: nomeAluno,
            historico: historico,
            estatisticas: estatisticas,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico por Aluno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarAlunos,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alunos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum aluno cadastrado',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alunos.length,
                  itemBuilder: (context, index) {
                    final aluno = _alunos[index];
                    return _buildCardAluno(aluno);
                  },
                ),
    );
  }

  Widget _buildCardAluno(Map<String, dynamic> aluno) {
    final nome = aluno['nome'];
    final email = aluno['email'];
    final alunoId = aluno['id'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            nome.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        title: Text(
          nome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(email),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _verHistoricoAluno(alunoId, nome),
      ),
    );
  }
}

class DetalhesAlunoPage extends StatefulWidget {
  final int alunoId;
  final String nomeAluno;
  final List<Map<String, dynamic>> historico;
  final Map<String, dynamic>? estatisticas;

  const DetalhesAlunoPage({
    super.key,
    required this.alunoId,
    required this.nomeAluno,
    required this.historico,
    this.estatisticas,
  });

  @override
  State<DetalhesAlunoPage> createState() => _DetalhesAlunoPageState();
}

class _DetalhesAlunoPageState extends State<DetalhesAlunoPage> {
  @override
  Widget build(BuildContext context) {
    final stats = widget.estatisticas?['estatisticas'];
    final totalRodadas = stats?['total_rodadas'] ?? 0;
    final presencas = stats?['presencas_registradas'] ?? 0;
    final ausencias = stats?['ausencias'] ?? 0;
    final frequencia = totalRodadas > 0 ? (presencas / totalRodadas * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico - ${widget.nomeAluno}'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estatísticas de Frequência',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Total', totalRodadas.toString(), Colors.blue),
                    _buildStatCard('Presentes', presencas.toString(), Colors.green),
                    _buildStatCard('Ausências', ausencias.toString(), Colors.red),
                    _buildStatCard('Frequência', '${frequencia.toStringAsFixed(1)}%', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: widget.historico.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum registro encontrado',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.historico.length,
                    itemBuilder: (context, index) {
                      final registro = widget.historico[index];
                      return _buildCardRegistro(registro);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCardRegistro(Map<String, dynamic> registro) {
    final data = registro['data'];
    final disciplina = registro['disciplina'];
    final rodada = registro['numero_rodada'];
    final statusPresenca = registro['status_presenca'];
    final timestamp = registro['timestamp'];
    
    final isPresente = statusPresenca == 'Presente';
    final cor = isPresente ? Colors.green : Colors.red;
    final icone = isPresente ? Icons.check_circle : Icons.cancel;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icone, color: cor),
        title: Text('$disciplina - Rodada $rodada'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: $data'),
            if (isPresente && timestamp != null)
              Text('Registrado: ${_formatarTimestamp(timestamp)}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusPresenca,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _formatarTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month} às ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
