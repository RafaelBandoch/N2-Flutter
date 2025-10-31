import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(text: 'prof@prof.com');
  final _senhaController = TextEditingController(text: '123');
  final _dbHelper = DatabaseHelper();
  String _mensagemErro = '';

  void _fazerLogin() async {
    final email = _emailController.text;
    final senha = _senhaController.text;

    final usuario = await _dbHelper.login(email, senha);

    if (usuario != null) {
      setState(() {
        _mensagemErro = '';
      });
      if (usuario['tipo'] == 'professor') {
        Navigator.pushReplacementNamed(context, '/dashboardProfessor',
            arguments: usuario);
      } else {
        Navigator.pushReplacementNamed(context, '/dashboardAluno',
            arguments: usuario);
      }
    } else {
      setState(() {
        _mensagemErro = 'Email ou senha inválidos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chamada Automatizada - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              onPressed: _fazerLogin,
              child: const Text('Entrar'),
            ),
            if (_mensagemErro.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_mensagemErro,
                    style: const TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/cadastroAluno');
              },
              child: const Text('Não tem conta? Cadastre-se como Aluno'),
            ),
            const SizedBox(height: 20),
            const Text('Login Professor: prof@prof.com / 123',
                style: TextStyle(color: Colors.grey)),
            const Text('Login Aluno: aluno@aluno.com / 123',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}