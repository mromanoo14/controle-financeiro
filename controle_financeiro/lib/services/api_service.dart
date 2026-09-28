import 'dart:convert';
import '../models/transacao.dart';
import 'package:http/http.dart' as http;
import '../models/conta.dart';
import '../models/categoria.dart';
import '../models/gastos.dart';

class ApiService {
  final String baseUrl = 'http://127.0.0.1:8000';

  String? token;

  Map<String, String> get headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // =========================================================
  // AUTENTICAÇÃO
  // =========================================================

  Future<String> login(
    String email,
    String senha,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'senha': senha,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao fazer login: ${response.body}',
      );
    }

    final dados = jsonDecode(response.body);

    token = dados['access_token'];

    return token!;
  }

  void logout() {
    token = null;
  }

  // =========================================================
  // SALDO - TEMPORÁRIO
  // =========================================================

  Future<double> buscarSaldo() async {
    return 0;
  }

  Future<double> atualizarSaldo(double saldo) async {
    return saldo;
  }

  // =========================================================
  // GASTOS - LEGADO
  // =========================================================

  Future<List<Gasto>> listarGastos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gastos'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao listar gastos: ${response.statusCode}',
      );
    }

    final List dados = jsonDecode(response.body);

    return dados
        .map(
          (item) => Gasto(
            id: item['id'],
            descricao: item['descricao'],
            categoria: item['categoria'],
            valor: (item['valor'] as num).toDouble(),
            data: DateTime.parse(item['data']),
            formaPagamento: item['forma_pagamento'],
          ),
        )
        .toList();
  }

  Future<Gasto> criarGasto(Gasto gasto) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gastos'),
      headers: headers,
      body: jsonEncode({
        'descricao': gasto.descricao,
        'categoria': gasto.categoria,
        'valor': gasto.valor,
        'data': gasto.data.toIso8601String(),
        'forma_pagamento': gasto.formaPagamento,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao criar gasto: ${response.body}',
      );
    }

    final dados = jsonDecode(response.body);

    return Gasto(
      id: dados['id'],
      descricao: dados['descricao'],
      categoria: dados['categoria'],
      valor: (dados['valor'] as num).toDouble(),
      data: DateTime.parse(dados['data']),
      formaPagamento: dados['forma_pagamento'],
    );
  }

  Future<Gasto> editarGasto(Gasto gasto) async {
    final response = await http.put(
      Uri.parse('$baseUrl/gastos/${gasto.id}'),
      headers: headers,
      body: jsonEncode({
        'descricao': gasto.descricao,
        'categoria': gasto.categoria,
        'valor': gasto.valor,
        'data': gasto.data.toIso8601String(),
        'forma_pagamento': gasto.formaPagamento,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao editar gasto: ${response.body}',
      );
    }

    final dados = jsonDecode(response.body);

    return Gasto(
      id: dados['id'],
      descricao: dados['descricao'],
      categoria: dados['categoria'],
      valor: (dados['valor'] as num).toDouble(),
      data: DateTime.parse(dados['data']),
      formaPagamento: dados['forma_pagamento'],
    );
  }

  Future<void> excluirGasto(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/gastos/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao excluir gasto: ${response.statusCode}',
      );
    }
  }

  // =========================================================
  // CATEGORIAS
  // =========================================================

  Future<List<Categoria>> listarCategorias() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categorias/'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao listar categorias: ${response.body}',
      );
    }

    final List dados = jsonDecode(response.body);

    return dados
        .map(
          (item) => Categoria(
            id: item['id'],
            nome: item['nome'],
            orcamento: (item['orcamento'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<Categoria> criarCategoria(
    String nome,
    double orcamento,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categorias/'),
      headers: headers,
      body: jsonEncode({
        'nome': nome,
        'orcamento': orcamento,
        'ativa': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao criar categoria: ${response.body}',
      );
    }

    final dados = jsonDecode(response.body);

    return Categoria(
      id: dados['id'],
      nome: dados['nome'],
      orcamento: (dados['orcamento'] as num).toDouble(),
    );
  }

  Future<Categoria> editarCategoria(
    int id,
    String nome,
    double orcamento,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/categorias/$id'),
      headers: headers,
      body: jsonEncode({
        'nome': nome,
        'orcamento': orcamento,
        'ativa': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao editar categoria: ${response.body}',
      );
    }

    final dados = jsonDecode(response.body);

    return Categoria(
      id: dados['id'],
      nome: dados['nome'],
      orcamento: (dados['orcamento'] as num).toDouble(),
    );
  }

  // =========================================================
// TRANSAÇÕES
// =========================================================

Future<List<Transacao>> listarTransacoes() async {
  final response = await http.get(
    Uri.parse('$baseUrl/transacoes/'),
    headers: headers,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Erro ao listar transações: ${response.body}',
    );
  }

  final List dados = jsonDecode(response.body);

  return dados.map((item) {
    return Transacao(
      id: item['id'],
      contaId: item['conta_id'],
      categoriaId: item['categoria_id'],
      descricao: item['descricao'],
      tipo: item['tipo'],
      valor: (item['valor'] as num).toDouble(),
      data: DateTime.parse(item['data']),
      formaPagamento: item['forma_pagamento'],
      observacao: item['observacao'],
      recorrente: item['recorrente'],
    );
  }).toList();
}


Future<Transacao> criarTransacao(
  Transacao transacao,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/transacoes/'),
    headers: headers,
    body: jsonEncode({
      'conta_id': transacao.contaId,
      'categoria_id': transacao.categoriaId,
      'descricao': transacao.descricao,
      'tipo': transacao.tipo,
      'valor': transacao.valor,
      'data': transacao.data.toIso8601String().split('T').first,
      'forma_pagamento': transacao.formaPagamento,
      'observacao': transacao.observacao,
      'recorrente': transacao.recorrente,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Erro ao criar transação: ${response.body}',
    );
  }

  final item = jsonDecode(response.body);

  return Transacao(
    id: item['id'],
    contaId: item['conta_id'],
    categoriaId: item['categoria_id'],
    descricao: item['descricao'],
    tipo: item['tipo'],
    valor: (item['valor'] as num).toDouble(),
    data: DateTime.parse(item['data']),
    formaPagamento: item['forma_pagamento'],
    observacao: item['observacao'],
    recorrente: item['recorrente'],
  );
}


Future<void> excluirTransacao(int id) async {
  final response = await http.delete(
    Uri.parse('$baseUrl/transacoes/$id'),
    headers: headers,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Erro ao excluir transação: ${response.body}',
    );
  }
}

  // =========================================================
// CONTAS
// =========================================================

Future<List<Conta>> listarContas() async {
  final response = await http.get(
    Uri.parse('$baseUrl/contas/'),
    headers: headers,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Erro ao listar contas: ${response.body}',
    );
  }

  final List dados = jsonDecode(response.body);

  return dados.map((item) {
    return Conta(
      id: item['id'],
      nome: item['nome'],
      tipo: item['tipo'],
      saldoInicial: (item['saldo_inicial'] as num).toDouble(),
      ativa: item['ativa'],
    );
  }).toList();
}


Future<Conta> criarConta(
  Conta conta,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/contas/'),
    headers: headers,
    body: jsonEncode({
      'nome': conta.nome,
      'tipo': conta.tipo,
      'saldo_inicial': conta.saldoInicial,
      'ativa': conta.ativa,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Erro ao criar conta: ${response.body}',
    );
  }

  final item = jsonDecode(response.body);

  return Conta(
    id: item['id'],
    nome: item['nome'],
    tipo: item['tipo'],
    saldoInicial:
        (item['saldo_inicial'] as num).toDouble(),
    ativa: item['ativa'],
  );
}
}