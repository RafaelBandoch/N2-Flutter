import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class IniciarAulaPage extends StatefulWidget {
  const IniciarAulaPage({super.key});

  @override
  State<IniciarAulaPage> createState() => _IniciarAulaPageState();
}

class _IniciarAulaPageState extends State<IniciarAulaPage> {
  final _disciplinaController = TextEditingController(text: 'N2 - Dispositivos Móveis');
  final _dbHelper = DatabaseHelper();
  bool _isLoading = false;

  void _iniciarAula(int professorId) async {
    if (_disciplinaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite o nome da disciplina.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final aulaId = await _dbHelper.iniciarAula(
          professorId, _disciplinaController.text);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/aulaAtiva',
            arguments: aulaId);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar aula: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final professorId = usuario['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Nova Aula')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Preparar a aula de hoje (${DateTime.now().toLocal().toString().split(' ')[0]})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _disciplinaController,
              decoration: const InputDecoration(labelText: 'Nome da Disciplina'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _iniciarAula(professorId),
                    child: const Text('Confirmar e Iniciar Aula'),
                  ),
          ],
        ),
      ),
    );
  }
}
