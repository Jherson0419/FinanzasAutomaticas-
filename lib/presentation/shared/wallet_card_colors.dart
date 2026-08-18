import 'package:flutter/material.dart';

import '../../domain/entities/cuenta.dart';

/// Estilo visual fijo de la tarjeta wallet de una cuenta: un degradado de
/// dos tonos de la misma familia de color y un ícono, según `TipoCuenta`.
/// No es configurable por el usuario — es identidad visual de la app.
class WalletCardEstilo {
  final Color inicio;
  final Color fin;
  final IconData icono;

  const WalletCardEstilo({
    required this.inicio,
    required this.fin,
    required this.icono,
  });

  Gradient get degradado => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inicio, fin],
  );
}

const Map<TipoCuenta, WalletCardEstilo> walletCardEstilos = {
  TipoCuenta.efectivo: WalletCardEstilo(
    inicio: Color(0xFF33195A),
    fin: Color(0xFF5B3690),
    icono: Icons.payments_outlined,
  ),
  TipoCuenta.billetera: WalletCardEstilo(
    inicio: Color(0xFF8A3B23),
    fin: Color(0xFFC26440),
    icono: Icons.account_balance_wallet_outlined,
  ),
  TipoCuenta.debito: WalletCardEstilo(
    inicio: Color(0xFF0F4A42),
    fin: Color(0xFF1E7B6C),
    icono: Icons.credit_card,
  ),
  TipoCuenta.credito: WalletCardEstilo(
    inicio: Color(0xFF17346B),
    fin: Color(0xFF2F5FA6),
    icono: Icons.credit_card,
  ),
};
