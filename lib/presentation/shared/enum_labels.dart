import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/entities/transaccion.dart';

String labelMoneda(Moneda moneda) {
  switch (moneda) {
    case Moneda.pen:
      return 'Soles (PEN)';
    case Moneda.usd:
      return 'Dólares (USD)';
  }
}

String labelTipoCuenta(TipoCuenta tipo) {
  switch (tipo) {
    case TipoCuenta.debito:
      return 'Débito';
    case TipoCuenta.credito:
      return 'Crédito';
    case TipoCuenta.billetera:
      return 'Billetera digital';
    case TipoCuenta.efectivo:
      return 'Efectivo';
  }
}

String labelMetodoPago(MetodoPago metodo) {
  switch (metodo) {
    case MetodoPago.efectivo:
      return 'Efectivo';
    case MetodoPago.transferencia:
      return 'Transferencia';
    case MetodoPago.tarjeta:
      return 'Tarjeta';
    case MetodoPago.yape:
      return 'Yape';
    case MetodoPago.plin:
      return 'Plin';
    case MetodoPago.otro:
      return 'Otro';
  }
}

String labelTipoDeuda(TipoDeuda tipo) {
  switch (tipo) {
    case TipoDeuda.tarjetaCredito:
      return 'Tarjeta de crédito';
    case TipoDeuda.prestamoPersonal:
      return 'Préstamo personal';
    case TipoDeuda.prestamoVehicular:
      return 'Préstamo vehicular';
    case TipoDeuda.hipoteca:
      return 'Hipoteca';
    case TipoDeuda.prestamoEstudiantil:
      return 'Préstamo estudiantil';
    case TipoDeuda.compraCuotas:
      return 'Compra a cuotas';
    case TipoDeuda.deudaInformal:
      return 'Deuda informal';
    case TipoDeuda.otro:
      return 'Otro';
  }
}

String labelTipoAcreedor(TipoAcreedor tipo) {
  switch (tipo) {
    case TipoAcreedor.entidadFinanciera:
      return 'Entidad financiera';
    case TipoAcreedor.personaNatural:
      return 'Persona natural';
    case TipoAcreedor.comercio:
      return 'Comercio';
  }
}

String labelTipoTasa(TipoTasa tipo) {
  return tipo == TipoTasa.fija ? 'Fija' : 'Variable';
}

String labelEstructuraPago(EstructuraPago estructura) {
  return estructura == EstructuraPago.cuotasFijas
      ? 'Cuotas fijas'
      : 'Pago libre';
}

String labelPeriodicidadCuota(PeriodicidadCuota periodicidad) {
  return periodicidad == PeriodicidadCuota.mensual ? 'Mensual' : 'Quincenal';
}

String placeholderNombreAcreedor(TipoAcreedor tipo) {
  return tipo == TipoAcreedor.personaNatural
      ? 'Ej. Juan Pérez'
      : 'Ej. BCP, Cuotas Perú';
}
