import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/iniciar_aula_page.dart';
import 'pages/aula_ativa_page.dart';
import 'pages/dashboard_professor_page.dart';
import 'pages/historico_professor_page.dart';
import 'pages/historico_alunos_page.dart';
import 'pages/cadastro_aluno_page.dart';
import 'pages/dashboard_aluno_page.dart';

void main() {
  runApp(const AppChamada());
}

class AppChamada extends StatelessWidget {
  const AppChamada({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chamada Automatizada',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/iniciarAula': (context) => const IniciarAulaPage(),
        '/aulaAtiva': (context) => const AulaAtivaPage(),
        '/dashboardProfessor': (context) => const DashboardProfessorPage(),
        '/historicoProfessor': (context) => const HistoricoProfessorPage(),
        '/historicoAlunos': (context) => const HistoricoAlunosPage(),
        '/cadastroAluno': (context) => const CadastroAlunoPage(),
        '/dashboardAluno': (context) => const DashboardAlunoPage(),
      },
    );
  }
}
