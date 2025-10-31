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
      version: 2, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha TEXT NOT NULL,
        tipo TEXT NOT NULL CHECK(tipo IN ('professor', 'aluno')),
        matricula TEXT 
      )
    ''');

    await db.execute('''
      CREATE TABLE aulas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        disciplina TEXT NOT NULL,
        FOREIGN KEY (professor_id) REFERENCES usuarios (id)
      )
    ''');

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

    await db.execute('''
      CREATE TABLE configuracoes (
        aluno_id INTEGER PRIMARY KEY,
        notificacoes INTEGER DEFAULT 1,
        FOREIGN KEY (aluno_id) REFERENCES usuarios (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        "INSERT INTO usuarios (nome, email, senha, tipo, matricula) VALUES ('Professor Teste', 'prof@prof.com', '123', 'professor', 'PROF001')");
    await db.execute(
        "INSERT INTO usuarios (nome, email, senha, tipo, matricula) VALUES ('Aluno Teste', 'aluno@aluno.com', '123', 'aluno', 'ALUNO001')");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE usuarios ADD COLUMN matricula TEXT");
      } catch (e) {
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS configuracoes (
          aluno_id INTEGER PRIMARY KEY,
          notificacoes INTEGER DEFAULT 1,
          FOREIGN KEY (aluno_id) REFERENCES usuarios (id) ON DELETE CASCADE
        )
      ''');
    }
  }


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

  Future<int> cadastrarAluno(
      String nome, String email, String senha, String matricula) async {
    final db = await database;
    return await db.insert('usuarios', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'tipo': 'aluno',
      'matricula': matricula,
    });
  }

  Future<Map<String, dynamic>?> getUsuario(int id) async {
    final db = await database;
    final res =
        await db.query('usuarios', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> atualizarAluno(
      int id, String nome, String matricula, String email) async {
    final db = await database;
    await db.update(
      'usuarios',
      {'nome': nome, 'matricula': matricula, 'email': email},
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<Map<String, dynamic>?> pegarConfiguracao(int alunoId) async {
    final db = await database;
    final res = await db.query('configuracoes',
        where: 'aluno_id = ?', whereArgs: [alunoId], limit: 1);
    
    if (res.isNotEmpty) {
      return res.first;
    } else {
      await salvarConfiguracao(alunoId, true);
      return {'aluno_id': alunoId, 'notificacoes': 1};
    }
  }

  Future<void> salvarConfiguracao(int alunoId, bool notificacoes) async {
    final db = await database;
    await db.insert(
      'configuracoes',
      {'aluno_id': alunoId, 'notificacoes': notificacoes ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> limparDadosAluno(int alunoId) async {
    final db = await database;
    await db.delete('presencas', where: 'aluno_id = ?', whereArgs: [alunoId]);
    await db.delete('configuracoes', where: 'aluno_id = ?', whereArgs: [alunoId]);
    await db.delete('usuarios', where: 'id = ?', whereArgs: [alunoId]);
  }



  Future<int> iniciarAula(int professorId, String disciplina) async {
    final db = await database;
    final data = DateTime.now().toIso8601String().split('T').first; 

    int aulaId = await db.insert('aulas', {
      'professor_id': professorId,
      'data': data,
      'disciplina': disciplina,
    });

    for (int i = 1; i <= 4; i++) {
      await db.insert('rodadas', {
        'aula_id': aulaId,
        'numero_rodada': i,
        'status': 'pendente', 
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

  Future<List<Map<String, dynamic>>> getPresencasRodada(int rodadaId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, u.nome 
      FROM presencas p
      JOIN usuarios u ON p.aluno_id = u.id
      WHERE p.rodada_id = ?
    ''', [rodadaId]);
  }

 

  Future<List<Map<String, dynamic>>> getRodadasAtivas() async {
    final db = await database;
    final data = DateTime.now().toIso8601String().split('T').first;
    return await db.rawQuery('''
      SELECT r.* FROM rodadas r
      JOIN aulas a ON r.aula_id = a.id
      WHERE a.data = ? AND r.status = 'ativa'
    ''', [data]);
  }

  Future<bool> registrarPresenca(int alunoId, int rodadaId) async {
    final db = await database;
    final jaRegistrou = await db.query('presencas',
        where: 'aluno_id = ? AND rodada_id = ?',
        whereArgs: [alunoId, rodadaId]);

    if (jaRegistrou.isNotEmpty) {
      return false; 
    }

    await db.insert('presencas', {
      'aluno_id': alunoId,
      'rodada_id': rodadaId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return true; 
  }

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
}
