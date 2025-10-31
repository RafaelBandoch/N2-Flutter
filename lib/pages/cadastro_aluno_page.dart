import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class CadastroAlunoPage extends StatefulWidget {
  const CadastroAlunoPage({super.key});

  @override
  State<CadastroAlunoPage> createState() => _CadastroAlunoPageState();
}

class _CadastroAlunoPageState extends State<CadastroAlunoPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  String _mensagem = '';

  void _cadastrar() async {
    final nome = _nomeController.text;
    final email = _emailController.text;
    final senha = _senhaController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      setState(() {
        _mensagem = 'Por favor, preencha todos os campos.';
      });
      return;
    }

    try {
      await _dbHelper.cadastrarAluno(nome, email, senha);
      setState(() {
        _mensagem = 'Aluno cadastrado com sucesso! Pode fazer login.';
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      setState(() {
        _mensagem = 'Erro ao cadastrar. O email já pode estar em uso.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Aluno')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senhaController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cadastrar,
              child: const Text('Cadastrar'),
            ),
            if (_mensagem.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_mensagem,
                    style: TextStyle(
                        color: _mensagem.contains('Erro')
                            ? Colors.red
                            : Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}
