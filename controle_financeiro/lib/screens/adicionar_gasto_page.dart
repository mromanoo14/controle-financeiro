import 'package:flutter/material.dart';
import '../models/gastos.dart';

class AdicionarGastoPage extends StatefulWidget {
  final List<String> categorias;
  final List<String> formasPagamento;
  final Gasto? gasto;

  const AdicionarGastoPage({
    super.key,
    required this.categorias,
    required this.formasPagamento,
    this.gasto,
  });

  @override
  State<AdicionarGastoPage> createState() => _AdicionarGastoPageState();
}

class _AdicionarGastoPageState extends State<AdicionarGastoPage> {
  late TextEditingController descricaoController;
  late TextEditingController valorController;

  String? categoriaSelecionada;
  String? formaPagamentoSelecionada;
  late DateTime dataSelecionada;

  bool get editando => widget.gasto != null;

  @override
  void initState() {
    super.initState();

    descricaoController = TextEditingController(
      text: widget.gasto?.descricao ?? '',
    );

    valorController = TextEditingController(
      text: widget.gasto?.valor.toString().replaceAll('.', ',') ?? '',
    );

    categoriaSelecionada = widget.gasto?.categoria;

    formaPagamentoSelecionada = widget.gasto?.formaPagamento;

    dataSelecionada = widget.gasto?.data ?? DateTime.now();
  }

  @override
  void dispose() {
    descricaoController.dispose();
    valorController.dispose();

    super.dispose();
  }

  Future<void> selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() {
        dataSelecionada = data;
      });
    }
  }

  String formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  void salvarGasto() {
    final descricao = descricaoController.text.trim();

    final valorTexto = valorController.text
        .trim()
        .replaceAll(',', '.');

    if (descricao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite uma descrição.'),
        ),
      );
      return;
    }

    if (valorTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um valor.'),
        ),
      );
      return;
    }

    final valor = double.tryParse(valorTexto);

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um valor válido.'),
        ),
      );
      return;
    }

    if (categoriaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria.'),
        ),
      );
      return;
    }

    if (formaPagamentoSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma forma de pagamento.'),
        ),
      );
      return;
    }

    final novoGasto = Gasto(
      descricao: descricao,
      categoria: categoriaSelecionada!,
      valor: valor,
      data: dataSelecionada,
      formaPagamento: formaPagamentoSelecionada!,
    );

    Navigator.pop(context, novoGasto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editando ? 'Editar gasto' : 'Adicionar gasto',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Gasolina',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor',
                hintText: 'Ex: 100,00',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: categoriaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: widget.categorias.map(
                (categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria),
                  );
                },
              ).toList(),
              onChanged: (valor) {
                setState(() {
                  categoriaSelecionada = valor;
                });
              },
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: selecionarData,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(
                  formatarData(dataSelecionada),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: formaPagamentoSelecionada,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                border: OutlineInputBorder(),
              ),
              items: widget.formasPagamento.map(
                (forma) {
                  return DropdownMenuItem(
                    value: forma,
                    child: Text(forma),
                  );
                },
              ).toList(),
              onChanged: (valor) {
                setState(() {
                  formaPagamentoSelecionada = valor;
                });
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: salvarGasto,
                icon: Icon(
                  editando ? Icons.save : Icons.add,
                ),
                label: Text(
                  editando ? 'Salvar alterações' : 'Adicionar gasto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}