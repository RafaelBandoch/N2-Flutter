
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'chamada_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de Usuários (Professores e Alunos)
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL,
        tipo TEXT NOT NULL CHECK(tipo IN ('professor', 'aluno'))
      )
    ''');

    // Tabela de Aulas (criada pelo professor)
    await db.execute('''
      CREATE TABLE aulas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        disciplina TEXT NOT NULL,
        FOREIGN KEY (professor_id) REFERENCES usuarios (id)
      )
    ''');

    // Tabela das 4 Rodadas de chamada
    await db.execute('''
      CREATE TABLE rodadas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aula_id INTEGER NOT NULL,
        numero_rodada INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pendente',
        inicio REAL,
        fim REAL,
        FOREIGN KEY (aula_id) REFERENCES aulas (id)
      )
    ''');

    // Tabela de Presenças (registros dos alunos)
    await db.execute('''
      CREATE TABLE presencas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aluno_id INTEGER NOT NULL,
        rodada_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (aluno_id) REFERENCES usuarios (id),
        FOREIGN KEY (rodada_id) REFERENCES rodadas (id)
      )
    ''');

    // Criar um professor e um aluno padrão para teste
    await db.execute(
        "INSERT INTO usuarios (nome, email, senha, tipo) VALUES ('Professor Teste', 'prof@prof.com', '123', 'professor')");
    await db.execute(
        "INSERT INTO usuarios (nome, email, senha, tipo) VALUES ('Aluno Teste', 'aluno@aluno.com', '123', 'aluno')");
  }

  // --- Funções de Usuário ---

  Future<Map<String, dynamic>?> login(String email, String senha) async {
    final db = await database;
    final res = await db.query(
      'usuarios',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> cadastrarAluno(String nome, String email, String senha) async {
    final db = await database;
    return await db.insert('usuarios', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'tipo': 'aluno',
    });
  }

  Future<Map<String, dynamic>?> getUsuario(int id) async {
    final db = await database;
    final res =
        await db.query('usuarios', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  // --- Funções de Aula e Rodada (Professor) ---

  Future<int> iniciarAula(int professorId, String disciplina) async {
    final db = await database;
    final data = DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD

    // 1. Criar a aula
    int aulaId = await db.insert('aulas', {
      'professor_id': professorId,
      'data': data,
      'disciplina': disciplina,
    });

    // 2. Criar as 4 rodadas para essa aula
    for (int i = 1; i <= 4; i++) {
      await db.insert('rodadas', {
        'aula_id': aulaId,
        'numero_rodada': i,
        'status': 'pendente', // Estados: pendente, ativa, encerrada
      });
    }
    return aulaId;
  }

  Future<List<Map<String, dynamic>>> getRodadas(int aulaId) async {
    final db = await database;
    return await db.query('rodadas', where: 'aula_id = ?', whereArgs: [aulaId]);
  }

  Future<void> atualizarStatusRodada(int rodadaId, String status) async {
    final db = await database;
    await db.update('rodadas', {'status': status},
        where: 'id = ?', whereArgs: [rodadaId]);
  }

  Future<void> atualizarTimestampsRodada(int rodadaId, DateTime inicio, DateTime fim) async {
    final db = await database;
    await db.update('rodadas', {
      'inicio': inicio.toIso8601String(),
      'fim': fim.toIso8601String(),
    }, where: 'id = ?', whereArgs: [rodadaId]);
  }

  Future<List<Map<String, dynamic>>> getPresencasRodada(int rodadaId) async {
    final db = await database;
    // Junta tabela de presença com a de usuários para pegar o nome do aluno
    return await db.rawQuery('''
      SELECT p.*, u.nome 
      FROM presencas p
      JOIN usuarios u ON p.aluno_id = u.id
      WHERE p.rodada_id = ?
    ''', [rodadaId]);
  }

  // --- Funções de Aluno ---

  Future<List<Map<String, dynamic>>> getRodadasAtivas() async {
    final db = await database;
    final data = DateTime.now().toIso8601String().split('T').first;
    final agora = DateTime.now();
    
    // Pega rodadas que devem estar ativas baseado nos timestamps
    final rodadas = await db.rawQuery('''
      SELECT r.* FROM rodadas r
      JOIN aulas a ON r.aula_id = a.id
      WHERE a.data = ? AND r.inicio IS NOT NULL AND r.fim IS NOT NULL
    ''', [data]);
    
    // Filtra apenas as que estão realmente ativas no momento
    final rodadasAtivas = <Map<String, dynamic>>[];
    for (final rodada in rodadas) {
      final inicioStr = rodada['inicio'] as String?;
      final fimStr = rodada['fim'] as String?;
      final rodadaId = rodada['id'] as int?;
      
      if (inicioStr != null && fimStr != null && rodadaId != null) {
        final inicio = DateTime.parse(inicioStr);
        final fim = DateTime.parse(fimStr);
        
        if (agora.isAfter(inicio) && agora.isBefore(fim)) {
          // Atualiza o status no banco se necessário
          if (rodada['status'] != 'ativa') {
            await atualizarStatusRodada(rodadaId, 'ativa');
          }
          rodadasAtivas.add(rodada);
        } else if (agora.isAfter(fim) && rodada['status'] != 'encerrada') {
          // Marca como encerrada se passou do tempo
          await atualizarStatusRodada(rodadaId, 'encerrada');
        }
      }
    }
    
    return rodadasAtivas;
  }

  Future<bool> registrarPresenca(int alunoId, int rodadaId) async {
    final db = await database;
    // Verificar se já não registrou presença nesta rodada
    final jaRegistrou = await db.query('presencas',
        where: 'aluno_id = ? AND rodada_id = ?',
        whereArgs: [alunoId, rodadaId]);

    if (jaRegistrou.isNotEmpty) {
      return false; // Já registrou
    }

    await db.insert('presencas', {
      'aluno_id': alunoId,
      'rodada_id': rodadaId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return true; // Registrado com sucesso
  }

  // Para o Histórico do Aluno (Nota 8)
  Future<List<Map<String, dynamic>>> getHistoricoAluno(int alunoId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        a.data,
        a.disciplina,
        r.numero_rodada,
        p.timestamp
      FROM presencas p
      JOIN rodadas r ON p.rodada_id = r.id
      JOIN aulas a ON r.aula_id = a.id
      WHERE p.aluno_id = ?
      ORDER BY p.timestamp DESC
    ''', [alunoId]);
  }

  // --- Funções para Dashboard do Professor ---

  // Busca aulas ativas (que têm rodadas em andamento)
  Future<List<Map<String, dynamic>>> getAulasAtivas(int professorId) async {
    final db = await database;
    final data = DateTime.now().toIso8601String().split('T').first;
    
    return await db.rawQuery('''
      SELECT DISTINCT 
        a.id,
        a.disciplina,
        a.data,
        COUNT(r.id) as total_rodadas,
        COUNT(CASE WHEN r.status = 'ativa' THEN 1 END) as rodadas_ativas,
        COUNT(CASE WHEN r.status = 'encerrada' THEN 1 END) as rodadas_encerradas,
        COUNT(CASE WHEN r.status = 'pendente' THEN 1 END) as rodadas_pendentes
      FROM aulas a
      LEFT JOIN rodadas r ON a.id = r.aula_id
      WHERE a.professor_id = ? AND a.data = ?
      GROUP BY a.id, a.disciplina, a.data
      HAVING rodadas_ativas > 0 OR rodadas_pendentes > 0
      ORDER BY a.id DESC
    ''', [professorId, data]);
  }

  // Busca todas as aulas do professor (para histórico)
  Future<List<Map<String, dynamic>>> getAulasProfessor(int professorId) async {
    final db = await database;
    return await db.query('aulas', 
      where: 'professor_id = ?', 
      whereArgs: [professorId],
      orderBy: 'data DESC, id DESC'
    );
  }

  // Apaga uma aula e todas as suas rodadas e presenças relacionadas
  Future<bool> apagarAula(int aulaId) async {
    final db = await database;
    
    try {
      // Primeiro, busca todas as rodadas da aula
      final rodadas = await db.query('rodadas', where: 'aula_id = ?', whereArgs: [aulaId]);
      
      // Apaga todas as presenças das rodadas desta aula
      for (final rodada in rodadas) {
        await db.delete('presencas', where: 'rodada_id = ?', whereArgs: [rodada['id']]);
      }
      
      // Apaga todas as rodadas da aula
      await db.delete('rodadas', where: 'aula_id = ?', whereArgs: [aulaId]);
      
      // Por fim, apaga a aula
      final result = await db.delete('aulas', where: 'id = ?', whereArgs: [aulaId]);
      
      return result > 0;
    } catch (e) {
      print('ERRO ao apagar aula: $e');
      return false;
    }
  }

  // Busca estatísticas de uma aula específica
  Future<Map<String, dynamic>?> getEstatisticasAula(int aulaId) async {
    final db = await database;
    
    try {
      // Busca informações da aula
      final aula = await db.query('aulas', where: 'id = ?', whereArgs: [aulaId], limit: 1);
      if (aula.isEmpty) return null;
      
      // Busca estatísticas das rodadas
      final rodadas = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_rodadas,
          COUNT(CASE WHEN status = 'ativa' THEN 1 END) as rodadas_ativas,
          COUNT(CASE WHEN status = 'encerrada' THEN 1 END) as rodadas_encerradas,
          COUNT(CASE WHEN status = 'pendente' THEN 1 END) as rodadas_pendentes
        FROM rodadas 
        WHERE aula_id = ?
      ''', [aulaId]);
      
      // Busca total de presenças registradas
      final presencas = await db.rawQuery('''
        SELECT COUNT(*) as total_presencas
        FROM presencas p
        JOIN rodadas r ON p.rodada_id = r.id
        WHERE r.aula_id = ?
      ''', [aulaId]);
      
      return {
        'aula': aula.first,
        'rodadas': rodadas.first,
        'presencas': presencas.first,
      };
    } catch (e) {
      print('ERRO ao buscar estatísticas da aula: $e');
      return null;
    }
  }

  // --- Funções para Histórico por Aluno ---

  // Busca todos os alunos cadastrados
  Future<List<Map<String, dynamic>>> getAlunos() async {
    final db = await database;
    return await db.query('usuarios', 
      where: 'tipo = ?', 
      whereArgs: ['aluno'],
      orderBy: 'nome ASC'
    );
  }

  // Busca histórico completo de um aluno específico
  Future<List<Map<String, dynamic>>> getHistoricoCompletoAluno(int alunoId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        a.data,
        a.disciplina,
        r.numero_rodada,
        r.status as status_rodada,
        p.timestamp,
        CASE 
          WHEN p.id IS NOT NULL THEN 'Presente'
          ELSE 'Ausente'
        END as status_presenca
      FROM aulas a
      JOIN rodadas r ON a.id = r.aula_id
      LEFT JOIN presencas p ON r.id = p.rodada_id AND p.aluno_id = ?
      WHERE r.status IN ('ativa', 'encerrada')
      ORDER BY a.data DESC, r.numero_rodada ASC
    ''', [alunoId]);
  }

  // Busca estatísticas de frequência de um aluno
  Future<Map<String, dynamic>?> getEstatisticasAluno(int alunoId) async {
    final db = await database;
    
    try {
      // Busca informações do aluno
      final aluno = await db.query('usuarios', where: 'id = ?', whereArgs: [alunoId], limit: 1);
      if (aluno.isEmpty) return null;
      
      // Busca estatísticas de presença
      final stats = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_rodadas,
          COUNT(p.id) as presencas_registradas,
          COUNT(*) - COUNT(p.id) as ausencias
        FROM rodadas r
        LEFT JOIN presencas p ON r.id = p.rodada_id AND p.aluno_id = ?
        WHERE r.status IN ('ativa', 'encerrada')
      ''', [alunoId]);
      
      // Busca disciplinas que o aluno participou
      final disciplinas = await db.rawQuery('''
        SELECT DISTINCT a.disciplina
        FROM aulas a
        JOIN rodadas r ON a.id = r.aula_id
        WHERE r.status IN ('ativa', 'encerrada')
      ''');
      
      return {
        'aluno': aluno.first,
        'estatisticas': stats.first,
        'disciplinas': disciplinas.map((d) => d['disciplina']).toList(),
      };
    } catch (e) {
      print('ERRO ao buscar estatísticas do aluno: $e');
      return null;
    }
  }
}